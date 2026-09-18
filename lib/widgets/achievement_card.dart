import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../app_text_styles.dart';

class AchievementCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final bool unlocked;

  const AchievementCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.unlocked,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: unlocked
                  ? AppColors.vibrantAmber
                  : AppColors.tonal(AppColors.textMuted),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: unlocked
                  ? AppColors.onColor(AppColors.vibrantAmber)
                  : AppColors.textMuted,
              size: 26,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: AppTextStyles.bodySecondary,
                ),
              ],
            ),
          ),

          Icon(
            unlocked
                ? Icons.check_circle_outline
                : Icons.lock_outline,
            color: unlocked ? AppColors.vibrantAmber : AppColors.textMuted,
          ),
        ],
      ),
    );
  }
}