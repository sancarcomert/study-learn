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
import 'widgets/app_buttons.dart';
import 'widgets/section_header.dart';
import 'widgets/task_tile.dart';
import 'task_time_status.dart';
import 'tap_scale.dart';

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  late DateTime _selectedDate;
  // Görüntülenen haftanın Pazartesi'si. Önceden hep "bugünün haftası"na
  // sabitti — başka haftaya geçiş yoktu. Artık ‹ › ile kayabiliyor.
  late DateTime _weekAnchor;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _weekAnchor = _mondayOf(_selectedDate);
  }

  DateTime _mondayOf(DateTime d) =>
      DateTime(d.year, d.month, d.day - (d.weekday - 1));

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _shiftWeek(int deltaDays) {
    setState(() => _weekAnchor = _weekAnchor.add(Duration(days: deltaDays)));
  }

  void _selectDay(DateTime day) {
    setState(() {
      _selectedDate = day;
      _weekAnchor = _mondayOf(day);
    });
  }

  void _jumpToToday() {
    final now = DateTime.now();
    _selectDay(DateTime(now.year, now.month, now.day));
  }

  @override
  Widget build(BuildContext context) {
    final allTasks = ref.watch(taskProvider);
    final subjects = ref.watch(subjectProvider);

    final dayTasks =
        allTasks.where((t) => _isSameDay(t.dueDate, _selectedDate)).toList();

    final scheduled = dayTasks.where((t) => t.scheduledTime != null).toList()
      ..sort((a, b) => a.scheduledTime!.compareTo(b.scheduledTime!));
    final unscheduled = dayTasks.where((t) => t.scheduledTime == null).toList();

    final now = DateTime.now();
    final isTodaySelected = _isSameDay(_selectedDate, now);

    return Scaffold(
      appBar: AppBar(
        title: Text('Görevler', style: AppTextStyles.heading2),
        actions: [
          if (!isTodaySelected)
            TextButton(
              onPressed: _jumpToToday,
              child: Text('Bugün',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  )),
            ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 4),
          _WeekNavRow(weekAnchor: _weekAnchor, onShift: _shiftWeek),
          const SizedBox(height: 4),
          _DaySelectorStrip(
            weekAnchor: _weekAnchor,
            selectedDate: _selectedDate,
            onDaySelected: _selectDay,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: dayTasks.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: EmptyStateCard(
                        icon: Icons.event_available,
                        message: isTodaySelected
                            ? 'Bu gün için görev yok.\nSağ alttaki + ile ekleyebilirsin.'
                            : 'Bu gün için görev yok.',
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
                        const SectionHeader(title: 'Saatsiz Görevler'),
                        const SizedBox(height: 12),
                        ...unscheduled.map(
                          (task) => TaskTile(task: task, subjects: subjects),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: GradientFab(
        tooltip: 'Görev ekle',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AddTaskScreen(),
            ),
          );
        },
      ),
    );
  }
}

// Hafta değiştirme şeridi — ‹ hafta aralığı › — _DaySelectorStrip'in
// üstünde. Görüntülenen 7 günü değiştirir, seçili günü değiştirmez
// (kullanıcı yeni haftada bir güne dokununca seçim güncellenir).
class _WeekNavRow extends StatelessWidget {
  final DateTime weekAnchor;
  final ValueChanged<int> onShift;

  const _WeekNavRow({required this.weekAnchor, required this.onShift});

  static const _months = [
    'Oca',
    'Şub',
    'Mar',
    'Nis',
    'May',
    'Haz',
    'Tem',
    'Ağu',
    'Eyl',
    'Eki',
    'Kas',
    'Ara',
  ];

