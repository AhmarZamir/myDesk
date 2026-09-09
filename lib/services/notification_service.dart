import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  final SupabaseClient _db;
  NotificationService([SupabaseClient? client]) : _db = client ?? Supabase.instance.client;

  String get _uid => _db.auth.currentUser!.id;

  Future<Map<String, int>> counts() async {
    final rows = await _db.rpc('notification_counts') as List;
    final data = rows.isEmpty ? <String, dynamic>{} : Map<String, dynamic>.from(rows.first);
    return {
      'task': (data['task_count'] as num?)?.toInt() ?? 0,
      'khata': (data['khata_count'] as num?)?.toInt() ?? 0,
      'total': (data['total_count'] as num?)?.toInt() ?? 0,
    };
  }

  Stream<List<Map<String, dynamic>>> stream() => _db
      .from('notifications')
      .stream(primaryKey: ['id'])
      .eq('recipient_id', _uid)
      .order('created_at', ascending: false);

  Future<List<Map<String, dynamic>>> recent({int limit = 12}) async {
    final rows = await _db.from('notifications').select().eq('recipient_id', _uid).order('created_at', ascending: false).limit(limit);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> markRead({String? kind}) => _db.rpc('mark_notifications_read', params: {'p_kind': kind});

  Future<void> markOneRead(String notificationId) => _db
      .from('notifications')
      .update({'read_at': DateTime.now().toIso8601String()})
      .eq('id', notificationId)
      .eq('recipient_id', _uid);
}
