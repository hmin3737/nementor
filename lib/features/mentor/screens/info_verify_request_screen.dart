import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/app_colors.dart';
import '../../../core/app_spacing.dart';
import '../../../core/app_typography.dart';
import '../../../shared/services/supabase_service.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../auth/providers/auth_provider.dart';

// ── 내 요청 내역 ─────────────────────────────────────────────────
final _myInfoVerifyRequestsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user == null) return [];
  final rows = await SupabaseService.client
      .from('info_verify_requests')
      .select()
      .eq('mentor_id', user.id)
      .order('created_at', ascending: false);
  return (rows as List).cast<Map<String, dynamic>>();
});

enum _PickSource { gallery, camera, pdf }

class _PickedFile {
  const _PickedFile(
      {required this.path, required this.name, required this.isPdf});
  final String path;
  final String name;
  final bool isPdf;
}

class InfoVerifyRequestScreen extends ConsumerStatefulWidget {
  const InfoVerifyRequestScreen({super.key});

  @override
  ConsumerState<InfoVerifyRequestScreen> createState() =>
      _InfoVerifyRequestScreenState();
}

class _InfoVerifyRequestScreenState
    extends ConsumerState<InfoVerifyRequestScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  final _labelCtrl = TextEditingController(); // 항목 종류 (field_key)
  final _valueCtrl = TextEditingController(); // 항목 내용 (field_value)
  final _noteCtrl = TextEditingController();  // 추가 설명
  final _picker = ImagePicker();
  _PickedFile? _attachedFile;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _labelCtrl.dispose();
    _valueCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final source = await showModalBottomSheet<_PickSource>(
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
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: AppColors.accent),
              title: Text('갤러리에서 선택', style: AppTypography.callout),
              onTap: () => Navigator.pop(ctx, _PickSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined,
                  color: AppColors.accent),
              title: Text('카메라로 촬영', style: AppTypography.callout),
              onTap: () => Navigator.pop(ctx, _PickSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined,
                  color: AppColors.accent),
              title: Text('PDF 파일 선택', style: AppTypography.callout),
              onTap: () => Navigator.pop(ctx, _PickSource.pdf),
            ),
            const SizedBox(height: AppSpacing.base),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    if (source == _PickSource.pdf) {
      final result = await FilePicker.platform
          .pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
      final picked = result?.files.firstOrNull;
      if (picked?.path == null) return;
      setState(() => _attachedFile =
          _PickedFile(path: picked!.path!, name: picked.name, isPdf: true));
    } else {
      final file = await _picker.pickImage(
        source: source == _PickSource.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        imageQuality: 85,
      );
      if (file == null) return;
      setState(() => _attachedFile =
          _PickedFile(path: file.path, name: file.name, isPdf: false));
    }
  }

  Future<void> _submit() async {
    final label = _labelCtrl.text.trim();
    final value = _valueCtrl.text.trim();
    if (label.isEmpty) {
      showAppToast(context, '항목 종류를 입력해 주세요', type: ToastType.error);
      return;
    }
    if (value.isEmpty) {
      showAppToast(context, '등재할 내용을 입력해 주세요', type: ToastType.error);
      return;
    }
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;

    setState(() => _submitting = true);
    try {
      String? fileUrl;
      if (_attachedFile != null) {
        final ext = _attachedFile!.isPdf ? 'pdf' : 'jpg';
        final ts = DateTime.now().millisecondsSinceEpoch;
        final path = '${user.id}/info_${ts}.$ext';
        await SupabaseService.client.storage
            .from(SupabaseService.mentorDocumentsBucket)
            .upload(path, File(_attachedFile!.path));
        fileUrl = path;
      }

      await SupabaseService.client.from('info_verify_requests').insert({
        'mentor_id': user.id,
        'field_key': label,
        'field_value': value,
        'note': _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        if (fileUrl != null) 'file_url': fileUrl,
        'status': 'pending',
      });

      if (!mounted) return;
      showAppToast(context, '등재 요청이 제출되었어요. 검토 후 알려드릴게요.',
          type: ToastType.success);
      _labelCtrl.clear();
      _valueCtrl.clear();
      _noteCtrl.clear();
      setState(() => _attachedFile = null);
      ref.invalidate(_myInfoVerifyRequestsProvider);
      _tabCtrl.animateTo(1);
    } catch (e) {
      if (!mounted) return;
      showAppToast(context, '요청 중 오류가 발생했어요', type: ToastType.error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: AppColors.textPrimary, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text('내멘토 확인 정보 등재 요청', style: AppTypography.title3),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppColors.accent,
          labelColor: AppColors.accent,
          unselectedLabelColor: AppColors.textSub,
          labelStyle:
              AppTypography.subhead.copyWith(fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: '새 요청'),
            Tab(text: '요청 내역'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _NewRequestTab(
            labelCtrl: _labelCtrl,
            valueCtrl: _valueCtrl,
            noteCtrl: _noteCtrl,
            attachedFile: _attachedFile,
            onPickFile: _pickFile,
            onClearFile: () => setState(() => _attachedFile = null),
            submitting: _submitting,
            onSubmit: _submit,
          ),
          _HistoryTab(),
        ],
      ),
    );
  }
}

