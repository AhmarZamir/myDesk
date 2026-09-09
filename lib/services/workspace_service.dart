import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

class WorkspaceService {
  SupabaseClient get _db => Supabase.instance.client;
  String get _uid => _db.auth.currentUser!.id;
  String get currentUserId => _uid;

  static const int maxDocumentBytes = 15 * 1024 * 1024;

  Future<void> _ensureProfile() async => _db.rpc('ensure_current_profile');

  Future<List<Map<String, dynamic>>> documents() async {
    final data = await _db.from('documents').select().order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<List<Map<String, dynamic>>> desks() async {
    final data = await _db.rpc('get_my_desks');
    return List<Map<String, dynamic>>.from(data as List);
  }

  Future<List<Map<String, dynamic>>> deskMembers(String deskId) async {
    final data = await _db.rpc('get_desk_members', params: {'p_desk_id': deskId});
    return List<Map<String, dynamic>>.from(data as List);
  }

  Future<List<String>> documentRecipientIds(String documentId) async {
    final data = await _db.from('document_access').select('user_id').eq('document_id', documentId);
    return List<Map<String, dynamic>>.from(data).map((row) => row['user_id'] as String).toList();
  }

  Future<void> uploadDocument({
    required String title,
    required String category,
    required String fileName,
    required Uint8List bytes,
    String? deskId,
    String visibility = 'private',
    List<String> recipientIds = const [],
    DateTime? expiresAt,
  }) async {
    await _ensureProfile();
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) throw ArgumentError('Document title is required.');
    if (bytes.isEmpty) throw ArgumentError('The selected file is empty.');
    if (bytes.length > maxDocumentBytes) throw ArgumentError('Files must be 15 MB or smaller.');
    if (!const {'private', 'desk', 'custom'}.contains(visibility)) throw ArgumentError('Invalid document visibility.');
    if (visibility == 'desk' && deskId == null) throw ArgumentError('A Shared Desk is required for whole-desk sharing.');
    if (visibility == 'custom' && recipientIds.where((id) => id != _uid).isEmpty) throw ArgumentError('Select at least one other person.');

    final safeName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final storagePath = '$_uid/${DateTime.now().millisecondsSinceEpoch}_$safeName';
    await _db.storage.from('documents').uploadBinary(storagePath, bytes, fileOptions: const FileOptions(upsert: false));

    String? documentId;
    try {
      final inserted = await _db.from('documents').insert({
        'owner_id': _uid,
        'desk_id': deskId,
        'title': cleanTitle,
        'category': category,
        'storage_path': storagePath,
        'visibility': visibility,
        'expires_at': expiresAt?.toIso8601String(),
      }).select('id').single();
      documentId = inserted['id'] as String;
      if (visibility == 'custom') {
        final rows = recipientIds.where((id) => id != _uid).toSet().map((id) => {'document_id': documentId, 'user_id': id, 'granted_by': _uid}).toList();
        if (rows.isNotEmpty) await _db.from('document_access').insert(rows);
      }
    } catch (_) {
      if (documentId != null) await _db.from('documents').delete().eq('id', documentId);
      await _db.storage.from('documents').remove([storagePath]);
      rethrow;
    }
  }

  Future<void> updateDocumentAccess({required String documentId, required String visibility, String? deskId, List<String> recipientIds = const []}) async {
    if (!const {'private', 'desk', 'custom'}.contains(visibility)) throw ArgumentError('Invalid document visibility.');
    if (visibility == 'desk' && deskId == null) throw ArgumentError('A Shared Desk is required.');
    if (visibility == 'custom' && recipientIds.where((id) => id != _uid).isEmpty) throw ArgumentError('Select at least one other person.');
    await _db.from('documents').update({'visibility': visibility, 'desk_id': visibility == 'private' ? null : deskId}).eq('id', documentId);
    await _db.from('document_access').delete().eq('document_id', documentId);
    if (visibility == 'custom') {
      final rows = recipientIds.where((id) => id != _uid).toSet().map((id) => {'document_id': documentId, 'user_id': id, 'granted_by': _uid}).toList();
      if (rows.isNotEmpty) await _db.from('document_access').insert(rows);
    }
  }

  Future<String> documentUrl(String storagePath) async => _db.storage.from('documents').createSignedUrl(storagePath, 600);
  Future<void> deleteDocument(String id, String storagePath) async {
    await _db.from('documents').delete().eq('id', id);
    if (storagePath != 'metadata-only') await _db.storage.from('documents').remove([storagePath]);
  }

  Future<List<Map<String, dynamic>>> bills() async {
    final data = List<Map<String, dynamic>>.from(await _db.from('bills').select().order('created_at', ascending: false));
    await _attachMemberNames(data, idField: 'assigned_to', outputField: 'assignee_name');
    return data;
  }

