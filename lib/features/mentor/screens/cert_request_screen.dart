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
import '../../../shared/models/user_model.dart';
import '../../../shared/widgets/cert_badge.dart';
import '../../auth/providers/auth_provider.dart';

enum _PickSource { gallery, camera, pdf }

class _PickedFile {
  const _PickedFile({required this.path, required this.name, required this.isPdf});
  final String path;
  final String name;
  final bool isPdf;
}

// ── 과목 데이터 ──────────────────────────────────────────────
const _subjectCategories = [
  _SubjectCategory(
    label: '수학',
    subjects: ['고등수학(미적분)', '고등수학(확률과통계)', '고등수학(기하)'],
  ),
  _SubjectCategory(
    label: '국어·영어',
    subjects: ['고등국어', '고등영어'],
  ),
  _SubjectCategory(
    label: '과학',
    subjects: [
      '물리학I', '물리학II',
      '화학I', '화학II',
      '생명과학I', '생명과학II',
      '지구과학I', '지구과학II',
    ],
  ),
  _SubjectCategory(
    label: '사회',
    subjects: [
      '생활과윤리', '윤리와사상',
      '동아시아사', '세계사',
      '한국지리', '세계지리',
      '정치와법', '경제', '사회문화',
    ],
  ),
];

class _SubjectCategory {
  const _SubjectCategory({required this.label, required this.subjects});
  final String label;
  final List<String> subjects;
}

// ── 내 인증 요청 내역 ─────────────────────────────────────────
final _myCertRequestsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user == null) return [];
  final rows = await SupabaseService.client
      .from(SupabaseService.certRequestsTable)
      .select()
      .eq('mentor_id', user.id)
      .order('created_at', ascending: false);
  return (rows as List).cast<Map<String, dynamic>>();
});

class CertRequestScreen extends ConsumerStatefulWidget {
  const CertRequestScreen({super.key});

  @override
  ConsumerState<CertRequestScreen> createState() => _CertRequestScreenState();
}

