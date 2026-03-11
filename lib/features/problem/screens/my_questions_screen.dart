import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/app_colors.dart';
import '../../../core/app_spacing.dart';
import '../../../core/app_typography.dart';
import '../../../shared/widgets/shimmer_box.dart';
import '../providers/question_provider.dart';
import '../widgets/question_card.dart';

class MyQuestionsScreen extends ConsumerWidget {
  const MyQuestionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncQ = ref.watch(myQuestionsProvider);

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
        title: Text('내 질문 내역', style: AppTypography.title3),
        centerTitle: true,
      ),
      body: asyncQ.when(
        loading: () => ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.base),
          itemCount: 5,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (_, __) => ShimmerBox(
              width: double.infinity, height: 100),
        ),
        error: (e, _) => Center(
          child: Text('불러오기 실패: $e',
              style:
                  AppTypography.callout.copyWith(color: AppColors.textSub)),
        ),
        data: (questions) {
          if (questions.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.help_outline,
                      size: 56, color: AppColors.border),
                  const SizedBox(height: AppSpacing.base),
                  Text('아직 등록한 질문이 없어요',
                      style: AppTypography.callout
                          .copyWith(color: AppColors.textSub)),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.base),
            itemCount: questions.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: AppSpacing.sm),
            itemBuilder: (_, i) => QuestionCard(
              question: questions[i],
              onTap: () =>
                  context.push('/student/question/${questions[i].id}'),
              showStatus: true,
            ),
          );
        },
      ),
    );
  }
}