  Future<void> addBill({required String title, required double amount, DateTime? dueDate, String? deskId, String? assignedTo}) async {
    await _ensureProfile();
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) throw ArgumentError('Bill name is required.');
    if (!amount.isFinite || amount <= 0) throw ArgumentError('Amount must be greater than zero.');
    await _db.from('bills').insert({'owner_id': _uid, 'desk_id': deskId, 'title': cleanTitle, 'amount': amount, 'due_date': dueDate?.toIso8601String().split('T').first, 'assigned_to': assignedTo ?? _uid, 'status': 'unpaid'});
  }

  Future<void> setBillStatus(String id, String status) {
    if (!const {'paid', 'unpaid', 'overdue'}.contains(status)) throw ArgumentError('Invalid bill status.');
    return _db.from('bills').update({'status': status}).eq('id', id);
  }
  Future<void> deleteBill(String id) => _db.from('bills').delete().eq('id', id);

  Future<List<Map<String, dynamic>>> tasks() async {
    final data = List<Map<String, dynamic>>.from(await _db.from('tasks').select().order('created_at', ascending: false));
    await _attachMemberNames(data, idField: 'assignee_id', outputField: 'assignee_name');
    return data;
  }

  Future<void> addTask({required String title, String? description, DateTime? dueDate, String priority = 'medium', String? deskId, String? assigneeId}) async {
    await _ensureProfile();
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) throw ArgumentError('Task title is required.');
    if (!const {'low', 'medium', 'high'}.contains(priority)) throw ArgumentError('Invalid priority.');
    await _db.from('tasks').insert({'creator_id': _uid, 'assignee_id': assigneeId ?? _uid, 'desk_id': deskId, 'title': cleanTitle, 'description': description?.trim(), 'due_date': dueDate?.toIso8601String(), 'priority': priority, 'status': 'pending'});
  }

  Future<void> setTaskStatus(String id, String status) {
    if (!const {'pending', 'in_progress', 'completed'}.contains(status)) throw ArgumentError('Invalid task status.');
    return _db.from('tasks').update({'status': status}).eq('id', id);
  }
  Future<void> deleteTask(String id) => _db.from('tasks').delete().eq('id', id);

  Future<List<Map<String, dynamic>>> khataEntries() async {
    final data = await _db.from('khata_entries').select().order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> addKhataEntry({required double amount, required String note, required String counterpartyName, required bool theyOweMe, String? deskId, String? buddyUserId}) async {
    await _ensureProfile();
    if (!amount.isFinite || amount <= 0) throw ArgumentError('Amount must be greater than zero.');
    final person = counterpartyName.trim();
    if (person.isEmpty) throw ArgumentError('Person name is required.');
    await _db.from('khata_entries').insert({'desk_id': deskId, 'created_by': _uid, 'creditor_id': _uid, 'debtor_id': _uid, 'buddy_user_id': buddyUserId, 'counterparty_name': person, 'direction': theyOweMe ? 'receivable' : 'payable', 'amount': amount, 'note': note.trim(), 'status': 'open'});
  }

  Future<void> settleKhata(String id) => _db.from('khata_entries').update({'status': 'settled', 'settled_at': DateTime.now().toIso8601String()}).eq('id', id);
  Future<void> deleteKhata(String id) => _db.from('khata_entries').delete().eq('id', id);

  Future<Map<String, dynamic>> dashboardSnapshot() async {
    final results = await Future.wait<dynamic>([documents(), bills(), tasks(), desks(), khataEntries()]);
    final docs = results[0] as List<Map<String, dynamic>>;
    final billsData = results[1] as List<Map<String, dynamic>>;
    final tasksData = results[2] as List<Map<String, dynamic>>;
    final desksData = results[3] as List<Map<String, dynamic>>;
    final khata = results[4] as List<Map<String, dynamic>>;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final soon = today.add(const Duration(days: 7));
    final unpaidBills = billsData.where((b) => b['status'] != 'paid').toList();
    final overdueBills = unpaidBills.where((b) { final due = DateTime.tryParse('${b['due_date'] ?? ''}'); return due != null && due.isBefore(today); }).toList();
    final pendingTasks = tasksData.where((t) => t['status'] != 'completed').toList();
    final assignedTasks = pendingTasks.where((t) => t['assignee_id'] == _uid).toList();
    final dueSoonTasks = pendingTasks.where((t) { final due = DateTime.tryParse('${t['due_date'] ?? ''}'); return due != null && !due.isBefore(today) && !due.isAfter(soon); }).toList();
    final expiringDocs = docs.where((d) { final expiry = DateTime.tryParse('${d['expires_at'] ?? ''}'); return expiry != null && !expiry.isBefore(today) && !expiry.isAfter(today.add(const Duration(days: 30))); }).toList();
    final openKhata = khata.where((e) => e['status'] == 'open').toList();
    return {'documents': docs.length, 'unpaid_bills': unpaidBills.length, 'pending_tasks': pendingTasks.length, 'desks': desksData.length, 'open_khata': openKhata.length, 'overdue_bills': overdueBills, 'due_soon_tasks': dueSoonTasks, 'assigned_tasks': assignedTasks, 'expiring_documents': expiringDocs};
  }

  Future<void> _attachMemberNames(List<Map<String, dynamic>> rows, {required String idField, required String outputField}) async {
    final ownName = _db.auth.currentUser?.userMetadata?['full_name']?.toString();
    for (final row in rows) { final id = row[idField]?.toString(); if (id == _uid) row[outputField] = ownName?.isNotEmpty == true ? ownName : 'You'; }
    final deskIds = rows.map((r) => r['desk_id']?.toString()).whereType<String>().toSet();
    for (final deskId in deskIds) {
      try {
        final members = await deskMembers(deskId);
        final names = {for (final m in members) '${m['user_id']}': '${m['full_name']}'};
        for (final row in rows.where((r) => r['desk_id']?.toString() == deskId)) { final id = row[idField]?.toString(); if (id != null && names[id] != null) row[outputField] = names[id]; }
      } catch (_) {}
    }
  }
}