class _CertRequestScreenState extends ConsumerState<CertRequestScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  final _messageCtrl = TextEditingController();
  final _picker = ImagePicker();
  int _categoryIndex = 0;
  String? _selectedSubject;
  String _level = 'pro';
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
    _messageCtrl.dispose();
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
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppSpacing.base),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.accent),
              title: const Text('갤러리에서 선택', style: AppTypography.callout),
              onTap: () => Navigator.pop(ctx, _PickSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: AppColors.accent),
              title: const Text('카메라로 촬영', style: AppTypography.callout),
              onTap: () => Navigator.pop(ctx, _PickSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined, color: AppColors.accent),
              title: const Text('PDF 파일 선택', style: AppTypography.callout),
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
    if (_selectedSubject == null) {
      showAppToast(context, '과목을 선택해 주세요', type: ToastType.error);
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
        final path = '${user.id}/cert_$ts.$ext';
        await SupabaseService.client.storage
            .from(SupabaseService.mentorDocumentsBucket)
            .upload(path, File(_attachedFile!.path));
        fileUrl = path;
      }

      await SupabaseService.client
          .from(SupabaseService.certRequestsTable)
          .insert({
        'mentor_id': user.id,
        'subject': _selectedSubject,
        'level': _level,
        'message': _messageCtrl.text.trim().isEmpty
            ? null
            : _messageCtrl.text.trim(),
        if (fileUrl != null) 'file_url': fileUrl,
      });
      if (!mounted) return;
      showAppToast(context, '인증 요청이 제출되었어요. 검토 후 알려드릴게요.',
          type: ToastType.success);
      setState(() {
        _selectedSubject = null;
        _attachedFile = null;
        _level = 'pro';
      });
      _messageCtrl.clear();
      ref.invalidate(_myCertRequestsProvider);
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
    final category = _subjectCategories[_categoryIndex];

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
        title: const Text('내멘토 인증 요청', style: AppTypography.title3),
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
          // ── 새 요청 탭 ─────────────────────────────────────
          GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 안내 카드
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.base),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.08),
                      borderRadius:
                          BorderRadius.circular(AppSpacing.cardRadius),
                      border: Border.all(
                          color: AppColors.accent.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline,
                            color: AppColors.accent, size: 18),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            '관리자가 검토 후 승인하면 해당 과목의 PRO 또는 MASTER 인증 배지가 프로필에 표시됩니다.',
                            style: AppTypography.footnote.copyWith(
                                color: AppColors.accent, height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x2l),

                  // 과목 선택
                  Text('과목 선택 *',
                      style: AppTypography.subhead
                          .copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: AppSpacing.sm),

                  // 카테고리 탭
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children:
                          List.generate(_subjectCategories.length, (i) {
                        final selected = _categoryIndex == i;
                        return Padding(
                          padding: EdgeInsets.only(
                              right: i < _subjectCategories.length - 1
                                  ? AppSpacing.xs
                                  : 0),
                          child: GestureDetector(
                            onTap: () => setState(() {
                              _categoryIndex = i;
                              _selectedSubject = null;
                            }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.base,
                                  vertical: AppSpacing.xs),
                              decoration: BoxDecoration(
                                color: selected
                                    ? AppColors.accent
                                    : AppColors.card,
                                borderRadius: BorderRadius.circular(
                                    AppSpacing.chipRadius),
                                border: Border.all(
                                  color: selected
                                      ? AppColors.accent
                                      : AppColors.border,
                                ),
                              ),
                              child: Text(
                                _subjectCategories[i].label,
                                style: AppTypography.calloutBold.copyWith(
                                  color: selected
                                      ? Colors.white
                                      : AppColors.textSub,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.base),

                  // 과목 칩 그리드
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.base),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius:
                          BorderRadius.circular(AppSpacing.cardRadius),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: category.subjects.map((subject) {
                        final selected = _selectedSubject == subject;
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _selectedSubject = subject),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.base,
                                vertical: AppSpacing.xs),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.accent.withValues(alpha: 0.12)
                                  : AppColors.surface,
                              borderRadius: BorderRadius.circular(
                                  AppSpacing.chipRadius),
                              border: Border.all(
                                color: selected
                                    ? AppColors.accent
                                    : AppColors.border,
                                width: selected ? 1.5 : 1,
                              ),
                            ),
                            child: Text(
                              subject,
                              style: AppTypography.callout.copyWith(
                                color: selected
                                    ? AppColors.accent
                                    : AppColors.textPrimary,
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  if (_selectedSubject != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        const Icon(Icons.check_circle_outline,
                            color: AppColors.success, size: 16),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          '선택: $_selectedSubject',
                          style: AppTypography.callout.copyWith(
                              color: AppColors.success,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),

                  // 레벨
                  Text('인증 레벨 *',
                      style: AppTypography.subhead
                          .copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      _LevelChip(
                        label: 'PRO',
                        selected: _level == 'pro',
                        onTap: () => setState(() => _level = 'pro'),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _LevelChip(
                        label: 'MASTER',
                        selected: _level == 'master',
                        onTap: () => setState(() => _level = 'master'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _level == 'pro'
                        ? 'PRO: 해당 과목을 가르친 경험이 있는 멘토'
                        : 'MASTER: 해당 과목 최상위 전문가 멘토',
                    style: AppTypography.footnote
                        .copyWith(color: AppColors.textSub),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // 파일 첨부
                  Text('증빙 자료 첨부 (선택)',
                      style: AppTypography.subhead
                          .copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: AppSpacing.sm),
                  GestureDetector(
                    onTap: _attachedFile == null ? _pickFile : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.base,
                          vertical: AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.inputRadius),
                        border: Border.all(
                          color: _attachedFile != null
                              ? AppColors.success.withValues(alpha: 0.5)
                              : AppColors.border,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _attachedFile != null
                                ? (_attachedFile!.isPdf
                                    ? Icons.picture_as_pdf
                                    : Icons.check_circle_outline)
                                : Icons.attach_file,
                            color: _attachedFile != null
                                ? (_attachedFile!.isPdf
                                    ? AppColors.warning
                                    : AppColors.success)
                                : AppColors.textDisabled,
                            size: 20,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              _attachedFile?.name ?? '성적표, 수상 경력 등 (사진·PDF)',
                              style: AppTypography.callout.copyWith(
                                color: _attachedFile != null
                                    ? AppColors.textPrimary
                                    : AppColors.textDisabled,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (_attachedFile != null)
                            GestureDetector(
                              onTap: () =>
                                  setState(() => _attachedFile = null),
                              child: const Icon(Icons.close,
                                  color: AppColors.textDisabled, size: 18),
                            )
                          else
                            GestureDetector(
                              onTap: _pickFile,
                              child: Text('선택',
                                  style: AppTypography.callout
                                      .copyWith(color: AppColors.accent)),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // 요청 메시지
                  Text('요청 메시지 (선택)',
                      style: AppTypography.subhead
                          .copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _messageCtrl,
                    style: AppTypography.callout,
                    maxLines: 4,
                    decoration: _inputDeco(
                        '인증을 요청하는 이유, 관련 경력 등을 자유롭게 적어주세요.'),
                  ),
                  const SizedBox(height: AppSpacing.x3l),

                  AppButton(
                    label: '인증 요청 제출',
                    onPressed: _submitting ? null : _submit,
                    isLoading: _submitting,
                  ),
                  const SizedBox(height: AppSpacing.x2l),
                ],
              ),
            ),
          ),

          // ── 요청 내역 탭 ────────────────────────────────────
          _HistoryTab(),
        ],
      ),
    );
  }

  InputDecoration _inputDeco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle:
            AppTypography.callout.copyWith(color: AppColors.textDisabled),
        filled: true,
        fillColor: AppColors.card,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.base, vertical: AppSpacing.sm),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
            borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
            borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
            borderSide:
                const BorderSide(color: AppColors.accent, width: 1.5)),
      );
}

// ── 요청 내역 탭 ──────────────────────────────────────────────
class _HistoryTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(_myCertRequestsProvider);
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
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (_, i) => _CertHistoryCard(item: items[i]),
        );
      },
    );
  }
}

