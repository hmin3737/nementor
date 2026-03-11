import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/app_colors.dart';
import '../../../core/app_router.dart';
import '../../../core/app_spacing.dart';
import '../../../core/app_strings.dart';
import '../../../core/app_typography.dart';
import '../../../shared/models/board_model.dart';
import '../../../shared/widgets/shimmer_box.dart';
import '../providers/board_provider.dart';

class MyColumnsScreen extends ConsumerWidget {
  const MyColumnsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(myBoardPostsProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text('내 칼럼 관리', style: AppTypography.title3),
        centerTitle: true,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined,
                color: AppColors.textPrimary),
            tooltip: AppStrings.writeColumn,
            onPressed: () => context.push(AppRoutes.boardWrite),
          ),
        ],
      ),
      body: listAsync.when(
        loading: () => _buildShimmer(),
        error: (e, _) => Center(
          child: Text(AppStrings.serverError,
              style:
                  AppTypography.callout.copyWith(color: AppColors.textSub)),
        ),
        data: (posts) {
          if (posts.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.article_outlined,
                      size: 48, color: AppColors.textDisabled),
                  const SizedBox(height: AppSpacing.base),
                  Text('작성한 칼럼이 없어요',
                      style: AppTypography.callout
                          .copyWith(color: AppColors.textSub)),
                  const SizedBox(height: AppSpacing.base),
                  TextButton(
                    onPressed: () => context.push(AppRoutes.boardWrite),
                    child: Text(AppStrings.writeColumn,
                        style: AppTypography.subhead
                            .copyWith(color: AppColors.accent)),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(myBoardPostsProvider.future),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              itemCount: posts.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: AppColors.border),
              itemBuilder: (_, i) => _MyColumnCard(post: posts[i]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildShimmer() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      itemCount: 4,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, color: AppColors.border),
      itemBuilder: (_, __) => Container(
        color: AppColors.card,
        padding: const EdgeInsets.all(AppSpacing.base),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShimmerBox(width: double.infinity, height: 16),
            SizedBox(height: AppSpacing.xs),
            ShimmerBox(width: 200, height: 14),
            SizedBox(height: AppSpacing.sm),
            ShimmerBox(width: 120, height: 12),
          ],
        ),
      ),
    );
  }
}

class _MyColumnCard extends StatelessWidget {
  const _MyColumnCard({required this.post});
  final BoardPost post;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/board/${post.id}'),
      child: Container(
        color: AppColors.card,
        padding: const EdgeInsets.all(AppSpacing.base),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(post.title,
                style: AppTypography.calloutBold,
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: AppSpacing.xs),
            Text(post.bodyPreview,
                style:
                    AppTypography.caption.copyWith(color: AppColors.textSub),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                _Stat(
                    icon: Icons.visibility_outlined, value: post.viewCount),
                const SizedBox(width: AppSpacing.base),
                _Stat(icon: Icons.favorite_border, value: post.likeCount),
                const SizedBox(width: AppSpacing.base),
                _Stat(
                    icon: Icons.chat_bubble_outline,
                    value: post.commentCount),
                const Spacer(),
                Text(
                  _timeAgo(post.createdAt),
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textDisabled),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inDays < 1) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${dt.month}.${dt.day}';
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value});
  final IconData icon;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.textDisabled),
        const SizedBox(width: 3),
        Text('$value',
            style:
                AppTypography.caption.copyWith(color: AppColors.textDisabled)),
      ],
    );
  }
}
