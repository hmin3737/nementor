import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/app_colors.dart';
import '../../core/app_spacing.dart';

class ShimmerBox extends StatelessWidget {
  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = AppSpacing.md,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.shimmerBase,
      highlightColor: AppColors.shimmerHighlight,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.shimmerBase,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

class ShimmerQuestionCard extends StatelessWidget {
  const ShimmerQuestionCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.shimmerBase,
      highlightColor: AppColors.shimmerHighlight,
      child: Container(
        margin: const EdgeInsets.symmetric(
            horizontal: AppSpacing.base, vertical: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.base),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                    width: 80, height: 20, color: AppColors.shimmerBase),
                Container(
                    width: 60, height: 20, color: AppColors.shimmerBase),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(width: double.infinity, height: 16, color: AppColors.shimmerBase),
            const SizedBox(height: AppSpacing.xs),
            Container(width: 200, height: 16, color: AppColors.shimmerBase),
            const SizedBox(height: AppSpacing.base),
            Container(width: 120, height: 12, color: AppColors.shimmerBase),
          ],
        ),
      ),
    );
  }
}
