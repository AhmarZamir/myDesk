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

    try {
      await _client.rpc('ensure_current_profile');
      if (fullName?.trim().isNotEmpty == true) {
        await updateProfile(fullName!.trim());
      }
      return;
    } catch (_) {
      // Keep a client fallback for deployments where the safeguard migration
      // has not been applied yet.
    }

    final existing = await _client.from('profiles').select('id').eq('id', user.id).maybeSingle();
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

  Future<Map<String, dynamic>?> fetchProfile() async {
    final user = currentUser;
    if (user == null) return null;
    await ensureProfile();
    final row = await _client.from('profiles').select('id,full_name,avatar_url,created_at').eq('id', user.id).maybeSingle();
    return row == null ? null : Map<String, dynamic>.from(row);
  }

  Future<void> updateProfile(String fullName) async {
    final user = currentUser;
    if (user == null) throw StateError('Not signed in');
    final name = fullName.trim();
    if (name.length < 2) throw ArgumentError('Name must contain at least 2 characters');

    await _client.from('profiles').update({
      'full_name': name,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', user.id);
    await _client.auth.updateUser(UserAttributes(data: {'full_name': name}));
  }

  Future<void> requestPasswordReset(String email) async {
    final value = email.trim();
    if (value.isEmpty) throw ArgumentError('Email is required');
    final base = Uri.base;
    final redirect = (base.scheme == 'http' || base.scheme == 'https') ? '${base.origin}/' : null;
    await _client.auth.resetPasswordForEmail(value, redirectTo: redirect);
  }

  Future<void> updatePassword(String password) async {
    if (password.length < 8) throw ArgumentError('Use at least 8 characters');
    await _client.auth.updateUser(UserAttributes(password: password));
  }

  Future<void> signOut() => _client.auth.signOut();
}