class _NewRequestTab extends StatelessWidget {
  const _NewRequestTab({
    required this.labelCtrl,
    required this.valueCtrl,
    required this.noteCtrl,
    required this.attachedFile,
    required this.onPickFile,
    required this.onClearFile,
    required this.submitting,
    required this.onSubmit,
  });

  final TextEditingController labelCtrl;
  final TextEditingController valueCtrl;
  final TextEditingController noteCtrl;
  final _PickedFile? attachedFile;
  final VoidCallback onPickFile;
  final VoidCallback onClearFile;
  final bool submitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 안내
            Container(
              padding: const EdgeInsets.all(AppSpacing.base),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                border:
                    Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.verified_user,
                      color: AppColors.accent, size: 18),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      '관리자가 증빙 서류를 검토한 후 승인하면 프로필의 "내멘토가 확인한 정보"에 표시됩니다.',
                      style: AppTypography.footnote
                          .copyWith(color: AppColors.accent, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.x2l),

            // 항목 종류
            Text('항목 종류 *',
                style: AppTypography.subhead
                    .copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '예) 수상경력, 학원강사 경력, 검정고시 합격, SAT 점수, 올림피아드 입상 등',
              style: AppTypography.footnote.copyWith(color: AppColors.textSub),
            ),
            const SizedBox(height: AppSpacing.sm),
            _InputField(
              controller: labelCtrl,
              hint: '항목 종류를 직접 입력해 주세요',
            ),
            const SizedBox(height: AppSpacing.xl),

            // 내용
            Text('내용 *',
                style: AppTypography.subhead
                    .copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '구체적인 내용을 입력해 주세요. (기관명, 연도, 수상 등급 등)',
              style: AppTypography.footnote.copyWith(color: AppColors.textSub),
            ),
            const SizedBox(height: AppSpacing.sm),
            _InputField(
              controller: valueCtrl,
              hint: '예) 2023년 한국수학올림피아드(KMO) 은상',
              maxLines: 3,
            ),
            const SizedBox(height: AppSpacing.xl),

