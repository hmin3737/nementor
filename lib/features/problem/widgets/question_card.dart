import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/app_colors.dart';
import '../../../core/app_spacing.dart';
import '../../../core/app_strings.dart';
import '../../../core/app_typography.dart';
import '../../../shared/models/question_model.dart';

class QuestionCard extends StatefulWidget {
  const QuestionCard({
    super.key,
    required this.question,
    required this.onTap,
    this.showPreemptButton = false,
    this.onPreempt,
    this.showStatus = false,
  });

  final QuestionModel question;
  final VoidCallback onTap;
  final bool showPreemptButton;
  final VoidCallback? onPreempt;
  final bool showStatus;

  @override
  State<QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<QuestionCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween(begin: 1.0, end: 0.97)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String get _schoolLevelLabel {
    return switch (widget.question.schoolLevel) {
      SchoolLevel.elementary => AppStrings.elementary,
      SchoolLevel.middle => AppStrings.middle,
      SchoolLevel.high => AppStrings.high,
      SchoolLevel.etc => AppStrings.etc,
      null => '',
    };
  }

  String get _subjectLabel {
    return switch (widget.question.subject) {
      QuestionSubject.math => AppStrings.subjectMath,
      QuestionSubject.korean => AppStrings.subjectKorean,
      QuestionSubject.english => AppStrings.subjectEnglish,
      QuestionSubject.science => AppStrings.subjectScience,
      QuestionSubject.social => AppStrings.subjectSocial,
      QuestionSubject.etc => AppStrings.subjectEtc,
      null => '',
    };
  }

  String _formatPrice(int price) {
    return price.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    final timeStr = timeago.format(q.createdAt, locale: 'ko');
    final hasFilter =
        q.filter != null && q.filter!.filterType != MentorFilterType.all;

    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) => _ctrl.reverse(),
      onTapCancel: () => _ctrl.reverse(),
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) =>
            Transform.scale(scale: _scale.value, child: child),
        child: Container(
          margin: const EdgeInsets.symmetric(
            horizontal: AppSpacing.base,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            boxShadow: AppSpacing.cardShadow,
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.base),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 상단: 태그 + 상태배지 + 가격
                Row(
                  children: [
                    if (_schoolLevelLabel.isNotEmpty || _subjectLabel.isNotEmpty)
                      _TagChip(
                        label: [_schoolLevelLabel, _subjectLabel]
                            .where((s) => s.isNotEmpty)
                            .join(' · '),
                      ),
                    if (widget.showStatus) ...[
                      const SizedBox(width: AppSpacing.xs),
                      _StatusBadge(status: q.status),
                    ],
                    const Spacer(),
                    Text(
                      '₩${_formatPrice(q.price)}',
                      style: AppTypography.price,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                // 제목 또는 본문
                Text(
                  q.title?.isNotEmpty == true ? q.title! : q.body,
                  style: AppTypography.callout.copyWith(
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                // 이미지 썸네일
                if (q.imageUrls.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    height: 60,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: q.imageUrls.length.clamp(0, 3),
                      separatorBuilder: (_, __) =>
                          const SizedBox(width: AppSpacing.xs),
                      itemBuilder: (_, i) => ClipRRect(
                        borderRadius: BorderRadius.circular(AppSpacing.sm),
                        child: Image.network(
                          q.imageUrls[i],
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 60,
                            height: 60,
                            color: AppColors.surface,
                            child: const Icon(Icons.image_outlined,
                                color: AppColors.textDisabled),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                const Divider(height: 1, color: AppColors.divider),
                const SizedBox(height: AppSpacing.sm),
                // 하단: 시간 + 필터 배지 + 선점 버튼
                Row(
                  children: [
                    const Icon(
                      Icons.access_time,
                      size: 13,
                      color: AppColors.textSub,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(timeStr, style: AppTypography.caption),
                    if (hasFilter) ...[
                      const SizedBox(width: AppSpacing.sm),
                      _FilterBadge(filter: q.filter!),
                    ],
                    const Spacer(),
                    if (widget.showPreemptButton && widget.onPreempt != null)
                      GestureDetector(
                        onTap: widget.onPreempt,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            gradient: AppColors.accentGradient,
                            borderRadius:
                                BorderRadius.circular(AppSpacing.chipRadius),
                          ),
                          child: Text(
                            AppStrings.preempt,
                            style: AppTypography.captionBold.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: AppColors.textSub,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final QuestionStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      QuestionStatus.open => ('대기 중', AppColors.textSub),
      QuestionStatus.accepted => ('답변 중', const Color(0xFF1D7A3A)),
      QuestionStatus.closed => ('종료', AppColors.textDisabled),
      QuestionStatus.cancelled => ('취소됨', AppColors.error),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _FilterBadge extends StatelessWidget {
  const _FilterBadge({required this.filter});

  final QuestionFilter filter;

  String get _label {
    if (filter.filterType == MentorFilterType.specific) return '지정 멘토';
    if (filter.certConditions.isNotEmpty) {
      return '${filter.certConditions.first.subject} 프로↑';
    }
    return '조건 필터';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
      ),
      child: Text(
        _label,
        style: AppTypography.caption.copyWith(
          color: AppColors.accent,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
