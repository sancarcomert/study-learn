import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';
import 'subject_ai.dart';
import 'subject_provider.dart';
import 'task_model.dart';
import 'task_provider.dart';


class AddTaskScreen extends ConsumerStatefulWidget {
  final TaskModel? taskToEdit;

  const AddTaskScreen({
    super.key,
    this.taskToEdit,
  });

  @override
  ConsumerState<AddTaskScreen> createState() =>
      _AddTaskScreenState();
}


class _AddTaskScreenState extends ConsumerState<AddTaskScreen> {

  final TextEditingController _titleController =
      TextEditingController();


  String? _selectedSubjectId;
  String? _suggestedSubject;


  DateTime _selectedDate = DateTime.now();

  TaskPriority _selectedPriority =
      TaskPriority.medium;


  TimeOfDay? _selectedTime;

  int _selectedDuration = 30;

  TopicDifficulty _selectedDifficulty = TopicDifficulty.medium;

  // 'none' / 'daily' / 'weekly' — sadece yeni görev eklerken kullanılır,
  // düzenleme modunda hiç gösterilmez (V1: seri yönetimi kapsam dışı).
  String _recurrence = 'none';

  static const List<int> _durationOptions = [15, 30, 45, 60, 90];


  bool get _isEditing =>
      widget.taskToEdit != null;


  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }


  @override
  void initState() {
    super.initState();


    if (_isEditing) {

      final task = widget.taskToEdit!;


      _titleController.text =
          task.title;

      _selectedSubjectId =
          task.subjectId;

      _selectedDate =
          task.dueDate;

      _selectedPriority =
          task.priority;


      _selectedDuration =
          task.estimatedMinutes ?? 30;

      _selectedDifficulty = task.difficulty;


      if (task.scheduledTime != null) {

        _selectedTime =
            TimeOfDay.fromDateTime(
              task.scheduledTime!,
            );

      }

      _detailsExpanded = task.scheduledTime != null ||
          !_isSameDay(task.dueDate, DateTime.now()) ||
          task.priority != TaskPriority.medium ||
          task.difficulty != TopicDifficulty.medium ||
          (task.estimatedMinutes != null && task.estimatedMinutes != 30);

    }



    _titleController.addListener(() {

      final result =
          SubjectAI.predict(
            _titleController.text,
          );


      if (result != _suggestedSubject) {

        setState(() {

          _suggestedSubject = result;

        });

      }

    });

  }


  bool _detailsExpanded = false;


  @override
  void dispose() {

    _titleController.dispose();

    super.dispose();

  }


  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );

    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }


  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }


  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final target = DateTime(date.year, date.month, date.day);

    if (target == today) {
      return "Bugün";
    }

    if (target == tomorrow) {
      return "Yarın";
    }

    const months = [
      "Oca", "Şub", "Mar", "Nis", "May", "Haz",
      "Tem", "Ağu", "Eyl", "Eki", "Kas", "Ara",
    ];

    return "${date.day} ${months[date.month - 1]} ${date.year}";
  }


  String _weekdayName(DateTime date) {
    const names = [
      "Pazartesi", "Salı", "Çarşamba", "Perşembe",
      "Cuma", "Cumartesi", "Pazar",
    ];
    return names[date.weekday - 1];
  }


  String _priorityLabel(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return "Düşük";
      case TaskPriority.medium:
        return "Orta";
      case TaskPriority.high:
        return "Yüksek";
    }
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


  String _difficultyLabel(TopicDifficulty difficulty) {
    switch (difficulty) {
      case TopicDifficulty.easy:
        return "Kolay";
      case TopicDifficulty.medium:
        return "Orta";
      case TopicDifficulty.hard:
        return "Zor";
    }
  }


  Color _difficultyColor(TopicDifficulty difficulty) {
    switch (difficulty) {
      case TopicDifficulty.easy:
        return AppColors.success;
      case TopicDifficulty.medium:
        return AppColors.priorityMedium;
      case TopicDifficulty.hard:
        return AppColors.danger;
    }
  }




  void _submit() {


    final title =
        _titleController.text.trim();


    if (title.isEmpty) {

      ScaffoldMessenger.of(context)
          .showSnackBar(

        const SnackBar(
          content:
              Text(
                "Görev adı boş olamaz",
              ),
        ),

      );

      return;

    }



    final scheduledTime =
        _selectedTime == null
            ? null
            : DateTime(
                _selectedDate.year,
                _selectedDate.month,
                _selectedDate.day,
                _selectedTime!.hour,
                _selectedTime!.minute,
              );



    if (_isEditing) {


      ref
          .read(taskProvider.notifier)
          .updateTask(

            widget.taskToEdit!,

            title: title,

            subjectId:
                _selectedSubjectId,

            dueDate:
                _selectedDate,

            priority:
                _selectedPriority,

            scheduledTime:
                scheduledTime,

            estimatedMinutes:
                _selectedDuration,

            difficulty:
                _selectedDifficulty,

          );


    } else if (_recurrence != 'none') {

      ref.read(taskProvider.notifier).addRecurringTask(
            title: title,
            subjectId: _selectedSubjectId,
            startDate: _selectedDate,
            recurrenceRule: _recurrence,
            priority: _selectedPriority,
            difficulty: _selectedDifficulty,
            scheduledTimeOfDay: _selectedTime,
            estimatedMinutes: _selectedDuration,
          );

    } else {


      ref
          .read(taskProvider.notifier)
          .addTask(

            title: title,

            subjectId:
                _selectedSubjectId,

            dueDate:
                _selectedDate,

            priority:
                _selectedPriority,

            scheduledTime:
                scheduledTime,

            estimatedMinutes:
                _selectedDuration,

            difficulty:
                _selectedDifficulty,

          );

    }


    Navigator.pop(context);

  }
  @override
