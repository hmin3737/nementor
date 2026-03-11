import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/app_colors.dart';
import '../../../core/app_spacing.dart';
import '../../../core/app_strings.dart';
import '../../../core/app_typography.dart';
import '../../../shared/models/question_model.dart';
import '../../../shared/services/supabase_service.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/shimmer_box.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/question_provider.dart';

void _openDetailImageViewer(BuildContext context, String url) {
  Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black87,
      barrierDismissible: true,
      pageBuilder: (pageCtx, _, __) => Scaffold(
        backgroundColor: Colors.black87,
        body: Stack(
          children: [
            Center(
              child: Hero(
                tag: 'detail_$url',
                child: InteractiveViewer(
                  child: Image.network(url, fit: BoxFit.contain),
                ),
              ),
            ),
            Positioned(
              top: 48,
              right: 16,
              child: GestureDetector(
                onTap: () => Navigator.of(pageCtx).pop(),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 22),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class QuestionDetailScreen extends ConsumerWidget {
  const QuestionDetailScreen({super.key, required this.questionId});
  final String questionId;

  String _formatPrice(int price) => price
      .toString()
      .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final qAsync = ref.watch(questionDetailProvider(questionId));
    final user = ref.watch(currentUserProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.primary),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/student/feed'),
        ),
        title: Text('질문 상세', style: AppTypography.title3),
        centerTitle: true,
      ),
      body: qAsync.when(
        loading: () => const _DetailShimmer(),
        error: (e, _) => Center(
          child: Text(AppStrings.serverError,
              style:
                  AppTypography.callout.copyWith(color: AppColors.textSub)),
        ),
        data: (q) {
          if (q == null) {
            return Center(
              child: Text('질문을 찾을 수 없어요',
                  style: AppTypography.callout
                      .copyWith(color: AppColors.textSub)),
            );
          }
          final isMentor = user?.role.name == 'mentor';
          final isStudent = user?.id == q.studentId;
          final isMyQuestion = isStudent;

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.base),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 상태 + 가격 헤더
                      Row(
                        children: [
                          _StatusBadge(status: q.status),
                          const Spacer(),
                          Text(
                            '₩${_formatPrice(q.price)}',
                            style: AppTypography.price,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.base),
                      // 태그
                      Wrap(
                        spacing: AppSpacing.sm,
                        children: [
                          if (q.schoolLevel != null)
                            _Chip(label: _schoolLevelLabel(q.schoolLevel!)),
                          if (q.subject != null)
                            _Chip(label: _subjectLabelOf(q.subject!)),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.base),
                      // 제목
                      if (q.title?.isNotEmpty == true) ...[
                        Text(q.title!, style: AppTypography.title3),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      // 본문
                      Text(q.body, style: AppTypography.body),
                      // 이미지
                      if (q.imageUrls.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.base),
                        ...q.imageUrls.map(
                          (url) => Padding(
                            padding:
                                const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: GestureDetector(
                              onTap: () => _openDetailImageViewer(context, url),
                              child: Hero(
                                tag: 'detail_$url',
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                      AppSpacing.inputRadius),
                                  child: Image.network(
                                    url,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.base),
                      // 메타
                      Row(
                        children: [
                          const Icon(Icons.access_time,
                              size: 14, color: AppColors.textSub),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            timeago.format(q.createdAt, locale: 'ko'),
                            style: AppTypography.caption,
                          ),
                          if (q.studentNickname?.isNotEmpty == true) ...[
                            const SizedBox(width: AppSpacing.base),
                            const Icon(Icons.person_outline,
                                size: 14, color: AppColors.textSub),
                            const SizedBox(width: AppSpacing.xs),
                            Text(q.studentNickname!,
                                style: AppTypography.caption),
                          ],
                        ],
                      ),
                      // 종료 선언 안내
                      if (q.hasCloseRequest) ...[
                        const SizedBox(height: AppSpacing.base),
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.base),
                          decoration: BoxDecoration(
                            color:
                                AppColors.warning.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(
                                AppSpacing.inputRadius),
                            border: Border.all(
                                color: AppColors.warning
                                    .withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.timer_outlined,
                                  color: AppColors.warning),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  AppStrings.endDeclared,
                                  style: AppTypography.footnote.copyWith(
                                      color: AppColors.warning),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // 하단 액션
              _BottomAction(
                question: q,
                isMentor: isMentor,
                isMyQuestion: isMyQuestion,
                onPreempt: () async {
                  if (user == null) return;
                  final roomId = await ref
                      .read(questionSubmitProvider.notifier)
                      .preempt(q.id, user.id);
                  if (!context.mounted) return;
                  if (roomId == null) {
                    showAppToast(context, AppStrings.alreadyPreempted,
                        type: ToastType.error);
                  } else {
                    // 학생에게 알림 전송
                    await SupabaseService.client
                        .from(SupabaseService.notificationsTable)
                        .insert({
                      'user_id': q.studentId,
                      'type': 'question',
                      'title': '멘토가 질문을 선점했어요',
                      'body': '답변이 시작됐어요. 채팅방에서 확인하세요.',
                      'ref_id': q.id,
                    });
                    if (!context.mounted) return;
                    context.push('/chat/$roomId');
                  }
                },
                onOpenChat: () async {
                  final roomId = await ref
                      .read(chatRoomIdProvider(q.id).future);
                  if (!context.mounted) return;
                  if (roomId != null) {
                    context.push('/chat/$roomId');
                  } else {
                    showAppToast(context, '채팅방을 찾을 수 없어요',
                        type: ToastType.error);
                  }
                },
                onCancel: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('질문 취소'),
                      content: const Text('질문을 취소하면 캐시가 환불됩니다. 취소할까요?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('아니오'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text('취소하기',
                              style: TextStyle(color: AppColors.error)),
                        ),
                      ],
                    ),
                  );
                  if (confirmed != true || !context.mounted) return;
                  final ok = await ref
                      .read(questionSubmitProvider.notifier)
                      .cancel(q.id);
                  if (!context.mounted) return;
                  if (ok) {
                    showAppToast(context, '질문이 취소됐어요. 캐시가 환불됩니다.',
                        type: ToastType.success);
                    ref.invalidate(currentUserProvider);
                    context.canPop()
                        ? context.pop()
                        : context.go('/student/feed');
                  } else {
                    showAppToast(context, AppStrings.serverError,
                        type: ToastType.error);
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  String _schoolLevelLabel(SchoolLevel l) => switch (l) {
        SchoolLevel.elementary => '초등',
        SchoolLevel.middle => '중등',
        SchoolLevel.high => '고등',
        SchoolLevel.etc => '기타',
      };

  String _subjectLabelOf(QuestionSubject s) => switch (s) {
        QuestionSubject.math => '수학',
        QuestionSubject.korean => '국어',
        QuestionSubject.english => '영어',
        QuestionSubject.science => '과학',
        QuestionSubject.social => '사회',
        QuestionSubject.etc => '기타',
      };
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final QuestionStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      QuestionStatus.open => ('답변 대기', AppColors.success),
      QuestionStatus.accepted => ('답변 중', AppColors.accent),
      QuestionStatus.closed => ('종료', AppColors.textSub),
      QuestionStatus.cancelled => ('취소됨', AppColors.error),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: AppTypography.caption.copyWith(
              color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
      ),
      child: Text(label,
          style: AppTypography.caption.copyWith(
              color: AppColors.textSub, fontWeight: FontWeight.w500)),
    );
  }
}

class _BottomAction extends StatelessWidget {
  const _BottomAction({
    required this.question,
    required this.isMentor,
    required this.isMyQuestion,
    required this.onPreempt,
    required this.onOpenChat,
    required this.onCancel,
  });
  final QuestionModel question;
  final bool isMentor;
  final bool isMyQuestion;
  final VoidCallback onPreempt;
  final VoidCallback onOpenChat;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.base, AppSpacing.sm, AppSpacing.base, AppSpacing.x2l),
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: () {
        if (question.status == QuestionStatus.open && isMentor) {
          return AppButton(label: AppStrings.preempt, onPressed: onPreempt);
        }
        if (question.status == QuestionStatus.open && isMyQuestion) {
          return AppButton(
            label: '질문 취소 (캐시 환불)',
            onPressed: onCancel,
            variant: AppButtonVariant.danger,
          );
        }
        if (question.status == QuestionStatus.accepted &&
            (isMyQuestion || isMentor)) {
          return AppButton(label: '채팅방 열기', onPressed: onOpenChat);
        }
        if (question.isClosed) {
          if (isMyQuestion || isMentor) {
            return AppButton(label: '채팅 내역 보기', onPressed: onOpenChat);
          }
          return Text(AppStrings.endConfirmed,
              style: AppTypography.callout.copyWith(color: AppColors.textSub),
              textAlign: TextAlign.center);
        }
        return const SizedBox.shrink();
      }(),
    );
  }
}

class _DetailShimmer extends StatelessWidget {
  const _DetailShimmer();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ShimmerBox(width: 80, height: 24),
              ShimmerBox(width: 80, height: 28),
            ],
          ),
          const SizedBox(height: AppSpacing.base),
          ShimmerBox(width: 200, height: 20),
          const SizedBox(height: AppSpacing.sm),
          ShimmerBox(width: double.infinity, height: 16),
          const SizedBox(height: AppSpacing.xs),
          ShimmerBox(width: double.infinity, height: 16),
          const SizedBox(height: AppSpacing.xs),
          ShimmerBox(width: 300, height: 16),
        ],
      ),
    );
  }
}
