import 'package:supabase_flutter/supabase_flutter.dart';

class DeskService {
  final SupabaseClient _client;
  DeskService([SupabaseClient? client]) : _client = client ?? Supabase.instance.client;

  Future<List<Map<String, dynamic>>> fetchMyDesks() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    final rows = await _client
        .from('desk_members')
        .select('role, joined_at, desks(id, name, type, owner_id, invite_code, created_at)')
        .eq('user_id', userId)
        .order('joined_at', ascending: false);

    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> fetchDeskMembers(String deskId) async {
    final rows = await _client.rpc('get_desk_members', params: {'p_desk_id': deskId});
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<Map<String, dynamic>> createDesk({required String name, required String type}) async {
    await _client.rpc('ensure_current_profile');
    final result = await _client.rpc('create_desk', params: {
      'p_name': name.trim(),
      'p_type': type,
    });
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> joinDesk(String inviteCode) async {
    await _client.rpc('ensure_current_profile');
    final result = await _client.rpc('join_desk', params: {
      'p_invite_code': inviteCode.trim(),
    });
    return Map<String, dynamic>.from(result as Map);
  }
}
