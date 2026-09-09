import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';
import 'smart_plan_screen.dart';
import 'focus_screen.dart';
import 'tap_scale.dart';

class PlanScreen extends StatelessWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text("Plan", style: AppTextStyles.heading2),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _PlanEntry(
            icon: Icons.auto_awesome_outlined,
            title: "Akıllı Plan",
            subtitle: "Bugünkü çalışma planını oluştur",
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SmartPlanScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _PlanEntry(
            icon: Icons.timer_outlined,
            title: "Odak Seansı",
            subtitle: "Kronometreyle çalış, süren kaydedilsin",
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FocusScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanEntry extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _PlanEntry({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppColors.cardShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.tonal(AppColors.primary),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.heading3),
                  const SizedBox(height: 4),
                  Text(subtitle, style: AppTextStyles.bodySecondary),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
