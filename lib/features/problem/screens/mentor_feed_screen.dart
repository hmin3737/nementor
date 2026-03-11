import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/app_colors.dart';
import '../../../core/app_router.dart';
import '../../../core/app_spacing.dart';
import '../../../core/app_strings.dart';
import '../../../core/app_typography.dart';
import '../../../shared/models/question_model.dart';
import '../../../shared/services/supabase_service.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/shimmer_box.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/question_provider.dart';
import '../widgets/question_card.dart';

enum _FeedSort { latest, priceHigh, deadline }

class MentorFeedScreen extends ConsumerStatefulWidget {
  const MentorFeedScreen({super.key});

  @override
  ConsumerState<MentorFeedScreen> createState() => _MentorFeedScreenState();
}

class _MentorFeedScreenState extends ConsumerState<MentorFeedScreen> {
  _FeedSort _sort = _FeedSort.latest;

  String _formatPrice(int price) => price
      .toString()
      .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  Future<void> _preempt(QuestionModel question) async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;

    final priceText = '₩${_formatPrice(question.price)}';
    final desc = AppStrings.preemptConfirmDesc.replaceFirst('{0}', priceText);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.dialogRadius),
        ),
        title: Text(AppStrings.preemptConfirm, style: AppTypography.title3),
        content: Text(desc,
            style: AppTypography.callout.copyWith(color: AppColors.textSub)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppStrings.cancel,
                style: AppTypography.subhead
                    .copyWith(color: AppColors.textSub)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppStrings.preempt,
                style: AppTypography.subhead
                    .copyWith(color: AppColors.accent)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final roomId = await ref
        .read(questionSubmitProvider.notifier)
        .preempt(question.id, user.id);

    if (!mounted) return;
    if (roomId == null) {
      showAppToast(context, AppStrings.alreadyPreempted,
          type: ToastType.error);
    } else {
      // 학생에게 알림 전송
      await SupabaseService.client
          .from(SupabaseService.notificationsTable)
          .insert({
        'user_id': question.studentId,
        'type': 'question',
        'title': '멘토가 질문을 선점했어요',
        'body': '답변이 시작됐어요. 채팅방에서 확인하세요.',
        'ref_id': question.id,
      });
      ref.invalidate(mentorFeedProvider);
      context.push('/chat/$roomId');
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedAsync = ref.watch(mentorFeedProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.surface,
            elevation: 0,
            title: Text(
              AppStrings.questionFeed,
              style:
                  AppTypography.title2.copyWith(color: AppColors.primary),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined,
                    color: AppColors.textPrimary),
                onPressed: () => context.push(AppRoutes.notification),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: _SortBar(
                current: _sort,
                onChanged: (s) => setState(() => _sort = s),
              ),
            ),
          ),
          feedAsync.when(
            loading: () => SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, __) => const ShimmerQuestionCard(),
                childCount: 6,
              ),
            ),
            error: (e, _) => SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.wifi_off_rounded,
                        size: 64, color: AppColors.textDisabled),
                    const SizedBox(height: AppSpacing.base),
                    Text(AppStrings.serverError,
                        style: AppTypography.callout
                            .copyWith(color: AppColors.textSub)),
                    const SizedBox(height: AppSpacing.base),
                    TextButton(
                      onPressed: () => ref.invalidate(mentorFeedProvider),
                      child: Text(AppStrings.retry,
                          style: AppTypography.subhead
                              .copyWith(color: AppColors.accent)),
                    ),
                  ],
                ),
              ),
            ),
            data: (questions) {
              final sorted = [...questions];
              switch (_sort) {
                case _FeedSort.priceHigh:
                  sorted.sort((a, b) => b.price.compareTo(a.price));
                case _FeedSort.deadline:
                  sorted.sort((a, b) =>
                      a.createdAt.compareTo(b.createdAt));
                case _FeedSort.latest:
                  break;
              }
              if (sorted.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Text('새로운 질문이 없어요',
                        style: AppTypography.callout
                            .copyWith(color: AppColors.textSub)),
                  ),
                );
              }
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => QuestionCard(
                    question: sorted[i],
                    onTap: () =>
                        context.push('/student/question/${sorted[i].id}'),
                    showPreemptButton: true,
                    onPreempt: () => _preempt(sorted[i]),
                  ),
                  childCount: sorted.length,
                ),
              );
            },
          ),
          const SliverPadding(
              padding: EdgeInsets.only(bottom: AppSpacing.x4l)),
        ],
      ),
    );
  }
}

class _SortBar extends StatelessWidget {
  const _SortBar({required this.current, required this.onChanged});

  final _FeedSort current;
  final ValueChanged<_FeedSort> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base, vertical: AppSpacing.sm),
      child: Row(
        children: [
          _SortChip(
            label: '최신순',
            selected: current == _FeedSort.latest,
            onTap: () => onChanged(_FeedSort.latest),
          ),
          const SizedBox(width: AppSpacing.sm),
          _SortChip(
            label: '가격 높은 순',
            selected: current == _FeedSort.priceHigh,
            onTap: () => onChanged(_FeedSort.priceHigh),
          ),
          const SizedBox(width: AppSpacing.sm),
          _SortChip(
            label: '마감 임박',
            selected: current == _FeedSort.deadline,
            onTap: () => onChanged(_FeedSort.deadline),
          ),
        ],
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  const _SortChip(
      {required this.label,
      required this.selected,
      required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.footnote.copyWith(
            color: selected ? Colors.white : AppColors.textSub,
            fontWeight:
                selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
