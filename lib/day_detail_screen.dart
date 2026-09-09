import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';
import 'task_provider.dart';
import 'widgets/animated_progress_bar.dart';
import 'widgets/eyebrow.dart';

class DayDetailScreen extends ConsumerWidget {
  final DateTime date;

  const DayDetailScreen({
    super.key,
    required this.date,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allTasks = ref.watch(taskProvider);

    final dayTasks = allTasks.where((task) {
      return task.dueDate.year == date.year &&
          task.dueDate.month == date.month &&
          task.dueDate.day == date.day;
    }).toList();

    final completed =
        dayTasks.where((task) => task.isCompleted).length;

    final progress =
        dayTasks.isEmpty ? 0.0 : completed / dayTasks.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Gün Detayı',
          style: AppTextStyles.heading2,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: AppColors.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                Text(
                  '${date.day}.${date.month}.${date.year}',
                  style: AppTextStyles.heading2,
                ),

                const SizedBox(height: 12),

                Text(
                  '$completed / ${dayTasks.length} görev tamamlandı',
                  style: AppTextStyles.bodySecondary,
                ),

                const SizedBox(height: 12),

                AnimatedProgressBar(
                  value: progress,
                  color: AppColors.success,
                  backgroundColor: AppColors.background,
                  height: 10,
                  borderRadius: 10,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          const Eyebrow(text: 'GÖREVLER'),

          const SizedBox(height: 12),

          if (dayTasks.isEmpty)
            Text(
              'Bu gün için görev yok.',
              style: AppTextStyles.bodySecondary,
            )
          else
            ...dayTasks.map(
              (task) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          task.isCompleted
                              ? Icons.check_circle_outline
                              : Icons.circle_outlined,
                          color: task.isCompleted
                              ? AppColors.success
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            task.title,
                            style: AppTextStyles.body.copyWith(
                              decoration: task.isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: task.isCompleted
                                  ? AppColors.textSecondary
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (task.scheduledTime != null ||
                        task.estimatedMinutes != null) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (task.scheduledTime != null)
                            _InfoChip(
                              icon: Icons.schedule,
                              color: AppColors.secondary,
                              text:
                                  '${task.scheduledTime!.hour.toString().padLeft(2, '0')}:${task.scheduledTime!.minute.toString().padLeft(2, '0')}',
                            ),
                          if (task.estimatedMinutes != null)
                            _InfoChip(
                              icon: Icons.timer_outlined,
                              text: '${task.estimatedMinutes} dk',
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.text,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: AppColors.tonal(color),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: AppTextStyles.caption.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}