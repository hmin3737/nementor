import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/app_colors.dart';
import '../../../core/app_spacing.dart';
import '../../../core/app_typography.dart';
import '../../../shared/services/supabase_service.dart';
import '../../../shared/widgets/app_button.dart';
import '../../auth/providers/auth_provider.dart';

enum _DocStatus { noDoc, pending, rejected }

enum _PickSource { gallery, camera, pdf }

/// 선택된 파일을 통일된 형태로 표현
class _PickedFile {
  const _PickedFile({required this.path, required this.name, required this.isPdf});
  final String path;
  final String name;
  final bool isPdf;
}

final _mentorDocStatusProvider =
    FutureProvider.autoDispose<_DocStatus>((ref) async {
  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user == null) return _DocStatus.noDoc;

  final rows = await SupabaseService.client
      .from(SupabaseService.mentorDocumentsTable)
      .select('status')
      .eq('mentor_id', user.id)
      .order('created_at', ascending: false)
      .limit(10);

  if (rows.isEmpty) return _DocStatus.noDoc;

  final statuses = rows.map((r) => r['status'] as String).toSet();
  if (statuses.contains('pending') || statuses.contains('approved')) {
    return _DocStatus.pending;
  }
  return _DocStatus.rejected;
});

class MentorDocumentScreen extends ConsumerStatefulWidget {
  const MentorDocumentScreen({super.key});

  @override
  ConsumerState<MentorDocumentScreen> createState() =>
      _MentorDocumentScreenState();
}

class _MentorDocumentScreenState extends ConsumerState<MentorDocumentScreen> {
  _PickedFile? _idPhoto;
  final List<_PickedFile> _additionalDocs = [];
  bool _uploading = false;
  final _picker = ImagePicker();

