import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/services/auth_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

// 현재 로그인된 사용자 프로필
final currentUserProvider = StreamProvider<UserModel?>((ref) {
  final service = ref.watch(authServiceProvider);
  return service.authStateChanges.asyncMap((state) async {
    if (state.event == AuthChangeEvent.signedOut) return null;
    return service.getCurrentUser();
  });
});

// 로그인 여부
final isLoggedInProvider = Provider<bool>((ref) {
  final authUser = ref.watch(currentUserProvider);
  return authUser.valueOrNull != null;
});

// 역할
final userRoleProvider = Provider<UserRole?>((ref) {
  return ref.watch(currentUserProvider).valueOrNull?.role;
});

// 캐시 잔액
final cashBalanceProvider = Provider<int>((ref) {
  return ref.watch(currentUserProvider).valueOrNull?.cashBalance ?? 0;
});

// 회원가입/로그인 상태 관리
class AuthNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> signInWithKakao() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authServiceProvider).signInWithKakao(),
    );
  }

  Future<void> signInWithApple() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authServiceProvider).signInWithApple(),
    );
  }

  Future<void> signInWithEmail(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authServiceProvider).signInWithEmail(email, password),
    );
  }

  Future<void> signUpWithEmail(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authServiceProvider).signUpWithEmail(email, password),
    );
  }

  Future<UserModel> completeSignUp({
    required String nickname,
    required UserRole role,
  }) async {
    state = const AsyncLoading();
    late UserModel user;
    state = await AsyncValue.guard(() async {
      user = await ref.read(authServiceProvider).completeSignUp(
            nickname: nickname,
            role: role,
          );
    });
    state.hasError ? state : const AsyncData(null);
    return user;
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authServiceProvider).signOut(),
    );
  }
}

final authNotifierProvider =
    AsyncNotifierProvider<AuthNotifier, void>(AuthNotifier.new);
