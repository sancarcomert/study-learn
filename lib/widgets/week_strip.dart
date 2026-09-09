// lib/widgets/week_strip.dart
import 'package:flutter/material.dart';
import '../task_model.dart';
import '../app_colors.dart';
import '../app_text_styles.dart';
import '../tap_scale.dart';

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

        final taskCount = allTasks
            .where((t) =>
                t.dueDate.year == day.year &&
                t.dueDate.month == day.month &&
                t.dueDate.day == day.day)
            .length;

        return TapScale(
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
                const SizedBox(height: 8),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isToday ? AppColors.primary : AppColors.surface,
                        shape: BoxShape.circle,
                        boxShadow: isToday ? null : AppColors.softShadow,
                      ),
                      child: Text(
                        '${day.day}',
                        style: AppTextStyles.body.copyWith(
                          color: isToday ? AppColors.ink : AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (taskCount > 0)
                      Positioned(
                        top: -4,
                        right: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          constraints: const BoxConstraints(minWidth: 16),
                          decoration: BoxDecoration(
                            color: AppColors.secondary,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.background,
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            taskCount > 9 ? '9+' : '$taskCount',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.caption.copyWith(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}