  /// 갤러리/카메라/PDF 중 소스를 선택하는 바텀시트 → 선택된 소스만 반환
  Future<_PickSource?> _showSourceSheet() async {
    return showModalBottomSheet<_PickSource>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppSpacing.base),
            _SheetOption(
              icon: Icons.photo_library_outlined,
              label: '갤러리에서 선택',
              onTap: () => Navigator.pop(ctx, _PickSource.gallery),
            ),
            _SheetOption(
              icon: Icons.camera_alt_outlined,
              label: '카메라로 촬영',
              onTap: () => Navigator.pop(ctx, _PickSource.camera),
            ),
            _SheetOption(
              icon: Icons.picture_as_pdf_outlined,
              label: 'PDF 파일 선택',
              onTap: () => Navigator.pop(ctx, _PickSource.pdf),
            ),
            const SizedBox(height: AppSpacing.base),
          ],
        ),
      ),
    );
  }

  /// 소스 선택 후 실제 파일 픽킹
  Future<_PickedFile?> _pickFile() async {
    final source = await _showSourceSheet();
    if (source == null || !mounted) return null;

    if (source == _PickSource.gallery || source == _PickSource.camera) {
      final file = await _picker.pickImage(
        source: source == _PickSource.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        imageQuality: 85,
      );
      if (file == null) return null;
      return _PickedFile(path: file.path, name: file.name, isPdf: false);
    } else {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      final picked = result?.files.firstOrNull;
      if (picked?.path == null) return null;
      return _PickedFile(path: picked!.path!, name: picked.name, isPdf: true);
    }
  }

  Future<void> _refreshUser() async {
    ref.invalidate(_mentorDocStatusProvider);
    ref.invalidate(currentUserProvider);
  }

  Future<void> _pickIdPhoto() async {
    final picked = await _pickFile();
    if (picked != null) setState(() => _idPhoto = picked);
  }

  Future<void> _pickAdditionalDoc() async {
    if (_additionalDocs.length >= 3) return;
    final picked = await _pickFile();
    if (picked != null) setState(() => _additionalDocs.add(picked));
  }

  Future<void> _submit() async {
    if (_idPhoto == null) return;
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;

    setState(() => _uploading = true);
    try {
      final ts = DateTime.now().millisecondsSinceEpoch;

      // Upload ID photo (required)
      final idExt = _idPhoto!.isPdf ? 'pdf' : 'jpg';
      final idPath = '${user.id}/${ts}_id_photo.$idExt';
      await SupabaseService.client.storage
          .from(SupabaseService.mentorDocumentsBucket)
          .upload(idPath, File(_idPhoto!.path));
      await SupabaseService.client
          .from(SupabaseService.mentorDocumentsTable)
          .insert({
        'mentor_id': user.id,
        'document_type': 'id_photo',
        'file_url': idPath,
      });

      // Upload optional docs
      for (int i = 0; i < _additionalDocs.length; i++) {
        final doc = _additionalDocs[i];
        final ext = doc.isPdf ? 'pdf' : 'jpg';
        final docPath = '${user.id}/${ts}_academic_$i.$ext';
        await SupabaseService.client.storage
            .from(SupabaseService.mentorDocumentsBucket)
            .upload(docPath, File(doc.path));
        await SupabaseService.client
            .from(SupabaseService.mentorDocumentsTable)
            .insert({
          'mentor_id': user.id,
          'document_type': 'academic_doc',
          'file_url': docPath,
        });
      }

      if (!mounted) return;
      ref.invalidate(_mentorDocStatusProvider);
      setState(() {
        _idPhoto = null;
        _additionalDocs.clear();
        _uploading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('업로드 중 오류가 발생했어요: $e'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(_mentorDocStatusProvider);

    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('서류 제출',
            style: AppTypography.title3.copyWith(color: Colors.white)),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () async {
              await ref.read(authNotifierProvider.notifier).signOut();
            },
            child: Text('로그아웃',
                style: AppTypography.callout
                    .copyWith(color: Colors.white.withValues(alpha: 0.7))),
          ),
        ],
      ),
      body: statusAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: Colors.white)),
        error: (_, __) => const Center(
            child: Text('오류가 발생했어요', style: TextStyle(color: Colors.white))),
        data: (status) {
          if (status == _DocStatus.pending) {
            return _PendingView(onRefresh: _refreshUser);
          }
          return _UploadView(
            isRejected: status == _DocStatus.rejected,
            idPhoto: _idPhoto,
            additionalDocs: _additionalDocs,
            uploading: _uploading,
            onPickId: _pickIdPhoto,
            onPickAdditional: _pickAdditionalDoc,
            onRemoveAdditional: (i) =>
                setState(() => _additionalDocs.removeAt(i)),
            onSubmit: _submit,
          );
        },
      ),
    );
  }
}

// ── 바텀시트 옵션 항목 ──────────────────────────────────────────
class _SheetOption extends StatelessWidget {
  const _SheetOption(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.accent),
      title: Text(label, style: AppTypography.callout),
      onTap: onTap,
    );
  }
}

