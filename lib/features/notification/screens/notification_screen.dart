import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/app_colors.dart';
import '../../../core/app_spacing.dart';
import '../../../core/app_strings.dart';
import '../../../core/app_typography.dart';
import '../../../shared/services/supabase_service.dart';
import '../../auth/providers/auth_provider.dart';

enum _NotificationType { question, chat, review, system, consulting }

class _Notification {
  const _Notification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
    this.refId,
  });
  final String id;
  final _NotificationType type;
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;
  final String? refId;

  factory _Notification.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String? ?? 'system';
    _NotificationType type;
    switch (typeStr) {
      case 'question':
        type = _NotificationType.question;
        break;
      case 'chat':
        type = _NotificationType.chat;
        break;
      case 'review':
        type = _NotificationType.review;
        break;
      case 'consulting':
        type = _NotificationType.consulting;
        break;
      default:
        type = _NotificationType.system;
    }
    return _Notification(
      id: json['id'] as String,
      type: type,
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      refId: json['ref_id'] as String?,
    );
  }
}

final _notificationsProvider =
    FutureProvider.autoDispose<List<_Notification>>((ref) async {
  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user == null) return [];
  final rows = await SupabaseService.client
      .from(SupabaseService.notificationsTable)
      .select()
      .eq('user_id', user.id)
      .order('created_at', ascending: false)
      .limit(50);
  return rows.map((e) => _Notification.fromJson(e)).toList();
});

class NotificationScreen extends ConsumerWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notiAsync = ref.watch(_notificationsProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary),
          onPressed: () => context.canPop() ? context.pop() : null,
        ),
        title: Text(AppStrings.tabNotification, style: AppTypography.title3),
        centerTitle: true,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final user = ref.read(currentUserProvider).valueOrNull;
              if (user == null) return;
              await SupabaseService.client
                  .from(SupabaseService.notificationsTable)
                  .update({'is_read': true})
                  .eq('user_id', user.id)
                  .eq('is_read', false);
              ref.invalidate(_notificationsProvider);
            },
            child: Text('모두 읽음',
                style:
                    AppTypography.subhead.copyWith(color: AppColors.textSub)),
          ),
        ],
      ),
      body: notiAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Text(AppStrings.serverError,
              style: AppTypography.callout.copyWith(color: AppColors.textSub)),
        ),
        data: (notifications) {
          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_none_outlined,
                      size: 56, color: AppColors.textDisabled),
                  const SizedBox(height: AppSpacing.base),
                  Text('새 알림이 없어요',
                      style: AppTypography.callout
                          .copyWith(color: AppColors.textSub)),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(_notificationsProvider.future),
            child: ListView.separated(
              itemCount: notifications.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: AppColors.border),
              itemBuilder: (_, i) => _NotiTile(noti: notifications[i]),
            ),
          );
        },
      ),
    );
  }
}

class _NotiTile extends StatelessWidget {
  const _NotiTile({required this.noti});
  final _Notification noti;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: noti.isRead ? AppColors.card : AppColors.accent.withValues(alpha: 0.04),
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(_iconData, color: _iconColor, size: 20),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(noti.title,
                          style: AppTypography.calloutBold,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (!noti.isRead)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                            color: AppColors.accent, shape: BoxShape.circle),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(noti.body,
                    style: AppTypography.callout
                        .copyWith(color: AppColors.textSub),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: AppSpacing.xs),
                Text(_timeAgo(noti.createdAt),
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textDisabled)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData get _iconData {
    switch (noti.type) {
      case _NotificationType.question:
        return Icons.help_outline;
      case _NotificationType.chat:
        return Icons.chat_bubble_outline;
      case _NotificationType.review:
        return Icons.star_outline;
      case _NotificationType.consulting:
        return Icons.school_outlined;
      case _NotificationType.system:
        return Icons.notifications_outlined;
    }
  }

  Color get _iconColor {
    switch (noti.type) {
      case _NotificationType.question:
        return AppColors.accent;
      case _NotificationType.chat:
        return AppColors.consultAccent;
      case _NotificationType.review:
        return AppColors.warning;
      case _NotificationType.consulting:
        return AppColors.consultAccent;
      case _NotificationType.system:
        return AppColors.textSub;
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inDays < 1) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${dt.month}.${dt.day}';
  }
}
