import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';
import 'task_provider.dart';
import 'subject_provider.dart';
import 'subject_model.dart';
import 'task_model.dart';
import 'add_task_screen.dart';
import 'widgets/empty_state_card.dart';
import 'widgets/eyebrow.dart';
import 'task_time_status.dart';
import 'tap_scale.dart';

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final allTasks = ref.watch(taskProvider);
    final subjects = ref.watch(subjectProvider);

    final dayTasks =
        allTasks.where((t) => _isSameDay(t.dueDate, _selectedDate)).toList();

    final scheduled = dayTasks.where((t) => t.scheduledTime != null).toList()
      ..sort((a, b) => a.scheduledTime!.compareTo(b.scheduledTime!));
    final unscheduled =
        dayTasks.where((t) => t.scheduledTime == null).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Görevler', style: AppTextStyles.heading2),
      ),
      body: Column(
        children: [
          const SizedBox(height: 4),
          _DaySelectorStrip(
            selectedDate: _selectedDate,
            onDaySelected: (day) => setState(() => _selectedDate = day),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: dayTasks.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: EmptyStateCard(
                        icon: Icons.event_available,
                        message: 'Bu gün için görev yok.',
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                    children: [
                      if (scheduled.isNotEmpty)
                        ...List.generate(scheduled.length, (index) {
                          final task = scheduled[index];
                          final subject = task.subjectId == null
                              ? null
                              : subjects
                                  .where((s) => s.id == task.subjectId)
                                  .firstOrNull;
                          return _TimelineRow(
                            task: task,
                            subject: subject,
                            isLast: index == scheduled.length - 1,
                          );
                        }),
                      if (unscheduled.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        const Eyebrow(text: 'SAATSİZ GÖREVLER'),
                        const SizedBox(height: 12),
                        ...unscheduled.map((task) {
                          final subject = task.subjectId == null
                              ? null
                              : subjects
                                  .where((s) => s.id == task.subjectId)
                                  .firstOrNull;
                          return _UnscheduledTaskRow(
                              task: task, subject: subject);
                        }),
                      ],
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AddTaskScreen(),
            ),
          );
        },
        child: const Icon(Icons.add, color: AppColors.ink),
      ),
    );
  }
}

// Üstteki gün seçici şerit — WeekStrip'ten farklı olarak tıklayınca
// başka ekrana gitmiyor, bu ekranın içeriğini yerinde değiştiriyor.
class _DaySelectorStrip extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDaySelected;

  const _DaySelectorStrip({
    required this.selectedDate,
    required this.onDaySelected,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final dayLabels = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

    return SizedBox(
      height: 72,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(7, (index) {
          final day = DateTime(monday.year, monday.month, monday.day + index);
          final isSelected = _isSame(day, selectedDate);

          return TapScale(
            onTap: () => onDaySelected(day),
            child: SizedBox(
              width: 42,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(dayLabels[index], style: AppTextStyles.caption),
                  const SizedBox(height: 8),
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color:
                          isSelected ? AppColors.primary : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${day.day}',
                      style: AppTextStyles.body.copyWith(
                        color: isSelected
                            ? AppColors.ink
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  bool _isSame(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// Dikey zaman çizelgesindeki tek satır: saat etiketi + bağlantı
// noktası/çizgisi + rengi dersine bağlı görev kartı.
class _TimelineRow extends StatelessWidget {
  final TaskModel task;
  final SubjectModel? subject;
  final bool isLast;

  const _TimelineRow({
    required this.task,
    required this.subject,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        subject != null ? Color(subject!.colorValue) : AppColors.primary;
    final scheduled = task.scheduledTime!;
    final endTime =
        scheduled.add(Duration(minutes: task.estimatedMinutes ?? 30));

    final st = task.timeStatusAt(DateTime.now());
    final overdue = st == TaskTimeStatus.overdue;
    final inProgress = st == TaskTimeStatus.inProgress;
    // Kart zemini sakin kalır (ders tonu); gecikmişse yalnız nokta + saat
    // etiketi + saat aralığı kehribara döner — "bağır" değil "işaretle".
    final dotColor = overdue
        ? AppColors.warning
        : (inProgress ? AppColors.primary : color);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 44,
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '${scheduled.hour.toString().padLeft(2, '0')}:${scheduled.minute.toString().padLeft(2, '0')}',
                style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: overdue ? AppColors.warning : null,
                ),
              ),
            ),
          ),
          SizedBox(
            width: 20,
            child: Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: color.withOpacity(0.25),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: TapScale(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddTaskScreen(taskToEdit: task),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.tonal(color),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              task.title,
                              style: AppTextStyles.body.copyWith(
                                fontWeight: FontWeight.w700,
                                decoration: task.isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: task.isCompleted
                                    ? AppColors.textSecondary
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (task.isCompleted)
                            Icon(
                              Icons.check_circle_outline,
                              color: AppColors.success,
                              size: 18,
                            ),
                        ],
                      ),
                      if (subject != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subject!.name,
                          style: AppTextStyles.caption.copyWith(
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            overdue
                                ? Icons.warning_amber_rounded
                                : Icons.timer_outlined,
                            size: 12,
                            color: overdue
                                ? AppColors.warning
                                : (inProgress
                                    ? AppColors.primary
                                    : AppColors.textSecondary),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${scheduled.hour.toString().padLeft(2, '0')}:${scheduled.minute.toString().padLeft(2, '0')} - ${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}'
                            '${overdue ? ' · gecikti' : (inProgress ? ' · şimdi' : '')}',
                            style: AppTextStyles.caption.copyWith(
                              color: overdue
                                  ? AppColors.warning
                                  : (inProgress ? AppColors.primary : null),
                              fontWeight: (overdue || inProgress)
                                  ? FontWeight.w700
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Saati belirtilmemiş görevler için zaman çizelgesinin altına, sade
// bir liste olarak eklenen satır.
class _UnscheduledTaskRow extends StatelessWidget {
  final TaskModel task;
  final SubjectModel? subject;

  const _UnscheduledTaskRow({required this.task, required this.subject});

  @override
  Widget build(BuildContext context) {
    final color =
        subject != null ? Color(subject!.colorValue) : AppColors.textSecondary;

    return TapScale(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddTaskScreen(taskToEdit: task),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppColors.softShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                task.title,
                style: AppTextStyles.body.copyWith(
                  decoration:
                      task.isCompleted ? TextDecoration.lineThrough : null,
                  color: task.isCompleted
                      ? AppColors.textSecondary
                      : AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}