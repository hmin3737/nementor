import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
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
  String? _avatarUrl;
  File? _newAvatarFile;
  final _picker = ImagePicker();

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

  Future<void> _initMentorProfile(String userId) async {
    try {
      final data = await SupabaseService.client
          .from(SupabaseService.mentorProfilesTable)
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      if (data != null && mounted) {
        setState(() {
          _introCtrl.text = data['intro'] as String? ?? '';
          _bioCtrl.text = data['bio'] as String? ?? '';
          _universityCtrl.text = data['university'] as String? ?? '';
          _departmentCtrl.text = data['department'] as String? ?? '';
          _highSchoolCtrl.text = data['high_school'] as String? ?? '';
        });
      }
    } catch (_) {}
  }

  Future<void> _pickAvatar() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (file == null || !mounted) return;
    setState(() => _newAvatarFile = File(file.path));
  }

  Future<void> _save() async {
    final nick = _nicknameCtrl.text.trim();
    if (nick.length < 2) {
      showAppToast(context, '닉네임은 2자 이상이어야 해요', type: ToastType.error);
      return;
    }
    setState(() => _saving = true);

    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) {
      if (mounted) setState(() => _saving = false);
      return;
    }

    bool hasError = false;

    // ① 아바타 업로드 + users 업데이트
    try {
      String? uploadedAvatarUrl;
      if (_newAvatarFile != null) {
        final ts = DateTime.now().millisecondsSinceEpoch;
        final path = '${user.id}/avatar_$ts.jpg';
        await SupabaseService.client.storage
            .from(SupabaseService.avatarsBucket)
            .upload(path, _newAvatarFile!);
        uploadedAvatarUrl = SupabaseService.client.storage
            .from(SupabaseService.avatarsBucket)
            .getPublicUrl(path);
      }
      await SupabaseService.client
          .from(SupabaseService.usersTable)
          .update({
        'nickname': nick,
        if (uploadedAvatarUrl != null) 'avatar_url': uploadedAvatarUrl,
      }).eq('id', user.id);
    } catch (e) {
      hasError = true;
    }

    // ② 멘토 프로필 업데이트 (users 실패와 무관하게 독립 실행)
    if (user.role.name == 'mentor') {
      try {
        await SupabaseService.client
            .from(SupabaseService.mentorProfilesTable)
            .update({
          'intro': _introCtrl.text.trim().isEmpty
              ? null
              : _introCtrl.text.trim(),
          'bio': _bioCtrl.text.trim().isEmpty ? null : _bioCtrl.text.trim(),
          'university': _universityCtrl.text.trim().isEmpty
              ? null
              : _universityCtrl.text.trim(),
          'department': _departmentCtrl.text.trim().isEmpty
              ? null
              : _departmentCtrl.text.trim(),
          'high_school': _highSchoolCtrl.text.trim().isEmpty
              ? null
              : _highSchoolCtrl.text.trim(),
        }).eq('user_id', user.id);
      } catch (e) {
        hasError = true;
      }
    }

    ref.invalidate(currentUserProvider);

    if (mounted) {
      if (hasError) {
        showAppToast(context, AppStrings.serverError, type: ToastType.error);
      } else {
        showAppToast(context, '프로필이 저장되었어요', type: ToastType.success);
        context.pop();
      }
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final isMentor = user?.role.name == 'mentor';

    if (!_initialized && user != null) {
      _nicknameCtrl.text = user.nickname;
      _avatarUrl = user.avatarUrl;
      _initialized = true;
      if (isMentor) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _initMentorProfile(user.id);
        });
      }
    }

    final avatarWidget = _newAvatarFile != null
        ? CircleAvatar(
            radius: AppSpacing.avatarLg / 2,
            backgroundImage: FileImage(_newAvatarFile!),
          )
        : (_avatarUrl != null && _avatarUrl!.isNotEmpty
            ? CircleAvatar(
                radius: AppSpacing.avatarLg / 2,
                backgroundImage: NetworkImage(_avatarUrl!),
              )
            : const CircleAvatar(
                radius: AppSpacing.avatarLg / 2,
                backgroundColor: AppColors.border,
                child:
                    Icon(Icons.person, size: 36, color: AppColors.textSub),
              ));

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: AppColors.textPrimary),
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
                child: GestureDetector(
                  onTap: _pickAvatar,
                  child: Stack(
                    children: [
                      avatarWidget,
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
        hintStyle:
            AppTypography.callout.copyWith(color: AppColors.textDisabled),
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
