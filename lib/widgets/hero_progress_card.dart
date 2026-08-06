// lib/widgets/hero_progress_card.dart
import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../app_text_styles.dart';

class HeroProgressCard extends StatelessWidget {
  final double progress;
  final int completedCount;
  final int totalCount;
  final int streak;
  final int longestStreak;

  const HeroProgressCard({
    super.key,
    required this.progress,
    required this.completedCount,
    required this.totalCount,
    required this.streak,
    required this.longestStreak,
  });

  String _message() {
    // Comeback: kullanıcının daha önce bir serisi vardı (longestStreak > 0)
    // ama şu an sıfır (currentStreak == 0) — bu, "hiç seri yapmamış yeni
    // kullanıcı" değil "serisi kırılmış kullanıcı" demektir. Bu iki durum
    // farklı bir mesajı hak ediyor; kayıp değil, geleceğe odaklı bir ton.
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
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primary.withOpacity(0.75),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 4,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation(Colors.white),
                      ),
                    ),
                    Text(
                      '$percentage%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Text(
                  "$completedCount / $totalCount görev tamamlandı",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              if (streak > 0) ...[
                const SizedBox(width: 8),
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
                      const Text("🔥", style: TextStyle(fontSize: 13)),
                      const SizedBox(width: 4),
                      Text(
                        "$streak",
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
            ],
          ),

          const SizedBox(height: 8),

          Text(
            _message(),
            style: AppTextStyles.bodySecondary.copyWith(
              color: Colors.white70,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}