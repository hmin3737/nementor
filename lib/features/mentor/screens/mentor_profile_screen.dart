import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/app_colors.dart';
import '../../../core/app_spacing.dart';
import '../../../core/app_strings.dart';
import '../../../core/app_typography.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/services/supabase_service.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/cert_badge.dart';
import '../../../shared/widgets/shimmer_box.dart';

final _mentorProfileProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>?, String>(
        (ref, mentorId) async {
  final data = await SupabaseService.client
      .from(SupabaseService.mentorProfilesTable)
      .select('*, users!inner(nickname, email), mentor_certifications(*)')
      .eq('user_id', mentorId)
      .maybeSingle();
  return data;
});

class MentorProfileScreen extends ConsumerWidget {
  const MentorProfileScreen({super.key, required this.mentorId});
  final String mentorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(_mentorProfileProvider(mentorId));

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: profileAsync.when(
        loading: () => const _ProfileShimmer(),
        error: (e, _) => Center(
          child: Text(AppStrings.serverError,
              style:
                  AppTypography.callout.copyWith(color: AppColors.textSub)),
        ),
        data: (data) {
          if (data == null) {
            return Center(
              child: Text('멘토를 찾을 수 없어요',
                  style: AppTypography.callout
                      .copyWith(color: AppColors.textSub)),
            );
          }

          final nickname = data['users']?['nickname'] as String? ?? '';
          final university = data['university'] as String?;
          final department = data['department'] as String?;
          final intro = data['intro'] as String?;
          final bio = data['bio'] as String?;
          final highSchool = data['high_school'] as String?;
          final rating = (data['rating'] as num?)?.toDouble() ?? 0.0;
          final reviewCount = data['review_count'] as int? ?? 0;
          final verified = data['verified'] as bool? ?? false;
          final hourlyRateMin = data['hourly_rate_min'] as int?;
          final hourlyRateMax = data['hourly_rate_max'] as int?;
          final certs = (data['mentor_certifications'] as List<dynamic>?)
              ?.map((e) =>
                  MentorCertification.fromJson(e as Map<String, dynamic>))
              .toList() ?? [];

          String rateDisplay = '';
          if (hourlyRateMin != null) {
            rateDisplay = hourlyRateMax != null && hourlyRateMax != hourlyRateMin
                ? '₩${_fmt(hourlyRateMin)} ~ ₩${_fmt(hourlyRateMax)}'
                : '₩${_fmt(hourlyRateMin)}';
          }

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                backgroundColor: AppColors.card,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new,
                      color: AppColors.textPrimary),
                  onPressed: () => context.pop(),
                ),
                title: Text(nickname, style: AppTypography.title3),
                centerTitle: true,
              ),
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 헤더
                    Container(
                      color: AppColors.card,
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Column(
                        children: [
                          const CircleAvatar(
                            radius: AppSpacing.avatarLg / 2,
                            backgroundColor: AppColors.surface,
                            child: Icon(Icons.person,
                                size: 36, color: AppColors.textSub),
                          ),
                          const SizedBox(height: AppSpacing.base),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(nickname, style: AppTypography.title2),
                              if (verified) ...[
                                const SizedBox(width: AppSpacing.xs),
                                const Icon(Icons.verified,
                                    color: AppColors.accent, size: 20),
                              ],
                            ],
                          ),
                          if (university != null) ...[
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              [university, department]
                                  .where((s) => s?.isNotEmpty == true)
                                  .join(' · '),
                              style: AppTypography.subhead.copyWith(
                                  color: AppColors.textSub),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.star_rounded,
                                  color: AppColors.warning, size: 18),
                              const SizedBox(width: AppSpacing.xs),
                              Text(rating.toStringAsFixed(1),
                                  style: AppTypography.bodyBold),
                              Text(' · 리뷰 $reviewCount개',
                                  style: AppTypography.callout
                                      .copyWith(color: AppColors.textSub)),
                            ],
                          ),
                          if (rateDisplay.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.xs),
                            Text('시급 $rateDisplay',
                                style: AppTypography.subhead
                                    .copyWith(color: AppColors.accent)),
                          ],
                        ],
                      ),
                    ),

                    // 내멘토 인증
                    if (certs.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      _Section(
                        title: AppStrings.certTitle,
                        child: Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: certs
                              .map((c) => CertBadge(
                                    subject: c.subject,
                                    level: c.level,
                                  ))
                              .toList(),
                        ),
                      ),
                    ],

                    // 소개
                    if (intro?.isNotEmpty == true || bio?.isNotEmpty == true) ...[
                      const SizedBox(height: AppSpacing.sm),
                      _Section(
                        title: '소개',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (intro?.isNotEmpty == true)
                              Text(intro!,
                                  style: AppTypography.calloutBold),
                            if (bio?.isNotEmpty == true) ...[
                              const SizedBox(height: AppSpacing.sm),
                              Text(bio!,
                                  style: AppTypography.callout
                                      .copyWith(color: AppColors.textSub)),
                            ],
                          ],
                        ),
                      ),
                    ],

                    // 학력
                    if (highSchool != null || university != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      _Section(
                        title: '학력',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (highSchool != null)
                              _EducationRow(
                                  icon: Icons.school_outlined,
                                  label: highSchool),
                            if (university != null)
                              _EducationRow(
                                icon: Icons.account_balance_outlined,
                                label: [university, department]
                                    .where((s) => s?.isNotEmpty == true)
                                    .join(' · '),
                                verified: verified,
                              ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: AppSpacing.x4l),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.base, AppSpacing.sm, AppSpacing.base, AppSpacing.x2l),
        decoration: const BoxDecoration(
          color: AppColors.card,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: AppButton(
          label: AppStrings.requestConsulting,
          variant: AppButtonVariant.consult,
          onPressed: () {},
        ),
      ),
    );
  }

  String _fmt(int v) => v
      .toString()
      .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.card,
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: AppTypography.title3
                  .copyWith(color: AppColors.textPrimary)),
          const SizedBox(height: AppSpacing.base),
          child,
        ],
      ),
    );
  }
}

class _EducationRow extends StatelessWidget {
  const _EducationRow(
      {required this.icon, required this.label, this.verified = false});
  final IconData icon;
  final String label;
  final bool verified;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSub),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(label,
                style: AppTypography.callout.copyWith(
                    fontWeight:
                        verified ? FontWeight.w600 : FontWeight.normal)),
          ),
          if (verified)
            const Icon(Icons.verified, color: AppColors.accent, size: 16),
        ],
      ),
    );
  }
}

class _ProfileShimmer extends StatelessWidget {
  const _ProfileShimmer();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: AppColors.card,
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            children: [
              const ShimmerBox(
                  width: AppSpacing.avatarLg,
                  height: AppSpacing.avatarLg,
                  borderRadius: 100),
              const SizedBox(height: AppSpacing.base),
              const ShimmerBox(width: 120, height: 24),
              const SizedBox(height: AppSpacing.sm),
              const ShimmerBox(width: 180, height: 16),
            ],
          ),
        ),
      ],
    );
  }
}
