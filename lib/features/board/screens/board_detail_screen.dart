import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/app_colors.dart';
import '../../../core/app_router.dart';
import '../../../core/app_spacing.dart';
import '../../../core/app_strings.dart';
import '../../../core/app_typography.dart';
import '../../../shared/models/board_model.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/cert_badge.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/board_provider.dart';

class BoardDetailScreen extends ConsumerStatefulWidget {
  const BoardDetailScreen({super.key, required this.postId});
  final String postId;

  @override
  ConsumerState<BoardDetailScreen> createState() => _BoardDetailScreenState();
}

class _BoardDetailScreenState extends ConsumerState<BoardDetailScreen> {
  final _commentCtrl = TextEditingController();
  String? _replyToId;
  String? _replyToNick;
  bool _submitting = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    try {
      await ref.read(boardWriteProvider.notifier).addComment(
            postId: widget.postId,
            body: text,
            parentId: _replyToId,
          );
      _commentCtrl.clear();
      setState(() {
        _replyToId = null;
        _replyToNick = null;
      });
      ref.invalidate(boardCommentsProvider(widget.postId));
    } catch (e) {
      if (mounted) {
        showAppToast(context, AppStrings.serverError, type: ToastType.error);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _toggleLike() async {
    await ref.read(boardWriteProvider.notifier).toggleLike(widget.postId);
    ref.invalidate(boardLikedProvider(widget.postId));
    ref.invalidate(boardDetailProvider(widget.postId));
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.dialogRadius)),
        title: Text(AppStrings.deleteColumn, style: AppTypography.title3),
        content: Text(AppStrings.deleteColumnConfirm,
            style: AppTypography.callout.copyWith(color: AppColors.textSub)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppStrings.cancel,
                style: AppTypography.subhead.copyWith(color: AppColors.textSub)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppStrings.delete,
                style: AppTypography.subhead.copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(boardWriteProvider.notifier).delete(widget.postId);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final postAsync = ref.watch(boardDetailProvider(widget.postId));
    final commentsAsync = ref.watch(boardCommentsProvider(widget.postId));
    final likedAsync = ref.watch(boardLikedProvider(widget.postId));
    final user = ref.watch(currentUserProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(AppStrings.boardTitle, style: AppTypography.title3),
        centerTitle: true,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
        actions: [
          postAsync.when(
            data: (post) {
              if (post == null || post.mentorId != user?.id) {
                return const SizedBox.shrink();
              }
              return PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppColors.textPrimary),
                onSelected: (v) {
                  if (v == 'edit') {
                    context.push('${AppRoutes.boardWrite}?postId=${widget.postId}');
                  } else if (v == 'delete') {
                    _delete();
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Text(AppStrings.edit, style: AppTypography.callout),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(AppStrings.delete,
                        style: AppTypography.callout.copyWith(color: AppColors.error)),
                  ),
                ],
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: postAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(AppStrings.serverError,
                    style:
                        AppTypography.callout.copyWith(color: AppColors.textSub)),
              ),
              data: (post) {
                if (post == null) {
                  return Center(
                    child: Text('칼럼을 찾을 수 없어요',
                        style: AppTypography.callout
                            .copyWith(color: AppColors.textSub)),
                  );
                }
                final liked = likedAsync.valueOrNull ?? false;
                return ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    // 본문
                    Container(
                      color: AppColors.card,
                      padding: const EdgeInsets.all(AppSpacing.base),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(post.title, style: AppTypography.title2),
                          const SizedBox(height: AppSpacing.sm),
                          // 작성자
                          Row(
                            children: [
                              const CircleAvatar(
                                radius: 16,
                                backgroundColor: AppColors.border,
                                child: Icon(Icons.person,
                                    size: 16, color: AppColors.textSub),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(post.mentorNickname,
                                          style: AppTypography.calloutBold),
                                      if (post.mentorCertifications.isNotEmpty) ...{
                                        const SizedBox(width: AppSpacing.xs),
                                        CertBadge(
                                          subject: post
                                              .mentorCertifications.first.subject,
                                          level:
                                              post.mentorCertifications.first.level,
                                          compact: true,
                                        ),
                                      },
                                    ],
                                  ),
                                  if (post.mentorUniversity != null)
                                    Text(post.mentorUniversity!,
                                        style: AppTypography.caption
                                            .copyWith(color: AppColors.textSub)),
                                ],
                              ),
                              const Spacer(),
                              Text(
                                _formatDate(post.createdAt),
                                style: AppTypography.caption
                                    .copyWith(color: AppColors.textDisabled),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.base),
                          const Divider(color: AppColors.border),
                          const SizedBox(height: AppSpacing.base),
                          Text(post.body,
                              style: AppTypography.callout
                                  .copyWith(height: 1.7)),
                          const SizedBox(height: AppSpacing.base),
                          // 좋아요
                          GestureDetector(
                            onTap: user != null ? _toggleLike : null,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.base,
                                  vertical: AppSpacing.sm),
                              decoration: BoxDecoration(
                                color: liked
                                    ? AppColors.accent.withValues(alpha: 0.1)
                                    : AppColors.surface,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: liked
                                      ? AppColors.accent
                                      : AppColors.border,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    liked
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    size: 18,
                                    color: liked
                                        ? AppColors.accent
                                        : AppColors.textSub,
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  Text('${post.likeCount}',
                                      style: AppTypography.callout.copyWith(
                                          color: liked
                                              ? AppColors.accent
                                              : AppColors.textSub)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    // 댓글
                    Container(
                      color: AppColors.card,
                      padding: const EdgeInsets.all(AppSpacing.base),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '댓글 ${post.commentCount}',
                            style: AppTypography.title3,
                          ),
                          const SizedBox(height: AppSpacing.base),
                          commentsAsync.when(
                            loading: () => const Center(
                                child: CircularProgressIndicator()),
                            error: (_, __) => const SizedBox.shrink(),
                            data: (comments) => comments.isEmpty
                                ? Text('첫 댓글을 남겨보세요',
                                    style: AppTypography.callout.copyWith(
                                        color: AppColors.textSub))
                                : Column(
                                    children: comments
                                        .map((c) => _CommentTile(
                                              comment: c,
                                              currentUserId: user?.id,
                                              onReply: (id, nick) =>
                                                  setState(() {
                                                _replyToId = id;
                                                _replyToNick = nick;
                                              }),
                                            ))
                                        .toList(),
                                  ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 80),
                  ],
                );
              },
            ),
          ),
          // 댓글 입력
          if (user != null)
            Container(
              padding: EdgeInsets.only(
                left: AppSpacing.base,
                right: AppSpacing.sm,
                top: AppSpacing.sm,
                bottom:
                    MediaQuery.of(context).viewInsets.bottom + AppSpacing.base,
              ),
              decoration: const BoxDecoration(
                color: AppColors.card,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_replyToNick != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: Row(
                        children: [
                          Text('@$_replyToNick 에 답글',
                              style: AppTypography.caption
                                  .copyWith(color: AppColors.accent)),
                          const SizedBox(width: AppSpacing.xs),
                          GestureDetector(
                            onTap: () => setState(() {
                              _replyToId = null;
                              _replyToNick = null;
                            }),
                            child: const Icon(Icons.close,
                                size: 14, color: AppColors.textSub),
                          ),
                        ],
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentCtrl,
                          maxLines: 3,
                          minLines: 1,
                          decoration: InputDecoration(
                            hintText: _replyToNick != null
                                ? AppStrings.replyHint
                                : AppStrings.commentHint,
                            hintStyle: AppTypography.callout
                                .copyWith(color: AppColors.textDisabled),
                            filled: true,
                            fillColor: AppColors.surface,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.base,
                                vertical: AppSpacing.sm),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide:
                                  const BorderSide(color: AppColors.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide:
                                  const BorderSide(color: AppColors.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: const BorderSide(
                                  color: AppColors.accent, width: 1.5),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      GestureDetector(
                        onTap: _submitting ? null : _submitComment,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                              gradient: AppColors.accentGradient,
                              shape: BoxShape.circle),
                          child: _submitting
                              ? const Padding(
                                  padding: EdgeInsets.all(10),
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.send_rounded,
                                  color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.currentUserId,
    required this.onReply,
  });
  final BoardComment comment;
  final String? currentUserId;
  final void Function(String id, String nick) onReply;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CommentRow(
            comment: comment,
            isMentor: comment.userRole == UserRole.mentor,
            onReply: onReply,
          ),
          // 대댓글
          if (comment.replies.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.x2l),
              child: Column(
                children: comment.replies
                    .map((r) => _CommentRow(
                          comment: r,
                          isMentor: r.userRole == UserRole.mentor,
                          onReply: onReply,
                          isReply: true,
                        ))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _CommentRow extends StatelessWidget {
  const _CommentRow({
    required this.comment,
    required this.isMentor,
    required this.onReply,
    this.isReply = false,
  });
  final BoardComment comment;
  final bool isMentor;
  final void Function(String id, String nick) onReply;
  final bool isReply;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isReply)
            const Padding(
              padding: EdgeInsets.only(right: AppSpacing.xs, top: 4),
              child: Icon(Icons.subdirectory_arrow_right,
                  size: 16, color: AppColors.textDisabled),
            ),
          CircleAvatar(
            radius: 14,
            backgroundColor: isMentor
                ? AppColors.accent.withValues(alpha: 0.15)
                : AppColors.border,
            child: Icon(Icons.person,
                size: 14,
                color: isMentor ? AppColors.accent : AppColors.textSub),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(comment.userNickname, style: AppTypography.calloutBold),
                    if (isMentor) ...{
                      const SizedBox(width: AppSpacing.xs),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('멘토',
                            style: AppTypography.caption.copyWith(
                                color: AppColors.accent,
                                fontWeight: FontWeight.w600)),
                      ),
                    },
                    const Spacer(),
                    Text(_timeAgo(comment.createdAt),
                        style: AppTypography.caption
                            .copyWith(color: AppColors.textDisabled)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(comment.body, style: AppTypography.callout),
                const SizedBox(height: AppSpacing.xs),
                GestureDetector(
                  onTap: () => onReply(comment.id, comment.userNickname),
                  child: Text(AppStrings.writeReply,
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textSub)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inDays < 1) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }
}
