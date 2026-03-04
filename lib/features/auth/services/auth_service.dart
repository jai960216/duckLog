import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/models/profile.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

final currentUserProvider = Provider<User?>((ref) {
  return Supabase.instance.client.auth.currentUser;
});

final currentProfileProvider =
    FutureProvider.autoDispose<Profile?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;

  final client = ref.read(supabaseClientProvider);
  final response =
      await client.from('profiles').select().eq('id', user.id).maybeSingle();

  if (response == null) return null;
  return Profile.fromJson(response);
});

class AuthService {
  final SupabaseClient _client;

  AuthService(this._client);

  User? get currentUser => _client.auth.currentUser;

  // Google Sign In
  Future<AuthResponse> signInWithGoogle() async {
    return await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'com.ducklog.ducklog://login-callback',
    ).then((_) => _client.auth.currentSession != null
        ? AuthResponse(session: _client.auth.currentSession)
        : AuthResponse(session: null));
  }

  // Email Sign Up (dev/testing)
  Future<AuthResponse> signUpWithEmail(String email, String password) async {
    return await _client.auth.signUp(
      email: email,
      password: password,
    );
  }

  // Email Sign In (dev/testing)
  Future<AuthResponse> signInWithEmail(String email, String password) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // Kakao Sign In - via Supabase OAuth
  Future<bool> signInWithKakao() async {
    return await _client.auth.signInWithOAuth(
      OAuthProvider.kakao,
      redirectTo: 'com.ducklog.ducklog://login-callback',
    );
  }

  // Create or update profile after first login
  Future<Profile> upsertProfile({
    required String nickname,
    String? avatarUrl,
    String? bio,
  }) async {
    final user = currentUser;
    if (user == null) throw Exception('Not authenticated');

    final data = {
      'id': user.id,
      'nickname': nickname,
      'avatar_url': avatarUrl,
      'bio': bio,
    };

    await _client.from('profiles').upsert(data);
    final response =
        await _client.from('profiles').select().eq('id', user.id).single();
    return Profile.fromJson(response);
  }

  // Check if profile exists (for onboarding flow)
  Future<bool> hasProfile() async {
    final user = currentUser;
    if (user == null) return false;

    final response = await _client
        .from('profiles')
        .select('id')
        .eq('id', user.id)
        .maybeSingle();
    return response != null;
  }

  // Sign out
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // Delete account
  Future<void> deleteAccount() async {
    // RLS cascade will handle related data
    final user = currentUser;
    if (user == null) return;

    // Delete profile (cascade deletes goods, receipts, etc.)
    await _client.from('profiles').delete().eq('id', user.id);
    await _client.auth.signOut();
  }
}

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.read(supabaseClientProvider));
});
