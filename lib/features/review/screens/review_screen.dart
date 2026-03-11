import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/app_colors.dart';
import '../../../core/app_spacing.dart';
import '../../../core/app_strings.dart';
import '../../../core/app_typography.dart';
import '../../../shared/services/supabase_service.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../auth/providers/auth_provider.dart';

class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({
    super.key,
    required this.questionId,
    required this.mentorId,
    required this.mentorNickname,
  });

  final String questionId;
  final String mentorId;
  final String mentorNickname;

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  int _rating = 0;
  final _commentCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      showAppToast(context, '별점을 선택해 주세요', type: ToastType.error);
      return;
    }
    setState(() => _submitting = true);
    try {
      final user = ref.read(currentUserProvider).valueOrNull;
      if (user == null) return;

      await SupabaseService.client.from(SupabaseService.reviewsTable).insert({
        'question_id': widget.questionId,
        'student_id': user.id,
        'mentor_id': widget.mentorId,
        'rating': _rating,
        'comment': _commentCtrl.text.trim().isEmpty
            ? null
            : _commentCtrl.text.trim(),
      });

      if (mounted) {
        showAppToast(context, '후기가 등록되었어요', type: ToastType.success);
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        showAppToast(context, AppStrings.serverError, type: ToastType.error);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(AppStrings.reviewTitle, style: AppTypography.title3),
        centerTitle: true,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: AppSpacing.base),
              // 멘토 정보
              const CircleAvatar(
                radius: AppSpacing.avatarLg / 2,
                backgroundColor: AppColors.border,
                child:
                    Icon(Icons.person, size: 32, color: AppColors.textSub),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(widget.mentorNickname, style: AppTypography.title3),
              const SizedBox(height: AppSpacing.xs),
              Text('멘토의 답변은 어떠셨나요?',
                  style: AppTypography.callout
                      .copyWith(color: AppColors.textSub)),
              const SizedBox(height: AppSpacing.x2l),

              // 별점
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final filled = i < _rating;
                  return GestureDetector(
                    onTap: () => setState(() => _rating = i + 1),
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                      child: AnimatedScale(
                        scale: filled ? 1.15 : 1.0,
                        duration: const Duration(milliseconds: 150),
                        child: Icon(
                          filled ? Icons.star_rounded : Icons.star_outline_rounded,
                          color: filled
                              ? AppColors.warning
                              : AppColors.textDisabled,
                          size: 44,
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                _ratingLabel,
                style: AppTypography.subhead.copyWith(
                  color: _rating > 0 ? AppColors.warning : AppColors.textDisabled,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // 후기 텍스트
              Align(
                alignment: Alignment.centerLeft,
                child: Text('후기 (선택)',
                    style: AppTypography.subhead
                        .copyWith(fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: AppSpacing.xs),
              TextField(
                controller: _commentCtrl,
                maxLines: 4,
                maxLength: 300,
                style: AppTypography.callout,
                decoration: InputDecoration(
                  hintText: AppStrings.reviewHint,
                  hintStyle: AppTypography.callout
                      .copyWith(color: AppColors.textDisabled),
                  filled: true,
                  fillColor: AppColors.card,
                  contentPadding: const EdgeInsets.all(AppSpacing.base),
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppSpacing.inputRadius),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppSpacing.inputRadius),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppSpacing.inputRadius),
                    borderSide: const BorderSide(
                        color: AppColors.accent, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.x2l),

              AppButton(
                label: AppStrings.submitReview,
                variant: AppButtonVariant.primary,
                onPressed: _submitting ? null : _submit,
                isLoading: _submitting,
              ),
              const SizedBox(height: AppSpacing.base),
              TextButton(
                onPressed: () => context.pop(),
                child: Text(AppStrings.skipReview,
                    style: AppTypography.subhead
                        .copyWith(color: AppColors.textSub)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _ratingLabel {
    switch (_rating) {
      case 1:
        return '아쉬워요';
      case 2:
        return '별로예요';
      case 3:
        return '보통이에요';
      case 4:
        return '좋아요';
      case 5:
        return '최고예요!';
      default:
        return '별점을 선택해 주세요';
    }
  }
}
