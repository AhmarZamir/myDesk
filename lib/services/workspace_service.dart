import 'package:supabase_flutter/supabase_flutter.dart';

class WorkspaceService {
  SupabaseClient get _db => Supabase.instance.client;
  String get _uid => _db.auth.currentUser!.id;

  Future<List<Map<String, dynamic>>> documents() async {
    final data = await _db.from('documents').select().order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> addDocument({
    required String title,
    required String category,
    String? deskId,
    String visibility = 'private',
    DateTime? expiresAt,
  }) async {
    await _db.from('documents').insert({
      'owner_id': _uid,
      'desk_id': deskId,
      'title': title,
      'category': category,
      'storage_path': 'metadata-only',
      'visibility': visibility,
      'expires_at': expiresAt?.toIso8601String(),
    });
  }

  Future<void> deleteDocument(String id) => _db.from('documents').delete().eq('id', id);

  Future<List<Map<String, dynamic>>> bills() async {
    final data = await _db.from('bills').select().order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> addBill({
    required String title,
    required double amount,
    DateTime? dueDate,
    String? deskId,
  }) async {
    await _db.from('bills').insert({
      'owner_id': _uid,
      'desk_id': deskId,
      'title': title,
      'amount': amount,
      'due_date': dueDate?.toIso8601String().split('T').first,
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
  }) async {
    await _db.from('tasks').insert({
      'creator_id': _uid,
      'assignee_id': _uid,
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
    required bool theyOweMe,
    String? deskId,
  }) async {
    await _db.from('khata_entries').insert({
      'desk_id': deskId,
      'created_by': _uid,
      'creditor_id': theyOweMe ? _uid : _uid,
      'debtor_id': _uid,
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

  Future<List<Map<String, dynamic>>> desks() async {
    final data = await _db.from('desks').select('id,name,type').order('created_at');
    return List<Map<String, dynamic>>.from(data);
  }
}
