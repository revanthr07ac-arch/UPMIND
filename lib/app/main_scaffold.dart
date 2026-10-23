import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'theme/app_colors.dart';

class MainScaffold extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainScaffold({super.key, required this.navigationShell});

  void _onTap(BuildContext context, int index) {
    if (index == 2) {
      // Create Post modal/screen
      context.push('/create-post');
      return;
    }
    navigationShell.goBranch(
      index > 2 ? index - 1 : index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  int get _calculatedNavIndex {
    final branch = navigationShell.currentIndex;
    if (branch >= 2) return branch + 1;
    return branch;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _calculatedNavIndex,
        onDestinationSelected: (index) => _onTap(context, index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(
              Icons.home_rounded,
              color: AppColors.primaryBlue,
            ),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(
              Icons.explore_rounded,
              color: AppColors.primaryBlue,
            ),
            label: 'Discover',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.add_box_outlined,
              color: AppColors.secondaryViolet,
            ),
            selectedIcon: Icon(
              Icons.add_box_rounded,
              color: AppColors.secondaryViolet,
            ),
            label: 'Create',
          ),
          NavigationDestination(
            icon: Icon(Icons.school_outlined),
            selectedIcon: Icon(
              Icons.school_rounded,
              color: AppColors.primaryBlue,
            ),
            label: 'Learning',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(
              Icons.person_rounded,
              color: AppColors.primaryBlue,
            ),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
