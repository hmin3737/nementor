import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/app_colors.dart';
import '../../../core/app_spacing.dart';
import '../../../core/app_strings.dart';
import '../../../core/app_typography.dart';
import '../../../shared/services/supabase_service.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../auth/providers/auth_provider.dart';

class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _nicknameCtrl = TextEditingController();
  final _introCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _universityCtrl = TextEditingController();
  final _departmentCtrl = TextEditingController();
  final _highSchoolCtrl = TextEditingController();
  bool _saving = false;
  bool _initialized = false;

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    _introCtrl.dispose();
    _bioCtrl.dispose();
    _universityCtrl.dispose();
    _departmentCtrl.dispose();
    _highSchoolCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final nick = _nicknameCtrl.text.trim();
    if (nick.length < 2) {
      showAppToast(context, '닉네임은 2자 이상이어야 해요', type: ToastType.error);
      return;
    }
    setState(() => _saving = true);
    try {
      final user = ref.read(currentUserProvider).valueOrNull;
      if (user == null) return;

      await SupabaseService.client
          .from(SupabaseService.usersTable)
          .update({'nickname': nick})
          .eq('id', user.id);

      // 멘토 프로필 업데이트
      if (user.role.name == 'mentor') {
        await SupabaseService.client
            .from(SupabaseService.mentorProfilesTable)
            .update({
          if (_introCtrl.text.trim().isNotEmpty)
            'intro': _introCtrl.text.trim(),
          if (_bioCtrl.text.trim().isNotEmpty) 'bio': _bioCtrl.text.trim(),
          if (_universityCtrl.text.trim().isNotEmpty)
            'university': _universityCtrl.text.trim(),
          if (_departmentCtrl.text.trim().isNotEmpty)
            'department': _departmentCtrl.text.trim(),
          if (_highSchoolCtrl.text.trim().isNotEmpty)
            'high_school': _highSchoolCtrl.text.trim(),
        }).eq('user_id', user.id);
      }

      if (mounted) {
        showAppToast(context, '프로필이 저장되었어요', type: ToastType.success);
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        showAppToast(context, AppStrings.serverError, type: ToastType.error);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final isMentor = user?.role.name == 'mentor';

    if (!_initialized && user != null) {
      _nicknameCtrl.text = user.nickname;
      _initialized = true;
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(AppStrings.editProfile, style: AppTypography.title3),
        centerTitle: true,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.base),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 아바타
              Center(
                child: Stack(
                  children: [
                    const CircleAvatar(
                      radius: AppSpacing.avatarLg / 2,
                      backgroundColor: AppColors.border,
                      child: Icon(Icons.person, size: 36, color: AppColors.textSub),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt,
                            color: Colors.white, size: 16),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              _sectionTitle('닉네임 *'),
              const SizedBox(height: AppSpacing.xs),
              _buildField(
                controller: _nicknameCtrl,
                hint: '2~12자',
                maxLength: 12,
              ),
              const SizedBox(height: AppSpacing.xl),

              if (isMentor) ...[
                _sectionTitle('멘토 소개'),
                const SizedBox(height: AppSpacing.xs),
                _buildField(
                  controller: _introCtrl,
                  hint: '한줄 소개 (최대 50자)',
                  maxLength: 50,
                ),
                const SizedBox(height: AppSpacing.sm),
                _buildField(
                  controller: _bioCtrl,
                  hint: '상세 소개',
                  maxLines: 4,
                ),
                const SizedBox(height: AppSpacing.xl),

                _sectionTitle('학력'),
                const SizedBox(height: AppSpacing.xs),
                _buildField(
                  controller: _highSchoolCtrl,
                  hint: '고등학교명',
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: _buildField(
                        controller: _universityCtrl,
                        hint: '대학교명',
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _buildField(
                        controller: _departmentCtrl,
                        hint: '학과명',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
              ],

              AppButton(
                label: AppStrings.save,
                variant: AppButtonVariant.primary,
                onPressed: _saving ? null : _save,
                isLoading: _saving,
              ),
              const SizedBox(height: AppSpacing.x2l),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(
        text,
        style: AppTypography.subhead.copyWith(fontWeight: FontWeight.w600),
      );

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    int? maxLength,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLength: maxLength,
      maxLines: maxLines,
      style: AppTypography.callout,
      decoration: InputDecoration(
        counterText: '',
        hintText: hint,
        hintStyle: AppTypography.callout.copyWith(color: AppColors.textDisabled),
        filled: true,
        fillColor: AppColors.card,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.base, vertical: AppSpacing.md),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
      ),
    );
  }
}
