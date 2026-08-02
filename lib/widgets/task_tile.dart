import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../add_task_screen.dart';
import '../app_colors.dart';
import '../app_text_styles.dart';
import '../subject_model.dart';
import '../task_model.dart';
import '../task_provider.dart';
import '../tap_scale.dart';

class TaskTile extends ConsumerWidget {
  final TaskModel task;
  final List<SubjectModel> subjects;

  const TaskTile({
    super.key,
    required this.task,
    required this.subjects,
  });

  Color _priorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return AppColors.priorityLow;
      case TaskPriority.medium:
        return AppColors.priorityMedium;
      case TaskPriority.high:
        return AppColors.priorityHigh;
    }
  }

  IconData _priorityIcon(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return Icons.keyboard_arrow_down_rounded;
      case TaskPriority.medium:
        return Icons.remove_rounded;
      case TaskPriority.high:
        return Icons.keyboard_double_arrow_up_rounded;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
 final subject = task.subjectId == null
    ? null
    : subjects.where((s) => s.id == task.subjectId).firstOrNull;

final priorityColor = _priorityColor(task.priority);

print("Görev: ${task.title}");
print("Subject ID: ${task.subjectId}");
print("Bulunan subject: ${subject?.name}");

    return Dismissible(
      key: Key(task.id),
      direction: DismissDirection.endToStart,

      background: Container(
        margin: const EdgeInsets.only(bottom: 14),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: AppColors.danger,
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Icon(
          Icons.delete_outline,
          color: Colors.white,
        ),
      ),

      confirmDismiss: (_) async {
        return await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text("Görev silinsin mi?"),
                content: const Text(
                  "Bu işlem geri alınamaz.",
                ),
                actions: [
                  TextButton(
                    onPressed: () =>
                        Navigator.pop(context, false),
                    child: const Text("Vazgeç"),
                  ),
                  TextButton(
                    onPressed: () =>
                        Navigator.pop(context, true),
                    child: const Text("Sil"),
                  ),
                ],
              ),
            ) ??
            false;
      },

      onDismissed: (_) {
        ref.read(taskProvider.notifier).deleteTask(task.id);
      },

      child: GestureDetector(
        onLongPress: () {
          showModalBottomSheet(
            context: context,
            builder: (_) => SafeArea(
              child: Wrap(
                children: [
                  ListTile(
                    leading: const Icon(Icons.edit),
                    title: const Text("Düzenle"),
                    onTap: () {
                      Navigator.pop(context);

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              AddTaskScreen(taskToEdit: task),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading:
                        const Icon(Icons.delete_outline),
                    title: const Text("Sil"),
                    onTap: () {
                      Navigator.pop(context);

                      ref
                          .read(taskProvider.notifier)
                          .deleteTask(task.id);
                    },
                  ),
                ],
              ),
            ),
          );
        },

        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(18),

          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: priorityColor.withOpacity(0.15),
            ),
            boxShadow: AppColors.cardShadow,
          ),

          child: Row(
            children: [

              TapScale(
                onTap: () {
                  ref
                      .read(taskProvider.notifier)
                      .toggleTaskCompletion(
                        task.id,
                        ref,
                      );
                },

                child: Icon(
                  task.isCompleted
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,

                  color: task.isCompleted
                      ? AppColors.success
                      : AppColors.textSecondary,

                  size: 26,
                ),
              ),


              const SizedBox(width: 12),


              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            AddTaskScreen(
                              taskToEdit: task,
                            ),
                      ),
                    );
                  },


                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,

                    children: [

                      Text(
                        task.title,

                        style:
                            AppTextStyles.body.copyWith(
                          decoration:
                              task.isCompleted
                                  ? TextDecoration
                                      .lineThrough
                                  : null,

                          color: task.isCompleted
                              ? AppColors.textSecondary
                              : AppColors.textPrimary,
                        ),
                      ),


                      if (task.scheduledTime != null ||
                          task.estimatedMinutes != null) ...[
                        const SizedBox(height: 8),

                        Wrap(
                          spacing: 8,

                          children: [

                            if (task.scheduledTime != null)
                              _InfoChip(
                                icon: Icons.schedule_rounded,

                                text:
                                    '${task.scheduledTime!.hour.toString().padLeft(2, '0')}:${task.scheduledTime!.minute.toString().padLeft(2, '0')}',
                              ),


                            if (task.estimatedMinutes != null)
                              _InfoChip(
                                icon:
                                    Icons.timer_outlined,

                                text:
                                    '${task.estimatedMinutes} dk',
                              ),
                          ],
                        ),
                      ],
                                            if (subject != null) ...[
                        const SizedBox(height: 8),

                        Container(
                          padding:
                              const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),

                          decoration: BoxDecoration(
                            color: Color(subject.colorValue)
                                .withOpacity(0.12),

                            borderRadius:
                                BorderRadius.circular(10),
                          ),

                          child: Row(
                            mainAxisSize:
                                MainAxisSize.min,

                            children: [

                              Icon(
                                Icons.menu_book_rounded,

                                size: 14,

                                color:
                                    Color(subject.colorValue),
                              ),

                              const SizedBox(width: 5),

                              Text(
                                subject.name,

                                style:
                                    AppTextStyles.caption
                                        .copyWith(
                                  color: Color(
                                    subject.colorValue,
                                  ),

                                  fontWeight:
                                      FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),


              Icon(
                _priorityIcon(task.priority),

                color: priorityColor,

                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}



class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;


  const _InfoChip({
    required this.icon,
    required this.text,
  });


  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),

      decoration: BoxDecoration(
        color:
            AppColors.primary.withOpacity(0.08),

        borderRadius:
            BorderRadius.circular(12),
      ),

      child: Row(
        mainAxisSize:
            MainAxisSize.min,

        children: [

          Icon(
            icon,

            size: 14,

            color:
                AppColors.primary,
          ),

          const SizedBox(width: 5),

          Text(
            text,

            style:
                AppTextStyles.caption.copyWith(
              fontWeight:
                  FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}