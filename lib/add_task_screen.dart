import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';
import 'subject_provider.dart';
import 'task_provider.dart';
import 'task_model.dart';

class AddTaskScreen extends ConsumerStatefulWidget {
  final TaskModel? taskToEdit;
  const AddTaskScreen({super.key, this.taskToEdit});

  @override
  ConsumerState<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends ConsumerState<AddTaskScreen> {
  final _titleController = TextEditingController();
  String? _selectedSubjectId;
  DateTime _selectedDate = DateTime.now();
  TaskPriority _selectedPriority = TaskPriority.medium;
TimeOfDay? _selectedTime;
int _selectedDuration = 30;
  bool get _isEditing => widget.taskToEdit != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final task = widget.taskToEdit!;
      _titleController.text = task.title;
      _selectedSubjectId = task.subjectId;
      _selectedDate = task.dueDate;
      _selectedPriority = task.priority;
      _selectedTime = task.scheduledTime != null
    ? TimeOfDay.fromDateTime(task.scheduledTime!)
    : null;

_selectedDuration = task.estimatedMinutes ?? 30;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Görev başlığı boş olamaz')),
      );
      return;
    }
    if (title.length > 80) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Başlık çok uzun (max 80 karakter)')),
      );
      return;
    }

    if (_isEditing) {
   ref.read(taskProvider.notifier).updateTask(
  widget.taskToEdit!,
  title: title,
  subjectId: _selectedSubjectId,
  dueDate: _selectedDate,
  priority: _selectedPriority,
  scheduledTime: _selectedTime == null
      ? null
      : DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          _selectedTime!.hour,
          _selectedTime!.minute,
        ),
  estimatedMinutes: _selectedDuration,
);
    } else {
    ref.read(taskProvider.notifier).addTask(
  title: title,
  subjectId: _selectedSubjectId,
  dueDate: _selectedDate,
  priority: _selectedPriority,
  scheduledTime: _selectedTime == null
      ? null
      : DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          _selectedTime!.hour,
          _selectedTime!.minute,
        ),
  estimatedMinutes: _selectedDuration,
);
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final subjects = ref.watch(subjectProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Görevi Düzenle' : 'Yeni Görev', style: AppTextStyles.heading2),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Görev başlığı, örn. Türev konusu çöz'),
            ),
            Text('Saat (opsiyonel)', style: AppTextStyles.bodySecondary),
const SizedBox(height: 10),

GestureDetector(
  onTap: () async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );

    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  },
  child: Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.access_time_rounded,
          size: 18,
          color: AppColors.primary,
        ),
        const SizedBox(width: 10),
        Text(
          _selectedTime == null
              ? 'Saat seç'
              : _selectedTime!.format(context),
          style: AppTextStyles.body,
        ),
      ],
    ),
  ),
),

const SizedBox(height: 24),

Text('Tahmini Süre', style: AppTextStyles.bodySecondary),
const SizedBox(height: 10),

Wrap(
  spacing: 8,
  children: [30, 45, 60, 120].map((minutes) {
    final selected = _selectedDuration == minutes;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDuration = minutes;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : AppColors.background,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          minutes >= 60
              ? '${minutes ~/ 60} saat'
              : '$minutes dk',
          style: AppTextStyles.body.copyWith(
            color: selected
                ? Colors.white
                : AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }).toList(),
),

const SizedBox(height: 24),
            const SizedBox(height: 24),
            Text('Ders (opsiyonel)', style: AppTextStyles.bodySecondary),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _SubjectChip(
                  label: 'Dersiz',
                  color: AppColors.textSecondary,
                  isSelected: _selectedSubjectId == null,
                  onTap: () => setState(() => _selectedSubjectId = null),
                ),
                ...subjects.map((subject) => _SubjectChip(
                      label: subject.name,
                      color: Color(subject.colorValue),
                      isSelected: _selectedSubjectId == subject.id,
                      onTap: () => setState(() => _selectedSubjectId = subject.id),
                    )),
              ],
            ),
            const SizedBox(height: 24),
            Text('Tarih', style: AppTextStyles.bodySecondary),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Text(
                      DateFormat('dd MMMM yyyy', 'tr_TR').format(_selectedDate),
                      style: AppTextStyles.body,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('Öncelik', style: AppTextStyles.bodySecondary),
            const SizedBox(height: 10),
            Row(
              children: TaskPriority.values.map((priority) {
                final isSelected = _selectedPriority == priority;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedPriority = priority),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? _priorityColor(priority) : AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _priorityLabel(priority),
                        style: AppTextStyles.body.copyWith(
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submit,
                child: Text(_isEditing ? 'Değişiklikleri Kaydet' : 'Görevi Kaydet'),
              ),
            ),
          ],
        ),
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

  String _priorityLabel(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return 'Düşük';
      case TaskPriority.medium:
        return 'Orta';
      case TaskPriority.high:
        return 'Yüksek';
    }
  }
}

class _SubjectChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _SubjectChip({
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: AppTextStyles.bodySecondary.copyWith(
            color: isSelected ? Colors.white : color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}