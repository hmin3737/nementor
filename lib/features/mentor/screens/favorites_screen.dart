import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/app_colors.dart';
import '../../../core/app_spacing.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/widgets/cert_badge.dart';
import '../../../shared/widgets/shimmer_box.dart';
import '../providers/favorites_provider.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(favoriteMentorsProvider);

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
        title: const Text('관심 멘토',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            )),
        centerTitle: true,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      body: listAsync.when(
        loading: () => ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.base),
          itemCount: 5,
          separatorBuilder: (_, __) =>
              const SizedBox(height: AppSpacing.sm),
          itemBuilder: (_, __) => const ShimmerQuestionCard(),
        ),
        error: (e, _) => const Center(
          child: Text('불러오기 실패',
              style: TextStyle(color: AppColors.textSub)),
        ),
        data: (mentors) {
          if (mentors.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.favorite_border,
                      size: 64, color: AppColors.textDisabled),
                  SizedBox(height: AppSpacing.base),
                  Text('관심 멘토가 없어요',
                      style: TextStyle(
                          color: AppColors.textSub,
                          fontFamily: 'Pretendard',
                          fontSize: 15)),
                  SizedBox(height: AppSpacing.xs),
                  Text('멘토 탐색에서 하트를 눌러 추가하세요',
                      style: TextStyle(
                          color: AppColors.textDisabled,
                          fontFamily: 'Pretendard',
                          fontSize: 13)),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.base),
            itemCount: mentors.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: AppSpacing.sm),
            itemBuilder: (_, i) => _FavMentorCard(
              data: mentors[i],
              onTap: () =>
                  context.push('/mentor/${mentors[i]['user_id']}'),
              onUnfavorite: () => ref.invalidate(favoriteMentorsProvider),
            ),
          );
        },
      ),
    );
  }
}

class _FavMentorCard extends ConsumerWidget {
  const _FavMentorCard({
    required this.data,
    required this.onTap,
    required this.onUnfavorite,
  });
  final Map<String, dynamic> data;
  final VoidCallback onTap;
  final VoidCallback onUnfavorite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nickname = data['users']?['nickname'] as String? ?? '';
    final university = data['university'] as String?;
    final department = data['department'] as String?;
    final intro = data['intro'] as String?;
    final rating = (data['rating'] as num?)?.toDouble() ?? 0.0;
    final reviewCount = data['review_count'] as int? ?? 0;
    final mentorId = data['user_id'] as String;
    final certs =
        (data['users']?['mentor_certifications'] as List<dynamic>?)
                ?.map((e) => MentorCertification.fromJson(
                    e as Map<String, dynamic>))
                .toList() ??
            [];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.base),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          boxShadow: AppSpacing.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: AppSpacing.avatarMd / 2,
                  backgroundColor: AppColors.surface,
                  child: Icon(Icons.person, color: AppColors.textSub),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nickname,
                          style: const TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          )),
                      if (university != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          [university, department]
                              .where((s) => s?.isNotEmpty == true)
                              .join(' · '),
                          style: const TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 12,
                            color: AppColors.textSub,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // 하트(즐겨찾기 해제) 버튼
                MentorFavoriteButton(mentorId: mentorId),
              ],
            ),
            if (certs.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: certs
                    .take(3)
                    .map((c) => CertBadge(
                          subject: c.subject,
                          level: c.level,
                          compact: true,
                        ))
                    .toList(),
              ),
            ],
            if (intro?.isNotEmpty == true) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(intro!,
                  style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 12,
                    color: AppColors.textSub,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: AppSpacing.sm),
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                const Icon(Icons.star_rounded,
                    color: AppColors.warning, size: 16),
                const SizedBox(width: AppSpacing.xs),
                Text(rating.toStringAsFixed(1),
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    )),
                const SizedBox(width: AppSpacing.xs),
                Text('($reviewCount개)',
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 12,
                      color: AppColors.textSub,
                    )),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
