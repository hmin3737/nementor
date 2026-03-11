import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_spacing.dart';
import '../../core/app_typography.dart';

enum AppButtonVariant { primary, secondary, ghost, danger, consult }

class AppButton extends StatefulWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.icon,
    this.height,
    this.width,
    this.fontSize,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool isLoading;
  final IconData? icon;
  final double? height;
  final double? width;
  final double? fontSize;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) => _controller.forward();
  void _onTapUp(TapUpDetails _) => _controller.reverse();
  void _onTapCancel() => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null || widget.isLoading;
    final config = _ButtonConfig.of(widget.variant);

    return GestureDetector(
      onTapDown: disabled ? null : _onTapDown,
      onTapUp: disabled ? null : _onTapUp,
      onTapCancel: disabled ? null : _onTapCancel,
      onTap: disabled ? null : widget.onPressed,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) =>
            Transform.scale(scale: _scale.value, child: child),
        child: AnimatedOpacity(
          opacity: disabled ? 0.4 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: Container(
            height: widget.height ?? AppSpacing.buttonHeight,
            width: widget.width,
            decoration: BoxDecoration(
              color: config.backgroundColor,
              borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
              border: config.border,
              gradient: config.gradient,
            ),
            child: Center(
              child: widget.isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(config.textColor),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.icon != null) ...[
                          Icon(widget.icon, color: config.textColor, size: 20),
                          const SizedBox(width: AppSpacing.sm),
                        ],
                        Text(
                          widget.label,
                          style: AppTypography.button.copyWith(
                            color: config.textColor,
                            fontSize: widget.fontSize,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ButtonConfig {
  const _ButtonConfig({
    this.backgroundColor,
    this.gradient,
    this.border,
    required this.textColor,
  });

  final Color? backgroundColor;
  final Gradient? gradient;
  final BoxBorder? border;
  final Color textColor;

  factory _ButtonConfig.of(AppButtonVariant variant) {
    switch (variant) {
      case AppButtonVariant.primary:
        return const _ButtonConfig(
          gradient: AppColors.accentGradient,
          textColor: AppColors.textOnAccent,
        );
      case AppButtonVariant.consult:
        return const _ButtonConfig(
          gradient: AppColors.consultGradient,
          textColor: AppColors.textOnAccent,
        );
      case AppButtonVariant.secondary:
        return _ButtonConfig(
          backgroundColor: AppColors.surface,
          border: Border.all(color: AppColors.border),
          textColor: AppColors.textPrimary,
        );
      case AppButtonVariant.ghost:
        return const _ButtonConfig(
          backgroundColor: Colors.transparent,
          textColor: AppColors.accent,
        );
      case AppButtonVariant.danger:
        return const _ButtonConfig(
          backgroundColor: AppColors.error,
          textColor: AppColors.textOnAccent,
        );
    }
  }
}
