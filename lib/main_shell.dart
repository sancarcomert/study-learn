import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'tasks_screen.dart';
import 'plan_screen.dart';
import 'stats_screen.dart';
import 'profile_screen.dart';
import 'widget_service.dart';
import 'widgets/app_bottom_nav.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int _currentIndex = 0;

  // const değil — HomeScreen'e hangi sekmenin görünür olduğunu iletebilmek
  // için her build'de yeniden kuruluyor (bkz. home_screen.dart isActive).
  // IndexedStack aynı pozisyondaki widget'ın State'ini koruduğu için bu,
  // sekme değişince HomeScreen'in dispose/yeniden oluşturulmasına yol açmaz.
  List<Widget> get _screens => [
        HomeScreen(isActive: _currentIndex == 0),
        const TasksScreen(),
        const PlanScreen(),
        const StatsScreen(),
        const ProfileScreen(),
      ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Uygulama arka plana alınırken (kullanıcı görev işaretleyip Home'a
    // döndüğünde widget doğru görünsün) ve öne geldiğinde (gün değiştiyse
    // geri sayım yenilensin) ana ekran widget'ını tazele.
    // docs/rakip_analizi §6 B1.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.resumed) {
      WidgetService.sync();
    }
  }

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