import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../main.dart';
import '../../theme/app_colors.dart';
import '../pages/edit_hub_page.dart';
import '../pages/favorites_page.dart';
import '../pages/history_page.dart';
import '../pages/input_page.dart';
import '../pages/settings_page.dart';

class BottomNavShell extends ConsumerStatefulWidget {
  const BottomNavShell({super.key});

  @override
  ConsumerState<BottomNavShell> createState() => _BottomNavShellState();
}

class _BottomNavShellState extends ConsumerState<BottomNavShell> {
  static const _pages = <Widget>[
    InputPage(),
    EditHubPage(),
    HistoryPage(),
    FavoritesPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentIndex = ref.watch(bottomNavIndexProvider);
    // Wrap non-active pages in TickerMode to pause animations on inactive tabs
    final children = List<Widget>.generate(_pages.length, (i) {
      final page = _pages[i];
      return TickerMode(
        enabled: i == currentIndex,
        child: page,
      );
    });

    return Scaffold(
      body: IndexedStack(index: currentIndex, children: children),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: (i) => ref.read(bottomNavIndexProvider.notifier).state = i,
          backgroundColor: isDark ? AppColors.navyDeep : Colors.white,
          selectedItemColor: isDark ? AppColors.aqua : AppColors.dayBluePrimary,
          unselectedItemColor:
              isDark ? AppColors.textMuted : AppColors.dayTextMuted,
          type: BottomNavigationBarType.fixed,
          selectedFontSize: 12,
          unselectedFontSize: 11,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.science_outlined),
              activeIcon: Icon(Icons.science),
              label: '识别',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.edit_note_outlined),
              activeIcon: Icon(Icons.edit_note),
              label: '编辑',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history_outlined),
              activeIcon: Icon(Icons.history),
              label: '历史',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.star_outline),
              activeIcon: Icon(Icons.star),
              label: '收藏',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings),
              label: '设置',
            ),
          ],
        ),
      ),
    );
  }
}
