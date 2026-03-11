import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/app_colors.dart';
import '../core/app_router.dart';
import '../core/app_strings.dart';
import '../core/app_spacing.dart';

class StudentShell extends StatelessWidget {
  const StudentShell({super.key, required this.child});

  final Widget child;


  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final currentIndex = _indexFromLocation(location);

    return Scaffold(
      body: child,
      bottomNavigationBar: _StudentTabBar(currentIndex: currentIndex),
      floatingActionButton: _AskFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  int _indexFromLocation(String location) {
    if (location.startsWith('/student/explore')) return 1;
    if (location.startsWith('/notification')) return 2;
    if (location.startsWith('/mypage')) return 3;
    return 0;
  }
}

class _StudentTabBar extends StatelessWidget {
  const _StudentTabBar({required this.currentIndex});

  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: AppColors.border,
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: AppSpacing.tabBarHeight,
          child: Row(
            children: [
              _TabItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home,
                label: AppStrings.tabFeed,
                index: 0,
                currentIndex: currentIndex,
                route: AppRoutes.studentFeed,
              ),
              _TabItem(
                icon: Icons.search_outlined,
                activeIcon: Icons.search,
                label: AppStrings.tabExploreMentor,
                index: 1,
                currentIndex: currentIndex,
                route: AppRoutes.exploreMentor,
              ),
              // 가운데 빈 공간 (FAB 자리)
              const Expanded(child: SizedBox()),
              _TabItem(
                icon: Icons.notifications_outlined,
                activeIcon: Icons.notifications,
                label: AppStrings.tabNotification,
                index: 2,
                currentIndex: currentIndex,
                route: AppRoutes.notification,
              ),
              _TabItem(
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: AppStrings.tabMypage,
                index: 3,
                currentIndex: currentIndex,
                route: AppRoutes.mypage,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.route,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int index;
  final int currentIndex;
  final String route;

  @override
  Widget build(BuildContext context) {
    final isActive = index == currentIndex;
    final color =
        isActive ? AppColors.accent : AppColors.textDisabled;

    return Expanded(
      child: GestureDetector(
        onTap: () => context.go(route),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isActive ? activeIcon : icon, color: color, size: 24),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontFamily: 'Pretendard',
                fontWeight:
                    isActive ? FontWeight.w600 : FontWeight.normal,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AskFAB extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(AppRoutes.questionRegister),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          gradient: AppColors.accentGradient,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }
}
