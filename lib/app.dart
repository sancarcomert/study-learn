// lib/app.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_colors.dart';
import 'app_theme.dart';
import 'app_constants.dart';
import 'main_shell.dart';
import 'onboarding_screen.dart';
import 'stats_provider.dart';

class StudyPlannerApp extends ConsumerWidget {
  const StudyPlannerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(statsProvider);

    final shouldShowOnboarding = stats.hasCompletedOnboarding == false;

    // AppColors.xxx statik getter'lar üzerinden okunuyor (widget'larda
    // Theme.of(context) yerine doğrudan çağrılıyor) — bu yüzden mod
    // değişince tüm ağacın gerçekten yeniden inşa edilmesi lazım. `const`
    // alt widget'lar (MainShell gibi) parent yeniden build olsa bile aynı
    // instance kaldığı için rebuild edilmez; MaterialApp'e temayla
    // değişen bir `key` vermek tüm ağacı sıfırdan kurduruyor.
    AppColors.setMode(
      stats.themeMode == 'light' ? AppThemeMode.light : AppThemeMode.dark,
    );

    return MaterialApp(
      key: ValueKey(stats.themeMode),
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: shouldShowOnboarding
          ? const OnboardingScreen()
          : const MainShell(),
    );
  }
}