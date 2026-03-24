import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../config/google_auth_config.dart';
import '../../../services/fcm_service.dart';
import '../../../shared/models/profile.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

final currentUserProvider = Provider<User?>((ref) {
  ref.watch(authStateProvider); // auth 상태 변경 시 rebuild
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
  final profile = Profile.fromJson(response);

  // 기존 유저: friend_code가 비어있으면 자동 생성
  if (profile.friendCode.isEmpty) {
    final authService = ref.read(authServiceProvider);
    final updated = await authService.ensureFriendCode(user.id);
    if (updated != null) return updated;
  }

  return profile;
});

class AuthService {
  final SupabaseClient _client;

  AuthService(this._client);

  User? get currentUser => _client.auth.currentUser;

  // Google Sign In — 네이티브 SDK (앱 내 계정 선택기)
  Future<AuthResponse> signInWithGoogle() async {
    if (!GoogleAuthConfig.isConfigured) {
      throw Exception(
        'Google 로그인이 설정되지 않았습니다.\n'
        '--dart-define=GOOGLE_WEB_CLIENT_ID 를 확인해주세요.',
      );
    }

    final googleSignIn = GoogleSignIn(
      scopes: ['email'],
      serverClientId: GoogleAuthConfig.webClientId,
    );

    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) {
      throw Exception('Google 로그인이 취소되었습니다.');
    }

    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    final accessToken = googleAuth.accessToken;

    if (idToken == null) {
      throw Exception(
        'Google ID 토큰을 가져올 수 없습니다.\n'
        'serverClientId(웹 클라이언트 ID) 설정과 SHA-1 등록을 확인해주세요.',
      );
    }

    return await _client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
  }

  // Kakao Sign In - via Supabase OAuth
  Future<bool> signInWithKakao() async {
    return await _client.auth.signInWithOAuth(
      OAuthProvider.kakao,
      redirectTo: 'com.ducklog.ducklog://login-callback',
      scopes: 'account_email,profile_image,profile_nickname',
    );
  }

  // Create or update profile after first login
  Future<Profile> upsertProfile({
    required String nickname,
    String? avatarUrl,
    String? bio,
    int? birthYear,
  }) async {
    final user = currentUser;
    if (user == null) throw Exception('Not authenticated');

    // 기존 프로필 확인 (friend_code 유지 목적)
    final existing = await _client
        .from('profiles')
        .select('friend_code')
        .eq('id', user.id)
        .maybeSingle();

    final friendCode = existing?['friend_code'] as String? ??
        await _generateFriendCode();

    final data = {
      'id': user.id,
      'nickname': nickname,
      'friend_code': friendCode,
      'avatar_url': avatarUrl,
      'bio': bio,
      if (birthYear != null) 'birth_year': birthYear,
    };

    await _client.from('profiles').upsert(data);
    final response =
        await _client.from('profiles').select().eq('id', user.id).single();
    return Profile.fromJson(response);
  }

  /// 6자리 랜덤 영숫자 친구 코드 생성 (충돌 시 재시도)
  Future<String> _generateFriendCode() async {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();

    for (var attempt = 0; attempt < 10; attempt++) {
      final code = String.fromCharCodes(
        Iterable.generate(
          6,
          (_) => chars.codeUnitAt(random.nextInt(chars.length)),
        ),
      );

      // 중복 확인
      final existing = await _client
          .from('profiles')
          .select('id')
          .eq('friend_code', code)
          .maybeSingle();

      if (existing == null) return code;
    }

    // 10회 시도 실패 시 타임스탬프 기반 fallback
    final ts = DateTime.now().millisecondsSinceEpoch;
    return ts.toRadixString(36).substring(0, 6);
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

  /// 기존 유저의 friend_code가 없으면 생성하여 저장
  Future<Profile?> ensureFriendCode(String userId) async {
    try {
      final code = await _generateFriendCode();
      await _client
          .from('profiles')
          .update({'friend_code': code})
          .eq('id', userId);

      final response = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();
      return Profile.fromJson(response);
    } on PostgrestException {
      // DB에 friend_code 컬럼이 없는 경우 — 무시
      return null;
    }
  }

  /// 친구 코드로 프로필 검색
  Future<Profile?> searchByFriendCode(String code) async {
    final response = await _client
        .from('profiles')
        .select()
        .eq('friend_code', code.toLowerCase().trim())
        .maybeSingle();

    if (response == null) return null;
    return Profile.fromJson(response);
  }

  // Sign out
  Future<void> signOut() async {
    await FcmService.instance.clearToken();
    try { await GoogleSignIn().signOut(); } catch (_) {}
    await _client.auth.signOut();
  }

  // Delete account
  Future<void> deleteAccount() async {
    final user = currentUser;
    if (user == null) return;

    final userId = user.id;

    // 0. FCM 토큰 정리
    await FcmService.instance.clearToken();

    // 1. Storage 파일 정리
    await _deleteStorageFiles(userId);

    // 2. 구독 정보 삭제 (cascade가 없을 수 있으므로 명시적 삭제)
    // Note: Play Store 구독은 서버에서 취소 불가 — 유저가 Play Store에서 직접 해지해야 함.
    // DB에서 구독 행을 삭제하면 webhook이 매칭 유저를 못 찾으므로 자연 만료됨.
    try {
      await _client.from('subscriptions').delete().eq('user_id', userId);
    } catch (_) {
      // 구독이 없으면 무시
    }

    // 3. Delete profile (cascade deletes goods, receipts, etc.)
    await _client.from('profiles').delete().eq('id', userId);

    // 4. Auth 계정 삭제 (service_role 권한의 Edge Function 호출)
    try {
      await _client.functions.invoke('delete-account');
    } catch (_) {
      // Edge Function 실패 시에도 signOut 처리
    }

    await _client.auth.signOut();
  }

  /// Storage 버킷에서 유저 관련 파일 삭제
  /// Note: Supabase Storage list()은 직계 자식만 반환합니다.
  /// 현재 업로드 경로가 모두 userId/filename (flat) 구조이므로 문제없지만,
  /// 하위 디렉터리가 추가되면 재귀 삭제 로직이 필요합니다.
  Future<void> _deleteStorageFiles(String userId) async {
    const buckets = ['goods-photos', 'receipt-photos', 'avatars', 'catalog-photos'];

    for (final bucket in buckets) {
      try {
        final files = await _client.storage.from(bucket).list(path: userId);
        if (files.isNotEmpty) {
          final paths = files.map((f) => '$userId/${f.name}').toList();
          await _client.storage.from(bucket).remove(paths);
        }
      } catch (_) {
        // 버킷이 없거나 파일이 없으면 무시
      }
    }
  }
}

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.read(supabaseClientProvider));
});
