import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/app_colors.dart';
import '../../../core/app_spacing.dart';
import '../../../core/app_strings.dart';
import '../../../core/app_typography.dart';
import '../../../shared/models/chat_model.dart';
import '../../../shared/services/supabase_service.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../auth/providers/auth_provider.dart';

final _chatMessagesProvider = StreamProvider.autoDispose
    .family<List<ChatMessage>, String>((ref, roomId) {
  return SupabaseService.client
      .from(SupabaseService.chatMessagesTable)
      .stream(primaryKey: ['id'])
      .eq('room_id', roomId)
      .order('created_at')
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

  Future<void> _declareEnd() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.dialogRadius)),
        title: Text(AppStrings.declareEndConfirm, style: AppTypography.title3),
        content: Text(AppStrings.declareEndDesc,
            style: AppTypography.callout.copyWith(color: AppColors.textSub)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppStrings.cancel,
                style: AppTypography.subhead.copyWith(color: AppColors.textSub)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppStrings.declareEnd,
                style: AppTypography.subhead.copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await SupabaseService.client
          .rpc('declare_end', params: {'p_room_id': widget.roomId});
      if (mounted) showAppToast(context, AppStrings.endDeclared, type: ToastType.info);
    } catch (e) {
      if (mounted) showAppToast(context, AppStrings.serverError, type: ToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(_chatMessagesProvider(widget.roomId));
    final user = ref.watch(currentUserProvider).valueOrNull;
    final myId = user?.id ?? '';

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
          _InputBar(controller: _msgCtrl, sending: _sending, onSend: _sendMessage),
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
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs, horizontal: AppSpacing.base),
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

    final displayText =
        message.type == MessageType.image ? '[이미지]' : (message.text ?? '');

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
                    final h = message.createdAt.hour.toString().padLeft(2, '0');
                    final m = message.createdAt.minute.toString().padLeft(2, '0');
                    return '$h:$m';
                  }(),
                  style: AppTypography.caption.copyWith(color: AppColors.textDisabled),
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
  const _InputBar({required this.controller, required this.sending, required this.onSend});
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.base,
        right: AppSpacing.sm,
        top: AppSpacing.sm,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.base,
      ),
      decoration:
          const BoxDecoration(color: AppColors.card, border: Border(top: BorderSide(color: AppColors.border))),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.add_photo_alternate_outlined, color: AppColors.textSub),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.functions, color: AppColors.textSub),
            onPressed: () {},
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
