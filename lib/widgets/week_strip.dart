import 'package:flutter/material.dart';
import '../task_model.dart';
import '../app_colors.dart';
import '../app_text_styles.dart';
class WeekStrip extends StatelessWidget {
  final List<TaskModel> allTasks;
  final Function(DateTime)? onDaySelected;

  const WeekStrip({
    super.key,
    required this.allTasks,
    this.onDaySelected,
  });
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final dayLabels = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (index) {
        final day = DateTime(monday.year, monday.month, monday.day + index);
        final isToday = day.year == now.year &&
            day.month == now.month &&
            day.day == now.day;

        final hasCompletedTask = allTasks.any((t) =>
            t.isCompleted &&
            t.dueDate.year == day.year &&
            t.dueDate.month == day.month &&
            t.dueDate.day == day.day);

  return GestureDetector(
  onTap: () {
    onDaySelected?.call(day);
  },
  child: Container(
    constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
    alignment: Alignment.center,
    child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(dayLabels[index], style: AppTextStyles.caption),
      const SizedBox(height: 6),

      Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isToday ? AppColors.primary : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Text(
          '${day.day}',
          style: AppTextStyles.body.copyWith(
            color: isToday ? Colors.white : AppColors.textPrimary,
            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),

      const SizedBox(height: 4),

      Container(
        width: 5,
        height: 5,
        decoration: BoxDecoration(
          color: hasCompletedTask
              ? AppColors.success
              : Colors.transparent,
          shape: BoxShape.circle,
        ),
      ),
    ],
    ),
  ),
);
         }),
  );
}
}