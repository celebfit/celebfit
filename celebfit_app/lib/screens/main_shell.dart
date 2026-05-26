import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import 'analysis_screen.dart';
import 'home_screen.dart';
import 'my_page_screen.dart';
import 'result_screen.dart';
import 'style_select_screen.dart';

class MainShell extends StatelessWidget {
  const MainShell({super.key});

  static const _tabs = [
    _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: '홈'),
    _NavItem(
      icon: Icons.manage_search_outlined,
      activeIcon: Icons.manage_search,
      label: '분석',
    ),
    _NavItem(
      icon: Icons.auto_awesome_outlined,
      activeIcon: Icons.auto_awesome,
      label: '스타일',
    ),
    _NavItem(
      icon: Icons.fact_check_outlined,
      activeIcon: Icons.fact_check,
      label: '결과',
    ),
    _NavItem(
      icon: Icons.person_outline,
      activeIcon: Icons.person,
      label: '마이',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final currentTab = context.watch<AppState>().currentTab;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: currentTab,
        children: const [
          HomeScreen(),
          AnalysisScreen(),
          StyleSelectScreen(),
          ResultScreen(),
          MyPageScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_tabs.length, (index) {
                final tab = _tabs[index];
                return _NavBarItem(
                  item: tab,
                  isActive: currentTab == index,
                  onTap: () => context.read<AppState>().setTab(index),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

class _NavBarItem extends StatelessWidget {
  const _NavBarItem({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  final _NavItem item;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? item.activeIcon : item.icon,
              size: 22,
              color: isActive ? AppColors.primary : AppColors.navInactive,
            ),
            const SizedBox(height: 2),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive ? AppColors.primary : AppColors.navInactive,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
