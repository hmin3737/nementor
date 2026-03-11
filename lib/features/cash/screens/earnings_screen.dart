import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/app_colors.dart';
import '../../../core/app_spacing.dart';
import '../../../core/app_strings.dart';
import '../../../core/app_typography.dart';
import '../../../shared/models/cash_model.dart';
import '../../../shared/services/supabase_service.dart';
import '../../auth/providers/auth_provider.dart';

final _earningsProvider =
    FutureProvider.autoDispose<List<CashLedgerEntry>>((ref) async {
  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user == null) return [];
  final rows = await SupabaseService.client
      .from(SupabaseService.cashLedgerTable)
      .select()
      .eq('user_id', user.id)
      .order('created_at', ascending: false)
      .limit(100);
  final all = rows.map((e) => CashLedgerEntry.fromJson(e)).toList();
  return all
      .where((e) =>
          e.type == LedgerType.mentorEarn ||
          e.type == LedgerType.platformFee ||
          e.type == LedgerType.adminAdjust)
      .toList();
});

class EarningsScreen extends ConsumerWidget {
  const EarningsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final earningsAsync = ref.watch(_earningsProvider);
    final user = ref.watch(currentUserProvider).valueOrNull;
    final totalEarned = earningsAsync.maybeWhen(
      data: (entries) => entries
          .where((e) => e.type == LedgerType.mentorEarn)
          .fold(0, (sum, e) => sum + e.amount),
      orElse: () => 0,
    );

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
        title: Text(AppStrings.myEarnings, style: AppTypography.title3),
        centerTitle: true,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      body: Column(
        children: [
          // 잔액 카드 (충전 버튼 없음)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(AppSpacing.base),
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              gradient: AppColors.accentGradient,
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.myBalance,
                  style: AppTypography.callout
                      .copyWith(color: Colors.white.withValues(alpha: 0.8)),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${_fmt(user?.cashBalance ?? 0)} ${AppStrings.cashUnit}',
                  style: AppTypography.title1.copyWith(
                      color: Colors.white, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '총 답변 수익 ${_fmt(totalEarned)} ${AppStrings.cashUnit}',
                  style: AppTypography.caption
                      .copyWith(color: Colors.white.withValues(alpha: 0.75)),
                ),
              ],
            ),
          ),

          // 수익 내역
          Expanded(
            child: earningsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => Center(
                child: Text(AppStrings.serverError,
                    style: AppTypography.callout
                        .copyWith(color: AppColors.textSub)),
              ),
              data: (entries) {
                if (entries.isEmpty) {
                  return Center(
                    child: Text('아직 수익 내역이 없어요',
                        style: AppTypography.callout
                            .copyWith(color: AppColors.textSub)),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () => ref.refresh(_earningsProvider.future),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.base, vertical: AppSpacing.sm),
                    itemCount: entries.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: AppColors.border),
                    itemBuilder: (_, i) => _EarningsTile(entry: entries[i]),
                  ),
                );
              },
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

class _EarningsTile extends StatelessWidget {
  const _EarningsTile({required this.entry});
  final CashLedgerEntry entry;

  @override
  Widget build(BuildContext context) {
    final isCredit = entry.isCredit;
    return Container(
      color: AppColors.card,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base, vertical: AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isCredit
                  ? AppColors.success.withValues(alpha: 0.1)
                  : AppColors.error.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCredit
                  ? Icons.add_circle_outline
                  : Icons.remove_circle_outline,
              color: isCredit ? AppColors.success : AppColors.error,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.typeLabel, style: AppTypography.calloutBold),
                if (entry.note != null)
                  Text(entry.note!,
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textSub),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                Text(
                  _formatDate(entry.createdAt),
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textDisabled),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isCredit ? '+' : ''}${_fmt(entry.amount)} C',
                style: AppTypography.calloutBold.copyWith(
                    color: isCredit ? AppColors.success : AppColors.error),
              ),
              Text(
                '잔액 ${_fmt(entry.balance)} C',
                style: AppTypography.caption
                    .copyWith(color: AppColors.textDisabled),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _fmt(int v) => v
      .toString()
      .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  String _formatDate(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.month}.${dt.day} $h:$m';
  }
}
