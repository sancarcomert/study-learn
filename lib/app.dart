// lib/app.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: shouldShowOnboarding
          ? const OnboardingScreen()
          : const MainShell(),
    );
  }
}