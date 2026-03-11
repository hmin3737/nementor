import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/app_colors.dart';
import '../../../core/app_spacing.dart';
import '../../../core/app_strings.dart';
import '../../../core/app_typography.dart';
import '../../../shared/services/supabase_service.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_logo.dart';
import '../providers/auth_provider.dart';

enum _LoginMode { main, emailLogin, emailSignup, emailConfirmSent, forgotPassword, forgotPasswordSent }

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  _LoginMode _mode = _LoginMode.main;
  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _pwConfirmCtrl = TextEditingController();
  final _resetEmailCtrl = TextEditingController();
  bool _obscurePw = true;
  bool _obscurePwConfirm = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    _pwConfirmCtrl.dispose();
    _resetEmailCtrl.dispose();
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

  Future<void> _handleEmailLogin() async {
    final email = _emailCtrl.text.trim();
    final pw = _pwCtrl.text;
    if (email.isEmpty || pw.isEmpty) return;
    await ref.read(authNotifierProvider.notifier).signInWithEmail(email, pw);
    if (!mounted) return;
    final err = ref.read(authNotifierProvider).error;
    if (err != null) _showError(err.toString());
    // 성공 시 라우터 redirect가 자동 처리
  }

  Future<void> _handleEmailSignup() async {
    final email = _emailCtrl.text.trim();
    final pw = _pwCtrl.text;
    final pwConfirm = _pwConfirmCtrl.text;
    if (email.isEmpty || pw.isEmpty || pwConfirm.isEmpty) return;
    if (pw != pwConfirm) {
      _showError('비밀번호가 일치하지 않아요');
      return;
    }
    if (pw.length < 6) {
      _showError('비밀번호는 6자 이상이어야 해요');
      return;
    }
    await ref.read(authNotifierProvider.notifier).signUpWithEmail(email, pw);
    if (!mounted) return;
    final err = ref.read(authNotifierProvider).error;
    if (err != null) {
      _showError(err.toString());
      return;
    }
    // 세션이 생성됐으면 라우터가 roleSelect로 이동
    // 이메일 인증이 필요하면 확인 안내 화면으로
    final hasSession = SupabaseService.client.auth.currentUser != null;
    if (!hasSession) {
      setState(() => _mode = _LoginMode.emailConfirmSent);
    }
  }

  Future<void> _handleResetPassword() async {
    final email = _resetEmailCtrl.text.trim();
    if (email.isEmpty) return;
    await ref.read(authNotifierProvider.notifier).resetPassword(email);
    if (!mounted) return;
    final err = ref.read(authNotifierProvider).error;
    if (err != null) {
      _showError(err.toString());
    } else {
      setState(() => _mode = _LoginMode.forgotPasswordSent);
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
            padding: EdgeInsets.only(
              left: AppSpacing.x2l,
              right: AppSpacing.x2l,
              bottom: bottom + AppSpacing.x2l,
            ),
            child: SizedBox(
              height: MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom,
              child: switch (_mode) {
                _LoginMode.main => _buildMain(isLoading),
                _LoginMode.emailLogin => _buildEmailLogin(isLoading),
                _LoginMode.emailSignup => _buildEmailSignup(isLoading),
                _LoginMode.emailConfirmSent => _buildEmailConfirmSent(),
                _LoginMode.forgotPassword => _buildForgotPassword(isLoading),
                _LoginMode.forgotPasswordSent => _buildForgotPasswordSent(),
              },
            ),
          ),
        ),
      ),
    );
  }

  // ── 공통 헤더 ────────────────────────────────────────────────

  Widget _buildLogo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.x4l),
        const AppLogo(size: 48, color: Colors.white),
      ],
    );
  }

  Widget _buildBackButton({_LoginMode backTo = _LoginMode.main}) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.base),
      child: GestureDetector(
        onTap: () => setState(() => _mode = backTo),
        child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
      ),
    );
  }

  // ── 메인 화면 ────────────────────────────────────────────────

  Widget _buildMain(bool isLoading) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLogo(),
        const SizedBox(height: AppSpacing.x2l),
        Text(
          AppStrings.loginTitle,
          style: AppTypography.display.copyWith(color: Colors.white),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          AppStrings.loginSubtitle,
          style: AppTypography.callout.copyWith(
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
        const Spacer(),
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
        _SocialButton(
          label: '이메일로 로그인',
          backgroundColor: Colors.white.withValues(alpha: 0.12),
          textColor: Colors.white,
          icon: Icons.email_outlined,
          iconColor: Colors.white,
          onPressed: () => setState(() {
            _mode = _LoginMode.emailLogin;
            _emailCtrl.clear();
            _pwCtrl.clear();
          }),
        ),
        const SizedBox(height: AppSpacing.xl),
        Center(
          child: GestureDetector(
            onTap: () => setState(() {
              _mode = _LoginMode.emailSignup;
              _emailCtrl.clear();
              _pwCtrl.clear();
              _pwConfirmCtrl.clear();
            }),
            child: RichText(
              text: TextSpan(
                text: '처음이세요? ',
                style: AppTypography.footnote.copyWith(
                  color: Colors.white.withValues(alpha: 0.5),
                ),
                children: [
                  TextSpan(
                    text: '이메일로 회원가입',
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
    );
  }

  // ── 이메일 로그인 ────────────────────────────────────────────

  Widget _buildEmailLogin(bool isLoading) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBackButton(),
        const SizedBox(height: AppSpacing.xl),
        Text(
          '이메일로 로그인',
          style: AppTypography.title1.copyWith(color: Colors.white),
        ),
        const SizedBox(height: AppSpacing.x2l),
        _buildInput(
          controller: _emailCtrl,
          hint: '이메일',
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: AppSpacing.sm),
        _buildInput(
          controller: _pwCtrl,
          hint: '비밀번호',
          obscure: _obscurePw,
          onSubmitted: (_) => _handleEmailLogin(),
          suffixIcon: _obscureToggle(),
        ),
        const SizedBox(height: AppSpacing.base),
        AppButton(
          label: '로그인',
          onPressed: isLoading ? null : _handleEmailLogin,
          isLoading: isLoading,
        ),
        const SizedBox(height: AppSpacing.md),
        Center(
          child: TextButton(
            onPressed: () => setState(() {
              _mode = _LoginMode.forgotPassword;
              _resetEmailCtrl.text = _emailCtrl.text;
            }),
            child: Text(
              '비밀번호를 잊으셨나요?',
              style: AppTypography.footnote.copyWith(color: AppColors.accent),
            ),
          ),
        ),
        const Spacer(),
        Center(
          child: GestureDetector(
            onTap: () => setState(() {
              _mode = _LoginMode.emailSignup;
              _pwCtrl.clear();
            }),
            child: RichText(
              text: TextSpan(
                text: '계정이 없으신가요? ',
                style: AppTypography.footnote.copyWith(
                  color: Colors.white.withValues(alpha: 0.5),
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
        const SizedBox(height: AppSpacing.x2l),
      ],
    );
  }

  // ── 이메일 회원가입 ──────────────────────────────────────────

  Widget _buildEmailSignup(bool isLoading) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBackButton(),
        const SizedBox(height: AppSpacing.xl),
        Text(
          '이메일로 회원가입',
          style: AppTypography.title1.copyWith(color: Colors.white),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '가입 후 이메일 인증이 필요합니다',
          style: AppTypography.callout.copyWith(
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: AppSpacing.x2l),
        _buildInput(
          controller: _emailCtrl,
          hint: '이메일',
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: AppSpacing.sm),
        _buildInput(
          controller: _pwCtrl,
          hint: '비밀번호 (6자 이상)',
          obscure: _obscurePw,
          suffixIcon: _obscureToggle(),
        ),
        const SizedBox(height: AppSpacing.sm),
        _buildInput(
          controller: _pwConfirmCtrl,
          hint: '비밀번호 확인',
          obscure: _obscurePwConfirm,
          onSubmitted: (_) => _handleEmailSignup(),
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePwConfirm ? Icons.visibility_off : Icons.visibility,
              color: Colors.white54,
            ),
            onPressed: () => setState(() => _obscurePwConfirm = !_obscurePwConfirm),
          ),
        ),
        const SizedBox(height: AppSpacing.base),
        AppButton(
          label: '가입하기',
          onPressed: isLoading ? null : _handleEmailSignup,
          isLoading: isLoading,
        ),
        const Spacer(),
        Center(
          child: GestureDetector(
            onTap: () => setState(() {
              _mode = _LoginMode.emailLogin;
              _pwCtrl.clear();
              _pwConfirmCtrl.clear();
            }),
            child: RichText(
              text: TextSpan(
                text: '이미 계정이 있으신가요? ',
                style: AppTypography.footnote.copyWith(
                  color: Colors.white.withValues(alpha: 0.5),
                ),
                children: [
                  TextSpan(
                    text: '로그인',
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
        const SizedBox(height: AppSpacing.x2l),
      ],
    );
  }

  // ── 이메일 인증 안내 ─────────────────────────────────────────

  Widget _buildEmailConfirmSent() {
    final email = _emailCtrl.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Align(alignment: Alignment.centerLeft, child: _buildBackButton()),
        const Spacer(),
        const Icon(Icons.mark_email_unread_outlined, color: Colors.white, size: 72),
        const SizedBox(height: AppSpacing.x2l),
        Text(
          '인증 이메일을 보냈어요',
          style: AppTypography.title1.copyWith(color: Colors.white),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          '$email\n으로 인증 링크를 발송했습니다.\n링크 클릭 후 아래 버튼을 눌러 로그인해 주세요.',
          style: AppTypography.callout.copyWith(
            color: Colors.white.withValues(alpha: 0.6),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.x2l),
        AppButton(
          label: '인증 완료 → 로그인하기',
          onPressed: () => setState(() {
            _mode = _LoginMode.emailLogin;
            _pwCtrl.clear();
          }),
        ),
        const Spacer(),
        const SizedBox(height: AppSpacing.x2l),
      ],
    );
  }

  // ── 비밀번호 재설정 ──────────────────────────────────────────

  Widget _buildForgotPassword(bool isLoading) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBackButton(backTo: _LoginMode.emailLogin),
        const SizedBox(height: AppSpacing.xl),
        Text(
          '비밀번호 재설정',
          style: AppTypography.title1.copyWith(color: Colors.white),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '가입한 이메일로 재설정 링크를 보내드립니다',
          style: AppTypography.callout.copyWith(
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: AppSpacing.x2l),
        _buildInput(
          controller: _resetEmailCtrl,
          hint: '이메일',
          keyboardType: TextInputType.emailAddress,
          onSubmitted: (_) => _handleResetPassword(),
        ),
        const SizedBox(height: AppSpacing.base),
        AppButton(
          label: '재설정 링크 보내기',
          onPressed: isLoading ? null : _handleResetPassword,
          isLoading: isLoading,
        ),
        const Spacer(),
        const SizedBox(height: AppSpacing.x2l),
      ],
    );
  }

  Widget _buildForgotPasswordSent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: _buildBackButton(backTo: _LoginMode.emailLogin),
        ),
        const Spacer(),
        const Icon(Icons.lock_reset, color: Colors.white, size: 72),
        const SizedBox(height: AppSpacing.x2l),
        Text(
          '이메일을 확인해 주세요',
          style: AppTypography.title1.copyWith(color: Colors.white),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          '비밀번호 재설정 링크를 발송했습니다.\n링크를 클릭하여 새 비밀번호를 설정해 주세요.',
          style: AppTypography.callout.copyWith(
            color: Colors.white.withValues(alpha: 0.6),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.x2l),
        AppButton(
          label: '로그인으로 돌아가기',
          onPressed: () => setState(() => _mode = _LoginMode.emailLogin),
        ),
        const Spacer(),
        const SizedBox(height: AppSpacing.x2l),
      ],
    );
  }

  // ── 공통 위젯 ────────────────────────────────────────────────

  Widget _obscureToggle() => IconButton(
        icon: Icon(
          _obscurePw ? Icons.visibility_off : Icons.visibility,
          color: Colors.white54,
        ),
        onPressed: () => setState(() => _obscurePw = !_obscurePw),
      );

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
          color: Colors.white.withValues(alpha: 0.4),
        ),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.1),
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
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
      ),
    );
  }
}

// ── 소셜 로그인 버튼 ─────────────────────────────────────────

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
