import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/app_colors.dart';
import '../../../core/app_router.dart';
import '../../../core/app_spacing.dart';
import '../../../core/app_strings.dart';
import '../../../core/app_typography.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../auth/providers/auth_provider.dart';

class MypageScreen extends ConsumerWidget {
  const MypageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        elevation: 0,
        title: Text(AppStrings.mypageTitle, style: AppTypography.title3),
        centerTitle: true,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      body: ListView(
        children: [
          // 프로필 헤더
          Container(
            color: AppColors.card,
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: AppSpacing.avatarMd / 2,
                  backgroundColor: AppColors.surface,
                  child: Icon(Icons.person, size: 28, color: AppColors.textSub),
                ),
                const SizedBox(width: AppSpacing.base),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(user?.nickname ?? '',
                              style: AppTypography.title3),
                          const SizedBox(width: AppSpacing.xs),
                          _RoleBadge(role: user?.role),
                        ],
                      ),
                      Text(user?.email ?? '',
                          style: AppTypography.callout
                              .copyWith(color: AppColors.textSub)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined,
                      color: AppColors.textSub, size: 20),
                  onPressed: () => context.push(AppRoutes.profileEdit),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // 캐시 잔액
          GestureDetector(
            onTap: () => context.push(AppRoutes.cash),
            child: Container(
              color: AppColors.card,
              padding: const EdgeInsets.all(AppSpacing.base),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: AppColors.accentGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.toll_outlined,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(AppStrings.myBalance,
                            style: AppTypography.callout
                                .copyWith(color: AppColors.textSub)),
                        Text(
                          '${_fmt(user?.cashBalance ?? 0)} ${AppStrings.cashUnit}',
                          style: AppTypography.title3
                              .copyWith(color: AppColors.accent),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push(AppRoutes.charge),
                    child: Text(AppStrings.chargeTitle,
                        style: AppTypography.subhead
                            .copyWith(color: AppColors.accent)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // 내역 메뉴
          _MenuSection(
            title: '활동 내역',
            items: [
              if (user?.role == UserRole.student) ...[
                _MenuItem(
                  icon: Icons.help_outline,
                  label: AppStrings.myQuestions,
                  onTap: () {},
                ),
              ],
              if (user?.role == UserRole.mentor) ...[
                _MenuItem(
                  icon: Icons.check_circle_outline,
                  label: AppStrings.myAnswers,
                  onTap: () {},
                ),
                _MenuItem(
                  icon: Icons.account_balance_wallet_outlined,
                  label: AppStrings.myEarnings,
                  onTap: () => context.push(AppRoutes.cash),
                ),
              ],
              _MenuItem(
                icon: Icons.gavel_outlined,
                label: AppStrings.myDisputes,
                onTap: () => context.push(AppRoutes.dispute),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // 설정 메뉴
          _MenuSection(
            title: AppStrings.settings,
            items: [
              _MenuItem(
                icon: Icons.notifications_outlined,
                label: AppStrings.notificationSettings,
                onTap: () {},
              ),
              _MenuItem(
                icon: Icons.privacy_tip_outlined,
                label: '개인정보 처리방침',
                onTap: () {},
              ),
              _MenuItem(
                icon: Icons.description_outlined,
                label: '이용약관',
                onTap: () {},
              ),
              _MenuItem(
                icon: Icons.info_outline,
                label: '앱 정보',
                trailing: Text('v1.0.0',
                    style: AppTypography.callout
                        .copyWith(color: AppColors.textDisabled)),
                onTap: () {},
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // 로그아웃
          Container(
            color: AppColors.card,
            child: ListTile(
              leading: const Icon(Icons.logout, color: AppColors.error),
              title: Text(AppStrings.logout,
                  style: AppTypography.callout.copyWith(color: AppColors.error)),
              onTap: () => _showLogoutDialog(context, ref),
            ),
          ),
          const SizedBox(height: AppSpacing.x3l),
        ],
      ),
    );
  }

  Future<void> _showLogoutDialog(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.dialogRadius)),
        title: Text(AppStrings.logout, style: AppTypography.title3),
        content: Text(AppStrings.logoutConfirm,
            style: AppTypography.callout.copyWith(color: AppColors.textSub)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppStrings.cancel,
                style: AppTypography.subhead.copyWith(color: AppColors.textSub)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppStrings.logout,
                style: AppTypography.subhead.copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(authNotifierProvider.notifier).signOut();
    } catch (e) {
      if (context.mounted) {
        showAppToast(context, AppStrings.serverError, type: ToastType.error);
      }
    }
  }

  String _fmt(int v) => v
      .toString()
      .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});
  final UserRole? role;

  @override
  Widget build(BuildContext context) {
    if (role == null) return const SizedBox.shrink();
    final label = role == UserRole.mentor ? '멘토' : '학생';
    final color = role == UserRole.mentor ? AppColors.consultAccent : AppColors.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: AppTypography.caption.copyWith(
              color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class _MenuSection extends StatelessWidget {
  const _MenuSection({required this.title, required this.items});
  final String title;
  final List<_MenuItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.base, AppSpacing.base, AppSpacing.base, AppSpacing.xs),
            child: Text(title,
                style: AppTypography.footnote
                    .copyWith(color: AppColors.textDisabled,
                        fontWeight: FontWeight.w600)),
          ),
          ...items,
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textSub, size: 22),
      title: Text(label, style: AppTypography.callout),
      trailing: trailing ??
          const Icon(Icons.chevron_right,
              color: AppColors.textDisabled, size: 20),
      onTap: onTap,
      dense: true,
    );
  }
}
