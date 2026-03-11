import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/providers/auth_provider.dart';
import '../shared/services/supabase_service.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/role_select_screen.dart';
import '../features/auth/screens/student_signup_screen.dart';
import '../features/auth/screens/mentor_signup_screen.dart';
import '../shared/models/user_model.dart';

// 학생 탭
import '../features/problem/screens/student_feed_screen.dart';
import '../features/problem/screens/question_register_screen.dart';
import '../features/problem/screens/question_detail_screen.dart';
import '../features/problem/screens/chat_room_screen.dart';
import '../features/mentor/screens/mentor_explore_screen.dart';
import '../features/mentor/screens/mentor_profile_screen.dart';

// 멘토 탭
import '../features/problem/screens/mentor_feed_screen.dart';
import '../features/board/screens/board_list_screen.dart';
import '../features/board/screens/board_detail_screen.dart';
import '../features/board/screens/board_write_screen.dart';
import '../features/consulting/screens/consulting_screen.dart';

// 공통
import '../features/cash/screens/cash_screen.dart';
import '../features/cash/screens/charge_screen.dart';
import '../features/cash/screens/earnings_screen.dart';
import '../features/board/screens/my_columns_screen.dart';
import '../features/notification/screens/notification_screen.dart';
import '../features/mypage/screens/mypage_screen.dart';
import '../features/mypage/screens/profile_edit_screen.dart';
import '../features/dispute/screens/dispute_screen.dart';
import '../features/dispute/screens/dispute_apply_screen.dart';
import '../features/admin/screens/admin_screen.dart';
import '../features/review/screens/review_screen.dart';
import '../features/mentor/screens/mentor_document_screen.dart';
import '../features/mentor/screens/cert_request_screen.dart';
import '../features/problem/screens/my_questions_screen.dart';
import '../features/mentor/screens/favorites_screen.dart';
import '../features/problem/screens/my_answers_screen.dart';
import '../features/mentor/screens/info_verify_request_screen.dart';
import '../features/splash_screen.dart';

// Shell (탭바 포함 scaffold)
import '../features/student_shell.dart';
import '../features/mentor_shell.dart';

/// 라우트 이름 상수
abstract final class AppRoutes {
  static const String login = '/login';
  static const String roleSelect = '/role-select';
  static const String studentSignup = '/student-signup';
  static const String mentorSignup = '/mentor-signup';
  static const String nickname = '/nickname';

  // 학생 탭
  static const String studentFeed = '/student/feed';
  static const String questionRegister = '/student/ask';
  static const String questionDetail = '/student/question/:id';
  static const String exploreMentor = '/student/explore';
  static const String studentBoard = '/student/board';
  static const String mentorProfile = '/mentor/:id';

  // 멘토 탭
  static const String mentorFeed = '/mentor/feed';
  static const String board = '/board';
  static const String boardDetail = '/board/:id';
  static const String boardWrite = '/board/write';
  static const String consulting = '/consulting';

  // 공통
  static const String chatRoom = '/chat/:roomId';
  static const String cash = '/cash';
  static const String charge = '/cash/charge';
  static const String notification = '/notification';
  static const String mypage = '/mypage';
  static const String profileEdit = '/mypage/edit';

  // 멘토 전용 탭 (학생 Shell 경로와 충돌 방지)
  static const String mentorNotification = '/mentor-notification';
  static const String mentorMypage = '/mentor-mypage';
  static const String dispute = '/dispute';
  static const String disputeApply = '/dispute/apply';
  static const String admin = '/admin';
  static const String review = '/review';
  static const String mentorDocs = '/mentor-docs';
  static const String certRequest = '/cert-request';
  static const String myQuestions = '/my-questions';
  static const String earnings = '/earnings';
  static const String myColumns = '/my-columns';
  static const String favorites = '/favorites';
  static const String myAnswers = '/my-answers';
  static const String infoVerifyRequest = '/info-verify-request';
  static const String splash = '/splash';
}

CustomTransitionPage<void> _fadePage(Widget child) => CustomTransitionPage(
      child: child,
      transitionDuration: const Duration(milliseconds: 180),
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
    );

