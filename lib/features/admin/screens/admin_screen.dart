import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/app_spacing.dart';
import '../../../core/app_strings.dart';
import '../../../core/app_typography.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/services/supabase_service.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/cert_badge.dart';

// ── 인증 필드 라벨 맵 ──────────────────────────────────────────
const _fieldLabels = {
  'middle_school': '중학교',
  'high_school': '고등학교',
  'university': '대학교',
  'department': '학과',
};

// ── 서류 심사 데이터 ─────────────────────────────────────────
final _pendingDocumentsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final rows = await SupabaseService.client
      .from(SupabaseService.mentorDocumentsTable)
      .select('*, users!inner(nickname, email)')
      .eq('status', 'pending')
      .order('created_at');
  return rows.cast<Map<String, dynamic>>();
});

// ── 멘토 전체 목록 ───────────────────────────────────────────
final _allMentorsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final rows = await SupabaseService.client
      .from(SupabaseService.mentorProfilesTable)
      .select('*, users!inner(nickname, email)')
      .order('created_at', ascending: false);
  return rows.cast<Map<String, dynamic>>();
});

// ── 분쟁 목록 ──────────────────────────────────────────────
final _pendingDisputesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final rows = await SupabaseService.client
      .from(SupabaseService.disputesTable)
      .select()
      .inFilter('status', ['pending', 'reviewing'])
      .order('created_at');
  return rows.cast<Map<String, dynamic>>();
});

// ── 인증 요청 목록 ──────────────────────────────────────────
final _pendingCertRequestsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final rows = await SupabaseService.client
      .from(SupabaseService.certRequestsTable)
      .select('*, users!inner(nickname)')
      .eq('status', 'pending')
      .order('created_at');
  return rows.cast<Map<String, dynamic>>();
});

// ── 게시판 게시물 전체 ──────────────────────────────────────
final _allBoardPostsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final rows = await SupabaseService.client
      .from(SupabaseService.boardPostsTable)
      .select()
      .order('created_at', ascending: false);
  return rows.cast<Map<String, dynamic>>();
});

// ── 특정 게시물 댓글 ──────────────────────────────────────
final _adminPostCommentsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
        (ref, postId) async {
  final rows = await SupabaseService.client
      .from(SupabaseService.boardCommentsTable)
      .select()
      .eq('post_id', postId)
      .order('created_at');
  return rows.cast<Map<String, dynamic>>();
});

// ── 등재 요청 목록 ───────────────────────────────────────────
final _pendingInfoVerifyRequestsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final rows = await SupabaseService.client
      .from('info_verify_requests')
      .select('*, users!inner(nickname, email)')
      .order('created_at');
  return rows.cast<Map<String, dynamic>>();
});

// ── 인증된 멘토 목록 (cert grant용) ────────────────────────
final _verifiedMentorsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final rows = await SupabaseService.client
      .from(SupabaseService.mentorProfilesTable)
      .select('*, users!inner(nickname, mentor_certifications(*))')
      .eq('verified', true)
      .order('created_at', ascending: false)
      .limit(30);
  return rows.cast<Map<String, dynamic>>();
});

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 7, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        elevation: 0,
        title: Text(AppStrings.adminTitle, style: AppTypography.title3),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () async {
              await ref.read(authNotifierProvider.notifier).signOut();
            },
            child: Text('로그아웃',
                style: AppTypography.callout
                    .copyWith(color: AppColors.textSub)),
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          labelStyle: AppTypography.captionBold,
          unselectedLabelStyle: AppTypography.caption,
          labelColor: AppColors.accent,
          unselectedLabelColor: AppColors.textSub,
          indicatorColor: AppColors.accent,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: '서류 심사'),
            Tab(text: '멘토 관리'),
            Tab(text: '분쟁 처리'),
            Tab(text: '인증 관리'),
            Tab(text: '캐시 관리'),
            Tab(text: '게시판 관리'),
            Tab(text: '등재 요청'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        physics: const NeverScrollableScrollPhysics(),
        children: const [
          _DocumentReviewTab(),
          _MentorManageTab(),
          _DisputeManageTab(),
          _CertManageTab(),
          _CashManageTab(),
          _BoardModerateTab(),
          _InfoVerifyManageTab(),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// 탭 1: 서류 심사
// ══════════════════════════════════════════════════════════════
class _DocumentReviewTab extends ConsumerWidget {
  const _DocumentReviewTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docsAsync = ref.watch(_pendingDocumentsProvider);

    return docsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(
          child: Text(AppStrings.serverError,
              style:
                  AppTypography.callout.copyWith(color: AppColors.textSub))),
      data: (docs) {
        if (docs.isEmpty) {
          return Center(
            child: Text('검토 대기 중인 서류가 없어요',
                style: AppTypography.callout
                    .copyWith(color: AppColors.textSub)),
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.refresh(_pendingDocumentsProvider.future),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            itemCount: docs.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: AppColors.border),
            itemBuilder: (_, i) => _DocumentTile(doc: docs[i], ref: ref),
          ),
        );
      },
    );
  }
}

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({required this.doc, required this.ref});
  final Map<String, dynamic> doc;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final nickname = doc['users']?['nickname'] as String? ?? '';
    final email = doc['users']?['email'] as String? ?? '';
    final docType = doc['document_type'] as String? ?? '';
    final isIdPhoto = docType == 'id_photo';

    return Container(
      color: AppColors.card,
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_outline,
                  color: AppColors.textSub, size: 20),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nickname, style: AppTypography.calloutBold),
                    Text(email,
                        style: AppTypography.caption
                            .copyWith(color: AppColors.textSub)),
                  ],
                ),
              ),
              if (isIdPhoto)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius:
                        BorderRadius.circular(AppSpacing.chipRadius),
                    border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.4)),
                  ),
                  child: Text('신분증',
                      style: AppTypography.caption.copyWith(
                          color: AppColors.warning,
                          fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
              '서류 유형: ${isIdPhoto ? '신분증 사진' : '학력 서류'}',
              style: AppTypography.callout
                  .copyWith(color: AppColors.textSub)),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: () => _openFile(context),
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('서류 보기'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accent,
              side: const BorderSide(color: AppColors.accent),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  label: AppStrings.approve,
                  color: AppColors.success,
                  onTap: () => _updateStatus(
                      context,
                      doc['id'] as String,
                      'approved',
                      doc['mentor_id'] as String?,
                      doc['file_url'] as String?,
                      docType),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _ActionButton(
                  label: AppStrings.reject,
                  color: AppColors.error,
                  onTap: () => _updateStatus(
                      context,
                      doc['id'] as String,
                      'rejected',
                      doc['mentor_id'] as String?,
                      doc['file_url'] as String?,
                      docType),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openFile(BuildContext context) async {
    final fileUrl = doc['file_url'] as String?;
    if (fileUrl == null) return;
    try {
      final signedUrl = await SupabaseService.client.storage
          .from(SupabaseService.mentorDocumentsBucket)
          .createSignedUrl(fileUrl, 3600);
      final uri = Uri.parse(signedUrl);
      if (await canLaunchUrl(uri)) await launchUrl(uri);
    } catch (e) {
      if (context.mounted) {
        showAppToast(context, '파일을 열 수 없어요', type: ToastType.error);
      }
    }
  }

  Future<void> _updateStatus(
      BuildContext context,
      String docId,
      String status,
      String? mentorId,
      String? fileUrl,
      String docType) async {
    try {
      // 반려 시 Storage 파일 즉시 삭제
      if (status == 'rejected' && fileUrl != null) {
        await SupabaseService.client.storage
            .from(SupabaseService.mentorDocumentsBucket)
            .remove([fileUrl]);
      }

      await SupabaseService.client
          .from(SupabaseService.mentorDocumentsTable)
          .update({'status': status}).eq('id', docId);

      // 신분증 승인 → 멘토 활동 자동 활성화
      if (status == 'approved' &&
          docType == 'id_photo' &&
          mentorId != null) {
        await SupabaseService.client
            .from(SupabaseService.mentorProfilesTable)
            .update({'verified': true}).eq('user_id', mentorId);
      }

      // 신분증 반려 → 멘토에게 알림 발송 (실패해도 핵심 처리 완료)
      if (status == 'rejected' &&
          docType == 'id_photo' &&
          mentorId != null) {
        try {
          await SupabaseService.client
              .from(SupabaseService.notificationsTable)
              .insert({
            'user_id': mentorId,
            'type': 'id_rejected',
            'title': '서류 반려',
            'body': '신분증 서류가 반려되었습니다. 서류를 다시 제출해 주세요.',
          });
        } catch (_) {}
      }

      ref.invalidate(_pendingDocumentsProvider);
      if (context.mounted) {
        showAppToast(
            context,
            status == 'approved'
                ? (docType == 'id_photo' ? '승인 완료 — 멘토 계정이 활성화되었어요' : '승인되었어요')
                : '반려 및 서류가 삭제되었어요',
            type: status == 'approved'
                ? ToastType.success
                : ToastType.error);
      }
    } catch (e) {
      if (context.mounted) {
        showAppToast(context, AppStrings.serverError, type: ToastType.error);
      }
    }
  }
}

// ══════════════════════════════════════════════════════════════
// 탭 2: 멘토 관리 (프로필 편집 + 인증 필드 지정)
// ══════════════════════════════════════════════════════════════
class _MentorManageTab extends ConsumerWidget {
  const _MentorManageTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mentorsAsync = ref.watch(_allMentorsProvider);

    return mentorsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(
          child: Text(AppStrings.serverError,
              style:
                  AppTypography.callout.copyWith(color: AppColors.textSub))),
      data: (mentors) {
        if (mentors.isEmpty) {
          return Center(
            child: Text('멘토가 없어요',
                style: AppTypography.callout
                    .copyWith(color: AppColors.textSub)),
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.refresh(_allMentorsProvider.future),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            itemCount: mentors.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: AppColors.border),
            itemBuilder: (_, i) =>
                _MentorManageTile(mentor: mentors[i], ref: ref),
          ),
        );
      },
    );
  }
}

