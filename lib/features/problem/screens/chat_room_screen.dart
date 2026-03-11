import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/app_colors.dart';
import '../../../core/app_spacing.dart';
import '../../../core/app_strings.dart';
import '../../../core/app_typography.dart';
import '../../../shared/models/chat_model.dart';
import '../../../shared/services/supabase_service.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../auth/providers/auth_provider.dart';
import '../../mentor/providers/favorites_provider.dart';
import '../providers/question_provider.dart';

// 채팅방 정보 조회 (student_id, mentor_id, question_id)
final _chatRoomInfoProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>?, String>(
        (ref, roomId) async {
  return await SupabaseService.client
      .from(SupabaseService.chatRoomsTable)
      .select('student_id, mentor_id, question_id')
      .eq('id', roomId)
      .maybeSingle();
});

// 채팅방에 연결된 질문 상태 조회
final _questionStatusProvider =
    FutureProvider.autoDispose.family<String, String>((ref, roomId) async {
  final room = await SupabaseService.client
      .from(SupabaseService.chatRoomsTable)
      .select('question_id')
      .eq('id', roomId)
      .maybeSingle();
  if (room == null) return 'open';
  final question = await SupabaseService.client
      .from(SupabaseService.questionsTable)
      .select('status')
      .eq('id', room['question_id'] as String)
      .maybeSingle();
  return question?['status'] as String? ?? 'open';
});

final _chatMessagesProvider = StreamProvider.autoDispose
    .family<List<ChatMessage>, String>((ref, roomId) {
  return SupabaseService.client
      .from(SupabaseService.chatMessagesTable)
      .stream(primaryKey: ['id'])
      .eq('room_id', roomId)
      .order('created_at', ascending: true)
      .map((rows) => rows.map((e) => ChatMessage.fromJson(e)).toList());
});

class ChatRoomScreen extends ConsumerStatefulWidget {
  const ChatRoomScreen({super.key, required this.roomId});
  final String roomId;

