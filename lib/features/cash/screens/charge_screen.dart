import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../../../core/app_colors.dart';
import '../../../core/app_spacing.dart';
import '../../../core/app_strings.dart';
import '../../../core/app_typography.dart';
import '../../../shared/models/cash_model.dart';
import '../../../shared/widgets/app_toast.dart';

class ChargeScreen extends ConsumerStatefulWidget {
  const ChargeScreen({super.key});

  @override
  ConsumerState<ChargeScreen> createState() => _ChargeScreenState();
}

class _ChargeScreenState extends ConsumerState<ChargeScreen> {
  bool _loading = false;
  String? _selectedProductId;

  Future<void> _purchase(IapProduct product) async {
    setState(() {
      _loading = true;
      _selectedProductId = product.productId;
    });
    try {
      final available = await InAppPurchase.instance.isAvailable();
      if (!available) {
        if (mounted) {
          showAppToast(context, '결제를 사용할 수 없어요', type: ToastType.error);
        }
        return;
      }

      final productDetailResponse = await InAppPurchase.instance
          .queryProductDetails({product.productId});

      if (productDetailResponse.productDetails.isEmpty) {
        if (mounted) {
          showAppToast(context, '상품 정보를 불러올 수 없어요', type: ToastType.error);
        }
        return;
      }

      final detail = productDetailResponse.productDetails.first;
      final param = PurchaseParam(productDetails: detail);
      await InAppPurchase.instance.buyConsumable(purchaseParam: param);
      // 실제 결제 완료 처리는 InAppPurchase.instance.purchaseStream 에서 처리
    } catch (e) {
      if (mounted) {
        showAppToast(context, AppStrings.serverError, type: ToastType.error);
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _selectedProductId = null;
        });
      }
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
        title: Text(AppStrings.chargeTitle, style: AppTypography.title3),
        centerTitle: true,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.base),
        children: [
          // 안내 배너
          Container(
            padding: const EdgeInsets.all(AppSpacing.base),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppColors.accent, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    '충전한 캐시는 질문 등록과 학습상담에 사용할 수 있어요.',
                    style: AppTypography.callout.copyWith(color: AppColors.accent),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.base),
          Text('충전 상품', style: AppTypography.title3),
          const SizedBox(height: AppSpacing.sm),
          ...IapProduct.products.map((product) {
            final isSelected = _selectedProductId == product.productId;
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _ProductCard(
                product: product,
                isLoading: _loading && isSelected,
                onTap: _loading ? null : () => _purchase(product),
              ),
            );
          }),
          const SizedBox(height: AppSpacing.base),
          // 환불 정책
          Container(
            padding: const EdgeInsets.all(AppSpacing.base),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('이용 안내', style: AppTypography.calloutBold),
                const SizedBox(height: AppSpacing.xs),
                _PolicyLine('캐시는 충전 후 즉시 사용 가능합니다.'),
                _PolicyLine('사용되지 않은 캐시는 결제일로부터 5년간 유효합니다.'),
                _PolicyLine('사용된 캐시는 환불이 불가합니다.'),
                _PolicyLine('충전 후 7일 이내 미사용 캐시는 전액 환불됩니다.'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.isLoading,
    required this.onTap,
  });
  final IapProduct product;
  final bool isLoading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.base),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          border: Border.all(color: AppColors.border),
          boxShadow: AppSpacing.cardShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: AppColors.accentGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.toll_outlined, color: Colors.white, size: 24),
            ),
            const SizedBox(width: AppSpacing.base),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_fmt(product.cashAmount)} 캐시',
                    style: AppTypography.calloutBold,
                  ),
                  Text(product.priceLabel,
                      style: AppTypography.callout
                          .copyWith(color: AppColors.textSub)),
                ],
              ),
            ),
            isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.base, vertical: AppSpacing.sm),
                    decoration: BoxDecoration(
                      gradient: AppColors.accentGradient,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('충전',
                        style: AppTypography.calloutBold
                            .copyWith(color: Colors.white)),
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

class _PolicyLine extends StatelessWidget {
  const _PolicyLine(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ',
              style: AppTypography.caption.copyWith(color: AppColors.textSub)),
          Expanded(
            child: Text(text,
                style: AppTypography.caption.copyWith(color: AppColors.textSub)),
          ),
        ],
      ),
    );
  }
}