class _MentorManageTile extends StatelessWidget {
  const _MentorManageTile({required this.mentor, required this.ref});
  final Map<String, dynamic> mentor;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final nickname = mentor['users']?['nickname'] as String? ?? '';
    final university = mentor['university'] as String?;
    final department = mentor['department'] as String?;
    final verified = mentor['verified'] as bool? ?? false;

    return ListTile(
      tileColor: AppColors.card,
      leading: CircleAvatar(
        backgroundColor:
            verified ? AppColors.accent.withValues(alpha: 0.1) : AppColors.surface,
        child: Icon(Icons.person,
            color: verified ? AppColors.accent : AppColors.textSub,
            size: 20),
      ),
      title: Row(
        children: [
          Text(nickname, style: AppTypography.calloutBold),
          if (verified) ...[
            const SizedBox(width: AppSpacing.xs),
            const Icon(Icons.verified, color: AppColors.accent, size: 14),
          ],
        ],
      ),
      subtitle: university != null
          ? Text(
              [university, department]
                  .where((s) => s?.isNotEmpty == true)
                  .join(' · '),
              style:
                  AppTypography.footnote.copyWith(color: AppColors.textSub))
          : null,
      trailing: TextButton(
        onPressed: () => _showEditSheet(context),
        child: Text('수정',
            style: AppTypography.callout.copyWith(color: AppColors.accent)),
      ),
    );
  }

  void _showEditSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _MentorEditSheet(mentor: mentor, ref: ref),
    );
  }
}

class _MentorEditSheet extends StatefulWidget {
  const _MentorEditSheet({required this.mentor, required this.ref});
  final Map<String, dynamic> mentor;
  final WidgetRef ref;

  @override
  State<_MentorEditSheet> createState() => _MentorEditSheetState();
}