            // 증빙 서류
            Text('증빙 서류 첨부 (선택)',
                style: AppTypography.subhead
                    .copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '상장, 수료증, 재직증명서, 성적증명서 등 (사진·PDF)',
              style: AppTypography.footnote
                  .copyWith(color: AppColors.textSub),
            ),
            const SizedBox(height: AppSpacing.sm),
            GestureDetector(
              onTap: attachedFile == null ? onPickFile : null,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.base, vertical: AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius:
                      BorderRadius.circular(AppSpacing.inputRadius),
                  border: Border.all(
                    color: attachedFile != null
                        ? AppColors.success.withValues(alpha: 0.5)
                        : AppColors.border,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      attachedFile != null
                          ? (attachedFile!.isPdf
                              ? Icons.picture_as_pdf
                              : Icons.check_circle_outline)
                          : Icons.attach_file,
                      color: attachedFile != null
                          ? (attachedFile!.isPdf
                              ? AppColors.warning
                              : AppColors.success)
                          : AppColors.textDisabled,
                      size: 20,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        attachedFile?.name ?? '파일을 첨부하려면 탭하세요',
                        style: AppTypography.callout.copyWith(
                          color: attachedFile != null
                              ? AppColors.textPrimary
                              : AppColors.textDisabled,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (attachedFile != null)
                      GestureDetector(
                        onTap: onClearFile,
                        child: const Icon(Icons.close,
                            color: AppColors.textDisabled, size: 18),
                      )
                    else
                      GestureDetector(
                        onTap: onPickFile,
                        child: Text('선택',
                            style: AppTypography.callout
                                .copyWith(color: AppColors.accent)),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // 추가 설명
            Text('추가 설명 (선택)',
                style: AppTypography.subhead
                    .copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: AppSpacing.sm),
            _InputField(
              controller: noteCtrl,
              hint: '관리자에게 전달할 추가 내용을 적어주세요.',
              maxLines: 4,
            ),
            const SizedBox(height: AppSpacing.x3l),

            AppButton(
              label: '등재 요청 제출',
              onPressed: submitting ? null : onSubmit,
              isLoading: submitting,
            ),
            const SizedBox(height: AppSpacing.x2l),
          ],
        ),
      ),
    );
  }
}

class _HistoryTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(_myInfoVerifyRequestsProvider);

    return requestsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('불러올 수 없어요',
            style: AppTypography.callout.copyWith(color: AppColors.textSub)),
      ),
      data: (items) {
        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.inbox_outlined,
                    size: 64, color: AppColors.textDisabled),
                const SizedBox(height: AppSpacing.base),
                Text('아직 제출한 요청이 없어요',
                    style: AppTypography.callout
                        .copyWith(color: AppColors.textSub)),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.base),
          itemCount: items.length,
          separatorBuilder: (_, __) =>
              const SizedBox(height: AppSpacing.sm),
          itemBuilder: (_, i) => _RequestCard(item: items[i]),
        );
      },
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.item});
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final fieldKey = item['field_key'] as String? ?? '';
    final fieldValue = item['field_value'] as String? ?? '';
    final status = item['status'] as String? ?? 'pending';
    final note = item['note'] as String?;
    final createdAt = item['created_at'] != null
        ? DateTime.tryParse(item['created_at'] as String) ?? DateTime.now()
        : DateTime.now();
    final adminNote = item['admin_note'] as String?;

    final (statusLabel, statusColor) = switch (status) {
      'approved' => ('승인됨', AppColors.success),
      'rejected' => ('거절됨', AppColors.error),
      _ => ('검토 중', AppColors.warning),
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(fieldKey, style: AppTypography.calloutBold),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius:
                      BorderRadius.circular(AppSpacing.chipRadius),
                  border: Border.all(
                      color: statusColor.withValues(alpha: 0.4)),
                ),
                child: Text(statusLabel,
                    style: AppTypography.caption.copyWith(
                        color: statusColor, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(fieldValue, style: AppTypography.callout),
          if (note != null && note.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text('메모: $note',
                style: AppTypography.footnote
                    .copyWith(color: AppColors.textSub)),
          ],
          if (adminNote != null && adminNote.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.06),
                borderRadius:
                    BorderRadius.circular(AppSpacing.inputRadius),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.admin_panel_settings_outlined,
                      size: 14, color: statusColor),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text('관리자: $adminNote',
                        style: AppTypography.footnote
                            .copyWith(color: statusColor)),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(
            timeago.format(createdAt, locale: 'ko'),
            style: AppTypography.caption
                .copyWith(color: AppColors.textDisabled),
          ),
        ],
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
  });
  final TextEditingController controller;
  final String hint;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: AppTypography.callout,
      decoration: InputDecoration(
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