class _CertHistoryCard extends StatelessWidget {
  const _CertHistoryCard({required this.item});
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final subject = item['subject'] as String? ?? '';
    final level = item['level'] as String? ?? 'pro';
    final status = item['status'] as String? ?? 'pending';
    final message = item['message'] as String?;
    final adminNote = item['admin_note'] as String?;
    final createdAt = item['created_at'] != null
        ? DateTime.tryParse(item['created_at'] as String) ?? DateTime.now()
        : DateTime.now();

    final (statusLabel, statusColor) = switch (status) {
      'approved' => ('승인됨', AppColors.success),
      'rejected' => ('반려됨', AppColors.error),
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
              CertBadge(
                subject: subject,
                level: level == 'master' ? CertLevel.master : CertLevel.pro,
                compact: true,
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius:
                      BorderRadius.circular(AppSpacing.chipRadius),
                  border:
                      Border.all(color: statusColor.withValues(alpha: 0.4)),
                ),
                child: Text(statusLabel,
                    style: AppTypography.caption.copyWith(
                        color: statusColor, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          if (message != null && message.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(message,
                style: AppTypography.callout
                    .copyWith(color: AppColors.textSub),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
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

class _LevelChip extends StatelessWidget {
  const _LevelChip(
      {required this.label,
      required this.selected,
      required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : AppColors.card,
          borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.calloutBold.copyWith(
            color: selected ? Colors.white : AppColors.textSub,
          ),
        ),
      ),
    );
  }
}