class _MentorEditSheetState extends State<_MentorEditSheet> {
  late final TextEditingController _realNameCtrl;
  late final TextEditingController _middleSchoolCtrl;
  late final TextEditingController _highSchoolCtrl;
  late final TextEditingController _universityCtrl;
  late final TextEditingController _departmentCtrl;
  late final TextEditingController _introCtrl;
  late final TextEditingController _bioCtrl;
  late final TextEditingController _rateMinCtrl;
  late final TextEditingController _rateMaxCtrl;
  late Set<String> _verifiedFields;
  late bool _verified;
  List<Map<String, dynamic>> _certs = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadCerts();
    final m = widget.mentor;
    _realNameCtrl =
        TextEditingController(text: m['real_name'] as String? ?? '');
    _middleSchoolCtrl =
        TextEditingController(text: m['middle_school'] as String? ?? '');
    _highSchoolCtrl =
        TextEditingController(text: m['high_school'] as String? ?? '');
    _universityCtrl =
        TextEditingController(text: m['university'] as String? ?? '');
    _departmentCtrl =
        TextEditingController(text: m['department'] as String? ?? '');
    _introCtrl = TextEditingController(text: m['intro'] as String? ?? '');
    _bioCtrl = TextEditingController(text: m['bio'] as String? ?? '');
    _rateMinCtrl = TextEditingController(
        text: m['hourly_rate_min']?.toString() ?? '');
    _rateMaxCtrl = TextEditingController(
        text: m['hourly_rate_max']?.toString() ?? '');
    _verifiedFields = ((m['verified_fields'] as List<dynamic>?) ?? [])
        .map((e) => e as String)
        .toSet();
    _verified = m['verified'] as bool? ?? false;
  }

  @override
  void dispose() {
    for (final c in [
      _realNameCtrl, _middleSchoolCtrl, _highSchoolCtrl,
      _universityCtrl, _departmentCtrl, _introCtrl, _bioCtrl,
      _rateMinCtrl, _rateMaxCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _v(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await SupabaseService.client
          .from(SupabaseService.mentorProfilesTable)
          .update({
        'real_name': _v(_realNameCtrl),
        'middle_school': _v(_middleSchoolCtrl),
        'high_school': _v(_highSchoolCtrl),
        'university': _v(_universityCtrl),
        'department': _v(_departmentCtrl),
        'intro': _v(_introCtrl),
        'bio': _v(_bioCtrl),
        'hourly_rate_min': int.tryParse(_rateMinCtrl.text.trim()),
        'hourly_rate_max': int.tryParse(_rateMaxCtrl.text.trim()),
        'verified_fields': _verifiedFields.toList(),
        'verified': _verified,
      }).eq('user_id', widget.mentor['user_id'] as String);

      widget.ref.invalidate(_allMentorsProvider);
      if (mounted) {
        Navigator.pop(context);
        showAppToast(context, '저장되었어요', type: ToastType.success);
      }
    } catch (e) {
      if (mounted) {
        showAppToast(context, AppStrings.serverError, type: ToastType.error);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _loadCerts() async {
    try {
      final rows = await SupabaseService.client
          .from(SupabaseService.mentorCertificationsTable)
          .select()
          .eq('mentor_id', widget.mentor['user_id'] as String)
          .order('subject');
      if (mounted) setState(() => _certs = rows.cast<Map<String, dynamic>>());
    } catch (_) {}
  }

  Future<void> _revokeCert(String certId) async {
    try {
      await SupabaseService.client
          .from(SupabaseService.mentorCertificationsTable)
          .delete()
          .eq('id', certId);
      widget.ref.invalidate(_verifiedMentorsProvider);
      await _loadCerts();
      if (mounted) showAppToast(context, '인증이 회수되었어요', type: ToastType.success);
    } catch (_) {
      if (mounted) showAppToast(context, AppStrings.serverError, type: ToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Padding(
      padding: EdgeInsets.fromLTRB(
          AppSpacing.base, AppSpacing.base, AppSpacing.base, bottom + AppSpacing.x2l),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 48),
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textSub),
                  onPressed: () {
                    FocusScope.of(context).unfocus();
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
            Text('멘토 정보 수정', style: AppTypography.title3),
            const SizedBox(height: AppSpacing.sm),

            // 멘토 활성화 토글
            Container(
              decoration: BoxDecoration(
                color: _verified
                    ? AppColors.success.withValues(alpha: 0.08)
                    : AppColors.error.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                border: Border.all(
                  color: _verified
                      ? AppColors.success.withValues(alpha: 0.3)
                      : AppColors.error.withValues(alpha: 0.3),
                ),
              ),
              child: SwitchListTile(
                dense: true,
                title: Text(
                  _verified ? '활성화됨 (학생에게 노출)' : '비활성화 (학생에게 미노출)',
                  style: AppTypography.callout.copyWith(
                    color: _verified ? AppColors.success : AppColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                value: _verified,
                activeColor: AppColors.success,
                onChanged: (v) => setState(() => _verified = v),
              ),
            ),
            const SizedBox(height: AppSpacing.base),

            _Field('실명', _realNameCtrl),
            _Field('중학교', _middleSchoolCtrl),
            _Field('고등학교', _highSchoolCtrl),
            _Field('대학교', _universityCtrl),
            _Field('학과', _departmentCtrl),
            _Field('한줄 소개', _introCtrl),
            _Field('상세 소개', _bioCtrl, maxLines: 3),
            _Field('시급 최솟값', _rateMinCtrl, numeric: true),
            _Field('시급 최댓값', _rateMaxCtrl, numeric: true),

            const SizedBox(height: AppSpacing.base),
            const Divider(color: AppColors.border),
            const SizedBox(height: AppSpacing.sm),

            // 인증 필드 체크박스
            Row(
              children: [
                const Icon(Icons.verified_user,
                    color: AppColors.accent, size: 16),
                const SizedBox(width: AppSpacing.xs),
                Text('내멘토 확인 정보 지정',
                    style: AppTypography.calloutBold
                        .copyWith(color: AppColors.accent)),
              ],
            ),
            Text('체크한 항목은 멘토 프로필에 "내멘토 확인" 표시가 됩니다.',
                style: AppTypography.footnote
                    .copyWith(color: AppColors.textSub)),
            const SizedBox(height: AppSpacing.sm),
            ..._fieldLabels.entries.map((e) {
              // 값이 있는 필드만 표시
              final ctrl = _ctrlFor(e.key);
              if (ctrl == null || ctrl.text.trim().isEmpty) {
                return const SizedBox.shrink();
              }
              final prefix = '${e.key}:';
              final isChecked =
                  _verifiedFields.any((f) => f.startsWith(prefix));
              return CheckboxListTile(
                dense: true,
                title: Text('${e.value} (${ctrl.text.trim()})',
                    style: AppTypography.callout),
                value: isChecked,
                activeColor: AppColors.accent,
                onChanged: (v) => setState(() {
                  _verifiedFields.removeWhere((f) => f.startsWith(prefix));
                  if (v == true) {
                    _verifiedFields.add('${e.key}:${ctrl.text.trim()}');
                  }
                }),
              );
            }),

            // 자유형 등재 정보 (고정 컬럼 외)
            Builder(builder: (context) {
              final knownPrefixes =
                  _fieldLabels.keys.map((k) => '$k:').toList();
              final freeEntries = _verifiedFields
                  .where((f) =>
                      !knownPrefixes.any((p) => f.startsWith(p)) &&
                      !_fieldLabels.containsKey(f))
                  .toList();
              if (freeEntries.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppSpacing.xs),
                  Text('자유형 등재 정보',
                      style: AppTypography.footnote
                          .copyWith(color: AppColors.textSub)),
                  ...freeEntries.map((entry) {
                    final colonIdx = entry.indexOf(':');
                    final label = colonIdx > 0
                        ? entry.substring(0, colonIdx)
                        : entry;
                    final value =
                        colonIdx > 0 ? entry.substring(colonIdx + 1) : '';
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text('$label: $value',
                          style: AppTypography.callout),
                      trailing: TextButton(
                        onPressed: () =>
                            setState(() => _verifiedFields.remove(entry)),
                        child: Text('회수',
                            style: AppTypography.callout
                                .copyWith(color: AppColors.error)),
                      ),
                    );
                  }),
                ],
              );
            }),

            if (_certs.isNotEmpty) ...[
              const Divider(color: AppColors.border),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  const Icon(Icons.workspace_premium, color: AppColors.accent, size: 16),
                  const SizedBox(width: AppSpacing.xs),
                  Text('인증 회수',
                      style: AppTypography.calloutBold.copyWith(color: AppColors.accent)),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              ..._certs.map((c) {
                final subject = c['subject'] as String? ?? '';
                final level = c['level'] as String? ?? 'pro';
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text('$subject · ${level.toUpperCase()}',
                      style: AppTypography.callout),
                  trailing: TextButton(
                    onPressed: () => _revokeCert(c['id'] as String),
                    child: Text('회수',
                        style: AppTypography.callout.copyWith(color: AppColors.error)),
                  ),
                );
              }),
              const SizedBox(height: AppSpacing.sm),
            ],

            const SizedBox(height: AppSpacing.base),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.inputRadius)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text('저장', style: AppTypography.calloutBold),
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  TextEditingController? _ctrlFor(String field) => switch (field) {
        'real_name' => _realNameCtrl,
        'middle_school' => _middleSchoolCtrl,
        'high_school' => _highSchoolCtrl,
        'university' => _universityCtrl,
        'department' => _departmentCtrl,
        _ => null,
      };
}

class _Field extends StatelessWidget {
  const _Field(this.label, this.ctrl,
      {this.maxLines = 1, this.numeric = false});
  final String label;
  final TextEditingController ctrl;
  final int maxLines;
  final bool numeric;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType:
            numeric ? TextInputType.number : TextInputType.text,
        style: AppTypography.callout,
        decoration: InputDecoration(
          labelText: label,
          labelStyle:
              AppTypography.footnote.copyWith(color: AppColors.textSub),
          filled: true,
          fillColor: AppColors.surface,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
          border: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(AppSpacing.inputRadius),
              borderSide: const BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(AppSpacing.inputRadius),
              borderSide: const BorderSide(color: AppColors.border)),
          focusedBorder: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(AppSpacing.inputRadius),
              borderSide: const BorderSide(
                  color: AppColors.accent, width: 1.5)),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// 탭 3: 분쟁 처리
// ══════════════════════════════════════════════════════════════
class _DisputeManageTab extends ConsumerWidget {
  const _DisputeManageTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final disputesAsync = ref.watch(_pendingDisputesProvider);

    return disputesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(
          child: Text(AppStrings.serverError,
              style:
                  AppTypography.callout.copyWith(color: AppColors.textSub))),
      data: (disputes) {
        if (disputes.isEmpty) {
          return Center(
            child: Text('처리 대기 중인 분쟁이 없어요',
                style: AppTypography.callout
                    .copyWith(color: AppColors.textSub)),
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.refresh(_pendingDisputesProvider.future),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            itemCount: disputes.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: AppColors.border),
            itemBuilder: (_, i) =>
                _DisputeTile(dispute: disputes[i], ref: ref),
          ),
        );
      },
    );
  }
}

class _DisputeTile extends ConsumerWidget {
  const _DisputeTile({required this.dispute, required this.ref});
  final Map<String, dynamic> dispute;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef widgetRef) {
    final reason = dispute['reason'] as String? ?? '';
    final status = dispute['status'] as String? ?? 'pending';
    final resultCtrl = TextEditingController();

    return Container(
      color: AppColors.card,
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: 3),
                decoration: BoxDecoration(
                  color: status == 'pending'
                      ? AppColors.warning.withValues(alpha: 0.1)
                      : AppColors.accent.withValues(alpha: 0.1),
                  borderRadius:
                      BorderRadius.circular(AppSpacing.chipRadius),
                ),
                child: Text(
                  status == 'pending'
                      ? AppStrings.disputePending
                      : AppStrings.disputeReviewing,
                  style: AppTypography.caption.copyWith(
                      color: status == 'pending'
                          ? AppColors.warning
                          : AppColors.accent,
                      fontWeight: FontWeight.w600),
                ),
              ),
              const Spacer(),
              Text(
                _formatDate(
                    DateTime.parse(dispute['created_at'] as String)),
                style: AppTypography.caption
                    .copyWith(color: AppColors.textDisabled),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(AppStrings.disputeReason, style: AppTypography.calloutBold),
          const SizedBox(height: AppSpacing.xs),
          Text(reason,
              style: AppTypography.callout
                  .copyWith(color: AppColors.textSub)),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: resultCtrl,
            maxLines: 2,
            style: AppTypography.callout,
            decoration: InputDecoration(
              hintText: '처리 결과를 입력하세요',
              hintStyle: AppTypography.callout
                  .copyWith(color: AppColors.textDisabled),
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.all(AppSpacing.sm),
              border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppSpacing.inputRadius),
                  borderSide:
                      const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppSpacing.inputRadius),
                  borderSide:
                      const BorderSide(color: AppColors.border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppSpacing.inputRadius),
                  borderSide: const BorderSide(
                      color: AppColors.accent, width: 1.5)),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: _ActionButton(
              label: '처리 완료',
              color: AppColors.accent,
              onTap: () async {
                final result = resultCtrl.text.trim();
                if (result.isEmpty) {
                  showAppToast(context, '처리 결과를 입력해 주세요',
                      type: ToastType.error);
                  return;
                }
                try {
                  await SupabaseService.client
                      .from(SupabaseService.disputesTable)
                      .update(
                          {'status': 'resolved', 'result': result}).eq(
                          'id', dispute['id'] as String);
                  ref.invalidate(_pendingDisputesProvider);
                  if (context.mounted) {
                    showAppToast(context, '분쟁이 처리되었어요',
                        type: ToastType.success);
                  }
                } catch (e) {
                  if (context.mounted) {
                    showAppToast(context, AppStrings.serverError,
                        type: ToastType.error);
                  }
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.month}.${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

// ══════════════════════════════════════════════════════════════
// 탭 4: 인증 관리 (인증 요청 처리 + 수동 cert 부여)
// ══════════════════════════════════════════════════════════════
class _CertManageTab extends ConsumerWidget {
  const _CertManageTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(_pendingCertRequestsProvider);
    final mentorsAsync = ref.watch(_verifiedMentorsProvider);

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      children: [
        // ── 인증 요청 섹션 ──────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.base, AppSpacing.sm, AppSpacing.base, AppSpacing.xs),
          child: Text('인증 요청',
              style: AppTypography.title3
                  .copyWith(color: AppColors.textPrimary)),
        ),
        requestsAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (_, __) => Padding(
            padding: const EdgeInsets.all(AppSpacing.base),
            child: Text(AppStrings.serverError,
                style: AppTypography.callout
                    .copyWith(color: AppColors.textSub)),
          ),
          data: (requests) {
            if (requests.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(AppSpacing.base),
                child: Text('대기 중인 인증 요청이 없어요',
                    style: AppTypography.callout
                        .copyWith(color: AppColors.textSub)),
              );
            }
            return Column(
              children: requests
                  .map((r) => _CertRequestTile(request: r, ref: ref))
                  .toList(),
            );
          },
        ),

        const Divider(height: AppSpacing.x2l, color: AppColors.border),

        // ── 수동 cert 부여 섹션 ──────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.base, AppSpacing.xs, AppSpacing.base, AppSpacing.xs),
          child: Text('인증 직접 부여',
              style: AppTypography.title3
                  .copyWith(color: AppColors.textPrimary)),
        ),
        mentorsAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (_, __) => Padding(
            padding: const EdgeInsets.all(AppSpacing.base),
            child: Text(AppStrings.serverError,
                style: AppTypography.callout
                    .copyWith(color: AppColors.textSub)),
          ),
          data: (mentors) {
            if (mentors.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(AppSpacing.base),
                child: Text('인증된 멘토가 없어요',
                    style: AppTypography.callout
                        .copyWith(color: AppColors.textSub)),
              );
            }
            return Column(
              children: mentors
                  .map((m) =>
                      _CertMentorTile(mentor: m, ref: ref))
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

class _CertRequestTile extends StatelessWidget {
  const _CertRequestTile({required this.request, required this.ref});
  final Map<String, dynamic> request;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final nickname = request['users']?['nickname'] as String? ?? '';
    final subject = request['subject'] as String? ?? '';
    final level = request['level'] as String? ?? 'pro';
    final message = request['message'] as String?;

    return Container(
      margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base, vertical: AppSpacing.xs),
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
              Text(nickname, style: AppTypography.calloutBold),
              const SizedBox(width: AppSpacing.sm),
              CertBadge(
                subject: subject,
                level: level == 'master' ? CertLevel.master : CertLevel.pro,
                compact: true,
              ),
            ],
          ),
          if (message?.isNotEmpty == true) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(message!,
                style: AppTypography.callout
                    .copyWith(color: AppColors.textSub),
                maxLines: 3,
                overflow: TextOverflow.ellipsis),
          ],
          if (request['file_url'] != null) ...[
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: () => _openFile(context),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('서류 보기'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accent,
                side: const BorderSide(color: AppColors.accent),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  label: AppStrings.approve,
                  color: AppColors.success,
                  onTap: () =>
                      _handleRequest(context, 'approved', subject, level),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _ActionButton(
                  label: AppStrings.reject,
                  color: AppColors.error,
                  onTap: () =>
                      _handleRequest(context, 'rejected', subject, level),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openFile(BuildContext context) async {
    final fileUrl = request['file_url'] as String?;
    if (fileUrl == null) return;
    try {
      final signedUrl = await SupabaseService.client.storage
          .from(SupabaseService.mentorDocumentsBucket)
          .createSignedUrl(fileUrl, 3600);
      final uri = Uri.parse(signedUrl);
      if (await canLaunchUrl(uri)) await launchUrl(uri);
    } catch (e) {
      if (context.mounted) {
        showAppToast(context, '파일을 열 수 없어요', type: ToastType.error);
      }
    }
  }

  Future<String?> _promptRejectNote(BuildContext context) async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('반려 사유', style: AppTypography.title3),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          style: AppTypography.callout,
          decoration: InputDecoration(
            hintText: '반려 사유를 입력해 주세요 (선택)',
            hintStyle:
                AppTypography.callout.copyWith(color: AppColors.textDisabled),
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.base, vertical: AppSpacing.sm),
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
              borderSide:
                  const BorderSide(color: AppColors.error, width: 1.5),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('취소',
                style: AppTypography.callout
                    .copyWith(color: AppColors.textSub)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text('반려',
                style: AppTypography.calloutBold
                    .copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return result;
  }

  Future<void> _handleRequest(BuildContext context, String status,
      String subject, String level) async {
    String? adminNote;
    if (status == 'rejected') {
      adminNote = await _promptRejectNote(context);
      if (adminNote == null || !context.mounted) return; // 취소
    }
    try {
      await SupabaseService.client
          .from(SupabaseService.certRequestsTable)
          .update({
        'status': status,
        if (adminNote != null && adminNote.isNotEmpty) 'admin_note': adminNote,
      }).eq('id', request['id'] as String);

      if (status == 'approved') {
        await SupabaseService.client
            .from(SupabaseService.mentorCertificationsTable)
            .upsert({
          'mentor_id': request['mentor_id'] as String,
          'subject': subject,
          'level': level,
          'granted_at': DateTime.now().toIso8601String(),
        });
      }
      // 알림 전송 (실패해도 핵심 처리는 완료된 것으로 간주)
      try {
        final noteText = adminNote != null && adminNote.isNotEmpty
            ? '\n사유: $adminNote'
            : '';
        await SupabaseService.client
            .from(SupabaseService.notificationsTable)
            .insert({
          'user_id': request['mentor_id'] as String,
          'type': status == 'approved' ? 'cert_approved' : 'cert_rejected',
          'title': status == 'approved' ? '인증 승인' : '인증 반려',
          'body': status == 'approved'
              ? '$subject ${level.toUpperCase()} 인증이 승인되었습니다.'
              : '$subject ${level.toUpperCase()} 인증 요청이 반려되었습니다.$noteText',
        });
      } catch (_) {}

      ref.invalidate(_pendingCertRequestsProvider);
      ref.invalidate(_verifiedMentorsProvider);
      if (context.mounted) {
        showAppToast(
            context,
            status == 'approved' ? '인증이 부여되었어요' : '요청이 반려되었어요',
            type: status == 'approved'
                ? ToastType.success
                : ToastType.error);
      }
    } catch (e) {
      if (context.mounted) {
        showAppToast(context, AppStrings.serverError, type: ToastType.error);
      }
    }
  }
}

class _CertMentorTile extends StatefulWidget {
  const _CertMentorTile({required this.mentor, required this.ref});
  final Map<String, dynamic> mentor;
  final WidgetRef ref;

  @override
  State<_CertMentorTile> createState() => _CertMentorTileState();
}

class _CertMentorTileState extends State<_CertMentorTile> {
  String _selectedSubject = '';
  String _selectedLevel = 'pro';

  @override
  Widget build(BuildContext context) {
    final nickname =
        widget.mentor['users']?['nickname'] as String? ?? '';
    final mentorId = widget.mentor['user_id'] as String;
    final certs =
        (widget.mentor['users']?['mentor_certifications'] as List<dynamic>?)
                ?.map((e) =>
                    MentorCertification.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [];

    return Container(
      color: AppColors.card,
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(nickname, style: AppTypography.calloutBold),
              if (certs.isNotEmpty) ...[
                const SizedBox(width: AppSpacing.xs),
                CertBadge(
                    subject: certs.first.subject,
                    level: certs.first.level,
                    compact: true),
              ],
            ],
          ),
          if (certs.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              children: certs
                  .map((c) => CertBadge(
                      subject: c.subject, level: c.level, compact: true))
                  .toList(),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedSubject.isEmpty ? null : _selectedSubject,
                      hint: Text('과목 선택',
                          style: AppTypography.callout
                              .copyWith(color: AppColors.textDisabled)),
                      isExpanded: true,
                      style: AppTypography.callout,
                      items: AppStrings.certSubjects
                          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _selectedSubject = v ?? ''),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              DropdownButton<String>(
                value: _selectedLevel,
                items: const [
                  DropdownMenuItem(value: 'pro', child: Text('PRO')),
                  DropdownMenuItem(
                      value: 'master', child: Text('MASTER')),
                ],
                onChanged: (v) =>
                    setState(() => _selectedLevel = v ?? 'pro'),
              ),
              const SizedBox(width: AppSpacing.sm),
              GestureDetector(
                onTap: () => _grantCert(context, mentorId),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs),
                  decoration: BoxDecoration(
                    gradient: AppColors.accentGradient,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('부여',
                      style: AppTypography.calloutBold
                          .copyWith(color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _grantCert(BuildContext context, String mentorId) async {
    if (_selectedSubject.trim().isEmpty) {
      showAppToast(context, '과목명을 입력해 주세요', type: ToastType.error);
      return;
    }
    try {
      await SupabaseService.client
          .from(SupabaseService.mentorCertificationsTable)
          .upsert({
        'mentor_id': mentorId,
        'subject': _selectedSubject.trim(),
        'level': _selectedLevel,
        'granted_at': DateTime.now().toIso8601String(),
      });
      widget.ref.invalidate(_verifiedMentorsProvider);
      if (context.mounted) {
        showAppToast(context, '인증이 부여되었어요', type: ToastType.success);
      }
    } catch (e) {
      if (context.mounted) {
        showAppToast(context, AppStrings.serverError, type: ToastType.error);
      }
    }
  }
}

// ══════════════════════════════════════════════════════════════
// 탭 5: 캐시 관리
// ══════════════════════════════════════════════════════════════
class _CashManageTab extends ConsumerStatefulWidget {
  const _CashManageTab();

  @override
  ConsumerState<_CashManageTab> createState() => _CashManageTabState();
}

class _CashManageTabState extends ConsumerState<_CashManageTab> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _results = [];
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
    _searchCtrl.addListener(_filterLocally);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_filterLocally);
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _searching = true);
    try {
      final rows = await SupabaseService.client
          .from(SupabaseService.usersTable)
          .select('id, nickname, email, cash_balance, role')
          .order('nickname')
          .limit(200);
      _allUsers = rows.cast<Map<String, dynamic>>();
      _filterLocally();
    } catch (_) {
      if (mounted) showAppToast(context, '목록을 불러올 수 없어요', type: ToastType.error);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _filterLocally() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _results = q.isEmpty
          ? List.of(_allUsers)
          : _allUsers.where((u) {
              final nick = (u['nickname'] as String? ?? '').toLowerCase();
              final email = (u['email'] as String? ?? '').toLowerCase();
              return nick.contains(q) || email.contains(q);
            }).toList();
    });
  }

  Future<void> _search() async {
    _filterLocally();
  }

  void _showAdjustSheet(Map<String, dynamic> user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CashAdjustSheet(
        user: user,
        onDone: () {
          _search(); // refresh list after adjustment
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 검색 바
        Container(
          color: AppColors.card,
          padding: const EdgeInsets.all(AppSpacing.base),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  style: AppTypography.callout,
                  onSubmitted: (_) => _search(),
                  decoration: InputDecoration(
                    hintText: '닉네임 또는 이메일로 검색',
                    hintStyle: AppTypography.callout
                        .copyWith(color: AppColors.textDisabled),
                    filled: true,
                    fillColor: AppColors.surface,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.base,
                        vertical: AppSpacing.sm),
                    border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.inputRadius),
                        borderSide:
                            const BorderSide(color: AppColors.border)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.inputRadius),
                        borderSide:
                            const BorderSide(color: AppColors.border)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.inputRadius),
                        borderSide: const BorderSide(
                            color: AppColors.accent, width: 1.5)),
                    prefixIcon: const Icon(Icons.search,
                        color: AppColors.textDisabled, size: 20),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              GestureDetector(
                onTap: _search,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.base, vertical: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius:
                        BorderRadius.circular(AppSpacing.inputRadius),
                  ),
                  child: _searching
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text('검색',
                          style: AppTypography.calloutBold
                              .copyWith(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.border),

        // 결과 목록
        if (_results.isEmpty)
          Expanded(
            child: Center(
              child: Text(
                '닉네임이나 이메일로 사용자를 검색하세요',
                style: AppTypography.callout
                    .copyWith(color: AppColors.textSub),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              itemCount: _results.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: AppColors.border),
              itemBuilder: (_, i) {
                final u = _results[i];
                final nickname = u['nickname'] as String? ?? '';
                final email = u['email'] as String? ?? '';
                final balance = u['cash_balance'] as int? ?? 0;
                final role = u['role'] as String? ?? 'student';
                return ListTile(
                  tileColor: AppColors.card,
                  leading: CircleAvatar(
                    backgroundColor: AppColors.surface,
                    child: Icon(
                      role == 'mentor' ? Icons.school : Icons.person,
                      color: AppColors.textSub,
                      size: 20,
                    ),
                  ),
                  title: Text(nickname, style: AppTypography.calloutBold),
                  subtitle: Text(email,
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textSub)),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _fmt(balance),
                        style: AppTypography.calloutBold
                            .copyWith(color: AppColors.accent),
                      ),
                      Text('캐시',
                          style: AppTypography.caption
                              .copyWith(color: AppColors.textDisabled)),
                    ],
                  ),
                  onTap: () => _showAdjustSheet(u),
                );
              },
            ),
          ),
      ],
    );
  }

  String _fmt(int v) => v
      .toString()
      .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}

