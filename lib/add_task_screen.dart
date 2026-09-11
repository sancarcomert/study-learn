import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';
import 'subject_ai.dart';
import 'subject_provider.dart';
import 'tap_scale.dart';
import 'task_model.dart';
import 'task_provider.dart';
import 'widgets/app_buttons.dart';
import 'widgets/app_snackbar.dart';
import 'widgets/eyebrow.dart';


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

  // Opsiyonel — null = süre belirtilmedi. Eskiden 30 dk zorla yazılıyordu,
  // her göreve sessizce süre ekliyordu (amatör). Artık kullanıcı seçmezse yok.
  int? _selectedDuration;

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


      _selectedDuration = task.estimatedMinutes;


      if (task.scheduledTime != null) {

        _selectedTime =
            TimeOfDay.fromDateTime(
              task.scheduledTime!,
            );

      }

      _detailsExpanded = task.scheduledTime != null ||
          !_isSameDay(task.dueDate, DateTime.now()) ||
          task.priority != TaskPriority.medium ||
          task.estimatedMinutes != null;

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
      builder: _pickerTheme,
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
      builder: _pickerTheme,
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  // Native tarih/saat picker'ının seçim vurgusu, ColorScheme.fromSeed'in
  // algoritmik türettiği tondan değil, gerçek marka altınından gelsin.
  Widget _pickerTheme(BuildContext context, Widget? child) {
    final base = Theme.of(context);
    return Theme(
      data: base.copyWith(
        colorScheme: base.colorScheme.copyWith(
          primary: AppColors.primary,
          onPrimary: AppColors.ink,
        ),
      ),
      child: child!,
    );
  }

  static const List<TimeOfDay> _quickTimes = [
    TimeOfDay(hour: 14, minute: 0),
    TimeOfDay(hour: 16, minute: 0),
    TimeOfDay(hour: 19, minute: 0),
    TimeOfDay(hour: 21, minute: 0),
  ];

  bool get _isDateToday => _isSameDay(_selectedDate, DateTime.now());

  bool get _isDateTomorrow => _isSameDay(
      _selectedDate, DateTime.now().add(const Duration(days: 1)));

  bool get _isCustomDate => !_isDateToday && !_isDateTomorrow;

  bool get _isCustomTime =>
      _selectedTime != null && !_quickTimes.contains(_selectedTime);


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


  void _submit() {


    final title =
        _titleController.text.trim();


    if (title.isEmpty) {

      AppSnackBar.error(context, "Görev adı boş olamaz");

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

          );


    } else if (_recurrence != 'none') {

      ref.read(taskProvider.notifier).addRecurringTask(
            title: title,
            subjectId: _selectedSubjectId,
            startDate: _selectedDate,
            recurrenceRule: _recurrence,
            priority: _selectedPriority,
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
                              .withValues(alpha: 0.1),

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



                // Aşağıdaki "Planlama" kartıyla aynı dil — DERS/TEKRAR daha
                // önce çıplak sayfaya dökülüyordu, tutarsız duruyordu.
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.surfaceVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Eyebrow(text: "DERS"),

                      const SizedBox(height: 10),

                      Wrap(
                        spacing: 8,
                        children: [
                          _SubjectChip(
                            label: "Derssiz",
                            color: AppColors.textSecondary,
                            isSelected: _selectedSubjectId == null,
                            onTap: () {
                              setState(() {
                                _selectedSubjectId = null;
                              });
                            },
                          ),
                          ...subjects.map(
                            (subject) => _SubjectChip(
                              label: subject.name,
                              color: Color(subject.colorValue),
                              isSelected: _selectedSubjectId == subject.id,
                              onTap: () {
                                setState(() {
                                  _selectedSubjectId = subject.id;
                                });
                              },
                            ),
                          ),
                        ],
                      ),

                      // Tekrar seçimi ders seçiminin hemen altında her
                      // zaman görünür — geri dönüşü olmayan bir karar
                      // (birden fazla görev oluşturuyor), gözden
                      // kaçmaması gerekiyor.
                      if (!_isEditing) ...[
                        const SizedBox(height: 20),
                        const Divider(
                          height: 1,
                          color: AppColors.surfaceVariant,
                        ),
                        const SizedBox(height: 20),

                        const Eyebrow(text: "TEKRAR"),

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
                              color: AppColors.secondary,
                              isSelected: _recurrence == 'daily',
                              onTap: () {
                                setState(() {
                                  _recurrence = 'daily';
                                });
                              },
                            ),
                            _SubjectChip(
                              label: "Her ${_weekdayName(_selectedDate)}",
                              color: AppColors.secondary,
                              isSelected: _recurrence == 'weekly',
                              onTap: () {
                                setState(() {
                                  _recurrence = 'weekly';
                                });
                              },
                            ),
                          ],
                        ),

                        if (_recurrence != 'none') ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.tonal(AppColors.warning),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.info_outline,
                                  size: 16,
                                  color: AppColors.warning,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _recurrence == 'weekly'
                                        ? "Bu, önümüzdeki 12 hafta için ayrı ayrı görev oluşturur. Seriyi daha sonra topluca silebilirsin."
                                        : "Bu, önümüzdeki 30 gün için ayrı ayrı görev oluşturur. Seriyi daha sonra topluca silebilirsin.",
                                    style: AppTextStyles.caption,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                TapScale(
                  onTap: () {
                    setState(() {
                      _detailsExpanded = !_detailsExpanded;
                    });
                  },
                  // Önceden çıplak bir metin satırıydı — iki kart arasında
                  // asılı kalıyordu. Artık kendi hafif kabuğu var, "Planlama"
                  // kartının kapısı gibi okunuyor.
                  child: Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppColors.tonal(AppColors.primary),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _detailsExpanded
                              ? "Detayları Gizle"
                              : "Detayları Ekle",
                          style: AppTextStyles.bodySecondary.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 4),
                        AnimatedRotation(
                          turns: _detailsExpanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOut,
                          child: const Icon(
                            Icons.keyboard_arrow_down,
                            color: AppColors.primary,
                            size: 20,
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

                            // Rakip analizinde (rabbit, Ders Takip AI —
                            // docs/rakip_analizi_ve_yon_2026-09.md) ortak
                            // desen: zamanlama kontrolleri çıplak sayfaya
                            // değil, sınırları belli TEK bir kart içine
                            // gruplanıyor. Öncesinde burada dört ayrı çip
                            // satırı sayfaya doğrudan dökülüyordu —
                            // NextTaskCard/_RankStrip'teki kart dilini
                            // buraya da taşıdık.
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppColors.surfaceVariant,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Eyebrow(text: "TARİH"),

                                  const SizedBox(height: 10),

                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _SubjectChip(
                                        label: "Bugün",
                                        color: AppColors.secondary,
                                        icon: Icons.calendar_today_outlined,
                                        isSelected: _isDateToday,
                                        onTap: () => setState(() {
                                          _selectedDate = DateTime.now();
                                        }),
                                      ),
                                      _SubjectChip(
                                        label: "Yarın",
                                        color: AppColors.secondary,
                                        icon: Icons.calendar_today_outlined,
                                        isSelected: _isDateTomorrow,
                                        onTap: () => setState(() {
                                          _selectedDate = DateTime.now()
                                              .add(const Duration(days: 1));
                                        }),
                                      ),
                                      _SubjectChip(
                                        label: _isCustomDate
                                            ? _formatDate(_selectedDate)
                                            : "Özel",
                                        color: AppColors.secondary,
                                        icon: Icons.calendar_today_outlined,
                                        isSelected: _isCustomDate,
                                        onTap: _pickDate,
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 20),
                                  const Divider(
                                    height: 1,
                                    color: AppColors.surfaceVariant,
                                  ),
                                  const SizedBox(height: 20),

                                  const Eyebrow(text: "SAAT (OPSİYONEL)"),

                                  const SizedBox(height: 10),

                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _SubjectChip(
                                        label: "Belirtme",
                                        color: AppColors.textSecondary,
                                        icon: Icons.notifications_off_outlined,
                                        isSelected: _selectedTime == null,
                                        onTap: () => setState(() {
                                          _selectedTime = null;
                                        }),
                                      ),
                                      for (final t in _quickTimes)
                                        _SubjectChip(
                                          label: t.format(context),
                                          color: AppColors.secondary,
                                          icon: Icons.schedule_outlined,
                                          isSelected: _selectedTime == t,
                                          onTap: () => setState(() {
                                            _selectedTime = t;
                                          }),
                                        ),
                                      _SubjectChip(
                                        label: _isCustomTime
                                            ? _selectedTime!.format(context)
                                            : "Özel",
                                        color: AppColors.secondary,
                                        icon: Icons.schedule_outlined,
                                        isSelected: _isCustomTime,
                                        onTap: _pickTime,
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 20),
                                  const Divider(
                                    height: 1,
                                    color: AppColors.surfaceVariant,
                                  ),
                                  const SizedBox(height: 20),

                                  const Eyebrow(text: "SÜRE (OPSİYONEL)"),

                                  const SizedBox(height: 10),

                                  Wrap(
                                    spacing: 8,
                                    children: _durationOptions.map((minutes) {
                                      final isSelected =
                                          _selectedDuration == minutes;

                                      return _SubjectChip(
                                        label: "$minutes dk",
                                        // CTA hiyerarşisi (CLAUDE.md): altın
                                        // yalnız birincil pozitif aksiyon
                                        // (Görevi Ekle) için — burada da
                                        // kullanılması "her yer altın"
                                        // izlenimi veriyordu.
                                        color: AppColors.secondary,
                                        icon: Icons.timer_outlined,
                                        isSelected: isSelected,
                                        // Seçili çipe tekrar dokun → süreyi
                                        // kaldır.
                                        onTap: () {
                                          setState(() {
                                            _selectedDuration = isSelected
                                                ? null
                                                : minutes;
                                          });
                                        },
                                      );
                                    }).toList(),
                                  ),

                                  const SizedBox(height: 20),
                                  const Divider(
                                    height: 1,
                                    color: AppColors.surfaceVariant,
                                  ),
                                  const SizedBox(height: 20),

                                  const Eyebrow(text: "ÖNCELİK"),

                                  const SizedBox(height: 10),

                                  Wrap(
                                    spacing: 8,
                                    children:
                                        TaskPriority.values.map((priority) {
                                      final isSelected =
                                          _selectedPriority == priority;

                                      return _SubjectChip(
                                        label: _priorityLabel(priority),
                                        color: _priorityColor(priority),
                                        icon: Icons.flag_outlined,
                                        isSelected: isSelected,
                                        onTap: () {
                                          setState(() {
                                            _selectedPriority = priority;
                                          });
                                        },
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                ),

                const SizedBox(height: 20),

              ],
            ),
          ),


          const SizedBox(height: 12),


          PrimaryButton(
            label: _isEditing ? "Kaydet" : "Görevi Ekle",
            onPressed: _submit,
          ),


        ],

      ),

    ),

  );

}

} // build kapanışı

 // _AddTaskScreenState kapanışı