class _AuthNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _AuthNotifier();
  AsyncValue<UserModel?> authState = const AsyncValue.loading();

  ref.listen(currentUserProvider, (_, next) {
    authState = next;
    notifier.notify();
  });

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: notifier,
    redirect: (context, state) {
      final user = authState.valueOrNull;
      final loc = state.matchedLocation;
      final isSplash = loc == AppRoutes.splash;
      final isAuthPage = loc == AppRoutes.login ||
          loc == AppRoutes.roleSelect ||
          loc.startsWith('/student-signup') ||
          loc.startsWith('/mentor-signup') ||
          loc == AppRoutes.nickname;

      // ignore: avoid_print
      print('[Router] loc=$loc isLoading=${authState.isLoading} hasError=${authState.hasError} user=${user?.role}');

      // 인증 로딩 중 → 스플래시 화면 유지
      if (authState.isLoading) return isSplash ? null : AppRoutes.splash;

      // DB 조회 에러 → 로그인 유지 (role-select로 튕기지 않도록)
      if (authState.hasError) {
        // ignore: avoid_print
        print('[Router] authState error: ${authState.error}');
        return isAuthPage ? null : AppRoutes.login;
      }

      final supabaseUser = SupabaseService.client.auth.currentUser;
      if (supabaseUser != null && user == null && loc == AppRoutes.login) {
        return AppRoutes.roleSelect;
      }

      if (user == null && !isAuthPage) return AppRoutes.login;

      // Admin
      if (user?.role == UserRole.admin && !loc.startsWith('/admin')) {
        return AppRoutes.admin;
      }

      // Unverified mentor → doc upload
      if (user != null &&
          user.role == UserRole.mentor &&
          user.mentorVerified != true &&
          loc != AppRoutes.mentorDocs) {
        return AppRoutes.mentorDocs;
      }

      // Verified mentor on doc upload page → feed
      if (user != null &&
          user.role == UserRole.mentor &&
          user.mentorVerified == true &&
          loc == AppRoutes.mentorDocs) {
        return AppRoutes.mentorFeed;
      }

      // 로그인 상태로 인증/스플래시 페이지 접근 → 피드로
      if (user != null && (isAuthPage || isSplash)) {
        if (user.role == UserRole.mentor) return AppRoutes.mentorFeed;
        return AppRoutes.studentFeed;
      }

      return null;
    },
    routes: [
      // ── 스플래시 ─────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.splash,
        pageBuilder: (_, __) => _fadePage(const SplashScreen()),
      ),

      // ── 인증 ──────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.login,
        pageBuilder: (_, __) => _fadePage(const LoginScreen()),
      ),
      GoRoute(
        path: AppRoutes.roleSelect,
        pageBuilder: (_, __) => _fadePage(const RoleSelectScreen()),
      ),
      GoRoute(
        path: AppRoutes.studentSignup,
        pageBuilder: (_, __) => _fadePage(const StudentSignupScreen()),
      ),
      GoRoute(
        path: AppRoutes.mentorSignup,
        pageBuilder: (_, __) => _fadePage(const MentorSignupScreen()),
      ),
      GoRoute(
        path: AppRoutes.nickname,
        pageBuilder: (_, state) {
          final role = state.uri.queryParameters['role'] ?? 'student';
          return _fadePage(NicknameScreen(
            role: role == 'mentor' ? UserRole.mentor : UserRole.student,
          ));
        },
      ),
      GoRoute(
        path: AppRoutes.mentorDocs,
        pageBuilder: (_, __) => _fadePage(const MentorDocumentScreen()),
      ),

      // ── 학생 Shell (탭바) ─────────────────────────────────────
      ShellRoute(
        builder: (_, __, child) => StudentShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.studentFeed,
            pageBuilder: (_, __) => _fadePage(const StudentFeedScreen()),
          ),
          GoRoute(
            path: AppRoutes.exploreMentor,
            pageBuilder: (_, __) => _fadePage(const MentorExploreScreen()),
          ),
          GoRoute(
            path: AppRoutes.studentBoard,
            pageBuilder: (_, __) => _fadePage(const BoardListScreen()),
          ),
          GoRoute(
            path: AppRoutes.mypage,
            pageBuilder: (_, __) => _fadePage(const MypageScreen()),
          ),
        ],
      ),

      // ── 멘토 Shell (탭바) ─────────────────────────────────────
      ShellRoute(
        builder: (_, __, child) => MentorShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.mentorFeed,
            pageBuilder: (_, __) => _fadePage(const MentorFeedScreen()),
          ),
          GoRoute(
            path: AppRoutes.board,
            pageBuilder: (_, __) => _fadePage(const BoardListScreen()),
          ),
          GoRoute(
            path: AppRoutes.consulting,
            pageBuilder: (_, __) => _fadePage(const ConsultingScreen()),
          ),
          GoRoute(
            path: AppRoutes.mentorMypage,
            pageBuilder: (_, __) => _fadePage(const MypageScreen()),
          ),
        ],
      ),

      // ── 독립 라우트 ───────────────────────────────────────────
      GoRoute(
        path: AppRoutes.questionRegister,
        pageBuilder: (_, __) => _fadePage(const QuestionRegisterScreen()),
      ),
      GoRoute(
        path: '/student/question/:id',
        pageBuilder: (_, state) => _fadePage(
            QuestionDetailScreen(questionId: state.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/mentor/:id',
        pageBuilder: (_, state) => _fadePage(
            MentorProfileScreen(mentorId: state.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/chat/:roomId',
        pageBuilder: (_, state) => _fadePage(
            ChatRoomScreen(roomId: state.pathParameters['roomId']!)),
      ),
      GoRoute(
        path: AppRoutes.boardWrite,
        pageBuilder: (_, state) {
          final postId = state.uri.queryParameters['postId'];
          return _fadePage(BoardWriteScreen(editPostId: postId));
        },
      ),
      GoRoute(
        path: '/board/:id',
        pageBuilder: (_, state) => _fadePage(
            BoardDetailScreen(postId: state.pathParameters['id']!)),
      ),
      GoRoute(
        path: AppRoutes.cash,
        pageBuilder: (_, __) => _fadePage(const CashScreen()),
      ),
      GoRoute(
        path: AppRoutes.charge,
        pageBuilder: (_, __) => _fadePage(const ChargeScreen()),
      ),
      GoRoute(
        path: AppRoutes.profileEdit,
        pageBuilder: (_, __) => _fadePage(const ProfileEditScreen()),
      ),
      GoRoute(
        path: AppRoutes.dispute,
        pageBuilder: (_, __) => _fadePage(const DisputeScreen()),
      ),
      GoRoute(
        path: AppRoutes.disputeApply,
        pageBuilder: (_, state) {
          final questionId = state.uri.queryParameters['questionId']!;
          return _fadePage(DisputeApplyScreen(questionId: questionId));
        },
      ),
      GoRoute(
        path: AppRoutes.admin,
        pageBuilder: (_, __) => _fadePage(const AdminScreen()),
      ),
      GoRoute(
        path: AppRoutes.review,
        pageBuilder: (_, state) {
          final q = state.uri.queryParameters;
          return _fadePage(ReviewScreen(
            questionId: q['questionId']!,
            mentorId: q['mentorId']!,
            mentorNickname: q['mentorNickname'] ?? '멘토',
          ));
        },
      ),
      GoRoute(
        path: AppRoutes.certRequest,
        pageBuilder: (_, __) => _fadePage(const CertRequestScreen()),
      ),
      GoRoute(
        path: AppRoutes.myQuestions,
        pageBuilder: (_, __) => _fadePage(const MyQuestionsScreen()),
      ),
      GoRoute(
        path: AppRoutes.earnings,
        pageBuilder: (_, __) => _fadePage(const EarningsScreen()),
      ),
      GoRoute(
        path: AppRoutes.myColumns,
        pageBuilder: (_, __) => _fadePage(const MyColumnsScreen()),
      ),
      GoRoute(
        path: AppRoutes.notification,
        pageBuilder: (_, __) => _fadePage(const NotificationScreen()),
      ),
      GoRoute(
        path: AppRoutes.mentorNotification,
        pageBuilder: (_, __) => _fadePage(const NotificationScreen()),
      ),
      GoRoute(
        path: AppRoutes.favorites,
        pageBuilder: (_, __) => _fadePage(const FavoritesScreen()),
      ),
      GoRoute(
        path: AppRoutes.myAnswers,
        pageBuilder: (_, __) => _fadePage(const MyAnswersScreen()),
      ),
      GoRoute(
        path: AppRoutes.infoVerifyRequest,
        pageBuilder: (_, __) => _fadePage(const InfoVerifyRequestScreen()),
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(
        child: Text('페이지를 찾을 수 없어요: ${state.error}'),
      ),
    ),
  );
});
