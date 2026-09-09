import 'package:supabase_flutter/supabase_flutter.dart';

class BuddyService {
  final SupabaseClient _client;
  BuddyService([SupabaseClient? client]) : _client = client ?? Supabase.instance.client;

  Future<List<Map<String, dynamic>>> buddies() async {
    final rows = await _client.rpc('get_my_buddies');
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<String> createInviteToken() async {
    final token = await _client.rpc('create_buddy_invite');
    return token.toString();
  }

  String referralLink(String token) {
    final base = Uri.base;
    if (base.hasScheme && base.host.isNotEmpty) {
      return Uri(scheme: base.scheme, host: base.host, port: base.hasPort ? base.port : null, queryParameters: {'buddy': token}).toString();
    }
    return token;
  }

  Future<void> acceptInvite(String token) async {
    await _client.rpc('accept_buddy_invite', params: {'p_token': token.trim().toLowerCase()});
  }

  Future<void> removeBuddy(String userId) async {
    await _client.rpc('remove_buddy', params: {'p_buddy_user_id': userId});
  }

  Future<void> addBuddyToDesk({required String deskId, required String buddyUserId}) async {
    await _client.rpc('add_buddy_to_desk', params: {
      'p_desk_id': deskId,
      'p_buddy_user_id': buddyUserId,
    });
  }
}
