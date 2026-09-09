import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_text_styles.dart';

/// Ders bazlı konu kapsama yüzdelerini gösteren sütun grafiği. Konu Takip
/// özeti ve İstatistik ekranı aynı bileşeni kullanır.
class CoverageBarChart extends StatelessWidget {
  final List<CoverageBar> bars;

  const CoverageBarChart({super.key, required this.bars});

  @override
  Widget build(BuildContext context) {
    if (bars.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 160,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: 1,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 0.25,
            getDrawingHorizontalLine: (_) => const FlLine(
              color: AppColors.surfaceVariant,
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AppColors.surface,
              getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                '%${(rod.toY * 100).round()}',
                AppTextStyles.caption.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 34,
                interval: 0.25,
                getTitlesWidget: (value, _) => Text(
                  '%${(value * 100).round()}',
                  style: AppTextStyles.caption,
                ),
              ),
            ),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, _) {
                  final i = value.toInt();
                  if (i < 0 || i >= bars.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _short(bars[i].label),
                      style: AppTextStyles.caption,
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < bars.length; i++)
              BarChartGroupData(x: i, barRods: [
                BarChartRodData(
                  toY: bars[i].ratio.clamp(0.0, 1.0),
                  color: bars[i].color,
                  width: 20,
                  borderRadius: BorderRadius.circular(4),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: 1,
                    color: AppColors.surfaceVariant,
                  ),
                ),
              ]),
          ],
        ),
        swapAnimationDuration: const Duration(milliseconds: 650),
        swapAnimationCurve: Curves.easeOutCubic,
      ),
    );
  }

  /// Uzun ders adlarını eksende kısalt.
  static String _short(String name) {
    if (name.length <= 6) return name;
    return '${name.substring(0, 5)}…';
  }
}

class CoverageBar {
  final String label;
  final double ratio;
  final Color color;
  const CoverageBar({
    required this.label,
    required this.ratio,
    required this.color,
  });
}
