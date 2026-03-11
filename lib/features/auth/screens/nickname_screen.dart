import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/app_colors.dart';
import '../../../core/app_spacing.dart';
import '../../../core/app_strings.dart';
import '../../../core/app_typography.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/widgets/app_button.dart';
import '../providers/auth_provider.dart';

class NicknameScreen extends ConsumerStatefulWidget {
  const NicknameScreen({super.key, required this.role});

  final UserRole role;

  @override
  ConsumerState<NicknameScreen> createState() => _NicknameScreenState();
}

class _NicknameScreenState extends ConsumerState<NicknameScreen> {
  final _ctrl = TextEditingController();
  bool? _isAvailable;
  bool _checking = false;
  String _lastChecked = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _checkNickname() async {
    final nick = _ctrl.text.trim();
    if (nick.isEmpty || nick == _lastChecked) return;
    setState(() {
      _checking = true;
      _isAvailable = null;
    });
    final ok =
        await ref.read(authServiceProvider).isNicknameAvailable(nick);
    if (!mounted) return;
    setState(() {
      _isAvailable = ok;
      _checking = false;
      _lastChecked = nick;
    });
  }

  Future<void> _submit() async {
    if (_isAvailable != true) return;
    final nick = _ctrl.text.trim();
    try {
      await ref.read(authNotifierProvider.notifier).completeSignUp(
            nickname: nick,
            role: widget.role,
          );
      if (!mounted) return;
      if (widget.role == UserRole.mentor) {
        context.go('/mentor/feed');
      } else {
        context.go('/student/feed');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  bool get _isValid {
    final nick = _ctrl.text.trim();
    return nick.length >= 2 && nick.length <= 12 && _isAvailable == true;
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authNotifierProvider).isLoading;

    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x2l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.xl),
                Text(
                  AppStrings.nicknameTitle,
                  style: AppTypography.title1.copyWith(color: Colors.white),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  AppStrings.nicknameHint,
                  style: AppTypography.callout.copyWith(
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: AppSpacing.x2l),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        maxLength: 12,
                        style: AppTypography.body.copyWith(
                          color: Colors.white,
                        ),
                        onChanged: (_) {
                          if (_lastChecked.isNotEmpty) {
                            setState(() {
                              _isAvailable = null;
                              _lastChecked = '';
                            });
                          }
                        },
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: '닉네임 입력',
                          hintStyle: AppTypography.body.copyWith(
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.08),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.base,
                            vertical: AppSpacing.md,
                          ),
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppSpacing.inputRadius),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppSpacing.inputRadius),
                            borderSide: BorderSide(
                              color: _isAvailable == null
                                  ? Colors.white.withValues(alpha: 0.15)
                                  : _isAvailable!
                                      ? AppColors.success
                                      : AppColors.error,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppSpacing.inputRadius),
                            borderSide: const BorderSide(
                              color: AppColors.accent,
                              width: 1.5,
                            ),
                          ),
                          suffixIcon: _isAvailable != null
                              ? Icon(
                                  _isAvailable!
                                      ? Icons.check_circle
                                      : Icons.cancel,
                                  color: _isAvailable!
                                      ? AppColors.success
                                      : AppColors.error,
                                )
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    AppButton(
                      label: AppStrings.nicknameCheck,
                      height: 48,
                      width: 88,
                      fontSize: 14,
                      variant: AppButtonVariant.secondary,
                      onPressed: _checking ? null : _checkNickname,
                      isLoading: _checking,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                if (_isAvailable != null)
                  Text(
                    _isAvailable!
                        ? AppStrings.nicknameAvailable
                        : AppStrings.nicknameTaken,
                    style: AppTypography.footnote.copyWith(
                      color: _isAvailable!
                          ? AppColors.success
                          : AppColors.error,
                    ),
                  ),
                const Spacer(),
                AppButton(
                  label: '완료',
                  onPressed: _isValid && !isLoading ? _submit : null,
                  isLoading: isLoading,
                ),
                const SizedBox(height: AppSpacing.x2l),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
