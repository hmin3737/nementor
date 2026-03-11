import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/app_colors.dart';
import '../../../core/app_spacing.dart';
import '../../../core/app_strings.dart';
import '../../../core/app_typography.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/services/supabase_service.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/cert_badge.dart';

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

// ── 멘토 인증 부여 대상 ─────────────────────────────────────
final _verifiedMentorsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final rows = await SupabaseService.client
      .from(SupabaseService.mentorProfilesTable)
      .select('*, users!inner(nickname), mentor_certifications(*)')
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
    _tabCtrl = TabController(length: 3, vsync: this);
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
        bottom: TabBar(
          controller: _tabCtrl,
          labelStyle: AppTypography.calloutBold,
          unselectedLabelStyle: AppTypography.callout,
          labelColor: AppColors.accent,
          unselectedLabelColor: AppColors.textSub,
          indicatorColor: AppColors.accent,
          tabs: const [
            Tab(text: '서류 심사'),
            Tab(text: '분쟁 처리'),
            Tab(text: '인증 관리'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: const [
          _DocumentReviewTab(),
          _DisputeManageTab(),
          _CertManageTab(),
        ],
      ),
    );
  }
}

// ── 서류 심사 탭 ──────────────────────────────────────────────
class _DocumentReviewTab extends ConsumerWidget {
  const _DocumentReviewTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docsAsync = ref.watch(_pendingDocumentsProvider);

    return docsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(
          child: Text(AppStrings.serverError,
              style: AppTypography.callout.copyWith(color: AppColors.textSub))),
      data: (docs) {
        if (docs.isEmpty) {
          return Center(
            child: Text('검토 대기 중인 서류가 없어요',
                style:
                    AppTypography.callout.copyWith(color: AppColors.textSub)),
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
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text('서류 유형: $docType',
              style:
                  AppTypography.callout.copyWith(color: AppColors.textSub)),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  label: AppStrings.approve,
                  color: AppColors.success,
                  onTap: () => _updateStatus(context, doc['id'] as String,
                      'approved', doc['mentor_id'] as String),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _ActionButton(
                  label: AppStrings.reject,
                  color: AppColors.error,
                  onTap: () => _updateStatus(
                      context, doc['id'] as String, 'rejected', null),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _updateStatus(BuildContext context, String docId, String status,
      String? mentorId) async {
    try {
      await SupabaseService.client
          .from(SupabaseService.mentorDocumentsTable)
          .update({'status': status})
          .eq('id', docId);
      if (status == 'approved' && mentorId != null) {
        await SupabaseService.client
            .from(SupabaseService.mentorProfilesTable)
            .update({'verified': true}).eq('user_id', mentorId);
      }
      ref.invalidate(_pendingDocumentsProvider);
      if (context.mounted) {
        showAppToast(context,
            status == 'approved' ? '승인되었어요' : '반려되었어요',
            type: status == 'approved' ? ToastType.success : ToastType.error);
      }
    } catch (e) {
      if (context.mounted) {
        showAppToast(context, AppStrings.serverError, type: ToastType.error);
      }
    }
  }
}

// ── 분쟁 처리 탭 ──────────────────────────────────────────────
class _DisputeManageTab extends ConsumerWidget {
  const _DisputeManageTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final disputesAsync = ref.watch(_pendingDisputesProvider);

    return disputesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(
          child: Text(AppStrings.serverError,
              style: AppTypography.callout.copyWith(color: AppColors.textSub))),
      data: (disputes) {
        if (disputes.isEmpty) {
          return Center(
            child: Text('처리 대기 중인 분쟁이 없어요',
                style:
                    AppTypography.callout.copyWith(color: AppColors.textSub)),
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
              style:
                  AppTypography.callout.copyWith(color: AppColors.textSub)),
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
                      .update({'status': 'resolved', 'result': result})
                      .eq('id', dispute['id'] as String);
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

// ── 인증 관리 탭 ──────────────────────────────────────────────
class _CertManageTab extends ConsumerWidget {
  const _CertManageTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mentorsAsync = ref.watch(_verifiedMentorsProvider);

    return mentorsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(
          child: Text(AppStrings.serverError,
              style: AppTypography.callout.copyWith(color: AppColors.textSub))),
      data: (mentors) {
        if (mentors.isEmpty) {
          return Center(
            child: Text('인증된 멘토가 없어요',
                style:
                    AppTypography.callout.copyWith(color: AppColors.textSub)),
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.refresh(_verifiedMentorsProvider.future),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            itemCount: mentors.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: AppColors.border),
            itemBuilder: (_, i) =>
                _CertMentorTile(mentor: mentors[i], ref: ref),
          ),
        );
      },
    );
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
    final nickname = widget.mentor['users']?['nickname'] as String? ?? '';
    final mentorId = widget.mentor['user_id'] as String;
    final certs = (widget.mentor['mentor_certifications'] as List<dynamic>?)
            ?.map((e) => MentorCertification.fromJson(e as Map<String, dynamic>))
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
          // 인증 부여 폼
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _selectedSubject = v),
                  style: AppTypography.callout,
                  decoration: InputDecoration(
                    hintText: '과목명',
                    hintStyle: AppTypography.callout
                        .copyWith(color: AppColors.textDisabled),
                    filled: true,
                    fillColor: AppColors.surface,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.border)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.border)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                            color: AppColors.accent, width: 1.5)),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              DropdownButton<String>(
                value: _selectedLevel,
                items: const [
                  DropdownMenuItem(value: 'pro', child: Text('PRO')),
                  DropdownMenuItem(value: 'master', child: Text('MASTER')),
                ],
                onChanged: (v) => setState(() => _selectedLevel = v ?? 'pro'),
              ),
              const SizedBox(width: AppSpacing.sm),
              GestureDetector(
                onTap: () => _grantCert(context, mentorId),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
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
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Center(
          child: Text(label,
              style: AppTypography.calloutBold.copyWith(color: color)),
        ),
      ),
    );
  }
}
