import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/app_colors.dart';
import '../core/app_router.dart';
import '../core/app_strings.dart';
import '../core/app_spacing.dart';

class MentorShell extends StatelessWidget {
  const MentorShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final currentIndex = _indexFromLocation(location);

    return Scaffold(
      body: child,
      bottomNavigationBar: _MentorTabBar(currentIndex: currentIndex),
    );
  }

  int _indexFromLocation(String location) {
    if (location.startsWith('/board')) return 1;
    if (location.startsWith('/consulting')) return 2;
    if (location.startsWith('/notification')) return 3;
    if (location.startsWith('/mypage')) return 4;
    return 0;
  }
}

class _MentorTabBar extends StatelessWidget {
  const _MentorTabBar({required this.currentIndex});

  final int currentIndex;

  static const _items = [
    _MentorTabItem(
      icon: Icons.quiz_outlined,
      activeIcon: Icons.quiz,
      label: AppStrings.tabFeed,
      route: AppRoutes.mentorFeed,
    ),
    _MentorTabItem(
      icon: Icons.article_outlined,
      activeIcon: Icons.article,
      label: AppStrings.tabBoard,
      route: AppRoutes.board,
    ),
    _MentorTabItem(
      icon: Icons.chat_outlined,
      activeIcon: Icons.chat,
      label: AppStrings.tabConsulting,
      route: '/consulting',
    ),
    _MentorTabItem(
      icon: Icons.notifications_outlined,
      activeIcon: Icons.notifications,
      label: AppStrings.tabNotification,
      route: AppRoutes.notification,
    ),
    _MentorTabItem(
      icon: Icons.person_outline,
      activeIcon: Icons.person,
      label: AppStrings.tabMypage,
      route: AppRoutes.mypage,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: const Border(
          top: BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: AppSpacing.tabBarHeight,
          child: Row(
            children: _items
                .asMap()
                .entries
                .map((e) => _TabItemWidget(
                      item: e.value,
                      index: e.key,
                      currentIndex: currentIndex,
                    ))
                .toList(),
          ),
        ),
      ),
    );
  }
}

class _MentorTabItem {
  const _MentorTabItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.route,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String route;
}

class _TabItemWidget extends StatelessWidget {
  const _TabItemWidget({
    required this.item,
    required this.index,
    required this.currentIndex,
  });

  final _MentorTabItem item;
  final int index;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    final isActive = index == currentIndex;
    final color = isActive ? AppColors.accent : AppColors.textDisabled;

    return Expanded(
      child: GestureDetector(
        onTap: () => context.go(item.route),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? item.activeIcon : item.icon,
              color: color,
              size: 24,
            ),
            const SizedBox(height: 2),
            Text(
              item.label,
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
