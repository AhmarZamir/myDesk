import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  final SupabaseClient _db;
  NotificationService([SupabaseClient? client]) : _db = client ?? Supabase.instance.client;

  String get _uid => _db.auth.currentUser!.id;

  Future<Map<String, int>> counts() async {
    final row = await _db.rpc('notification_counts');
    final data = (row as List).isEmpty ? <String, dynamic>{} : Map<String, dynamic>.from((row as List).first);
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
    final rows = await _db
        .from('notifications')
        .select()
        .eq('recipient_id', _uid)
        .order('created_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> markRead({String? kind}) => _db.rpc('mark_notifications_read', params: {'p_kind': kind});
}
