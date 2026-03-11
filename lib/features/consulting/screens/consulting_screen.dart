import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/app_colors.dart';
import '../../../core/app_router.dart';
import '../../../core/app_spacing.dart';
import '../../../core/app_strings.dart';
import '../../../core/app_typography.dart';
import '../../../shared/services/supabase_service.dart';
import '../../auth/providers/auth_provider.dart';

enum _ConsultingStatus { pending, accepted, ongoing, ended, cancelled }

class _ConsultingSession {
  const _ConsultingSession({
    required this.id,
    required this.status,
    required this.partnerNickname,
    this.subject,
    required this.createdAt,
    this.chatRoomId,
  });

  final String id;
  final _ConsultingStatus status;
  final String partnerNickname;
  final String? subject;
  final DateTime createdAt;
  final String? chatRoomId;

  factory _ConsultingSession.fromJson(Map<String, dynamic> json,
      {required bool isMentor}) {
    final s = json['status'] as String? ?? 'pending';
    _ConsultingStatus status;
    switch (s) {
      case 'accepted':
        status = _ConsultingStatus.accepted;
        break;
      case 'ongoing':
        status = _ConsultingStatus.ongoing;
        break;
      case 'ended':
        status = _ConsultingStatus.ended;
        break;
      case 'cancelled':
        status = _ConsultingStatus.cancelled;
        break;
      default:
        status = _ConsultingStatus.pending;
    }

    final partnerData = isMentor
        ? json['student'] as Map<String, dynamic>?
        : json['mentor_profile'] as Map<String, dynamic>?;
    final partnerNickname =
        partnerData?['nickname'] as String? ?? '알 수 없음';

    return _ConsultingSession(
      id: json['id'] as String,
      status: status,
      partnerNickname: partnerNickname,
      subject: json['subject'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      chatRoomId: json['chat_room_id'] as String?,
    );
  }
}

final _consultingListProvider =
    FutureProvider.autoDispose<List<_ConsultingSession>>((ref) async {
  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user == null) return [];

  final isMentor = user.role.name == 'mentor';

  // consulting_sessions 테이블 기준 (설계에 따라 쿼리 조정 가능)
  final rows = await SupabaseService.client
      .from('consulting_sessions')
      .select(
          isMentor
              ? '*, student:users!student_id(nickname)'
              : '*, mentor_profile:mentor_profiles!mentor_id(intro, users!inner(nickname))',
      )
      .eq(isMentor ? 'mentor_id' : 'student_id', user.id)
      .order('created_at', ascending: false)
      .limit(30);

  return rows
      .map((e) =>
          _ConsultingSession.fromJson(e, isMentor: isMentor))
      .toList();
});

class ConsultingScreen extends ConsumerWidget {
  const ConsultingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(_consultingListProvider);
    final user = ref.watch(currentUserProvider).valueOrNull;
    final isMentor = user?.role.name == 'mentor';

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        elevation: 0,
        title: Text(AppStrings.tabConsulting, style: AppTypography.title3),
        centerTitle: true,
        actions: [
          if (isMentor)
            IconButton(
              icon: const Icon(Icons.notifications_outlined,
                  color: AppColors.textPrimary),
              onPressed: () => context.push(AppRoutes.notification),
            ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      body: listAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Text(AppStrings.serverError,
              style: AppTypography.callout.copyWith(color: AppColors.textSub)),
        ),
        data: (sessions) {
          if (sessions.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.school_outlined,
                      size: 56, color: AppColors.textDisabled),
                  const SizedBox(height: AppSpacing.base),
                  Text(
                    isMentor
                        ? '신청된 상담이 없어요'
                        : '상담 내역이 없어요\n멘토 탐색에서 상담을 신청해 보세요',
                    style: AppTypography.callout
                        .copyWith(color: AppColors.textSub),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.refresh(_consultingListProvider.future),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              itemCount: sessions.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: AppColors.border),
              itemBuilder: (_, i) => _SessionTile(
                session: sessions[i],
                isMentor: isMentor,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session, required this.isMentor});
  final _ConsultingSession session;
  final bool isMentor;

  @override
  Widget build(BuildContext context) {
    final canOpenChat = session.chatRoomId != null &&
        (session.status == _ConsultingStatus.accepted ||
            session.status == _ConsultingStatus.ongoing);

    return InkWell(
      onTap: canOpenChat
          ? () => context.push('/chat/${session.chatRoomId}')
          : null,
      child: Container(
        color: AppColors.card,
        padding: const EdgeInsets.all(AppSpacing.base),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.consultAccent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.school_outlined,
                  color: AppColors.consultAccent, size: 22),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        isMentor
                            ? '학생: ${session.partnerNickname}'
                            : '멘토: ${session.partnerNickname}',
                        style: AppTypography.calloutBold,
                      ),
                      const Spacer(),
                      _StatusChip(status: session.status),
                    ],
                  ),
                  if (session.subject != null) ...[
                    const SizedBox(height: 2),
                    Text(session.subject!,
                        style: AppTypography.callout
                            .copyWith(color: AppColors.textSub)),
                  ],
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _timeAgo(session.createdAt),
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textDisabled),
                  ),
                ],
              ),
            ),
            if (canOpenChat)
              const Icon(Icons.chevron_right,
                  color: AppColors.textDisabled, size: 20),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays < 1) return '오늘';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${dt.month}.${dt.day}';
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final _ConsultingStatus status;

  @override
  Widget build(BuildContext context) {
    late String label;
    late Color color;
    switch (status) {
      case _ConsultingStatus.pending:
        label = '대기 중';
        color = AppColors.warning;
        break;
      case _ConsultingStatus.accepted:
        label = '수락됨';
        color = AppColors.consultAccent;
        break;
      case _ConsultingStatus.ongoing:
        label = '진행 중';
        color = AppColors.accent;
        break;
      case _ConsultingStatus.ended:
        label = '종료';
        color = AppColors.textSub;
        break;
      case _ConsultingStatus.cancelled:
        label = '취소됨';
        color = AppColors.error;
        break;
    }
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: AppTypography.caption
              .copyWith(color: color, fontWeight: FontWeight.w600)),
    );
  }
}
