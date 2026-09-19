import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_colors.dart';
import 'home_screen.dart';
import 'tasks_screen.dart';
import 'plan_screen.dart';
import 'stats_screen.dart';
import 'profile_screen.dart';
import 'widget_service.dart';
import 'widgets/app_bottom_nav.dart';

// Riverpod'da tutuluyor, MainShell'in local State'inde değil — görünüm
// (açık/koyu tema) değişince StudyPlannerApp tüm ağacı yeniden kuruyor
// (bkz. app.dart'taki ValueKey açıklaması). ProviderScope MaterialApp'in
// DIŞINDA olduğu için bu provider o yeniden kurulumdan etkilenmiyor —
// local `int _currentIndex` olsaydı, Profil'deyken temayı değiştirmek
// sekmeyi sessizce Ana'ya sıfırlardı (kullanıcı "basılmıyor" sanırdı,
// aslında ekran değişiyordu).
final currentTabIndexProvider = StateProvider<int>((ref) => 0);

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell>
    with WidgetsBindingObserver {
  int get _currentIndex => ref.watch(currentTabIndexProvider);

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
        onTap: (index) =>
            ref.read(currentTabIndexProvider.notifier).state = index,
        // 2026-09-19: Mentora referansında aktif sekme (hangisi olursa
        // olsun) hep aynı tek violet vurguyu kullanıyor — "gökkuşağı nav"
        // döneminden kalan sekme-başı renk ayrımı (Ana=primary, gerisi
        // secondary) bu pivotla tamamen kaldırıldı.
        items: [
          AppBottomNavItem(
            icon: Icons.home_outlined,
            selectedIcon: Icons.home,
            label: "Ana",
            color: AppColors.primary,
          ),
          AppBottomNavItem(
            icon: Icons.check_circle_outline,
            selectedIcon: Icons.check_circle,
            label: "Görevler",
            color: AppColors.primary,
          ),
          AppBottomNavItem(
            icon: Icons.auto_awesome_outlined,
            selectedIcon: Icons.auto_awesome,
            label: "Plan",
            color: AppColors.primary,
          ),
          AppBottomNavItem(
            icon: Icons.bar_chart_outlined,
            selectedIcon: Icons.bar_chart,
            label: "İstatistik",
            color: AppColors.primary,
          ),
          AppBottomNavItem(
            icon: Icons.person_outline,
            selectedIcon: Icons.person,
            label: "Profil",
            color: AppColors.primary,
          ),
        ],
      ),
    );
  }
}