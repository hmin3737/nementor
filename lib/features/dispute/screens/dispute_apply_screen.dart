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

class DisputeApplyScreen extends ConsumerStatefulWidget {
  const DisputeApplyScreen({super.key, required this.questionId});
  final String questionId;

  @override
  ConsumerState<DisputeApplyScreen> createState() => _DisputeApplyScreenState();
}

class _DisputeApplyScreenState extends ConsumerState<DisputeApplyScreen> {
  final _reasonCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reasonCtrl.text.trim();
    if (reason.length < 10) {
      showAppToast(context, '분쟁 사유를 10자 이상 입력해 주세요', type: ToastType.error);
      return;
    }
    setState(() => _submitting = true);
    try {
      final user = ref.read(currentUserProvider).valueOrNull;
      if (user == null) return;
      await SupabaseService.client.from(SupabaseService.disputesTable).insert({
        'question_id': widget.questionId,
        'user_id': user.id,
        'reason': reason,
        'status': 'pending',
      });
      if (mounted) {
        showAppToast(context, '분쟁이 접수되었어요', type: ToastType.success);
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
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(AppStrings.disputeApply, style: AppTypography.title3),
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
              // 안내 박스
              Container(
                padding: const EdgeInsets.all(AppSpacing.base),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                  border:
                      Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_outlined,
                        color: AppColors.warning, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        '분쟁 신청 후 관리자가 검토하여 처리 결과를 안내해 드립니다.\n허위 신청 시 서비스 이용이 제한될 수 있습니다.',
                        style: AppTypography.callout
                            .copyWith(color: AppColors.warning),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              Text(AppStrings.disputeReason,
                  style: AppTypography.subhead
                      .copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: AppSpacing.xs),
              TextField(
                controller: _reasonCtrl,
                maxLines: 8,
                minLines: 5,
                style: AppTypography.callout,
                decoration: InputDecoration(
                  hintText: AppStrings.disputeReasonHint,
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
                    borderSide:
                        const BorderSide(color: AppColors.accent, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.x3l),

              AppButton(
                label: AppStrings.disputeApply,
                variant: AppButtonVariant.danger,
                onPressed: _submitting ? null : _submit,
                isLoading: _submitting,
              ),
              const SizedBox(height: AppSpacing.x2l),
            ],
          ),
        ),
      ),
    );
  }
}
