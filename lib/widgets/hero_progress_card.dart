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
      padding: const EdgeInsets.all(24),
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

          const Text(
            "Bugünkü durumun 👋",
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            _message(),
            style: AppTextStyles.body.copyWith(
              color: Colors.white70,
            ),
          ),

          const SizedBox(height: 24),

          Row(
            children: [

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    Text(
                      "$completedCount / $totalCount görev",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
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
                        valueColor:
                            const AlwaysStoppedAnimation(Colors.white),
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
              ),

              const SizedBox(width: 20),

              Container(
                width: 65,
                height: 65,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    "$percentage%",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),

          if (streak > 0) ...[
            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [

                  const Text(
                    "🔥",
                    style: TextStyle(fontSize: 22),
                  ),

                  const SizedBox(width: 8),

                  Text(
                    "$streak gündür düzenli çalışıyorsun",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
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