class _CashAdjustSheet extends StatefulWidget {
  const _CashAdjustSheet({required this.user, required this.onDone});
  final Map<String, dynamic> user;
  final VoidCallback onDone;

  @override
  State<_CashAdjustSheet> createState() => _CashAdjustSheetState();
}

class _CashAdjustSheetState extends State<_CashAdjustSheet> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _isAdd = true; // true = 지급, false = 차감
  bool _saving = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final amount = int.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      showAppToast(context, '올바른 금액을 입력해 주세요', type: ToastType.error);
      return;
    }
    setState(() => _saving = true);
    try {
      final userId = widget.user['id'] as String;
      final currentBalance = widget.user['cash_balance'] as int? ?? 0;
      final delta = _isAdd ? amount : -amount;
      final newBalance = currentBalance + delta;
      if (newBalance < 0) {
        showAppToast(context, '잔액이 부족합니다 (현재: ${_fmt(currentBalance)})',
            type: ToastType.error);
        return;
      }

      await SupabaseService.client
          .from(SupabaseService.usersTable)
          .update({'cash_balance': newBalance}).eq('id', userId);

      await SupabaseService.client
          .from(SupabaseService.cashLedgerTable)
          .insert({
        'user_id': userId,
        'amount': delta,
        'balance': newBalance,
        'type': 'admin_adjust',
        'note': _noteCtrl.text.trim().isEmpty
            ? '관리자 ${_isAdd ? '지급' : '차감'}'
            : _noteCtrl.text.trim(),
      });

      if (!mounted) return;
      Navigator.pop(context);
      showAppToast(
          context,
          '${_fmt(amount)} 캐시를 ${_isAdd ? '지급' : '차감'}했어요',
          type: ToastType.success);
      widget.onDone();
    } catch (e) {
      if (mounted) {
        showAppToast(context, '처리 중 오류가 발생했어요', type: ToastType.error);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nickname = widget.user['nickname'] as String? ?? '';
    final balance = widget.user['cash_balance'] as int? ?? 0;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          AppSpacing.base, AppSpacing.base, AppSpacing.base,
          bottom + AppSpacing.x2l),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.base),

          // 사용자 정보
          Row(
            children: [
              Text(nickname, style: AppTypography.title3),
              const SizedBox(width: AppSpacing.sm),
              Text('현재 잔액: ${_fmt(balance)} 캐시',
                  style: AppTypography.callout
                      .copyWith(color: AppColors.textSub)),
            ],
          ),
          const SizedBox(height: AppSpacing.base),

          // 지급 / 차감 토글
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _isAdd = true),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: _isAdd
                          ? AppColors.success
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _isAdd
                            ? AppColors.success
                            : AppColors.border,
                      ),
                    ),
                    child: Center(
                      child: Text('지급 (+)',
                          style: AppTypography.calloutBold.copyWith(
                              color: _isAdd
                                  ? Colors.white
                                  : AppColors.textSub)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _isAdd = false),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: !_isAdd
                          ? AppColors.error
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: !_isAdd
                            ? AppColors.error
                            : AppColors.border,
                      ),
                    ),
                    child: Center(
                      child: Text('차감 (-)',
                          style: AppTypography.calloutBold.copyWith(
                              color: !_isAdd
                                  ? Colors.white
                                  : AppColors.textSub)),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.base),

          // 금액 입력
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            style: AppTypography.callout,
            decoration: InputDecoration(
              labelText: '금액',
              labelStyle:
                  AppTypography.footnote.copyWith(color: AppColors.textSub),
              suffixText: '캐시',
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.base, vertical: AppSpacing.sm),
              border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppSpacing.inputRadius),
                  borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppSpacing.inputRadius),
                  borderSide: const BorderSide(color: AppColors.border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppSpacing.inputRadius),
                  borderSide: const BorderSide(
                      color: AppColors.accent, width: 1.5)),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // 메모
          TextField(
            controller: _noteCtrl,
            style: AppTypography.callout,
            decoration: InputDecoration(
              labelText: '메모 (선택)',
              labelStyle:
                  AppTypography.footnote.copyWith(color: AppColors.textSub),
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.base, vertical: AppSpacing.sm),
              border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppSpacing.inputRadius),
                  borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppSpacing.inputRadius),
                  borderSide: const BorderSide(color: AppColors.border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppSpacing.inputRadius),
                  borderSide: const BorderSide(
                      color: AppColors.accent, width: 1.5)),
            ),
          ),
          const SizedBox(height: AppSpacing.base),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _confirm,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _isAdd ? AppColors.success : AppColors.error,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppSpacing.inputRadius)),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(
                      _isAdd ? '지급 확인' : '차감 확인',
                      style: AppTypography.calloutBold,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(int v) => v
      .toString()
      .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}

