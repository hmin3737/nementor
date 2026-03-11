import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/app_colors.dart';
import '../../../core/app_spacing.dart';
import '../../../core/app_strings.dart';
import '../../../core/app_typography.dart';
import '../../../shared/services/supabase_service.dart';
import '../../auth/providers/auth_provider.dart';

enum _DisputeStatus { pending, reviewing, resolved }

class _Dispute {
  const _Dispute({
    required this.id,
    required this.questionId,
    required this.status,
    required this.reason,
    this.result,
    required this.createdAt,
  });
  final String id;
  final String questionId;
  final _DisputeStatus status;
  final String reason;
  final String? result;
  final DateTime createdAt;

  factory _Dispute.fromJson(Map<String, dynamic> json) {
    final s = json['status'] as String? ?? 'pending';
    _DisputeStatus status;
    switch (s) {
      case 'reviewing':
        status = _DisputeStatus.reviewing;
        break;
      case 'resolved':
        status = _DisputeStatus.resolved;
        break;
      default:
        status = _DisputeStatus.pending;
    }
    return _Dispute(
      id: json['id'] as String,
      questionId: json['question_id'] as String,
      status: status,
      reason: json['reason'] as String? ?? '',
      result: json['result'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

final _disputesProvider =
    FutureProvider.autoDispose<List<_Dispute>>((ref) async {
  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user == null) return [];
  final rows = await SupabaseService.client
      .from(SupabaseService.disputesTable)
      .select()
      .eq('user_id', user.id)
      .order('created_at', ascending: false);
  return rows.map((e) => _Dispute.fromJson(e)).toList();
});

class DisputeScreen extends ConsumerWidget {
  const DisputeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final disputesAsync = ref.watch(_disputesProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(AppStrings.disputeTitle, style: AppTypography.title3),
        centerTitle: true,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      body: disputesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Text(AppStrings.serverError,
              style: AppTypography.callout.copyWith(color: AppColors.textSub)),
        ),
        data: (disputes) {
          if (disputes.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.gavel_outlined,
                      size: 56, color: AppColors.textDisabled),
                  const SizedBox(height: AppSpacing.base),
                  Text('분쟁 신청 내역이 없어요',
                      style: AppTypography.callout
                          .copyWith(color: AppColors.textSub)),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(_disputesProvider.future),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              itemCount: disputes.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: AppColors.border),
              itemBuilder: (_, i) => _DisputeTile(dispute: disputes[i]),
            ),
          );
        },
      ),
    );
  }
}

class _DisputeTile extends StatelessWidget {
  const _DisputeTile({required this.dispute});
  final _Dispute dispute;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.card,
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatusChip(status: dispute.status),
              const Spacer(),
              Text(
                _formatDate(dispute.createdAt),
                style: AppTypography.caption
                    .copyWith(color: AppColors.textDisabled),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(AppStrings.disputeReason, style: AppTypography.calloutBold),
          const SizedBox(height: AppSpacing.xs),
          Text(dispute.reason,
              style: AppTypography.callout.copyWith(color: AppColors.textSub),
              maxLines: 3,
              overflow: TextOverflow.ellipsis),
          if (dispute.result != null) ...[
            const SizedBox(height: AppSpacing.sm),
            const Divider(color: AppColors.border),
            const SizedBox(height: AppSpacing.xs),
            Text(AppStrings.disputeResult, style: AppTypography.calloutBold),
            const SizedBox(height: AppSpacing.xs),
            Text(dispute.result!,
                style:
                    AppTypography.callout.copyWith(color: AppColors.textSub)),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final _DisputeStatus status;

  @override
  Widget build(BuildContext context) {
    late String label;
    late Color color;
    switch (status) {
      case _DisputeStatus.pending:
        label = AppStrings.disputePending;
        color = AppColors.warning;
        break;
      case _DisputeStatus.reviewing:
        label = AppStrings.disputeReviewing;
        color = AppColors.accent;
        break;
      case _DisputeStatus.resolved:
        label = AppStrings.disputeResolved;
        color = AppColors.success;
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
