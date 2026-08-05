// lib/widgets/hero_progress_card.dart
import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../app_text_styles.dart';

class HeroProgressCard extends StatelessWidget {
  final double progress;
  final int completedCount;
  final int totalCount;
  final int streak;

  const HeroProgressCard({
    super.key,
    required this.progress,
    required this.completedCount,
    required this.totalCount,
    required this.streak,
  });

  String _message() {
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primary.withOpacity(0.75),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.25),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Bugünkü durumun 👋",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (streak > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text("🔥", style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 4),
                      Text(
                        "$streak gün",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 4),

          Text(
            _message(),
            style: AppTextStyles.bodySecondary.copyWith(
              color: Colors.white70,
            ),
          ),

          const SizedBox(height: 20),

          Text(
            "$completedCount / $totalCount görev",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 10),

          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),

          const SizedBox(height: 8),

          Text(
            "%$percentage tamamlandı",
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}