  @override
  ConsumerState<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends ConsumerState<ChatRoomScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending = false;

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;
    setState(() => _sending = true);
    _msgCtrl.clear();
    try {
      await SupabaseService.client
          .from(SupabaseService.chatMessagesTable)
          .insert({
        'room_id': widget.roomId,
        'sender_id': user.id,
        'text': text,
        'type': 'text',
      });
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        showAppToast(context, AppStrings.serverError, type: ToastType.error);
        _msgCtrl.text = text;
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickAndSendImage() async {
    final picker = ImagePicker();
    final XFile? file =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file == null || !mounted) return;
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;
    setState(() => _sending = true);
    try {
      final bytes = await file.readAsBytes();
      final ext = file.name.contains('.') ? file.name.split('.').last : 'jpg';
      final path =
          'chat/${widget.roomId}/${DateTime.now().millisecondsSinceEpoch}.$ext';
      await SupabaseService.client.storage
          .from(SupabaseService.questionImagesBucket)
          .uploadBinary(path, bytes);
      final url = SupabaseService.client.storage
          .from(SupabaseService.questionImagesBucket)
          .getPublicUrl(path);
      await SupabaseService.client
          .from(SupabaseService.chatMessagesTable)
          .insert({
        'room_id': widget.roomId,
        'sender_id': user.id,
        'type': 'image',
        'image_url': url,
      });
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        showAppToast(context, AppStrings.serverError, type: ToastType.error);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _showMathInput() {
    final ctrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.dialogRadius)),
        title: Text(AppStrings.addMath, style: AppTypography.title3),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          minLines: 2,
          decoration: InputDecoration(
            hintText: 'e.g. x^2 + 2x + 1 = 0',
            hintStyle:
                AppTypography.callout.copyWith(color: AppColors.textDisabled),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                borderSide: const BorderSide(color: AppColors.border)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppStrings.cancel,
                style: AppTypography.subhead.copyWith(color: AppColors.textSub)),
          ),
          TextButton(
            onPressed: () async {
              final expr = ctrl.text.trim();
              if (expr.isEmpty) {
                Navigator.pop(ctx);
                return;
              }
              Navigator.pop(ctx);
              final user = ref.read(currentUserProvider).valueOrNull;
              if (user == null || !mounted) return;
              try {
                await SupabaseService.client
                    .from(SupabaseService.chatMessagesTable)
                    .insert({
                  'room_id': widget.roomId,
                  'sender_id': user.id,
                  'type': 'math',
                  'math_expression': expr,
                });
                _scrollToBottom();
              } catch (_) {
                if (mounted) {
                  showAppToast(context, AppStrings.serverError,
                      type: ToastType.error);
                }
              }
            },
            child: Text(AppStrings.confirm,
                style:
                    AppTypography.subhead.copyWith(color: AppColors.accent)),
          ),
        ],
      ),
    );
  }

  Future<void> _giveUp() async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;
    final roomInfo = ref.read(_chatRoomInfoProvider(widget.roomId)).valueOrNull;
    final questionId = roomInfo?['question_id'] as String?;
    if (questionId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.dialogRadius)),
        title: Text('답변 포기', style: AppTypography.title3),
        content: Text(
            '답변을 포기하면 질문이 다시 오픈 상태로 돌아갑니다.\n포기하시겠어요?',
            style: AppTypography.callout.copyWith(color: AppColors.textSub)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppStrings.cancel,
                style:
                    AppTypography.subhead.copyWith(color: AppColors.textSub)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('포기하기',
                style: AppTypography.subhead.copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final ok = await ref
        .read(questionSubmitProvider.notifier)
        .giveUp(questionId, user.id);
    if (!mounted) return;
    if (ok) {
      showAppToast(context, '답변을 포기했어요.', type: ToastType.success);
      context.pop();
    } else {
      showAppToast(context, AppStrings.serverError, type: ToastType.error);
    }
  }

  Future<void> _declareEnd() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.dialogRadius)),
        title: Text(AppStrings.declareEndConfirm, style: AppTypography.title3),
        content: Text('종료하면 즉시 답변이 마감됩니다.\n이의가 있으면 분쟁 신청이 가능합니다.',
            style: AppTypography.callout.copyWith(color: AppColors.textSub)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppStrings.cancel,
                style: AppTypography.subhead.copyWith(color: AppColors.textSub)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppStrings.declareEnd,
                style: AppTypography.subhead.copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      // 채팅방의 question_id 조회 후 즉시 closed 처리
      final room = await SupabaseService.client
          .from(SupabaseService.chatRoomsTable)
          .select('question_id')
          .eq('id', widget.roomId)
          .single();
      final questionId = room['question_id'] as String;
      await SupabaseService.client
          .from(SupabaseService.questionsTable)
          .update({'status': 'closed'})
          .eq('id', questionId);
      if (mounted) {
        ref.invalidate(_questionStatusProvider(widget.roomId));
        showAppToast(context, AppStrings.endConfirmed, type: ToastType.success);
      }
    } catch (e) {
      if (mounted) showAppToast(context, AppStrings.serverError, type: ToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(_chatMessagesProvider(widget.roomId));
    final roomInfo = ref.watch(_chatRoomInfoProvider(widget.roomId));
    final statusAsync = ref.watch(_questionStatusProvider(widget.roomId));
    final user = ref.watch(currentUserProvider).valueOrNull;
    final myId = user?.id ?? '';
    // 학생인 경우 채팅 상대(멘토)의 ID를 꺼내 즐겨찾기 버튼 표시
    final isStudent = user?.id == roomInfo.valueOrNull?['student_id'];
    final mentorId = roomInfo.valueOrNull?['mentor_id'] as String?;
    final isMentor = !isStudent && mentorId != null && user?.id == mentorId;
    // statusAsync가 로딩 중이면 isClosed를 확정할 수 없으므로 로딩 화면을 표시
    if (statusAsync.isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.surface,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isClosed = statusAsync.valueOrNull == 'closed';

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(AppStrings.chatRoom, style: AppTypography.title3),
        centerTitle: true,
        actions: [
          if (isStudent && mentorId != null)
            MentorFavoriteButton(mentorId: mentorId),
          if (!isClosed && isMentor)
            TextButton(
              onPressed: _giveUp,
              child: Text('포기',
                  style:
                      AppTypography.subhead.copyWith(color: AppColors.error)),
            ),
          if (!isClosed)
            TextButton(
              onPressed: _declareEnd,
              child: Text(AppStrings.declareEnd,
                  style: AppTypography.subhead.copyWith(color: AppColors.error)),
            ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      body: Column(
        children: [
          if (isClosed)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.sm, horizontal: AppSpacing.base),
              color: AppColors.border,
              child: Text(
                '종료된 상담입니다. 채팅 내역만 확인할 수 있어요.',
                style: AppTypography.caption.copyWith(color: AppColors.textSub),
                textAlign: TextAlign.center,
              ),
            ),
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                  child: Text(AppStrings.serverError,
                      style: AppTypography.callout.copyWith(color: AppColors.textSub))),
              data: (messages) {
                _scrollToBottom();
                if (messages.isEmpty) {
                  return Center(
                      child: Text('첫 메시지를 보내보세요',
                          style: AppTypography.callout.copyWith(color: AppColors.textSub)));
                }
                return ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.base, vertical: AppSpacing.base),
                  itemCount: messages.length,
                  itemBuilder: (_, i) => _MessageBubble(
                      message: messages[i], isMe: messages[i].senderId == myId),
                );
              },
            ),
          ),
          if (!isClosed)
            _InputBar(
              controller: _msgCtrl,
              sending: _sending,
              onSend: _sendMessage,
              onPickImage: _pickAndSendImage,
              onMathInput: _showMathInput,
            ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isMe});
  final ChatMessage message;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    if (message.type == MessageType.system) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.base, vertical: AppSpacing.xs),
            decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(AppSpacing.chipRadius)),
            child: Text(message.text ?? '',
                style: AppTypography.caption.copyWith(color: AppColors.textSub)),
          ),
        ),
      );
    }

    if (message.type == MessageType.math) {
      return Padding(
        padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.xs, horizontal: AppSpacing.base),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.base),
          decoration: BoxDecoration(
              color: AppColors.mathBlock,
              borderRadius: BorderRadius.circular(AppSpacing.inputRadius)),
          child: Text(message.mathExpression ?? '',
              style: AppTypography.body.copyWith(fontFamily: 'monospace')),
        ),
      );
    }

    if (message.type == MessageType.image && message.imageUrl != null) {
      final local = message.createdAt.toLocal();
      final h = local.hour.toString().padLeft(2, '0');
      final m = local.minute.toString().padLeft(2, '0');
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          mainAxisAlignment:
              isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe) ...[
              const CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.border,
                  child:
                      Icon(Icons.person, size: 16, color: AppColors.textSub)),
              const SizedBox(width: AppSpacing.sm),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment:
                    isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                    child: Image.network(
                      message.imageUrl!,
                      width: 200,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text('$h:$m',
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textDisabled)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final displayText = message.text ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            const CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.border,
              child: Icon(Icons.person, size: 16, color: AppColors.textSub),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.base, vertical: AppSpacing.sm),
                  constraints:
                      BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                  decoration: BoxDecoration(
                    color: isMe ? AppColors.accent : AppColors.card,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMe ? 16 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 16),
                    ),
                    boxShadow: AppSpacing.cardShadow,
                  ),
                  child: Text(displayText,
                      style: AppTypography.callout.copyWith(
                          color: isMe ? Colors.white : AppColors.textPrimary)),
                ),
                const SizedBox(height: 2),
                Text(
                  () {
                    final local = message.createdAt.toLocal();
                    final h = local.hour.toString().padLeft(2, '0');
                    final m = local.minute.toString().padLeft(2, '0');
                    return '$h:$m';
                  }(),
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textDisabled),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.sending,
    required this.onSend,
    required this.onPickImage,
    required this.onMathInput,
  });
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback onPickImage;
  final VoidCallback onMathInput;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.base,
        right: AppSpacing.sm,
        top: AppSpacing.sm,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.base,
      ),
      decoration: const BoxDecoration(
          color: AppColors.card,
          border: Border(top: BorderSide(color: AppColors.border))),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.add_photo_alternate_outlined,
                color: AppColors.textSub),
            onPressed: onPickImage,
          ),
          IconButton(
            icon: const Icon(Icons.functions, color: AppColors.textSub),
            onPressed: onMathInput,
          ),
          Expanded(
            child: TextField(
              controller: controller,
              maxLines: 4,
              minLines: 1,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: AppStrings.inputMessage,
                hintStyle: AppTypography.callout.copyWith(color: AppColors.textDisabled),
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.base, vertical: AppSpacing.sm),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: AppColors.border)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          GestureDetector(
            onTap: sending ? null : onSend,
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                  gradient: AppColors.accentGradient, shape: BoxShape.circle),
              child: sending
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