  @override
  Widget build(BuildContext context) {
    final sunday = weekAnchor.add(const Duration(days: 6));
    final sameMonth = weekAnchor.month == sunday.month;
    final label = sameMonth
        ? '${weekAnchor.day}–${sunday.day} ${_months[weekAnchor.month - 1]}'
        : '${weekAnchor.day} ${_months[weekAnchor.month - 1]} – '
            '${sunday.day} ${_months[sunday.month - 1]}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TapScale(
            onTap: () => onShift(-7),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Icon(Icons.chevron_left, color: AppColors.textSecondary),
            ),
          ),
          Text(label, style: AppTextStyles.bodySecondary),
          TapScale(
            onTap: () => onShift(7),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

// Üstteki gün seçici şerit — WeekStrip'ten farklı olarak tıklayınca
// başka ekrana gitmiyor, bu ekranın içeriğini yerinde değiştiriyor.
// Hangi haftanın gösterileceğini artık kendisi değil, ebeveyni
// (_WeekNavRow ile birlikte kayan `weekAnchor`) belirliyor.
class _DaySelectorStrip extends StatelessWidget {
  final DateTime weekAnchor;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDaySelected;

  const _DaySelectorStrip({
    required this.weekAnchor,
    required this.selectedDate,
    required this.onDaySelected,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dayLabels = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

    return SizedBox(
      height: 72,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(7, (index) {
          final day = DateTime(
              weekAnchor.year, weekAnchor.month, weekAnchor.day + index);
          final isSelected = _isSame(day, selectedDate);
          final isToday = _isSame(day, today);

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
                      // Seçili gün = marka violeti (uygulama genelinde
                      // "seçili/aktif" için tek renk — filtre pilleri, nav,
                      // rütbe rozeti ile aynı dil); "bugün ama seçili değil"
                      // durumu ince bir violet kenarlıkla ayrı işaretlenir.
                      color: isSelected ? AppColors.primary : null,
                      shape: BoxShape.circle,
                      border: (!isSelected && isToday)
                          ? Border.all(color: AppColors.primary, width: 1.4)
                          : null,
                      boxShadow: isSelected
                          ? [AppColors.glow(AppColors.primary)]
                          : null,
                    ),
                    child: Text(
                      '${day.day}',
                      style: AppTextStyles.body.copyWith(
                        color: isSelected
                            ? AppColors.onColor(AppColors.primary)
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
// noktası/çizgisi + rengi dersine bağlı görev kartı. Home'daki TaskTile
// ile aynı jestleri (tamamla, kaydırarak ertele/sil, uzun basınca
// düzenle/sil) TaskSwipeActions üzerinden paylaşır — yalnız görsel
// gövde (zaman çizelgesi düzeni) farklı.
class _TimelineRow extends ConsumerWidget {
  final TaskModel task;
  final SubjectModel? subject;
  final bool isLast;

  const _TimelineRow({
    required this.task,
    required this.subject,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
    final dotColor =
        overdue ? AppColors.warning : (inProgress ? AppColors.primary : color);

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
                      color: color.withValues(alpha: 0.25),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: TaskSwipeActions(
                task: task,
                margin: EdgeInsets.zero,
                borderRadius: BorderRadius.circular(16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(17, 14, 14, 14),
                        decoration: BoxDecoration(
                          color: AppColors.tonal(color),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TapScale(
                                  onTap: () => ref
                                      .read(taskProvider.notifier)
                                      .toggleTaskCompletion(task.id, ref),
                                  child: Container(
                                    width: 26,
                                    height: 26,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: task.isCompleted
                                          ? AppColors.tonal(
                                              AppColors.success)
                                          : Colors.transparent,
                                      border: task.isCompleted
                                          ? null
                                          : Border.all(
                                              color: AppColors.textSecondary
                                                  .withValues(alpha: 0.5),
                                              width: 1.4,
                                            ),
                                    ),
                                    child: task.isCompleted
                                        ? Icon(
                                            Icons.check_rounded,
                                            size: 16,
                                            color: AppColors.success,
                                          )
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TapScale(
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            AddTaskScreen(taskToEdit: task),
                                      ),
                                    ),
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
                                ),
                              ],
                            ),
                            if (subject != null) ...[
                              const SizedBox(height: 4),
                              Padding(
                                padding: const EdgeInsets.only(left: 30),
                                child: Text(
                                  subject!.name,
                                  style: AppTextStyles.caption.copyWith(
                                    color: color,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.only(left: 30),
                              child: Row(
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
                                          : (inProgress
                                              ? AppColors.primary
                                              : null),
                                      fontWeight: (overdue || inProgress)
                                          ? FontWeight.w700
                                          : null,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Öncelik çizgisi — Todoist usulü, ders rengiyle
                      // (arka plan dolgusu) karışmasın diye ayrı bir sinyal.
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: 3,
                          color: _priorityColor(task.priority),
                        ),
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
}
