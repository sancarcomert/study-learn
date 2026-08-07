// lib/widgets/hero_progress_card.dart
import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../app_text_styles.dart';
import 'eyebrow.dart';
import 'animated_progress_ring.dart';

class HeroProgressCard extends StatelessWidget {
  final double progress;
  final int completedCount;
  final int totalCount;
  final int streak;
  final int longestStreak;
  final String? nextBlockText;

  const HeroProgressCard({
    super.key,
    required this.progress,
    required this.completedCount,
    required this.totalCount,
    required this.streak,
    required this.longestStreak,
    this.nextBlockText,
  });

  String _message() {
    if (streak == 0 && longestStreak > 0) {
      return "Yeniden başlıyoruz, sorun değil 🌱";
    }
    if (progress == 0) {
      return "Başlamak için küçük bir adım yeterli 🚀";
    }
    if (progress >= 1) {
      return "Harika! Bugünkü hedef tamamlandı 🎉";
    }
    if (progress >= 0.5) {
      return "Güzel gidiyorsun, devam et 💪";
    }
    return "Bugün için güzel bir başlangıç yapalım.";
  }

  @override
  Widget build(BuildContext context) {
    final percentage = (progress * 100).round();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.tonal(AppColors.primary),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Eyebrow(text: 'BUGÜNÜN ODAĞI', color: AppColors.primary),
                    const SizedBox(height: 8),
                    Text(
                      '$completedCount / $totalCount görev tamamlandı',
                      style: AppTextStyles.heading3,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      nextBlockText ?? _message(),
                      style: AppTextStyles.bodySecondary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              AnimatedProgressRing(
                value: progress,
                color: AppColors.primary,
                backgroundColor: AppColors.primary.withOpacity(0.15),
                center: Text(
                  '$percentage%',
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          if (streak > 0) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("🔥", style: TextStyle(fontSize: 13)),
                  const SizedBox(width: 4),
                  Text(
                    "$streak gün",
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}