class _SubjectChip extends StatelessWidget {

  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;
  // Todoist'in rozet deseni (docs/rakip_analizi_ve_yon_2026-09.md) — her
  // kategori (tarih/saat/süre/öncelik) kendi ikonunu taşır, salt metin
  // yerine. DERS/TEKRAR çipleri kendi rengiyle zaten ayrışıyor, ikonsuz.
  final IconData? icon;

  const _SubjectChip({
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
    this.icon,
  });


  @override
  Widget build(BuildContext context) {
    // Seçili/rengi bağlı metin rengiyle aynı mantık (computeLuminance()
    // burada güvenilir değil — altın ile adaçayı yeşili gibi görsel olarak
    // çok farklı iki ton matematiksel olarak neredeyse aynı parlaklığa
    // denk geliyor). Tek gerçek risk olan altını (primary) doğrudan
    // hedefliyoruz: o zeminde koyu metin, diğer her yerde beyaz.
    final fgColor = isSelected
        ? (color == AppColors.primary ? AppColors.ink : Colors.white)
        : color;

    return TapScale(
      // Daha önce çıplak GestureDetector'dı — dokunuşta ne hafif küçülme
      // ne haptik vardı, seçim "oturmuyor" hissi veriyordu. Artık
      // uygulamanın her yerindeki dokunma dili (TapScale, 0.96/100ms +
      // hafif titreşim) burada da geçerli.
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? null
              : Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              Icon(Icons.check, size: 15, color: fgColor),
              const SizedBox(width: 5),
            ] else if (icon != null) ...[
              Icon(icon, size: 15, color: fgColor),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(color: fgColor, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}