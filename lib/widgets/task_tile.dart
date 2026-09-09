import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../add_task_screen.dart';
import '../app_colors.dart';
import '../app_text_styles.dart';
import '../focus_screen.dart';
import '../subject_model.dart';
import '../task_model.dart';
import '../task_provider.dart';
import '../task_time_status.dart';
import '../tap_scale.dart';
import 'app_snackbar.dart';

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subject = task.subjectId == null
        ? null
        : subjects.where((s) => s.id == task.subjectId).firstOrNull;

    final priorityColor = _priorityColor(task.priority);

    return Dismissible(
      key: Key(task.id),
      direction: DismissDirection.horizontal,

      // Sağa kaydırma (startToEnd): ertele — silme değil, sadece dueDate
      // güncellemesi olduğu için kart listeden kalıcı olarak kalkmamalı.
      background: Container(
        margin: const EdgeInsets.only(bottom: 14),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 24),
        decoration: BoxDecoration(
          color: AppColors.warning,
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Icon(
          Icons.update,
          color: Colors.white,
        ),
      ),

      // Sola kaydırma (endToStart): sil.
      secondaryBackground: Container(
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

      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          ref.read(taskProvider.notifier).postponeTask(task.id);
          AppSnackBar.success(context, '"${task.title}" yarına ertelendi');
          // false: kart listede kalır, sadece dueDate değişti — bir
          // sonraki state güncellemesinde ait olduğu güne göre zaten
          // doğru yerde görünür/kaybolur.
          return false;
        }

        return await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text("Görev silinsin mi?"),
                content: const Text(
                  "Silindikten sonra kısa süreliğine geri alabilirsin.",
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text("Vazgeç"),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.danger,
                    ),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text("Sil"),
                  ),
                ],
              ),
            ) ??
            false;
      },

      onDismissed: (_) {
        // Notifier'ı burada, widget hâlâ mount'luyken yakalıyoruz.
        // "GERİ AL" onUndo'su gecikmeli çalışıyor (kullanıcı ne zaman
        // basarsa) — o ana kadar bu TaskTile zaten dispose olmuş oluyor,
        // dolayısıyla `ref`i doğrudan closure'da kullanmak Riverpod'da
        // "Cannot use ref after widget was disposed" hatasına yol açıp
        // geri alma işlemini sessizce başarısız kılıyordu. Notifier'ın
        // kendisi widget yaşam döngüsünden bağımsız olduğu için sorun
        // çözülüyor.
        final notifier = ref.read(taskProvider.notifier);
        final deleted = notifier.deleteTask(task.id);
        if (deleted != null) {
          AppSnackBar.undo(
            context,
            '"${deleted.title}" silindi',
            onUndo: () => notifier.restoreTask(deleted),
          );
        }
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
                          builder: (_) => AddTaskScreen(taskToEdit: task),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete_outline),
                    title: const Text("Sil"),
                    onTap: () {
                      Navigator.pop(context);

                      // bkz. Dismissible.onDismissed'teki not: notifier'ı
                      // ref üzerinden değil, doğrudan yakalanmış referansla
                      // kullanıyoruz (widget o ana kadar dispose olmuş olur).
                      final notifier = ref.read(taskProvider.notifier);
                      final deleted = notifier.deleteTask(task.id);
                      if (deleted != null) {
                        AppSnackBar.undo(
                          context,
                          '"${deleted.title}" silindi',
                          onUndo: () => notifier.restoreTask(deleted),
                        );
                      }
                    },
                  ),
                  // Tekrarlayan bir görevse, tüm seriyi tek seferde
                  // silme seçeneği sunuyoruz — aksi halde kullanıcı
                  // 30 örneği tek tek silmek zorunda kalır.
                  if (task.recurringGroupId != null)
                    ListTile(
                      leading: const Icon(
                        Icons.delete_sweep_outlined,
                        color: AppColors.danger,
                      ),
                      title: const Text(
                        "Seriyi Sil (Tüm Tekrarlar)",
                        style: TextStyle(color: AppColors.danger),
                      ),
                      onTap: () async {
                        Navigator.pop(context);

                        final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text("Seri tamamen silinsin mi?"),
                                content: const Text(
                                  "Bu görevin tüm tekrarları (geçmiş ve gelecek) silinecek. Bu işlem geri alınamaz.",
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text("Vazgeç"),
                                  ),
                                  TextButton(
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppColors.danger,
                                    ),
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text("Seriyi Sil"),
                                  ),
                                ],
                              ),
                            ) ??
                            false;

                        if (confirmed) {
                          ref
                              .read(taskProvider.notifier)
                              .deleteRecurringGroup(task.recurringGroupId!);
                        }
                      },
                    ),
                ],
              ),
            ),
          );
        },

        child: Container(
          margin: const EdgeInsets.only(bottom: 14),

          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: priorityColor.withOpacity(0.15),
            ),
            boxShadow: AppColors.cardShadow,
          ),

          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),

            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Öncelik göstergesi — kartın tek ve tutarlı önceliği
                  // temsil eden görsel işareti. Sağdaki ikon kaldırıldı,
                  // aynı bilgiyi iki farklı temsille tekrar etmemek için.
                  Container(
                    width: 4,
                    color: priorityColor,
                  ),

                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 16, 16, 16),

                      child: Row(
                        children: [
                          TapScale(
                            onTap: () {
                              ref.read(taskProvider.notifier).toggleTaskCompletion(
                                    task.id,
                                    ref,
                                  );
                            },

                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 350),
                              transitionBuilder: (child, animation) =>
                                  ScaleTransition(
                                scale: CurvedAnimation(
                                  parent: animation,
                                  curve: Curves.easeOutBack,
                                ),
                                child: child,
                              ),
                              child: Icon(
                                task.isCompleted
                                    ? Icons.check_circle_outline
                                    : Icons.radio_button_unchecked,
                                key: ValueKey(task.isCompleted),
                                color: task.isCompleted
                                    ? AppColors.success
                                    : AppColors.textSecondary,
                                size: 26,
                              ),
                            ),
                          ),

                          const SizedBox(width: 14),

                          Expanded(
                            child: TapScale(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AddTaskScreen(
                                      taskToEdit: task,
                                    ),
                                  ),
                                );
                              },

                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AnimatedDefaultTextStyle(
                                    duration: const Duration(milliseconds: 250),
                                    style: AppTextStyles.body.copyWith(
                                      fontSize: 16,
                                      height: 1.25,
                                      fontWeight: task.isCompleted
                                          ? FontWeight.w500
                                          : FontWeight.w700,

                                      decoration: task.isCompleted
                                          ? TextDecoration.lineThrough
                                          : null,

                                      color: task.isCompleted
                                          ? AppColors.textSecondary
                                          : AppColors.textPrimary,
                                    ),
                                    child: Text(task.title),
                                  ),

                                  if (subject != null ||
                                      task.scheduledTime != null ||
                                      task.estimatedMinutes != null ||
                                      task.recurringGroupId != null) ...[
                                    const SizedBox(height: 10),

                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        if (subject != null)
                                          _SubjectChip(subject: subject),

                                        if (task.scheduledTime != null)
                                          Builder(builder: (_) {
                                            final st = task.timeStatusAt(
                                                DateTime.now());
                                            final hhmm =
                                                '${task.scheduledTime!.hour.toString().padLeft(2, '0')}:${task.scheduledTime!.minute.toString().padLeft(2, '0')}';
                                            switch (st) {
                                              case TaskTimeStatus.overdue:
                                                return _InfoChip(
                                                  icon: Icons
                                                      .warning_amber_rounded,
                                                  color: AppColors.warning,
                                                  text: '$hhmm · gecikti',
                                                );
                                              case TaskTimeStatus.inProgress:
                                                return _InfoChip(
                                                  icon: Icons.schedule,
                                                  color: AppColors.primary,
                                                  text: '$hhmm · şimdi',
                                                );
                                              default:
                                                return _InfoChip(
                                                  icon: Icons.schedule,
                                                  color: AppColors.secondary,
                                                  text: hhmm,
                                                );
                                            }
                                          }),

                                        if (task.estimatedMinutes != null)
                                          _InfoChip(
                                            icon: Icons.timer_outlined,
                                            text: '${task.estimatedMinutes} dk',
                                          ),

                                        // Bu görevin bir tekrar serisinin
                                        // parçası olduğunu görsel olarak
                                        // belli ediyor — uzun basmadan da
                                        // fark edilsin diye.
                                        if (task.recurringGroupId != null)
                                          _InfoChip(
                                            icon: Icons.repeat,
                                            text: task.recurrenceRule ==
                                                    'weekly'
                                                ? 'Haftalık'
                                                : 'Günlük',
                                          ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),

                          // Bu görev üzerinde odak seansı başlat — süre
                          // TOPLAM ÇALIŞMA'ya işlenir. Tamamlanmış görevde
                          // gösterilmez.
                          if (!task.isCompleted) ...[
                            const SizedBox(width: 8),
                            TapScale(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => FocusScreen(
                                      initialNote: task.title,
                                      initialTargetMin: task.estimatedMinutes,
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                width: 34,
                                height: 34,
                                alignment: Alignment.center,
                                decoration: const BoxDecoration(
                                  color: AppColors.surfaceVariant,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.play_arrow,
                                  size: 18,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SubjectChip extends StatelessWidget {
  final SubjectModel subject;

  const _SubjectChip({required this.subject});

  @override
  Widget build(BuildContext context) {
    final color = Color(subject.colorValue);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),

      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),

      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.menu_book_outlined,
            size: 14,
            color: color,
          ),

          const SizedBox(width: 5),

          Text(
            subject.name,
            style: AppTextStyles.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
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
        color: color.withOpacity(0.08),
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