// ══════════════════════════════════════════════════════════════
// 탭 6: 게시판 관리
// ══════════════════════════════════════════════════════════════
class _BoardModerateTab extends ConsumerWidget {
  const _BoardModerateTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(_allBoardPostsProvider);
    return postsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(
          child: Text(AppStrings.serverError,
              style:
                  AppTypography.callout.copyWith(color: AppColors.textSub))),
      data: (posts) {
        if (posts.isEmpty) {
          return Center(
            child: Text('게시물이 없어요',
                style: AppTypography.callout
                    .copyWith(color: AppColors.textSub)),
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.refresh(_allBoardPostsProvider.future),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            itemCount: posts.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: AppColors.border),
            itemBuilder: (_, i) => _BoardPostTile(post: posts[i]),
          ),
        );
      },
    );
  }
}

class _BoardPostTile extends ConsumerStatefulWidget {
  const _BoardPostTile({required this.post});
  final Map<String, dynamic> post;

  @override
  ConsumerState<_BoardPostTile> createState() => _BoardPostTileState();
}

class _BoardPostTileState extends ConsumerState<_BoardPostTile> {
  bool _expanded = false;

  Future<void> _deletePost() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.dialogRadius)),
        title: Text('게시물 삭제', style: AppTypography.title3),
        content: Text(
            '이 게시물을 삭제하시겠어요?\n작성자: ${widget.post['mentor_nickname']}',
            style:
                AppTypography.callout.copyWith(color: AppColors.textSub)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppStrings.cancel,
                style: AppTypography.subhead
                    .copyWith(color: AppColors.textSub)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppStrings.delete,
                style: AppTypography.subhead
                    .copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await SupabaseService.client
          .from(SupabaseService.boardPostsTable)
          .delete()
          .eq('id', widget.post['id'] as String);
      if (mounted) {
        showAppToast(context, '게시물을 삭제했어요', type: ToastType.success);
        ref.invalidate(_allBoardPostsProvider);
      }
    } catch (e) {
      if (mounted) {
        showAppToast(context, AppStrings.serverError, type: ToastType.error);
      }
    }
  }

  Future<void> _deleteComment(String commentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.dialogRadius)),
        title: Text('댓글 삭제', style: AppTypography.title3),
        content: Text('이 댓글을 삭제하시겠어요?',
            style:
                AppTypography.callout.copyWith(color: AppColors.textSub)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppStrings.cancel,
                style: AppTypography.subhead
                    .copyWith(color: AppColors.textSub)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppStrings.delete,
                style: AppTypography.subhead
                    .copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await SupabaseService.client
          .from(SupabaseService.boardCommentsTable)
          .delete()
          .eq('id', commentId);
      if (mounted) {
        showAppToast(context, '댓글을 삭제했어요', type: ToastType.success);
        ref.invalidate(
            _adminPostCommentsProvider(widget.post['id'] as String));
      }
    } catch (e) {
      if (mounted) {
        showAppToast(context, AppStrings.serverError, type: ToastType.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final postId = widget.post['id'] as String;
    final title = widget.post['title'] as String? ?? '';
    final nickname = widget.post['mentor_nickname'] as String? ?? '';
    final commentCount = widget.post['comment_count'] as int? ?? 0;
    final createdAt =
        DateTime.tryParse(widget.post['created_at'] as String? ?? '');
    final dateStr = createdAt != null
        ? '${createdAt.year}.${createdAt.month.toString().padLeft(2, '0')}.${createdAt.day.toString().padLeft(2, '0')}'
        : '';

    return Container(
      color: AppColors.card,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.base),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: AppTypography.calloutBold,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          Text(nickname,
                              style: AppTypography.caption
                                  .copyWith(color: AppColors.textSub)),
                          Text(' · $dateStr',
                              style: AppTypography.caption.copyWith(
                                  color: AppColors.textDisabled)),
                          if (commentCount > 0)
                            Text(' · 댓글 $commentCount',
                                style: AppTypography.caption.copyWith(
                                    color: AppColors.textDisabled)),
                        ],
                      ),
                    ],
                  ),
                ),
                if (commentCount > 0)
                  IconButton(
                    icon: Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: AppColors.textSub,
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => _expanded = !_expanded),
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.only(left: AppSpacing.sm),
                  ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: AppColors.error, size: 20),
                  onPressed: _deletePost,
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.only(left: AppSpacing.sm),
                ),
              ],
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1, color: AppColors.border),
            ref.watch(_adminPostCommentsProvider(postId)).when(
              loading: () => const Padding(
                padding: EdgeInsets.all(AppSpacing.base),
                child: Center(
                    child:
                        CircularProgressIndicator(strokeWidth: 2)),
              ),
              error: (_, __) => const SizedBox.shrink(),
              data: (comments) => comments.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(AppSpacing.base),
                      child: Text('댓글이 없어요',
                          style: AppTypography.caption
                              .copyWith(color: AppColors.textSub)),
                    )
                  : Column(
                      children: comments.map((c) {
                        final commentId = c['id'] as String;
                        final body = c['body'] as String? ?? '';
                        final userNickname =
                            c['user_nickname'] as String? ?? '';
                        final isReply = c['parent_id'] != null;
                        return Container(
                          color: AppColors.surface,
                          padding: EdgeInsets.only(
                            left: isReply
                                ? AppSpacing.x2l + AppSpacing.base
                                : AppSpacing.base,
                            right: AppSpacing.sm,
                            top: AppSpacing.sm,
                            bottom: AppSpacing.sm,
                          ),
                          child: Row(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              if (isReply)
                                const Padding(
                                  padding: EdgeInsets.only(
                                      right: AppSpacing.xs, top: 2),
                                  child: Icon(
                                      Icons.subdirectory_arrow_right,
                                      size: 14,
                                      color: AppColors.textDisabled),
                                ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(userNickname,
                                        style:
                                            AppTypography.captionBold),
                                    Text(body,
                                        style: AppTypography.caption
                                            .copyWith(
                                                color:
                                                    AppColors.textSub)),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: AppColors.error, size: 16),
                                onPressed: () =>
                                    _deleteComment(commentId),
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.only(
                                    left: AppSpacing.sm),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── 공통 버튼 ───────────────────────────────────────────────
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.color,
    required this.onTap,
  });
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Center(
          child: Text(label,
              style:
                  AppTypography.calloutBold.copyWith(color: color)),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// 탭 7: 등재 요청 관리
// ══════════════════════════════════════════════════════════════
class _InfoVerifyManageTab extends ConsumerWidget {
  const _InfoVerifyManageTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(_pendingInfoVerifyRequestsProvider);

    return requestsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(
          child: Text(AppStrings.serverError,
              style:
                  AppTypography.callout.copyWith(color: AppColors.textSub))),
      data: (requests) {
        if (requests.isEmpty) {
          return Center(
            child: Text('등재 요청이 없어요',
                style: AppTypography.callout
                    .copyWith(color: AppColors.textSub)),
          );
        }
        return RefreshIndicator(
          onRefresh: () =>
              ref.refresh(_pendingInfoVerifyRequestsProvider.future),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            itemCount: requests.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: AppColors.border),
            itemBuilder: (_, i) =>
                _InfoVerifyTile(item: requests[i], ref: ref),
          ),
        );
      },
    );
  }
}

