import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/app_colors.dart';
import '../../../core/app_router.dart';
import '../../../core/app_spacing.dart';
import '../../../core/app_strings.dart';
import '../../../core/app_typography.dart';
import '../../../shared/widgets/app_button.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _showEmailForm = false;
  bool _isSignUp = false;
  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  bool _obscurePw = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleKakao() async {
    await ref.read(authNotifierProvider.notifier).signInWithKakao();
    if (!mounted) return;
    final err = ref.read(authNotifierProvider).error;
    if (err != null) _showError(err.toString());
  }

  Future<void> _handleApple() async {
    await ref.read(authNotifierProvider.notifier).signInWithApple();
    if (!mounted) return;
    final err = ref.read(authNotifierProvider).error;
    if (err != null) _showError(err.toString());
  }

  Future<void> _handleEmailSubmit() async {
    final email = _emailCtrl.text.trim();
    final pw = _pwCtrl.text;
    if (email.isEmpty || pw.isEmpty) return;

    if (_isSignUp) {
      await ref.read(authNotifierProvider.notifier).signUpWithEmail(email, pw);
      if (!mounted) return;
      final err = ref.read(authNotifierProvider).error;
      if (err != null) {
        _showError(err.toString());
      } else {
        context.go(AppRoutes.roleSelect);
      }
    } else {
      await ref.read(authNotifierProvider.notifier).signInWithEmail(email, pw);
      if (!mounted) return;
      final err = ref.read(authNotifierProvider).error;
      if (err != null) _showError(err.toString());
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(AppSpacing.base),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.md),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authNotifierProvider).isLoading;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            padding: EdgeInsets.only(bottom: bottom + AppSpacing.x2l),
            child: SizedBox(
              height: MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.x2l),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.x4l),
                    // 로고
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Center(
                        child: Text(
                          'N',
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.x2l),
                    Text(
                      AppStrings.loginTitle,
                      style: AppTypography.display.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      AppStrings.loginSubtitle,
                      style: AppTypography.callout.copyWith(
                        color: Colors.white.withOpacity(0.6),
                      ),
                    ),
                    const Spacer(),
                    // 이메일 폼
                    if (_showEmailForm) ...[
                      _EmailForm(
                        emailCtrl: _emailCtrl,
                        pwCtrl: _pwCtrl,
                        obscurePw: _obscurePw,
                        isSignUp: _isSignUp,
                        onToggleObscure: () =>
                            setState(() => _obscurePw = !_obscurePw),
                        onToggleMode: () =>
                            setState(() => _isSignUp = !_isSignUp),
                        onSubmit: _handleEmailSubmit,
                        isLoading: isLoading,
                      ),
                      const SizedBox(height: AppSpacing.base),
                      TextButton(
                        onPressed: () =>
                            setState(() => _showEmailForm = false),
                        child: Text(
                          '다른 방법으로 로그인',
                          style: AppTypography.subhead.copyWith(
                            color: Colors.white.withOpacity(0.6),
                          ),
                        ),
                      ),
                    ] else ...[
                      // 카카오 버튼
                      _SocialButton(
                        label: AppStrings.kakaoLogin,
                        backgroundColor: const Color(0xFFFEE500),
                        textColor: const Color(0xFF191919),
                        icon: Icons.chat_bubble_rounded,
                        iconColor: const Color(0xFF191919),
                        onPressed: isLoading ? null : _handleKakao,
                        isLoading: isLoading,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      // 애플 버튼
                      _SocialButton(
                        label: AppStrings.appleLogin,
                        backgroundColor: Colors.white,
                        textColor: Colors.black,
                        icon: Icons.apple_rounded,
                        iconColor: Colors.black,
                        onPressed: isLoading ? null : _handleApple,
                        isLoading: isLoading,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      // 이메일 버튼
                      _SocialButton(
                        label: AppStrings.emailLogin,
                        backgroundColor: Colors.white.withOpacity(0.12),
                        textColor: Colors.white,
                        icon: Icons.email_outlined,
                        iconColor: Colors.white,
                        onPressed: () =>
                            setState(() => _showEmailForm = true),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    // 가입 유도
                    if (!_showEmailForm)
                      Center(
                        child: GestureDetector(
                          onTap: () => context.go(AppRoutes.roleSelect),
                          child: RichText(
                            text: TextSpan(
                              text: '처음이세요? ',
                              style: AppTypography.footnote.copyWith(
                                color: Colors.white.withOpacity(0.5),
                              ),
                              children: [
                                TextSpan(
                                  text: '회원가입',
                                  style: AppTypography.footnote.copyWith(
                                    color: AppColors.accent,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: AppSpacing.base),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SocialButton extends StatefulWidget {
  const _SocialButton({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    required this.icon,
    required this.iconColor,
    this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final Color backgroundColor;
  final Color textColor;
  final IconData icon;
  final Color iconColor;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  State<_SocialButton> createState() => _SocialButtonState();
}

class _SocialButtonState extends State<_SocialButton>
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onPressed == null ? null : (_) => _ctrl.forward(),
      onTapUp: widget.onPressed == null ? null : (_) => _ctrl.reverse(),
      onTapCancel: () => _ctrl.reverse(),
      onTap: widget.onPressed,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) =>
            Transform.scale(scale: _scale.value, child: child),
        child: Container(
          height: AppSpacing.buttonHeight,
          decoration: BoxDecoration(
            color: widget.backgroundColor,
            borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.isLoading)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: widget.textColor,
                  ),
                )
              else ...[
                Icon(widget.icon, color: widget.iconColor, size: 22),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  widget.label,
                  style: AppTypography.calloutBold.copyWith(
                    color: widget.textColor,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EmailForm extends StatelessWidget {
  const _EmailForm({
    required this.emailCtrl,
    required this.pwCtrl,
    required this.obscurePw,
    required this.isSignUp,
    required this.onToggleObscure,
    required this.onToggleMode,
    required this.onSubmit,
    required this.isLoading,
  });

  final TextEditingController emailCtrl;
  final TextEditingController pwCtrl;
  final bool obscurePw;
  final bool isSignUp;
  final VoidCallback onToggleObscure;
  final VoidCallback onToggleMode;
  final VoidCallback onSubmit;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInput(
          controller: emailCtrl,
          hint: '이메일',
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: AppSpacing.sm),
        _buildInput(
          controller: pwCtrl,
          hint: '비밀번호',
          obscure: obscurePw,
          suffixIcon: IconButton(
            icon: Icon(
              obscurePw ? Icons.visibility_off : Icons.visibility,
              color: Colors.white54,
            ),
            onPressed: onToggleObscure,
          ),
          onSubmitted: (_) => onSubmit(),
        ),
        const SizedBox(height: AppSpacing.base),
        AppButton(
          label: isSignUp ? '가입하기' : '로그인',
          onPressed: isLoading ? null : onSubmit,
          isLoading: isLoading,
        ),
        const SizedBox(height: AppSpacing.sm),
        Center(
          child: TextButton(
            onPressed: onToggleMode,
            child: Text(
              isSignUp ? '이미 계정이 있어요 → 로그인' : '계정이 없어요 → 이메일 가입',
              style: AppTypography.footnote.copyWith(
                color: AppColors.accent,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String hint,
    bool obscure = false,
    TextInputType? keyboardType,
    Widget? suffixIcon,
    ValueChanged<String>? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      onSubmitted: onSubmitted,
      style: AppTypography.callout.copyWith(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTypography.callout.copyWith(
          color: Colors.white.withOpacity(0.4),
        ),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          borderSide:
              const BorderSide(color: AppColors.accent, width: 1.5),
        ),
      ),
    );
  }
}
