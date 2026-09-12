import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_text_styles.dart';

/// GitHub tarzı aktivite ısı haritası — süreklilik göstergesi. Her hücre
/// bir gün; renk yoğunluğu o gün tamamlanan görev sayısına göre. Salt görsel:
/// gün → sayı haritası alır, hiçbir şey hesaplamaz/yazmaz.
class ActivityHeatmap extends StatelessWidget {
  /// Anahtar = gün (yıl/ay/gün, saat sıfır), değer = o gün tamamlanan görev.
  final Map<DateTime, int> countsByDay;
  final int weeks;

  const ActivityHeatmap({
    super.key,
    required this.countsByDay,
    this.weeks = 12,
  });

  static const _dayLabels = ['P', 'S', 'Ç', 'P', 'C', 'C', 'P'];

  Color _cellColor(int count) {
    if (count <= 0) return AppColors.surfaceVariant;
    if (count == 1) return AppColors.vibrantMint.withValues(alpha: 0.35);
    if (count == 2) return AppColors.vibrantMint.withValues(alpha: 0.65);
    return AppColors.vibrantMint;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final thisMonday = today.subtract(Duration(days: today.weekday - 1));
    final start = thisMonday.subtract(Duration(days: 7 * (weeks - 1)));

    return LayoutBuilder(builder: (context, c) {
      const gap = 4.0;
      final cell = ((c.maxWidth - gap * 6) / 7).clamp(10.0, 22.0);

      Widget square(Color color, {bool ghost = false}) => Container(
            width: cell,
            height: cell,
            decoration: BoxDecoration(
              color: ghost ? Colors.transparent : color,
              borderRadius: BorderRadius.circular(3),
            ),
          );

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final l in _dayLabels)
                SizedBox(
                  width: cell,
                  child: Text(l,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textMuted)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          for (var w = 0; w < weeks; w++) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var d = 0; d < 7; d++)
                  Builder(builder: (_) {
                    final day = start.add(Duration(days: w * 7 + d));
                    if (day.isAfter(today)) return square(Colors.transparent, ghost: true);
                    return square(_cellColor(countsByDay[day] ?? 0));
                  }),
              ],
            ),
            if (w != weeks - 1) const SizedBox(height: gap),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Text('Az',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textMuted)),
              const SizedBox(width: 6),
              for (final ct in [0, 1, 2, 3]) ...[
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _cellColor(ct),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 3),
              ],
              const SizedBox(width: 3),
              Text('Çok',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textMuted)),
            ],
          ),
        ],
      );
    });
  }
}
