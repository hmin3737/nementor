import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/app_colors.dart';
import '../../../core/app_spacing.dart';
import '../../../core/app_strings.dart';
import '../../../core/app_typography.dart';
import '../../../shared/services/supabase_service.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/board_provider.dart';

class BoardWriteScreen extends ConsumerStatefulWidget {
  const BoardWriteScreen({super.key, this.editPostId});
  final String? editPostId;

  @override
  ConsumerState<BoardWriteScreen> createState() => _BoardWriteScreenState();
}

class _BoardWriteScreenState extends ConsumerState<BoardWriteScreen> {
  final _titleCtrl = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollCtrl = ScrollController();
  final _picker = ImagePicker();
  late QuillController _quillCtrl;
  bool _initialized = false;
  bool _isPicking = false;

  @override
  void initState() {
    super.initState();
    _quillCtrl = QuillController.basic();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _focusNode.dispose();
    _scrollCtrl.dispose();
    _quillCtrl.dispose();
    super.dispose();
  }

  QuillController _makeController(String body) {
    try {
      final json = jsonDecode(body) as List;
      return QuillController(
        document: Document.fromJson(json),
        selection: const TextSelection.collapsed(offset: 0),
      );
    } catch (_) {
      final doc = Document();
      if (body.isNotEmpty) doc.insert(0, body);
      return QuillController(
        document: doc,
        selection: const TextSelection.collapsed(offset: 0),
      );
    }
  }

  Future<void> _pickAndInsertImage() async {
    if (_isPicking) return;
    _isPicking = true;
    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (image == null || !mounted) return;

      final user = ref.read(currentUserProvider).valueOrNull;
      if (user == null) return;

      showAppToast(context, '이미지 업로드 중...', type: ToastType.info);

      final bytes = await File(image.path).readAsBytes();
      final ext = image.path.split('.').last.toLowerCase();
      final path =
          '${user.id}/${DateTime.now().millisecondsSinceEpoch}.$ext';

      await SupabaseService.client.storage
          .from(SupabaseService.boardImagesBucket)
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: 'image/$ext'),
          );

      final url = SupabaseService.client.storage
          .from(SupabaseService.boardImagesBucket)
          .getPublicUrl(path);

      final index = _quillCtrl.selection.baseOffset;
      final length =
          _quillCtrl.selection.extentOffset - _quillCtrl.selection.baseOffset;
      _quillCtrl.replaceText(index, length, BlockEmbed.image(url), null);

      if (mounted) {
        showAppToast(context, '이미지가 추가됐어요', type: ToastType.success);
      }
    } catch (e) {
      if (mounted) {
        showAppToast(context, '이미지 업로드 실패', type: ToastType.error);
      }
    } finally {
      _isPicking = false;
    }
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      showAppToast(context, '제목을 입력해 주세요', type: ToastType.error);
      return;
    }
    final plainText = _quillCtrl.document.toPlainText().trim();
    if (plainText.isEmpty) {
      showAppToast(context, '내용을 입력해 주세요', type: ToastType.error);
      return;
    }
    final bodyJson = jsonEncode(_quillCtrl.document.toDelta().toJson());
    final postId = await ref.read(boardWriteProvider.notifier).submit(
          title: title,
          body: bodyJson,
          editPostId: widget.editPostId,
        );
    if (!mounted) return;
    final error = ref.read(boardWriteProvider).error;
    if (error != null) {
      showAppToast(context, AppStrings.serverError, type: ToastType.error);
    } else if (postId != null) {
      showAppToast(
        context,
        widget.editPostId != null ? '칼럼이 수정되었어요' : '칼럼이 등록되었어요',
        type: ToastType.success,
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final writeState = ref.watch(boardWriteProvider);

    // 수정 모드: 기존 내용 로드
    if (widget.editPostId != null && !_initialized) {
      final postAsync = ref.watch(boardDetailProvider(widget.editPostId!));
      postAsync.whenData((post) {
        if (post != null && !_initialized) {
          _initialized = true;
          _titleCtrl.text = post.title;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final old = _quillCtrl;
            setState(() => _quillCtrl = _makeController(post.body));
            old.dispose();
          });
        }
      });
    } else {
      _initialized = true;
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          widget.editPostId != null ? AppStrings.editColumn : AppStrings.writeColumn,
          style: AppTypography.title3,
        ),
        centerTitle: true,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      body: Column(
        children: [
          // 제목
          Container(
            color: AppColors.card,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.base,
              vertical: AppSpacing.sm,
            ),
            child: TextField(
              controller: _titleCtrl,
              maxLength: 100,
              style: AppTypography.title3,
              decoration: InputDecoration(
                counterText: '',
                hintText: '제목을 입력하세요',
                hintStyle:
                    AppTypography.title3.copyWith(color: AppColors.textDisabled),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.border),

          // Quill 툴바
          Container(
            color: AppColors.card,
            child: QuillSimpleToolbar(
              controller: _quillCtrl,
              config: QuillSimpleToolbarConfig(
                multiRowsDisplay: false,
                showFontFamily: false,
                showFontSize: true,
                showBoldButton: true,
                showItalicButton: true,
                showUnderLineButton: true,
                showStrikeThrough: false,
                showInlineCode: false,
                showColorButton: true,
                showBackgroundColorButton: false,
                showAlignmentButtons: true,
                showLeftAlignment: true,
                showCenterAlignment: true,
                showRightAlignment: true,
                showJustifyAlignment: false,
                showHeaderStyle: true,
                showListNumbers: true,
                showListBullets: true,
                showListCheck: false,
                showCodeBlock: false,
                showQuote: false,
                showIndent: true,
                showLink: false,
                showUndo: true,
                showRedo: true,
                showDividers: true,
                showSearchButton: false,
                showSubscript: false,
                showSuperscript: false,
                showSmallButton: false,
                showClearFormat: true,
                customButtons: [
                  QuillToolbarCustomButtonOptions(
                    icon: const Icon(Icons.image_outlined),
                    tooltip: '이미지 삽입',
                    onPressed: () => _pickAndInsertImage(),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.border),

          // 에디터 본문
          Expanded(
            child: QuillEditor(
              controller: _quillCtrl,
              focusNode: _focusNode,
              scrollController: _scrollCtrl,
              config: const QuillEditorConfig(
                placeholder: '내용을 입력하세요',
                padding: EdgeInsets.all(AppSpacing.base),
                expands: false,
                autoFocus: false,
              ),
            ),
          ),

          // 등록 버튼
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.base,
                AppSpacing.sm,
                AppSpacing.base,
                AppSpacing.base,
              ),
              decoration: const BoxDecoration(
                color: AppColors.card,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: AppButton(
                label: widget.editPostId != null ? AppStrings.save : AppStrings.submit,
                variant: AppButtonVariant.primary,
                onPressed: writeState.isLoading ? null : _submit,
                isLoading: writeState.isLoading,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
