import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/app_colors.dart';
import '../../../core/app_spacing.dart';
import '../../../core/app_typography.dart';
import '../../../shared/services/supabase_service.dart';
import '../../../shared/widgets/shimmer_box.dart';
import '../../auth/providers/auth_provider.dart';

final _myAnswersProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) return [];
  // 내가 선점(답변)한 질문: chat_rooms에서 mentor_id가 나인 것의 question 정보
  final rows = await SupabaseService.client
      .from(SupabaseService.chatRoomsTable)
      .select('*, questions!inner(id, title, body, price, status, created_at, subject, school_level)')
      .eq('mentor_id', user.id)
      .order('created_at', ascending: false)
      .limit(50);
  return (rows as List).cast<Map<String, dynamic>>();
});

class MyAnswersScreen extends ConsumerWidget {
  const MyAnswersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final answersAsync = ref.watch(_myAnswersProvider);

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
        title: const Text('내 답변 내역', style: AppTypography.title3),
        centerTitle: true,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      body: answersAsync.when(
        loading: () => ListView.builder(
          itemCount: 6,
          itemBuilder: (_, __) => const _AnswerShimmer(),
        ),
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
                  const Icon(Icons.check_circle_outline,
                      size: 64, color: AppColors.textDisabled),
                  const SizedBox(height: AppSpacing.base),
                  Text('아직 답변한 질문이 없어요',
                      style: AppTypography.callout
                          .copyWith(color: AppColors.textSub)),
                ],
              ),
            );
          }
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (_, i) => _AnswerCard(
              item: items[i],
              onTap: () {
                final roomId = items[i]['id'] as String;
                context.push('/chat/$roomId');
              },
            ),
          );
        },
      ),
    );
  }
}

class _AnswerCard extends StatelessWidget {
  const _AnswerCard({required this.item, required this.onTap});
  final Map<String, dynamic> item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final q = item['questions'] as Map<String, dynamic>? ?? {};
    final title = q['title'] as String?;
    final body = q['body'] as String? ?? '';
    final price = q['price'] as int? ?? 0;
    final status = q['status'] as String? ?? '';
    final createdAt = item['created_at'] != null
        ? DateTime.tryParse(item['created_at'] as String) ?? DateTime.now()
        : DateTime.now();

    final (statusLabel, statusColor) = switch (status) {
      'accepted' => ('답변 중', AppColors.accent),
      'closed' => ('종료', AppColors.textSub),
      'cancelled' => ('취소됨', AppColors.error),
      _ => ('오픈', AppColors.success),
    };

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(
            horizontal: AppSpacing.base, vertical: AppSpacing.xs),
        padding: const EdgeInsets.all(AppSpacing.base),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          border: Border.all(color: AppColors.border),
          boxShadow: AppSpacing.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
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
                const Spacer(),
                Text(
                  '₩${_fmt(price)}',
                  style: AppTypography.calloutBold
                      .copyWith(color: AppColors.accent),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (title != null && title.isNotEmpty) ...[
              Text(title,
                  style: AppTypography.calloutBold,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: AppSpacing.xs),
            ],
            Text(body,
                style: AppTypography.callout
                    .copyWith(color: AppColors.textSub),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: AppSpacing.sm),
            Text(
              timeago.format(createdAt, locale: 'ko'),
              style: AppTypography.caption
                  .copyWith(color: AppColors.textDisabled),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(int v) => v
      .toString()
      .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}

class _AnswerShimmer extends StatelessWidget {
  const _AnswerShimmer();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base, vertical: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          ShimmerBox(width: 80, height: 20),
          SizedBox(height: AppSpacing.sm),
          ShimmerBox(width: double.infinity, height: 16),
          SizedBox(height: AppSpacing.xs),
          ShimmerBox(width: 200, height: 14),
        ],
      ),
    );
  }
}
