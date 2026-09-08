import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

class WorkspaceService {
  SupabaseClient get _db => Supabase.instance.client;
  String get _uid => _db.auth.currentUser!.id;

  Future<void> _ensureProfile() async {
    await _db.rpc('ensure_current_profile');
  }

  Future<List<Map<String, dynamic>>> documents() async {
    final data = await _db.from('documents').select().order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<List<Map<String, dynamic>>> desks() async {
    final data = await _db.from('desks').select('id,name,type').order('created_at');
    return List<Map<String, dynamic>>.from(data);
  }

  Future<List<Map<String, dynamic>>> deskMembers(String deskId) async {
    final data = await _db.rpc('get_desk_members', params: {'p_desk_id': deskId});
    return List<Map<String, dynamic>>.from(data as List);
  }

  Future<List<String>> documentRecipientIds(String documentId) async {
    final data = await _db
        .from('document_access')
        .select('user_id')
        .eq('document_id', documentId);
    return List<Map<String, dynamic>>.from(data)
        .map((row) => row['user_id'] as String)
        .toList();
  }

  Future<void> uploadDocument({
    required String title,
    required String category,
    required String fileName,
    required Uint8List bytes,
    String? deskId,
    String visibility = 'private',
    List<String> recipientIds = const [],
  }) async {
    await _ensureProfile();

    if (visibility != 'private' && deskId == null) {
      throw ArgumentError('A Shared Desk is required for shared documents.');
    }
    if (visibility == 'custom' && recipientIds.isEmpty) {
      throw ArgumentError('Select at least one person for custom access.');
    }

    final safeName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final storagePath = '$_uid/${DateTime.now().millisecondsSinceEpoch}_$safeName';

    await _db.storage.from('documents').uploadBinary(
      storagePath,
      bytes,
      fileOptions: const FileOptions(upsert: false),
    );

    String? documentId;
    try {
      final inserted = await _db.from('documents').insert({
        'owner_id': _uid,
        'desk_id': deskId,
        'title': title,
        'category': category,
        'storage_path': storagePath,
        'visibility': visibility,
      }).select('id').single();

      documentId = inserted['id'] as String;

      if (visibility == 'custom') {
        await _db.from('document_access').insert(
          recipientIds
              .where((id) => id != _uid)
              .toSet()
              .map((id) => {
                    'document_id': documentId,
                    'user_id': id,
                    'granted_by': _uid,
                  })
              .toList(),
        );
      }
    } catch (_) {
      if (documentId != null) {
        await _db.from('documents').delete().eq('id', documentId);
      }
      await _db.storage.from('documents').remove([storagePath]);
      rethrow;
    }
  }

  Future<void> updateDocumentAccess({
    required String documentId,
    required String visibility,
    String? deskId,
    List<String> recipientIds = const [],
  }) async {
    if (visibility != 'private' && deskId == null) {
      throw ArgumentError('A Shared Desk is required for shared documents.');
    }
    if (visibility == 'custom' && recipientIds.isEmpty) {
      throw ArgumentError('Select at least one person.');
    }

    await _db.from('documents').update({
      'visibility': visibility,
      'desk_id': visibility == 'private' ? null : deskId,
    }).eq('id', documentId);

    await _db.from('document_access').delete().eq('document_id', documentId);
    if (visibility == 'custom') {
      final rows = recipientIds
          .where((id) => id != _uid)
          .toSet()
          .map((id) => {
                'document_id': documentId,
                'user_id': id,
                'granted_by': _uid,
              })
          .toList();
      if (rows.isNotEmpty) await _db.from('document_access').insert(rows);
    }
  }

  Future<String> documentUrl(String storagePath) async =>
      _db.storage.from('documents').createSignedUrl(storagePath, 600);

  Future<void> deleteDocument(String id, String storagePath) async {
    await _db.from('documents').delete().eq('id', id);
    if (storagePath != 'metadata-only') {
      await _db.storage.from('documents').remove([storagePath]);
    }
  }

  Future<List<Map<String, dynamic>>> bills() async {
    final data = await _db.from('bills').select().order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> addBill({
    required String title,
    required double amount,
    DateTime? dueDate,
    String? deskId,
    String? assignedTo,
  }) async {
    await _ensureProfile();
    await _db.from('bills').insert({
      'owner_id': _uid,
      'desk_id': deskId,
      'title': title,
      'amount': amount,
      'due_date': dueDate?.toIso8601String().split('T').first,
      'assigned_to': assignedTo,
      'status': 'unpaid',
    });
  }

  Future<void> setBillStatus(String id, String status) =>
      _db.from('bills').update({'status': status}).eq('id', id);

  Future<void> deleteBill(String id) => _db.from('bills').delete().eq('id', id);

  Future<List<Map<String, dynamic>>> tasks() async {
    final data = await _db.from('tasks').select().order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> addTask({
    required String title,
    String? description,
    DateTime? dueDate,
    String priority = 'medium',
    String? deskId,
    String? assigneeId,
  }) async {
    await _ensureProfile();
    await _db.from('tasks').insert({
      'creator_id': _uid,
      'assignee_id': assigneeId ?? _uid,
      'desk_id': deskId,
      'title': title,
      'description': description,
      'due_date': dueDate?.toIso8601String(),
      'priority': priority,
      'status': 'pending',
    });
  }

  Future<void> setTaskStatus(String id, String status) =>
      _db.from('tasks').update({'status': status}).eq('id', id);

  Future<void> deleteTask(String id) => _db.from('tasks').delete().eq('id', id);

  Future<List<Map<String, dynamic>>> khataEntries() async {
    final data = await _db.from('khata_entries').select().order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> addKhataEntry({
    required double amount,
    required String note,
    required String counterpartyName,
    required bool theyOweMe,
    String? deskId,
  }) async {
    await _ensureProfile();
    await _db.from('khata_entries').insert({
      'desk_id': deskId,
      'created_by': _uid,
      'creditor_id': _uid,
      'debtor_id': _uid,
      'counterparty_name': counterpartyName,
      'direction': theyOweMe ? 'receivable' : 'payable',
      'amount': amount,
      'note': note,
      'status': 'open',
    });
  }

  Future<void> settleKhata(String id) => _db.from('khata_entries').update({
        'status': 'settled',
        'settled_at': DateTime.now().toIso8601String(),
      }).eq('id', id);

  Future<void> deleteKhata(String id) => _db.from('khata_entries').delete().eq('id', id);
}
