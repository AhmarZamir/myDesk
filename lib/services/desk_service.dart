import 'package:supabase_flutter/supabase_flutter.dart';

class DeskService {
  final SupabaseClient _client;
  DeskService([SupabaseClient? client]) : _client = client ?? Supabase.instance.client;

  Future<List<Map<String, dynamic>>> fetchMyDesks() async {
    final rows = await _client.rpc('get_my_desks');
    return List<Map<String, dynamic>>.from(rows as List);
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

  Future<String> rotateInvite(String deskId) async {
    final result = await _client.rpc('rotate_desk_invite', params: {'p_desk_id': deskId});
    return result.toString();
  }

  Future<void> leaveDesk(String deskId) async {
    await _client.rpc('leave_desk', params: {'p_desk_id': deskId});
  }

  Future<void> deleteDesk(String deskId) async {
    await _client.rpc('delete_desk', params: {'p_desk_id': deskId});
  }

  Future<void> transferOwnership({required String deskId, required String newOwnerId}) async {
    await _client.rpc('transfer_desk_ownership', params: {
      'p_desk_id': deskId,
      'p_new_owner_id': newOwnerId,
    });
  }

  Future<void> setMemberRole({
    required String deskId,
    required String userId,
    required String role,
  }) async {
    await _client.rpc('set_desk_member_role', params: {
      'p_desk_id': deskId,
      'p_user_id': userId,
      'p_role': role,
    });
  }

  Future<void> removeMember({required String deskId, required String userId}) async {
    await _client.rpc('remove_desk_member', params: {
      'p_desk_id': deskId,
      'p_user_id': userId,
    });
  }
}