class _PendingView extends StatelessWidget {
  const _PendingView({required this.onRefresh});
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x2l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.hourglass_top_rounded,
                color: Colors.white, size: 64),
            const SizedBox(height: AppSpacing.xl),
            Text('서류 심사 중입니다',
                style:
                    AppTypography.title2.copyWith(color: Colors.white)),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '관리자가 제출하신 서류를 검토하고 있어요.\n승인되면 멘토 활동을 시작할 수 있어요.',
              style: AppTypography.callout.copyWith(
                color: Colors.white.withValues(alpha: 0.6),
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.x2l),
            GestureDetector(
              onTap: onRefresh,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl, vertical: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius:
                      BorderRadius.circular(AppSpacing.chipRadius),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh,
                        color: Colors.white.withValues(alpha: 0.8),
                        size: 18),
                    const SizedBox(width: AppSpacing.xs),
                    Text('심사 결과 확인',
                        style: AppTypography.callout
                            .copyWith(color: Colors.white)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UploadView extends StatelessWidget {
  const _UploadView({
    required this.isRejected,
    required this.idPhoto,
    required this.additionalDocs,
    required this.uploading,
    required this.onPickId,
    required this.onPickAdditional,
    required this.onRemoveAdditional,
    required this.onSubmit,
  });

  final bool isRejected;
  final _PickedFile? idPhoto;
  final List<_PickedFile> additionalDocs;
  final bool uploading;
  final VoidCallback onPickId;
  final VoidCallback onPickAdditional;
  final void Function(int) onRemoveAdditional;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.x2l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isRejected) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.base),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cancel_outlined,
                      color: AppColors.error, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      '서류가 반려되었습니다. 다시 제출해 주세요.',
                      style: AppTypography.callout
                          .copyWith(color: AppColors.error),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
          Text(
            '멘토 서류 제출',
            style: AppTypography.title1.copyWith(color: Colors.white),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '활동을 시작하기 전에 신분 확인 서류를 제출해 주세요.\n관리자 검토 후 승인이 완료되면 활동할 수 있어요.',
            style: AppTypography.callout.copyWith(
              color: Colors.white.withValues(alpha: 0.6),
              height: 1.6,
            ),
          ),
          const SizedBox(height: AppSpacing.x2l),

          // ID photo (required)
          _SectionLabel(label: '신분증 사진 *', required: true),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '주민등록증, 운전면허증, 여권 중 하나를 선택하거나 촬영해 주세요.\n사진 또는 PDF로 제출 가능합니다.',
            style: AppTypography.footnote
                .copyWith(color: Colors.white.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: AppSpacing.md),
          _PickerTile(
            file: idPhoto,
            placeholder: '신분증 선택 (사진·PDF)',
            onTap: onPickId,
            onRemove: idPhoto != null ? onPickId : null,
          ),
          const SizedBox(height: AppSpacing.x2l),

          // Additional docs (optional)
          _SectionLabel(label: '학력 서류 (선택)', required: false),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '재학/졸업증명서, 성적증명서 등을 선택적으로 제출할 수 있어요.\n사진 또는 PDF · 최대 3개',
            style: AppTypography.footnote
                .copyWith(color: Colors.white.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: AppSpacing.md),
          ...List.generate(
            additionalDocs.length,
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _PickerTile(
                file: additionalDocs[i],
                placeholder: '학력 서류 ${i + 1}',
                onTap: () {},
                onRemove: () => onRemoveAdditional(i),
              ),
            ),
          ),
          if (additionalDocs.length < 3)
            _AddDocButton(onTap: onPickAdditional),
          const SizedBox(height: AppSpacing.x3l),

          AppButton(
            label: '서류 제출하기',
            onPressed: idPhoto != null && !uploading ? onSubmit : null,
            isLoading: uploading,
          ),
          const SizedBox(height: AppSpacing.x2l),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.required});
  final String label;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label,
            style: AppTypography.subhead.copyWith(
                color: Colors.white, fontWeight: FontWeight.w600)),
        if (required) ...[
          const SizedBox(width: AppSpacing.xs),
          const Text('*',
              style: TextStyle(color: AppColors.error, fontSize: 14)),
        ],
      ],
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.file,
    required this.placeholder,
    required this.onTap,
    this.onRemove,
  });
  final _PickedFile? file;
  final String placeholder;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final isPdf = file?.isPdf ?? false;
    return GestureDetector(
      onTap: file == null ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.base, vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          border: Border.all(
            color: file != null
                ? AppColors.success.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          children: [
            Icon(
              file != null
                  ? (isPdf ? Icons.picture_as_pdf : Icons.check_circle)
                  : Icons.upload_file_outlined,
              color: file != null
                  ? (isPdf ? AppColors.warning : AppColors.success)
                  : Colors.white.withValues(alpha: 0.4),
              size: 20,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                file != null ? file!.name : placeholder,
                style: AppTypography.callout.copyWith(
                  color: file != null
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.4),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onRemove != null)
              GestureDetector(
                onTap: onRemove,
                child: Icon(Icons.close,
                    color: Colors.white.withValues(alpha: 0.5), size: 18),
              ),
          ],
        ),
      ),
    );
  }
}

class _AddDocButton extends StatelessWidget {
  const _AddDocButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add,
                color: Colors.white.withValues(alpha: 0.5), size: 20),
            const SizedBox(width: AppSpacing.xs),
            Text('학력 서류 추가',
                style: AppTypography.callout.copyWith(
                    color: Colors.white.withValues(alpha: 0.5))),
          ],
        ),
      ),
    );
  }
}