class _InfoVerifyTile extends StatelessWidget {
  const _InfoVerifyTile({required this.item, required this.ref});
  final Map<String, dynamic> item;
  final WidgetRef ref;

  static const _labels = {
    'real_name': '실명',
    'middle_school': '중학교',
    'high_school': '고등학교',
    'university': '대학교',
    'department': '학과',
  };

  @override
  Widget build(BuildContext context) {
    final nickname = item['users']?['nickname'] as String? ?? '';
    final email = item['users']?['email'] as String? ?? '';
    final fieldKey = item['field_key'] as String? ?? '';
    final fieldValue = item['field_value'] as String? ?? '';
    final note = item['note'] as String?;
    final status = item['status'] as String? ?? 'pending';
    final fieldLabel = _labels[fieldKey] ?? fieldKey;

    final (statusLabel, statusColor) = switch (status) {
      'approved' => ('승인됨', AppColors.success),
      'rejected' => ('거절됨', AppColors.error),
      _ => ('검토 중', AppColors.warning),
    };

    return Container(
      color: AppColors.card,
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_outline,
                  color: AppColors.textSub, size: 20),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nickname, style: AppTypography.calloutBold),
                    Text(email,
                        style: AppTypography.caption
                            .copyWith(color: AppColors.textSub)),
                  ],
                ),
              ),
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
                        color: statusColor,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.08),
                  borderRadius:
                      BorderRadius.circular(AppSpacing.chipRadius),
                ),
                child: Text(fieldLabel,
                    style: AppTypography.caption.copyWith(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(fieldValue,
                    style: AppTypography.callout
                        .copyWith(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          if (note != null && note.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text('메모: $note',
                style: AppTypography.footnote
                    .copyWith(color: AppColors.textSub)),
          ],
          if (item['file_url'] != null) ...[
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: () => _openFile(context, item['file_url'] as String),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('증빙 서류 보기'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accent,
                side: const BorderSide(color: AppColors.accent),
              ),
            ),
          ],
          if (status == 'pending') ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    label: AppStrings.approve,
                    color: AppColors.success,
                    onTap: () => _handleAction(context, 'approve'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _ActionButton(
                    label: AppStrings.reject,
                    color: AppColors.error,
                    onTap: () => _handleAction(context, 'reject'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openFile(BuildContext context, String fileUrl) async {
    try {
      final signedUrl = await SupabaseService.client.storage
          .from(SupabaseService.mentorDocumentsBucket)
          .createSignedUrl(fileUrl, 3600);
      final uri = Uri.parse(signedUrl);
      if (await canLaunchUrl(uri)) await launchUrl(uri);
    } catch (e) {
      if (context.mounted) {
        showAppToast(context, '파일을 열 수 없어요', type: ToastType.error);
      }
    }
  }

  Future<void> _handleAction(BuildContext context, String action) async {
    final adminNoteCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.dialogRadius)),
        title: Text(action == 'approve' ? '등재 요청 승인' : '등재 요청 거절',
            style: AppTypography.title3),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              action == 'approve'
                  ? '승인하면 멘토 프로필의 "내멘토가 확인한 정보"에 등재됩니다.'
                  : '거절 사유를 입력하세요 (선택).',
              style: AppTypography.callout.copyWith(color: AppColors.textSub),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: adminNoteCtrl,
              decoration: InputDecoration(
                hintText: '관리자 메모 (선택)',
                hintStyle: AppTypography.callout
                    .copyWith(color: AppColors.textDisabled),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppStrings.cancel,
                style: AppTypography.subhead
                    .copyWith(color: AppColors.textSub)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              action == 'approve' ? '승인' : '거절',
              style: AppTypography.subhead.copyWith(
                  color: action == 'approve'
                      ? AppColors.success
                      : AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      final rpcName = action == 'approve'
          ? 'approve_info_verify_request'
          : 'reject_info_verify_request';
      await SupabaseService.client.rpc(rpcName, params: {
        'p_request_id': item['id'] as String,
        if (adminNoteCtrl.text.trim().isNotEmpty)
          'p_admin_note': adminNoteCtrl.text.trim(),
      });
      ref.invalidate(_pendingInfoVerifyRequestsProvider);
      if (context.mounted) {
        showAppToast(
          context,
          action == 'approve' ? '승인 완료 — 멘토 프로필에 등재되었어요' : '거절 처리되었어요',
          type: action == 'approve' ? ToastType.success : ToastType.error,
        );
      }
    } catch (e) {
      if (context.mounted) {
        showAppToast(context, AppStrings.serverError, type: ToastType.error);
      }
    }
  }
}
