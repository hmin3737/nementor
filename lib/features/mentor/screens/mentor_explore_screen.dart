import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/app_colors.dart';
import '../../../core/app_router.dart';
import '../../../core/app_spacing.dart';
import '../../../core/app_strings.dart';
import '../../../core/app_typography.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/services/supabase_service.dart';
import '../../../shared/widgets/cert_badge.dart';
import '../../../shared/widgets/shimmer_box.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/favorites_provider.dart';

final _mentorListProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final data = await SupabaseService.client
      .from(SupabaseService.mentorProfilesTable)
      .select('*, users!inner(nickname, email, mentor_certifications(*))')
      .eq('verified', true)
      .order('rating', ascending: false)
      .limit(30);
  return (data as List).cast<Map<String, dynamic>>();
});

class MentorExploreScreen extends ConsumerStatefulWidget {
  const MentorExploreScreen({super.key});

  @override
  ConsumerState<MentorExploreScreen> createState() =>
      _MentorExploreScreenState();
}

class _MentorExploreScreenState extends ConsumerState<MentorExploreScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _favoritesOnly = false;
  final Set<String> _universityFilters = {};
  final Set<String> _highSchoolFilters = {};
  final Set<String> _middleSchoolFilters = {};

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool get _hasFilters =>
      _universityFilters.isNotEmpty ||
      _highSchoolFilters.isNotEmpty ||
      _middleSchoolFilters.isNotEmpty;

  bool _passesFilter(Map<String, dynamic> m) {
    if (!_hasFilters) return true;
    final uni = (m['university'] as String? ?? '').toLowerCase();
    final high = (m['high_school'] as String? ?? '').toLowerCase();
    final mid = (m['middle_school'] as String? ?? '').toLowerCase();

    if (_universityFilters.isNotEmpty &&
        !_universityFilters.any((f) => uni.contains(f.toLowerCase()))) {
      return false;
    }
    if (_highSchoolFilters.isNotEmpty &&
        !_highSchoolFilters.any((f) => high.contains(f.toLowerCase()))) {
      return false;
    }
    if (_middleSchoolFilters.isNotEmpty &&
        !_middleSchoolFilters.any((f) => mid.contains(f.toLowerCase()))) {
      return false;
    }
    return true;
  }

  Future<void> _showAddFilterDialog(
      String category, Set<String> targetSet) async {
    final ctrl = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.dialogRadius)),
        title: Text('$category 필터 추가', style: AppTypography.title3),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: AppTypography.callout,
          decoration: InputDecoration(
            hintText: '학교명을 입력하세요 (예: 서울대)',
            hintStyle:
                AppTypography.callout.copyWith(color: AppColors.textDisabled),
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.base, vertical: AppSpacing.sm),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                borderSide:
                    const BorderSide(color: AppColors.accent, width: 1.5)),
          ),
          onSubmitted: (v) {
            if (v.trim().isNotEmpty) Navigator.pop(ctx, v.trim());
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppStrings.cancel,
                style: AppTypography.subhead
                    .copyWith(color: AppColors.textSub)),
          ),
          TextButton(
            onPressed: () {
              final v = ctrl.text.trim();
              if (v.isNotEmpty) Navigator.pop(ctx, v);
            },
            child: Text('추가',
                style: AppTypography.subhead
                    .copyWith(color: AppColors.accent)),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.dispose());
    if (value != null && value.isNotEmpty) {
      setState(() => targetSet.add(value));
    }
  }

  Widget _schoolFilterButton(
      String label, Set<String> filters, VoidCallback onTap) {
    final isActive = filters.isNotEmpty;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.accent.withValues(alpha: 0.12)
              : AppColors.card,
          borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
          border: Border.all(
              color: isActive ? AppColors.accent : AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: AppTypography.caption.copyWith(
                  color: isActive ? AppColors.accent : AppColors.textSub,
                  fontWeight:
                      isActive ? FontWeight.w600 : FontWeight.normal,
                )),
            const SizedBox(width: 3),
            Icon(Icons.add,
                size: 13,
                color: isActive ? AppColors.accent : AppColors.textSub),
          ],
        ),
      ),
    );
  }

  Widget _activeChip(String label, VoidCallback onRemove) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.xs),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
          border:
              Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: AppTypography.caption
                    .copyWith(color: AppColors.accent)),
            const SizedBox(width: 3),
            GestureDetector(
              onTap: onRemove,
              child: const Icon(Icons.close,
                  size: 13, color: AppColors.accent),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final isStudent = user?.role == UserRole.student;
    final listAsync = (_favoritesOnly && isStudent)
        ? ref.watch(favoriteMentorsProvider)
        : ref.watch(_mentorListProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.surface,
            elevation: 0,
            title: Text(AppStrings.exploreMentor,
                style:
                    AppTypography.title2.copyWith(color: AppColors.primary)),
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined,
                    color: AppColors.primary),
                onPressed: () => context.push(AppRoutes.notification),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: Size.fromHeight(_hasFilters ? 140 : 104),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.base, 0, AppSpacing.base, AppSpacing.xs),
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => _query = v.trim()),
                      decoration: InputDecoration(
                        hintText: '멘토 이름, 과목, 대학교 검색',
                        hintStyle: AppTypography.callout
                            .copyWith(color: AppColors.textDisabled),
                        prefixIcon: const Icon(Icons.search,
                            color: AppColors.textSub),
                        filled: true,
                        fillColor: AppColors.card,
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.sm),
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppSpacing.inputRadius),
                          borderSide:
                              const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppSpacing.inputRadius),
                          borderSide:
                              const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppSpacing.inputRadius),
                          borderSide: const BorderSide(
                              color: AppColors.accent, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                  // Filter chips row
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.base, 0, AppSpacing.base, AppSpacing.xs),
                    child: Row(
                      children: [
                        if (isStudent) ...[
                          GestureDetector(
                            onTap: () => setState(() => _favoritesOnly = !_favoritesOnly),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm, vertical: 6),
                              decoration: BoxDecoration(
                                color: _favoritesOnly
                                    ? AppColors.error.withValues(alpha: 0.12)
                                    : AppColors.card,
                                borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
                                border: Border.all(
                                  color: _favoritesOnly
                                      ? AppColors.error.withValues(alpha: 0.5)
                                      : AppColors.border,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _favoritesOnly ? Icons.favorite : Icons.favorite_border,
                                    size: 13,
                                    color: _favoritesOnly ? AppColors.error : AppColors.textSub,
                                  ),
                                  const SizedBox(width: 4),
                                  Text('관심 멘토',
                                      style: AppTypography.caption.copyWith(
                                        color: _favoritesOnly ? AppColors.error : AppColors.textSub,
                                        fontWeight: _favoritesOnly ? FontWeight.w600 : FontWeight.normal,
                                      )),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                        ],
                        _schoolFilterButton(
                          '대학교',
                          _universityFilters,
                          () => _showAddFilterDialog('대학교', _universityFilters),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        _schoolFilterButton(
                          '고등학교',
                          _highSchoolFilters,
                          () => _showAddFilterDialog('고등학교', _highSchoolFilters),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        _schoolFilterButton(
                          '중학교',
                          _middleSchoolFilters,
                          () => _showAddFilterDialog('중학교', _middleSchoolFilters),
                        ),
                      ],
                    ),
                  ),
                  // Active filter chips
                  if (_hasFilters)
                    SizedBox(
                      height: 36,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.base),
                        children: [
                          ..._universityFilters.map((f) => _activeChip(
                              '대학 $f',
                              () => setState(
                                  () => _universityFilters.remove(f)))),
                          ..._highSchoolFilters.map((f) => _activeChip(
                              '고등 $f',
                              () => setState(
                                  () => _highSchoolFilters.remove(f)))),
                          ..._middleSchoolFilters.map((f) => _activeChip(
                              '중학 $f',
                              () => setState(
                                  () => _middleSchoolFilters.remove(f)))),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          listAsync.when(
            loading: () => SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, __) => const ShimmerQuestionCard(),
                childCount: 6,
              ),
            ),
            error: (e, _) => SliverFillRemaining(
              child: Center(
                child: Text(AppStrings.serverError,
                    style: AppTypography.callout
                        .copyWith(color: AppColors.textSub)),
              ),
            ),
            data: (mentors) {
              final filtered = mentors.where((m) {
                if (!_passesFilter(m)) return false;
                if (_query.isEmpty) return true;
                final nick =
                    (m['users']?['nickname'] as String? ?? '')
                        .toLowerCase();
                final uni =
                    (m['university'] as String? ?? '').toLowerCase();
                final dept =
                    (m['department'] as String? ?? '').toLowerCase();
                final q = _query.toLowerCase();
                return nick.contains(q) ||
                    uni.contains(q) ||
                    dept.contains(q);
              }).toList();

              if (filtered.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Text('검색 결과가 없어요',
                        style: AppTypography.callout
                            .copyWith(color: AppColors.textSub)),
                  ),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _MentorCard(
                    data: filtered[i],
                    onTap: () => context
                        .push('/mentor/${filtered[i]['user_id']}'),
                  ),
                  childCount: filtered.length,
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

class _MentorCard extends StatelessWidget {
  const _MentorCard({required this.data, required this.onTap});
  final Map<String, dynamic> data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final nickname = data['users']?['nickname'] as String? ?? '';
    final university = data['university'] as String?;
    final department = data['department'] as String?;
    final intro = data['intro'] as String?;
    final rating = (data['rating'] as num?)?.toDouble() ?? 0.0;
    final reviewCount = data['review_count'] as int? ?? 0;
    final verified = data['verified'] as bool? ?? false;
    final hourlyRateMin = data['hourly_rate_min'] as int?;
    final hourlyRateMax = data['hourly_rate_max'] as int?;
    final certs = (data['users']?['mentor_certifications'] as List<dynamic>?)
        ?.map((e) =>
            MentorCertification.fromJson(e as Map<String, dynamic>))
        .toList() ??
        [];

    String rateDisplay = '';
    if (hourlyRateMin != null) {
      rateDisplay = hourlyRateMax != null && hourlyRateMax != hourlyRateMin
          ? '₩${_fmt(hourlyRateMin)}~₩${_fmt(hourlyRateMax)}'
          : '₩${_fmt(hourlyRateMin)}';
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(
            horizontal: AppSpacing.base, vertical: AppSpacing.sm),
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
                      Row(
                        children: [
                          Text(nickname, style: AppTypography.bodyBold),
                          if (verified) ...[
                            const SizedBox(width: AppSpacing.xs),
                            const Icon(Icons.verified,
                                color: AppColors.accent, size: 16),
                          ],
                        ],
                      ),
                      if (university != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          [university, department]
                              .where((s) => s?.isNotEmpty == true)
                              .join(' · '),
                          style: AppTypography.footnote.copyWith(
                            color: AppColors.textSub,
                            fontWeight: verified
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (rateDisplay.isNotEmpty)
                  Text(rateDisplay,
                      style: AppTypography.priceSmall),
                MentorFavoriteButton(
                    mentorId: data['user_id'] as String),
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
                  style: AppTypography.footnote
                      .copyWith(color: AppColors.textSub),
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
                    style: AppTypography.captionBold
                        .copyWith(color: AppColors.textPrimary)),
                const SizedBox(width: AppSpacing.xs),
                Text('($reviewCount개)',
                    style: AppTypography.caption),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(int v) => v
      .toString()
      .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}
