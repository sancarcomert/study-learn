import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'tasks_screen.dart';
import 'plan_screen.dart';
import 'stats_screen.dart';
import 'profile_screen.dart';
import 'widgets/app_bottom_nav.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    TasksScreen(),
    PlanScreen(),
    StatsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          AppBottomNavItem(
            icon: Icons.home_outlined,
            selectedIcon: Icons.home,
            label: "Ana",
          ),
          AppBottomNavItem(
            icon: Icons.check_circle_outline,
            selectedIcon: Icons.check_circle,
            label: "Görevler",
          ),
          AppBottomNavItem(
            icon: Icons.auto_awesome_outlined,
            selectedIcon: Icons.auto_awesome,
            label: "Plan",
          ),
          AppBottomNavItem(
            icon: Icons.bar_chart_outlined,
            selectedIcon: Icons.bar_chart,
            label: "İstatistik",
          ),
          AppBottomNavItem(
            icon: Icons.person_outline,
            selectedIcon: Icons.person,
            label: "Profil",
          ),
        ],
      ),
    );
  }
}