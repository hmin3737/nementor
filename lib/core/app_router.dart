import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/role_select_screen.dart';
import '../features/auth/screens/student_signup_screen.dart';
import '../features/auth/screens/mentor_signup_screen.dart';
import '../features/auth/screens/nickname_screen.dart';
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
import '../features/notification/screens/notification_screen.dart';
import '../features/mypage/screens/mypage_screen.dart';
import '../features/mypage/screens/profile_edit_screen.dart';
import '../features/dispute/screens/dispute_screen.dart';
import '../features/dispute/screens/dispute_apply_screen.dart';
import '../features/admin/screens/admin_screen.dart';
import '../features/review/screens/review_screen.dart';

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
  static const String dispute = '/dispute';
  static const String disputeApply = '/dispute/apply';
  static const String admin = '/admin';
  static const String review = '/review';
}

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(currentUserProvider);

  return GoRouter(
    initialLocation: AppRoutes.login,
    redirect: (context, state) {
      final user = authState.valueOrNull;
      final isLoginPage = state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.roleSelect ||
          state.matchedLocation.startsWith('/student-signup') ||
          state.matchedLocation.startsWith('/mentor-signup') ||
          state.matchedLocation == AppRoutes.nickname;

      if (authState.isLoading) return null;

      if (user == null && !isLoginPage) {
        return AppRoutes.login;
      }

      if (user != null && isLoginPage) {
        return user.role == UserRole.mentor
            ? AppRoutes.mentorFeed
            : AppRoutes.studentFeed;
      }

      // 관리자는 admin 페이지로
      if (user?.role == UserRole.admin &&
          !state.matchedLocation.startsWith('/admin')) {
        return AppRoutes.admin;
      }

      return null;
    },
    routes: [
      // ── 인증 ──────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.login,
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.roleSelect,
        builder: (_, __) => const RoleSelectScreen(),
      ),
      GoRoute(
        path: AppRoutes.studentSignup,
        builder: (_, __) => const StudentSignupScreen(),
      ),
      GoRoute(
        path: AppRoutes.mentorSignup,
        builder: (_, __) => const MentorSignupScreen(),
      ),
      GoRoute(
        path: AppRoutes.nickname,
        builder: (_, state) {
          final role = state.uri.queryParameters['role'] ?? 'student';
          return NicknameScreen(
            role: role == 'mentor' ? UserRole.mentor : UserRole.student,
          );
        },
      ),

      // ── 학생 Shell (탭바) ─────────────────────────────────────
      ShellRoute(
        builder: (_, __, child) => StudentShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.studentFeed,
            builder: (_, __) => const StudentFeedScreen(),
          ),
          GoRoute(
            path: AppRoutes.exploreMentor,
            builder: (_, __) => const MentorExploreScreen(),
          ),
          GoRoute(
            path: AppRoutes.notification,
            builder: (_, __) => const NotificationScreen(),
          ),
          GoRoute(
            path: AppRoutes.mypage,
            builder: (_, __) => const MypageScreen(),
          ),
        ],
      ),

      // ── 멘토 Shell (탭바) ─────────────────────────────────────
      ShellRoute(
        builder: (_, __, child) => MentorShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.mentorFeed,
            builder: (_, __) => const MentorFeedScreen(),
          ),
          GoRoute(
            path: AppRoutes.board,
            builder: (_, __) => const BoardListScreen(),
          ),
          GoRoute(
            path: AppRoutes.consulting,
            builder: (_, __) => const ConsultingScreen(),
          ),
          GoRoute(
            path: AppRoutes.notification,
            builder: (_, __) => const NotificationScreen(),
          ),
          GoRoute(
            path: AppRoutes.mypage,
            builder: (_, __) => const MypageScreen(),
          ),
        ],
      ),

      // ── 독립 라우트 ───────────────────────────────────────────
      GoRoute(
        path: AppRoutes.questionRegister,
        builder: (_, __) => const QuestionRegisterScreen(),
      ),
      GoRoute(
        path: '/student/question/:id',
        builder: (_, state) =>
            QuestionDetailScreen(questionId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/mentor/:id',
        builder: (_, state) =>
            MentorProfileScreen(mentorId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/chat/:roomId',
        builder: (_, state) =>
            ChatRoomScreen(roomId: state.pathParameters['roomId']!),
      ),
      GoRoute(
        path: '/board/:id',
        builder: (_, state) =>
            BoardDetailScreen(postId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.boardWrite,
        builder: (_, state) {
          final postId = state.uri.queryParameters['postId'];
          return BoardWriteScreen(editPostId: postId);
        },
      ),
      GoRoute(
        path: AppRoutes.cash,
        builder: (_, __) => const CashScreen(),
      ),
      GoRoute(
        path: AppRoutes.charge,
        builder: (_, __) => const ChargeScreen(),
      ),
      GoRoute(
        path: AppRoutes.profileEdit,
        builder: (_, __) => const ProfileEditScreen(),
      ),
      GoRoute(
        path: AppRoutes.dispute,
        builder: (_, __) => const DisputeScreen(),
      ),
      GoRoute(
        path: AppRoutes.disputeApply,
        builder: (_, state) {
          final questionId = state.uri.queryParameters['questionId']!;
          return DisputeApplyScreen(questionId: questionId);
        },
      ),
      GoRoute(
        path: AppRoutes.admin,
        builder: (_, __) => const AdminScreen(),
      ),
      GoRoute(
        path: AppRoutes.review,
        builder: (_, state) {
          final q = state.uri.queryParameters;
          return ReviewScreen(
            questionId: q['questionId']!,
            mentorId: q['mentorId']!,
            mentorNickname: q['mentorNickname'] ?? '멘토',
          );
        },
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(
        child: Text('페이지를 찾을 수 없어요: ${state.error}'),
      ),
    ),
  );
});
