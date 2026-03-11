import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/app_colors.dart';
import '../../../core/app_spacing.dart';
import '../../../core/app_strings.dart';
import '../../../core/app_typography.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_toast.dart';
import '../providers/board_provider.dart';

class BoardWriteScreen extends ConsumerStatefulWidget {
  const BoardWriteScreen({super.key, this.editPostId});
  final String? editPostId;

  @override
  ConsumerState<BoardWriteScreen> createState() => _BoardWriteScreenState();
}

class _BoardWriteScreenState extends ConsumerState<BoardWriteScreen> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  bool _initialized = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    final body = _bodyCtrl.text.trim();
    if (title.isEmpty || body.isEmpty) {
      showAppToast(context, '제목과 내용을 입력해 주세요', type: ToastType.error);
      return;
    }
    final postId = await ref.read(boardWriteProvider.notifier).submit(
          title: title,
          body: body,
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
          _titleCtrl.text = post.title;
          _bodyCtrl.text = post.body;
          _initialized = true;
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
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.base),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 제목
              TextField(
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
              const Divider(color: AppColors.border),
              const SizedBox(height: AppSpacing.sm),
              // 본문
              TextField(
                controller: _bodyCtrl,
                maxLines: null,
                minLines: 15,
                style: AppTypography.callout.copyWith(height: 1.8),
                decoration: InputDecoration(
                  hintText: '내용을 입력하세요\n\n수식은 \$...\$ 형식으로 작성할 수 있어요.',
                  hintStyle:
                      AppTypography.callout.copyWith(color: AppColors.textDisabled),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
              const SizedBox(height: AppSpacing.x3l),
              AppButton(
                label: widget.editPostId != null ? AppStrings.save : AppStrings.submit,
                variant: AppButtonVariant.primary,
                onPressed: writeState.isLoading ? null : _submit,
                isLoading: writeState.isLoading,
              ),
              const SizedBox(height: AppSpacing.x2l),
            ],
          ),
        ),
      ),
    );
  }
}
