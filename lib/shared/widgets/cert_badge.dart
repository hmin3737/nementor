import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_typography.dart';
import '../../shared/models/user_model.dart';

class CertBadge extends StatelessWidget {
  const CertBadge({
    super.key,
    required this.subject,
    required this.level,
    this.compact = false,
  });

  final String subject;
  final CertLevel level;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = level == CertLevel.master
        ? AppColors.masterCertColor
        : AppColors.proCertColor;
    final label = level == CertLevel.master ? 'MASTER' : 'PRO';

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            compact ? subject : '$subject ',
            style: (compact ? AppTypography.caption : AppTypography.footnote)
                .copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            label,
            style: (compact ? AppTypography.caption : AppTypography.footnote)
                .copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
