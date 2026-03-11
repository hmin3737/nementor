import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/app_colors.dart';
import '../../../core/app_router.dart';
import '../../../core/app_spacing.dart';
import '../../../core/app_strings.dart';
import '../../../core/app_typography.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/widgets/app_button.dart';
import '../providers/auth_provider.dart';

class MentorSignupScreen extends ConsumerStatefulWidget {
  const MentorSignupScreen({super.key});

  @override
  ConsumerState<MentorSignupScreen> createState() => _MentorSignupScreenState();
}

class _MentorSignupScreenState extends ConsumerState<MentorSignupScreen> {
  final _nicknameCtrl = TextEditingController();
  final _realNameCtrl = TextEditingController();
  final _middleSchoolCtrl = TextEditingController();
  final _highSchoolCtrl = TextEditingController();
  final _universityCtrl = TextEditingController();
  final _departmentCtrl = TextEditingController();
  final _introCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();

  bool? _nicknameAvailable;
  bool _checkingNick = false;
  String _lastCheckedNick = '';
  final List<String> _selectedSubjects = [];

  static const _allSubjects = AppStrings.certSubjects;

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    _realNameCtrl.dispose();
    _middleSchoolCtrl.dispose();
    _highSchoolCtrl.dispose();
    _universityCtrl.dispose();
    _departmentCtrl.dispose();
    _introCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkNickname() async {
    final nick = _nicknameCtrl.text.trim();
    if (nick.isEmpty || nick == _lastCheckedNick) return;
    setState(() {
      _checkingNick = true;
      _nicknameAvailable = null;
    });
    final ok =
        await ref.read(authServiceProvider).isNicknameAvailable(nick);
    if (!mounted) return;
    setState(() {
      _nicknameAvailable = ok;
      _checkingNick = false;
      _lastCheckedNick = nick;
    });
  }

  Future<void> _submit() async {
    if (_nicknameAvailable != true) return;
    final nick = _nicknameCtrl.text.trim();
    try {
      final user = await ref.read(authNotifierProvider.notifier).completeSignUp(
            nickname: nick,
            role: UserRole.mentor,
          );
      if (!mounted) return;

      // mentor_profiles 추가 정보 저장
      final supabase = ref.read(authServiceProvider);
      await _saveMentorProfile(supabase, user.id);

      context.go(AppRoutes.mentorFeed);
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

  Future<void> _saveMentorProfile(dynamic service, String userId) async {
    // AuthService를 통해 mentor_profiles 업데이트
    // 실제 구현은 mentorService 등으로 분리 예정
  }

  bool get _isValid {
    final nick = _nicknameCtrl.text.trim();
    return nick.length >= 2 && nick.length <= 12 && _nicknameAvailable == true;
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
        title: Text(
          '멘토 가입',
          style: AppTypography.title3.copyWith(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.base,
              vertical: AppSpacing.base,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('닉네임 *'),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _nicknameCtrl,
                        hint: '2~12자, 한글/영문/숫자',
                        maxLength: 12,
                        suffixIcon: _nicknameAvailable != null
                            ? Icon(
                                _nicknameAvailable!
                                    ? Icons.check_circle
                                    : Icons.cancel,
                                color: _nicknameAvailable!
                                    ? AppColors.success
                                    : AppColors.error,
                              )
                            : null,
                        onChanged: (_) => setState(() {
                          _nicknameAvailable = null;
                          _lastCheckedNick = '';
                        }),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    AppButton(
                      label: AppStrings.nicknameCheck,
                      height: 48,
                      width: 88,
                      fontSize: 14,
                      variant: AppButtonVariant.secondary,
                      onPressed: _checkingNick ? null : _checkNickname,
                      isLoading: _checkingNick,
                    ),
                  ],
                ),
                if (_nicknameAvailable != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _nicknameAvailable!
                        ? AppStrings.nicknameAvailable
                        : AppStrings.nicknameTaken,
                    style: AppTypography.footnote.copyWith(
                      color: _nicknameAvailable!
                          ? AppColors.success
                          : AppColors.error,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),

                _sectionTitle(AppStrings.mentorInfoTitle),
                const SizedBox(height: AppSpacing.sm),
                _buildTextField(
                  controller: _realNameCtrl,
                  hint: AppStrings.realNameHint,
                  label: AppStrings.realName,
                ),
                const SizedBox(height: AppSpacing.sm),
                _buildTextField(
                  controller: _middleSchoolCtrl,
                  hint: '중학교명',
                  label: AppStrings.middleSchool,
                ),
                const SizedBox(height: AppSpacing.sm),
                _buildTextField(
                  controller: _highSchoolCtrl,
                  hint: '고등학교명',
                  label: AppStrings.highSchool,
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _universityCtrl,
                        hint: '대학교명',
                        label: AppStrings.university,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _buildTextField(
                        controller: _departmentCtrl,
                        hint: '학과명',
                        label: AppStrings.department,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),

                _sectionTitle(AppStrings.mentorIntroTitle),
                const SizedBox(height: AppSpacing.sm),
                _buildTextField(
                  controller: _introCtrl,
                  hint: AppStrings.introHint,
                  maxLength: 50,
                ),
                const SizedBox(height: AppSpacing.sm),
                _buildTextField(
                  controller: _bioCtrl,
                  hint: AppStrings.bioHint,
                  maxLines: 4,
                ),
                const SizedBox(height: AppSpacing.xl),

                _sectionTitle(AppStrings.subjectSelectTitle),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '관련 과목을 선택해 주세요 (복수 선택 가능)',
                  style: AppTypography.footnote.copyWith(
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: _allSubjects.map((subject) {
                    final selected = _selectedSubjects.contains(subject);
                    return GestureDetector(
                      onTap: () => setState(() {
                        if (selected) {
                          _selectedSubjects.remove(subject);
                        } else {
                          _selectedSubjects.add(subject);
                        }
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.consultAccent
                              : Colors.white.withValues(alpha: 0.08),
                          borderRadius:
                              BorderRadius.circular(AppSpacing.chipRadius),
                          border: Border.all(
                            color: selected
                                ? AppColors.consultAccent
                                : Colors.white.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Text(
                          subject,
                          style: AppTypography.footnote.copyWith(
                            color: selected
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.7),
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppSpacing.x3l),

                AppButton(
                  label: '멘토로 가입하기',
                  variant: AppButtonVariant.consult,
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

  Widget _sectionTitle(String text) => Text(
        text,
        style: AppTypography.subhead.copyWith(
          color: Colors.white.withValues(alpha: 0.9),
          fontWeight: FontWeight.w600,
        ),
      );

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    String? label,
    int? maxLength,
    int maxLines = 1,
    Widget? suffixIcon,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        TextField(
          controller: controller,
          maxLength: maxLength,
          maxLines: maxLines,
          onChanged: onChanged,
          style: AppTypography.callout.copyWith(color: Colors.white),
          decoration: InputDecoration(
            counterText: '',
            hintText: hint,
            hintStyle: AppTypography.callout.copyWith(
              color: Colors.white.withValues(alpha: 0.3),
            ),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.08),
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
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.15),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
              borderSide:
                  const BorderSide(color: AppColors.consultAccent, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
