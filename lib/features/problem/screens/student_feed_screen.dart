import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/app_colors.dart';
import '../../../core/app_router.dart';
import '../../../core/app_spacing.dart';
import '../../../core/app_strings.dart';
import '../../../core/app_typography.dart';
import '../../../shared/widgets/shimmer_box.dart';
import '../providers/question_provider.dart';
import '../widgets/question_card.dart';

class StudentFeedScreen extends ConsumerWidget {
  const StudentFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(studentFeedProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.surface,
            elevation: 0,
            title: Text(
              AppStrings.appName,
              style: AppTypography.title2.copyWith(color: AppColors.primary),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined,
                    color: AppColors.primary),
                onPressed: () => context.push(AppRoutes.notification),
              ),
              IconButton(
                icon: const Icon(Icons.search, color: AppColors.primary),
                onPressed: () {},
              ),
            ],
          ),
          feedAsync.when(
            loading: () => SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, __) => const ShimmerQuestionCard(),
                childCount: 6,
              ),
            ),
            error: (e, _) => SliverFillRemaining(
              child: _ErrorView(
                message: AppStrings.serverError,
                onRetry: () => ref.invalidate(studentFeedProvider),
              ),
            ),
            data: (questions) {
              if (questions.isEmpty) {
                return const SliverFillRemaining(
                  child: _EmptyView(),
                );
              }
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => QuestionCard(
                    question: questions[i],
                    onTap: () => context
                        .push('/student/question/${questions[i].id}'),
                  ),
                  childCount: questions.length,
                ),
              );
            },
          ),
          const SliverPadding(
            padding: EdgeInsets.only(bottom: AppSpacing.x4l),
          ),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.help_outline_rounded,
            size: 64,
            color: AppColors.textDisabled,
          ),
          const SizedBox(height: AppSpacing.base),
          Text(
            '아직 등록된 질문이 없어요',
            style: AppTypography.callout.copyWith(color: AppColors.textSub),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '첫 질문을 등록해 보세요!',
            style: AppTypography.footnote,
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_rounded,
              size: 64, color: AppColors.textDisabled),
          const SizedBox(height: AppSpacing.base),
          Text(message,
              style:
                  AppTypography.callout.copyWith(color: AppColors.textSub)),
          const SizedBox(height: AppSpacing.base),
          TextButton(
            onPressed: onRetry,
            child: Text(AppStrings.retry,
                style: AppTypography.subhead.copyWith(
                    color: AppColors.accent)),
          ),
        ],
      ),
    );
  }
}
