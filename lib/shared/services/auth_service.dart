import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import 'supabase_service.dart';

class AuthService {
  final _client = SupabaseService.client;

  User? get currentAuthUser => _client.auth.currentUser;
  bool get isLoggedIn => currentAuthUser != null;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  // ── 현재 사용자 프로필 조회 ──────────────────────────────────
  Future<UserModel?> getCurrentUser() async {
    final authUser = currentAuthUser;
    if (authUser == null) return null;
    return getUserById(authUser.id);
  }

  Future<UserModel?> getUserById(String id) async {
    final data = await _client
        .from(SupabaseService.usersTable)
        .select()
        .eq('id', id)
        .maybeSingle();
    if (data == null) return null;
    return UserModel.fromJson(data);
  }

  // ── 카카오 로그인 ─────────────────────────────────────────────
  Future<void> signInWithKakao() async {
    await _client.auth.signInWithOAuth(
      OAuthProvider.kakao,
      redirectTo: 'io.nementor.app://login-callback',
    );
  }

  // ── 애플 로그인 ───────────────────────────────────────────────
  Future<AuthResponse> signInWithApple() async {
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );
    return _client.auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: credential.identityToken!,
      nonce: credential.authorizationCode,
    );
  }

  // ── 이메일 로그인 ────────────────────────────────────────────
  Future<AuthResponse> signInWithEmail(String email, String password) async {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  // ── 이메일 회원가입 ──────────────────────────────────────────
  Future<AuthResponse> signUpWithEmail(String email, String password) async {
    return _client.auth.signUp(email: email, password: password);
  }

  // ── 회원가입 완료 (role + nickname 저장) ─────────────────────
  Future<UserModel> completeSignUp({
    required String nickname,
    required UserRole role,
  }) async {
    final authUser = currentAuthUser!;

    // users 테이블에 삽입 (upsert: OAuth 재가입 대비)
    final data = await _client
        .from(SupabaseService.usersTable)
        .upsert({
          'id': authUser.id,
          'email': authUser.email ?? '',
          'nickname': nickname,
          'role': role.name,
          'cash_balance': 0,
        })
        .select()
        .single();

    // 멘토라면 mentor_profiles 행도 생성
    if (role == UserRole.mentor) {
      await _client.from(SupabaseService.mentorProfilesTable).upsert({
        'user_id': authUser.id,
        'verified': false,
        'rating': 0.0,
        'review_count': 0,
      });
    }

    return UserModel.fromJson(data);
  }

  // ── 닉네임 중복 확인 ─────────────────────────────────────────
  Future<bool> isNicknameAvailable(String nickname) async {
    final count = await _client
        .from(SupabaseService.usersTable)
        .select('id')
        .eq('nickname', nickname)
        .count(CountOption.exact);
    return count.count == 0;
  }

  // ── 로그아웃 ─────────────────────────────────────────────────
  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}
