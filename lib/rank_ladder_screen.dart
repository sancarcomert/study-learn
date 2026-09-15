import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';
import 'rank_provider.dart';
import 'rank_system.dart';
import 'stats_provider.dart';
import 'task_provider.dart';
import 'widgets/rank_bar.dart';
import 'widgets/rank_emblem.dart';

/// "Üstüne basınca görünen" tam rütbe merdiveni (P0-2). Oyunlardaki
/// bronze/silver/gold ilerleme ekranı gibi: 6 rütbenin tamamı, amblemleri,
/// XP aralıkları, "buradasın / ulaşıldı / kilitli".
class RankLadderScreen extends ConsumerWidget {
  const RankLadderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(rankProvider);
    final color = Color(info.colorHex);
    final stats = ref.watch(statsProvider);
    final completedTasks =
        ref.watch(taskProvider).where((t) => t.isCompleted).length;
    final focusHours = stats.focusMinutes / 60;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Rütbeler', style: AppTextStyles.heading2),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          // --- Hero: mevcut rütbe ---
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.alphaBlend(
                      color.withValues(alpha: 0.16), AppColors.surface),
                  AppColors.surface,
                ],
              ),
              border: Border.all(color: color.withValues(alpha: 0.35)),
              boxShadow: AppColors.cardShadow,
            ),
            child: Column(
              children: [
                RankEmblem(rank: info.rank, size: 104),
                const SizedBox(height: 12),
                Text(info.name, style: AppTextStyles.heading1),
                const SizedBox(height: 4),
                Text('Toplam ${info.xp} XP', style: AppTextStyles.caption),
                const SizedBox(height: 18),
                RankBar(info: info, height: 16),
                const SizedBox(height: 10),
                Text(
                  info.atMax
                      ? 'En üst rütbedesin'
                      : '${info.nextName} için ${info.xpToNextRank} XP',
                  style: AppTextStyles.bodySecondary
                      .copyWith(color: AppColors.textPrimary),
                ),
                const SizedBox(height: 18),
                // Karakter kartı istatistik satırı — rakip araştırmasındaki
                // Habitica bulgusu: rozet + XP çubuğunun altına üç küçük
                // istatistik, tek "kimlik" bloğu olarak.
                Row(
                  children: [
                    Expanded(
                      child: _CharStat(
                        icon: Icons.local_fire_department,
                        value: '${stats.currentStreak}',
                        label: 'GÜN SERİ',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _CharStat(
                        icon: Icons.check_circle_outline,
                        value: '$completedTasks',
                        label: 'GÖREV',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _CharStat(
                        icon: Icons.timer_outlined,
                        value: '${focusHours.toStringAsFixed(0)}sa',
                        label: 'ODAK',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          Text('TÜM RÜTBELER', style: AppTextStyles.eyebrow),
          const SizedBox(height: 12),

          for (var r = 1; r <= 6; r++) ...[
            _LadderRow(
              rank: r,
              current: r == info.rank,
              reached: r <= info.rank,
              xpNeeded: RankSystem.thresholds[r - 1] - info.xp,
            ),
            if (r < 6) const SizedBox(height: 10),
          ],

          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                  color: AppColors.vibrantAmber.withValues(alpha: 0.2)),
              boxShadow: AppColors.softShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.vibrantAmber.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.bolt_outlined,
                          size: 17, color: AppColors.vibrantAmber),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Rütbe nasıl yükselir?',
                      style: AppTextStyles.body
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const _XpSource(label: 'Bir görevi bitir', xp: '+10'),
                const _XpSource(label: 'Günlük hedefini tuttur', xp: '+30'),
                const _XpSource(label: 'Bir konuyu tamamla', xp: '+12'),
                const SizedBox(height: 10),
                Text(
                  'Süre değil, yaptıkların sayılır.',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _XpSource extends StatelessWidget {
  final String label;
  final String xp;

  const _XpSource({required this.label, required this.xp});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: AppTextStyles.bodySecondary),
          ),
          Text(
            '$xp XP',
            style: AppTextStyles.bodySecondary.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LadderRow extends StatelessWidget {
  final int rank;
  final bool current;
  final bool reached;
  final int xpNeeded;

  const _LadderRow({
    required this.rank,
    required this.current,
    required this.reached,
    required this.xpNeeded,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(RankSystem.colors[rank - 1]);
    final name = RankSystem.names[rank - 1];

    final String status;
    final Color statusColor;
    if (current) {
      status = 'Şu an buradasın';
      statusColor = color;
    } else if (reached) {
      status = 'Ulaşıldı';
      statusColor = AppColors.textMuted;
    } else {
      status = '${xpNeeded < 0 ? 0 : xpNeeded} XP kaldı';
      statusColor = AppColors.textMuted;
    }

    final locked = !current && !reached;

    return Opacity(
      // Kilitli rütbeler artık bütünüyle soluk — önceden yalnız amblem
      // hafifçe soluyordu, "kilitli" hissi zayıftı.
      opacity: locked ? 0.5 : 1,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: current
              ? Border.all(color: color, width: 1.6)
              : Border.all(color: AppColors.surfaceVariant, width: 1),
          boxShadow: current
              ? [
                  ...AppColors.softShadow,
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 18,
                    spreadRadius: -2,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            RankEmblem(rank: rank, size: 46),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: AppTextStyles.body.copyWith(
                      color: current || reached
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    status,
                    style: AppTextStyles.caption.copyWith(color: statusColor),
                  ),
                ],
              ),
            ),
            if (current)
              Icon(Icons.my_location_outlined, size: 18, color: color)
            else if (reached)
              const Icon(Icons.check_rounded,
                  size: 18, color: AppColors.textMuted)
            else
              const Icon(Icons.lock_outline,
                  size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

/// Karakter kartındaki tek istatistik hücresi (seri/görev/odak).
class _CharStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _CharStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(height: 6),
          Text(value, style: AppTextStyles.heading3),
          const SizedBox(height: 1),
          Text(label, style: AppTextStyles.caption.copyWith(fontSize: 9.5)),
        ],
      ),
    );
  }
}
