import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';
import 'rank_provider.dart';
import 'rank_system.dart';
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
                  Color.alphaBlend(color.withValues(alpha: 0.16),
                      AppColors.surface),
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: current
            ? Border.all(color: color, width: 1.4)
            : Border.all(color: AppColors.surfaceVariant, width: 1),
        boxShadow: current ? AppColors.softShadow : null,
      ),
      child: Row(
        children: [
          Opacity(
            opacity: reached || current ? 1 : 0.7,
            child: RankEmblem(rank: rank, size: 46),
          ),
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
                size: 18, color: AppColors.textMuted),
        ],
      ),
    );
  }
}
