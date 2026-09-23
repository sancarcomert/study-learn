import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../app_text_styles.dart';
import '../goal_gap_engine.dart';

/// Home header'ının altında [ExamCountdownChip] ile yan yana duran ince
/// rozet — GOAL → GAP zincirinin (Faz 10) "nerede duruyorum" özeti.
/// Hedef girilmemişse çağıran taraf bu widget'ı hiç oluşturmaz
/// ([primaryGoalGapProvider] null döner); hedef var ama henüz deneme
/// yoksa yalnız hedefi gösterir.
class GoalGapChip extends StatelessWidget {
  final GoalGap goalGap;

  const GoalGapChip({super.key, required this.goalGap});

  @override
  Widget build(BuildContext context) {
    if (!goalGap.hasTarget) return const SizedBox.shrink();
    final target = _fmt(goalGap.target!);

    if (!goalGap.hasResult) {
      return _chip(
        label: 'Hedef: $target net',
        color: AppColors.primary,
        icon: Icons.track_changes_outlined,
      );
    }

    final current = _fmt(goalGap.currentNet!);
    final gap = goalGap.gap!;
    final reached = gap <= 0;
    final label = reached
        ? '$current/$target net · hedefi geçtin'
        : '$current/$target net · ${_fmt(gap)} net kaldı';

    return _chip(
      label: label,
      color: reached ? AppColors.success : AppColors.primary,
      icon: Icons.track_changes_outlined,
    );
  }

  Widget _chip({
    required String label,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.tonal(color),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  static String _fmt(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
}
