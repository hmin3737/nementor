import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/app_colors.dart';
import '../../../core/app_router.dart';
import '../../../core/app_spacing.dart';
import '../../../core/app_strings.dart';
import '../../../core/app_typography.dart';
import '../../../shared/models/board_model.dart';
import '../../../shared/widgets/cert_badge.dart';
import '../../../shared/widgets/shimmer_box.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/board_provider.dart';

class BoardListScreen extends ConsumerWidget {
  const BoardListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(boardListProvider);
    final user = ref.watch(currentUserProvider).valueOrNull;
    final isMentor = user?.role.name == 'mentor';

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        elevation: 0,
        title: Text(AppStrings.boardTitle, style: AppTypography.title3),
        centerTitle: true,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined,
                color: AppColors.textPrimary),
            onPressed: () => context.push(AppRoutes.notification),
          ),
          if (isMentor)
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: AppColors.textPrimary),
              onPressed: () => context.push(AppRoutes.boardWrite),
            ),
        ],
      ),
      body: listAsync.when(
        loading: () => const _BoardShimmer(),
        error: (e, _) => Center(
          child: Text(AppStrings.serverError,
              style: AppTypography.callout.copyWith(color: AppColors.textSub)),
        ),
        data: (posts) {
          if (posts.isEmpty) {
            return Center(
              child: Text('아직 칼럼이 없어요',
                  style: AppTypography.callout.copyWith(color: AppColors.textSub)),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(boardListProvider.future),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              itemCount: posts.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: AppColors.border),
              itemBuilder: (_, i) => _PostCard(post: posts[i]),
            ),
          );
        },
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({required this.post});
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
            // 작성자 정보
            Row(
              children: [
                GestureDetector(
                  onTap: () => context.push('/mentor/${post.mentorId}'),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.border,
                        child: Icon(Icons.person, size: 16, color: AppColors.textSub),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(post.mentorNickname,
                                  style: AppTypography.calloutBold),
                              if (post.mentorCertifications.isNotEmpty) ...{
                                const SizedBox(width: AppSpacing.xs),
                                CertBadge(
                                  subject: post.mentorCertifications.first.subject,
                                  level: post.mentorCertifications.first.level,
                                  compact: true,
                                ),
                              },
                            ],
                          ),
                          if (post.mentorUniversity != null)
                            Text(post.mentorUniversity!,
                                style: AppTypography.caption
                                    .copyWith(color: AppColors.textSub)),
                        ],
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  _timeAgo(post.createdAt),
                  style: AppTypography.caption.copyWith(color: AppColors.textDisabled),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            // 제목
            Text(post.title,
                style: AppTypography.calloutBold,
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: AppSpacing.xs),
            // 본문 미리보기
            Text(post.bodyPreview,
                style: AppTypography.callout.copyWith(color: AppColors.textSub),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: AppSpacing.sm),
            // 통계
            Row(
              children: [
                _Stat(icon: Icons.visibility_outlined, value: post.viewCount),
                const SizedBox(width: AppSpacing.base),
                _Stat(icon: Icons.favorite_border, value: post.likeCount),
                const SizedBox(width: AppSpacing.base),
                _Stat(icon: Icons.chat_bubble_outline, value: post.commentCount),
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
            style: AppTypography.caption.copyWith(color: AppColors.textDisabled)),
      ],
    );
  }
}

class _BoardShimmer extends StatelessWidget {
  const _BoardShimmer();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      itemCount: 6,
      separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
      itemBuilder: (_, __) => Container(
        color: AppColors.card,
        padding: const EdgeInsets.all(AppSpacing.base),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              ShimmerBox(width: 32, height: 32, borderRadius: 100),
              SizedBox(width: AppSpacing.sm),
              ShimmerBox(width: 80, height: 14),
            ]),
            SizedBox(height: AppSpacing.sm),
            ShimmerBox(width: double.infinity, height: 16),
            SizedBox(height: AppSpacing.xs),
            ShimmerBox(width: 200, height: 14),
          ],
        ),
      ),
    );
  }
}