Widget build(BuildContext context) {

  final subjects = ref.watch(subjectProvider);


  return Scaffold(

    appBar: AppBar(
      title: Text(
        _isEditing
            ? "Görevi Düzenle"
            : "Yeni Görev",
        style: AppTextStyles.heading2,
      ),
    ),


    body: Padding(
      padding: const EdgeInsets.all(20),

      child: Column(

        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [

          Expanded(
            child: ListView(
              children: [

                TextField(

                  controller:
                      _titleController,

                  decoration:
                      const InputDecoration(

                    hintText:
                        "Örn: Türev konusu çöz",

                  ),

                ),



                if (_suggestedSubject != null) ...[

                  const SizedBox(height: 12),


                  Container(

                    padding:
                        const EdgeInsets.all(12),

                    decoration:
                        BoxDecoration(

                      color:
                          AppColors.primary
                              .withOpacity(0.1),

                      borderRadius:
                          BorderRadius.circular(12),

                    ),


                    child: Row(

                      children: [

                        const Icon(
                          Icons.auto_awesome,
                          color: AppColors.primary,
                        ),


                        const SizedBox(width: 8),


                        Text(
                          "Önerilen ders: $_suggestedSubject",
                          style:
                              AppTextStyles.body,
                        ),

                      ],

                    ),

                  ),

                ],



                const SizedBox(height: 20),



                Text(
                  "Ders",
                  style:
                      AppTextStyles.bodySecondary,
                ),



                const SizedBox(height: 10),



                Wrap(

                  spacing: 8,

                  children: [

                    _SubjectChip(

                      label:
                          "Derssiz",

                      color:
                          AppColors.textSecondary,

                      isSelected:
                          _selectedSubjectId == null,

                      onTap: () {

                        setState(() {

                          _selectedSubjectId =
                              null;

                        });

                      },

                    ),



                    ...subjects.map(

                      (subject) => _SubjectChip(

                        label:
                            subject.name,

                        color:
                            Color(
                              subject.colorValue,
                            ),

                        isSelected:
                            _selectedSubjectId ==
                                subject.id,


                        onTap: () {

                          setState(() {

                            _selectedSubjectId =
                                subject.id;

                          });

                        },

                      ),

                    ),

                  ],

                ),


                const SizedBox(height: 20),

                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    setState(() {
                      _detailsExpanded = !_detailsExpanded;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        AnimatedRotation(
                          turns: _detailsExpanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOut,
                          child: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _detailsExpanded
                              ? "Detayları Gizle"
                              : "Detayları Ekle",
                          style: AppTextStyles.bodySecondary.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  alignment: Alignment.topCenter,
                  child: !_detailsExpanded
                      ? const SizedBox(width: double.infinity)
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [

                            const SizedBox(height: 16),

                            const _SectionHeader(title: "Planlama"),

                            const SizedBox(height: 16),


                            Text(
                              "Tarih",
                              style: AppTextStyles.bodySecondary,
                            ),

                            const SizedBox(height: 10),

                            GestureDetector(
                              onTap: _pickDate,

                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),

                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(14),
                                ),

                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.calendar_today_rounded,
                                      size: 16,
                                      color: AppColors.primary,
                                    ),

                                    const SizedBox(width: 8),

                                    Text(
                                      _formatDate(_selectedDate),
                                      style: AppTextStyles.body.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),


                            const SizedBox(height: 24),


                            Text(
                              "Saat (opsiyonel)",
                              style: AppTextStyles.bodySecondary,
                            ),

                            const SizedBox(height: 10),

                            GestureDetector(
                              onTap: _pickTime,

                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),

                                decoration: BoxDecoration(
                                  color: _selectedTime != null
                                      ? AppColors.primary.withOpacity(0.12)
                                      : AppColors.primary.withOpacity(0.06),

                                  borderRadius: BorderRadius.circular(14),
                                ),

                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.schedule_rounded,
                                      size: 18,
                                      color: AppColors.primary,
                                    ),

                                    const SizedBox(width: 8),

                                    Text(
                                      _selectedTime == null
                                          ? "Saat seç"
                                          : _selectedTime!.format(context),
                                      style: AppTextStyles.body.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),

                                    if (_selectedTime != null) ...[
                                      const SizedBox(width: 8),
                                      GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _selectedTime = null;
                                          });
                                        },
                                        child: Icon(
                                          Icons.close_rounded,
                                          size: 16,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),


                            const SizedBox(height: 24),


                            Text(
                              "Süre",
                              style: AppTextStyles.bodySecondary,
                            ),

                            const SizedBox(height: 10),

                            Wrap(
                              spacing: 8,
                              children: _durationOptions.map((minutes) {
                                final isSelected = _selectedDuration == minutes;

                                return _SubjectChip(
                                  label: "$minutes dk",
                                  color: AppColors.primary,
                                  isSelected: isSelected,
                                  onTap: () {
                                    setState(() {
                                      _selectedDuration = minutes;
                                    });
                                  },
                                );
                              }).toList(),
                            ),


                            const SizedBox(height: 24),


                            Text(
                              "Öncelik",
                              style: AppTextStyles.bodySecondary,
                            ),

                            const SizedBox(height: 10),

                            Wrap(
                              spacing: 8,
                              children: TaskPriority.values.map((priority) {
                                final isSelected = _selectedPriority == priority;

                                return _SubjectChip(
                                  label: _priorityLabel(priority),
                                  color: _priorityColor(priority),
                                  isSelected: isSelected,
                                  onTap: () {
                                    setState(() {
                                      _selectedPriority = priority;
                                    });
                                  },
                                );
                              }).toList(),
                            ),


                            const SizedBox(height: 24),


                            Text(
                              "Zorluk",
                              style: AppTextStyles.bodySecondary,
                            ),

                            const SizedBox(height: 10),

                            Wrap(
                              spacing: 8,
                              children: TopicDifficulty.values.map((difficulty) {
                                final isSelected = _selectedDifficulty == difficulty;

                                return _SubjectChip(
                                  label: _difficultyLabel(difficulty),
                                  color: _difficultyColor(difficulty),
                                  isSelected: isSelected,
                                  onTap: () {
                                    setState(() {
                                      _selectedDifficulty = difficulty;
                                    });
                                  },
                                );
                              }).toList(),
                            ),

                            // Tekrar seçimi — sadece yeni görev eklerken
                            // gösterilir, düzenleme modunda hiç görünmez.
                            if (!_isEditing) ...[
                              const SizedBox(height: 24),

                              Text(
                                "Tekrar",
                                style: AppTextStyles.bodySecondary,
                              ),

                              const SizedBox(height: 10),

                              Wrap(
                                spacing: 8,
                                children: [
                                  _SubjectChip(
                                    label: "Tek seferlik",
                                    color: AppColors.textSecondary,
                                    isSelected: _recurrence == 'none',
                                    onTap: () {
                                      setState(() {
                                        _recurrence = 'none';
                                      });
                                    },
                                  ),
                                  _SubjectChip(
                                    label: "Her gün",
                                    color: AppColors.primary,
                                    isSelected: _recurrence == 'daily',
                                    onTap: () {
                                      setState(() {
                                        _recurrence = 'daily';
                                      });
                                    },
                                  ),
                                  _SubjectChip(
                                    label: "Her ${_weekdayName(_selectedDate)}",
                                    color: AppColors.primary,
                                    isSelected: _recurrence == 'weekly',
                                    onTap: () {
                                      setState(() {
                                        _recurrence = 'weekly';
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ],

                            const SizedBox(height: 4),
                          ],
                        ),
                ),

                const SizedBox(height: 20),

              ],
            ),
          ),


          const SizedBox(height: 12),


          SizedBox(

            width:
                double.infinity,


            child:
                ElevatedButton(

              onPressed:
                  _submit,


              child:
                  Text(

                _isEditing
                    ? "Kaydet"
                    : "Görevi Ekle",

              ),

            ),

          ),


        ],

      ),

    ),

  );

}

} // build kapanışı

 // _AddTaskScreenState kapanışı


class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: AppTextStyles.heading3,
        ),

        const SizedBox(width: 12),

        Expanded(
          child: Container(
            height: 1,
            color: AppColors.textSecondary.withOpacity(0.15),
          ),
        ),
      ],
    );
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

        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 8,
        ),

        decoration: BoxDecoration(
          color: isSelected
              ? color
              : color.withOpacity(0.15),

          borderRadius:
              BorderRadius.circular(20),
        ),

        child: Text(
          label,

          style: TextStyle(
            color: isSelected
                ? Colors.white
                : color,

            fontWeight:
                FontWeight.w600,
          ),

        ),

      ),

    );

  }
}