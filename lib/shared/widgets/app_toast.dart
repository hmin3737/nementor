import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_spacing.dart';
import '../../core/app_typography.dart';

enum ToastType { success, error, info }

void showAppToast(
  BuildContext context,
  String message, {
  ToastType type = ToastType.info,
  Duration duration = const Duration(seconds: 2),
}) {
  final color = switch (type) {
    ToastType.success => AppColors.success,
    ToastType.error => AppColors.error,
    ToastType.info => AppColors.primary,
  };
  final icon = switch (type) {
    ToastType.success => Icons.check_circle_outline,
    ToastType.error => Icons.cancel_outlined,
    ToastType.info => Icons.info_outline,
  };

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: AppTypography.footnote.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: duration,
        margin: const EdgeInsets.fromLTRB(
          AppSpacing.base,
          AppSpacing.base,
          AppSpacing.base,
          AppSpacing.x2l,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.md),
        ),
        dismissDirection: type == ToastType.error
            ? DismissDirection.horizontal
            : DismissDirection.down,
      ),
    );
}
