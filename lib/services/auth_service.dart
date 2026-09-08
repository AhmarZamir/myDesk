import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _client;
  AuthService([SupabaseClient? client]) : _client = client ?? Supabase.instance.client;

  Stream<AuthState> get authChanges => _client.auth.onAuthStateChange;
  User? get currentUser => _client.auth.currentUser;

  Future<AuthResponse> signIn({required String email, required String password}) async {
    final response = await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    await ensureProfile();
    return response;
  }

  Future<AuthResponse> signUp({required String fullName, required String email, required String password}) async {
    final response = await _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'full_name': fullName.trim()},
    );

    if (_client.auth.currentUser != null) {
      await ensureProfile(fullName: fullName);
    }

    return response;
  }

  Future<void> ensureProfile({String? fullName}) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    final existing = await _client
        .from('profiles')
        .select('id')
        .eq('id', user.id)
        .maybeSingle();

    if (existing != null) return;

    final metadataName = user.userMetadata?['full_name']?.toString().trim();
    final fallbackName = user.email?.split('@').first ?? '';

    await _client.from('profiles').insert({
      'id': user.id,
      'full_name': (fullName?.trim().isNotEmpty == true)
          ? fullName!.trim()
          : (metadataName?.isNotEmpty == true ? metadataName : fallbackName),
    });
  }

  Future<void> signOut() => _client.auth.signOut();
}
