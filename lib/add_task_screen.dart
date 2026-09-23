import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';
import 'subject_ai.dart';
import 'subject_provider.dart';
import 'stats_provider.dart';
import 'tap_scale.dart';
import 'task_model.dart';
import 'task_provider.dart';
import 'task_time_options.dart';
import 'topic_model.dart';
import 'topic_provider.dart';
import 'widgets/app_buttons.dart';
import 'widgets/app_snackbar.dart';
import 'widgets/eyebrow.dart';

/// Görev ekle / düzenle.
///
/// Bilgi mimarisi ilkesi: uygulamanın ZATEN bildiği bir şey öğrenciye ikinci
/// kez yazdırılmaz. Konu seçildiyse görev adı konudur; "ne zaman" gerçek saate
/// göre önerilir ve ana kartta durur (bir "Detaylar" katmanının arkasında
/// değil).
class AddTaskScreen extends ConsumerStatefulWidget {
  final TaskModel? taskToEdit;

  const AddTaskScreen({super.key, this.taskToEdit});

  @override
  ConsumerState<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends ConsumerState<AddTaskScreen> {
  final TextEditingController _titleController = TextEditingController();

  String? _selectedSubjectId;
  String? _suggestedSubject;

  // Konu Takip'e bağlı görev — seçiliyse görevin adı konudan gelir ve görev,
  // o konuya bir çalışma olayı olarak (tamamlanınca) bağlanır. Yalnız
  // [_selectedSubjectId]'nin konuları arasından seçilebilir.
  String? _selectedTopicId;

  // Başlık, seçilen konudan OTOMATİK dolduruldu mu? true iken konu/ders
  // değişince başlık da onunla güncellenir; öğrenci başlığa kendisi dokunduğu
  // an false olur ve bir daha ezilmez.
  bool _titleAutoFilled = false;

  // Ne zaman — yeni görevin varsayılanı "bugün daha sonra" (saatsiz).
  TaskWhen _when = TaskWhen.laterToday;

  TaskPriority _selectedPriority = TaskPriority.medium;

  // Opsiyonel — null = süre belirtilmedi.
  int? _selectedDuration;

  // 'none' / 'daily' / 'weekly' — yalnız yeni görevde (seri yönetimi V1 dışı).
  String _recurrence = 'none';

  bool _detailsExpanded = false;

  static const List<int> _durationOptions = [15, 30, 45, 60, 90];

  bool get _isEditing => widget.taskToEdit != null;

  @override
  void initState() {
    super.initState();

    if (_isEditing) {
      final task = widget.taskToEdit!;
      _titleController.text = task.title;
      _selectedSubjectId = task.subjectId;
      _selectedTopicId = task.topicId;
      _when = TaskWhen.fromExisting(
          task.dueDate, task.scheduledTime, DateTime.now());
      _selectedPriority = task.priority;
      _selectedDuration = task.estimatedMinutes;
      _detailsExpanded = task.priority != TaskPriority.medium ||
          task.estimatedMinutes != null;
    }

    _titleController.addListener(() {
      final result = SubjectAI.predict(_titleController.text);
      if (result != _suggestedSubject) {
        setState(() => _suggestedSubject = result);
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  // Konu seçimi/kaldırma — başlığı ("Bölünebilme") uygulamanın zaten bildiği
  // bilgiden türetir; öğrenci aynı şeyi ikinci kez yazmaz.
  void _selectTopic(TopicModel? topic) {
    setState(() {
      _selectedTopicId = topic?.id;
      final canOverwrite =
          _titleController.text.trim().isEmpty || _titleAutoFilled;
      if (topic != null && canOverwrite) {
        _titleController.text = topic.name;
        _titleAutoFilled = true;
      } else if (topic == null && _titleAutoFilled) {
        _titleController.clear();
        _titleAutoFilled = false;
      }
    });
  }

  /// Ders değişince/kalkınca konu sıfırlanır; otomatik doldurulmuş başlık da.
  void _resetTopicSelection() {
    _selectedTopicId = null;
    if (_titleAutoFilled) {
      _titleController.clear();
      _titleAutoFilled = false;
    }
  }

  // Native picker'ların seçim vurgusu marka renginden gelsin.
  Widget _pickerTheme(BuildContext context, Widget? child) {
    final base = Theme.of(context);
    return Theme(
      data: base.copyWith(
        colorScheme: base.colorScheme.copyWith(
          primary: AppColors.primary,
          onPrimary: AppColors.onColor(AppColors.primary),
        ),
      ),
      child: child!,
    );
  }

  /// "Özel": tam tarih, sonra saat. Saat seçimi iptal edilirse görev o güne
  /// SAATSİZ yazılır (bilinçli olarak saatsiz görev mümkün kalır).
  Future<void> _pickCustom() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final current = _when.dueDay(now);
    final day = await showDatePicker(
      context: context,
      initialDate: current.isBefore(today) ? today : current,
      firstDate: today.subtract(const Duration(days: 365)),
      lastDate: today.add(const Duration(days: 365 * 2)),
      helpText: 'Hangi gün?',
      builder: _pickerTheme,
    );
    if (day == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: _when.customTime ?? TimeOfDay.fromDateTime(now),
      helpText: 'Saat (iptal = saatsiz)',
      builder: _pickerTheme,
    );
    if (!mounted) return;
    setState(() => _when = TaskWhen.custom(day, time));
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

  String _detailsSummary() {
    final parts = <String>[
      if (_selectedDuration != null) '$_selectedDuration dk',
      if (_selectedPriority != TaskPriority.medium)
        _priorityLabel(_selectedPriority),
    ];
    return parts.isEmpty
        ? 'Süre ve öncelik'
        : 'Süre ve öncelik · ${parts.join(' · ')}';
  }

  void _submit() {
    var title = _titleController.text.trim();

    // Başlık boşsa uygulamanın zaten bildiği bilgiye düş: konu adı, yoksa ders
    // adı — öğrenciye "adı boş olamaz" demek yerine.
    if (title.isEmpty) {
      final topicId = _selectedTopicId;
      final subjectId = _selectedSubjectId;
      if (topicId != null && subjectId != null) {
        title = ref
                .read(topicsForSubjectProvider(subjectId))
                .where((t) => t.id == topicId)
                .firstOrNull
                ?.name ??
            '';
      }
      if (title.isEmpty && subjectId != null) {
        title = ref
                .read(subjectProvider)
                .where((s) => s.id == subjectId)
                .firstOrNull
                ?.name ??
            '';
      }
    }

    if (title.isEmpty) {
      AppSnackBar.error(context, "Görev adı boş olamaz");
      return;
    }

    // Göreli seçenekler (şimdi / 30 dk sonra…) KAYDETME anındaki saate göre
    // çözülür — ekran açık kaldıysa da geçmişe kalan bir saat yazılmaz.
    final now = DateTime.now();
    final due = _when.dueDay(now);
    final scheduledTime = _when.scheduledAt(now);

    if (_isEditing) {
      ref.read(taskProvider.notifier).updateTask(
            widget.taskToEdit!,
            title: title,
            subjectId: _selectedSubjectId,
            dueDate: due,
            priority: _selectedPriority,
            scheduledTime: scheduledTime,
            estimatedMinutes: _selectedDuration,
            topicId: _selectedTopicId,
          );
    } else if (_recurrence != 'none') {
      final isFirstTask = !ref.read(statsProvider).hasAddedFirstTask;

      ref.read(taskProvider.notifier).addRecurringTask(
            title: title,
            subjectId: _selectedSubjectId,
            startDate: due,
            recurrenceRule: _recurrence,
            priority: _selectedPriority,
            scheduledTimeOfDay: scheduledTime == null
                ? null
                : TimeOfDay(
                    hour: scheduledTime.hour, minute: scheduledTime.minute),
            estimatedMinutes: _selectedDuration,
            topicId: _selectedTopicId,
          );

      if (isFirstTask) {
        ref.read(statsProvider.notifier).markFirstTaskAdded();
        AppSnackBar.success(context, 'İlk görevini ekledin.');
      }
    } else {
      final isFirstTask = !ref.read(statsProvider).hasAddedFirstTask;

      ref.read(taskProvider.notifier).addTask(
            title: title,
            subjectId: _selectedSubjectId,
            dueDate: due,
            priority: _selectedPriority,
            scheduledTime: scheduledTime,
            estimatedMinutes: _selectedDuration,
            topicId: _selectedTopicId,
          );

      if (isFirstTask) {
        ref.read(statsProvider.notifier).markFirstTaskAdded();
        AppSnackBar.success(context, 'İlk görevini ekledin.');
      }
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final subjects = ref.watch(subjectProvider);
    final now = DateTime.now();
    final availableKinds = TaskTimeOptions.available(now);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? "Görevi Düzenle" : "Yeni Görev",
          style: AppTextStyles.heading2,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ListView(
                children: [
                  const Eyebrow(text: "GÖREV"),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.surfaceVariant),
                      boxShadow: AppColors.softShadow,
                    ),
                    child: TextField(
                      controller: _titleController,
                      onChanged: (_) => _titleAutoFilled = false,
                      style: AppTextStyles.body,
                      decoration: const InputDecoration(
                        hintText: "Örn: Türev konusu çöz",
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // "Neden bu görev?" — yalnız Çalışma Koçu'nun otomatik plan
                  // akışından gelen, somut bir sinyale dayanan görevlerde dolu.
                  // Salt bilgi, düzenlenemez.
                  if (_isEditing && widget.taskToEdit!.sourceReason != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.insights_outlined,
                              color: AppColors.primary, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.taskToEdit!.sourceReason!,
                              style: AppTextStyles.body,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (_suggestedSubject != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.auto_awesome, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Text(
                            "Önerilen ders: $_suggestedSubject",
                            style: AppTextStyles.body,
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // DERS (+ KONU)
                  _Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Eyebrow(text: "DERS"),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _SubjectChip(
                              label: "Derssiz",
                              color: AppColors.textSecondary,
                              isSelected: _selectedSubjectId == null,
                              onTap: () => setState(() {
                                _selectedSubjectId = null;
                                _resetTopicSelection();
                              }),
                            ),
                            ...subjects.map(
                              (subject) => _SubjectChip(
                                label: subject.name,
                                color: Color(subject.colorValue),
                                isSelected: _selectedSubjectId == subject.id,
                                onTap: () => setState(() {
                                  if (_selectedSubjectId != subject.id) {
                                    _resetTopicSelection();
                                  }
                                  _selectedSubjectId = subject.id;
                                }),
                              ),
                            ),
                          ],
                        ),
                        if (_selectedSubjectId != null)
                          Builder(builder: (context) {
                            final topics = ref.watch(
                                topicsForSubjectProvider(_selectedSubjectId!));
                            if (topics.isEmpty) return const SizedBox.shrink();
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 20),
                                Divider(
                                    height: 1, color: AppColors.surfaceVariant),
                                const SizedBox(height: 20),
                                const Eyebrow(text: "KONU (OPSİYONEL)"),
                                const SizedBox(height: 4),
                                Text(
                                  "Seçersen görev adı konudan gelir; görev, "
                                  "tamamlanınca o konunun çalışması olarak "
                                  "kaydedilir.",
                                  style: AppTextStyles.caption,
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: topics.map((topic) {
                                    final isSelected =
                                        _selectedTopicId == topic.id;
                                    return _SubjectChip(
                                      label: topic.name,
                                      color: topic.status ==
                                              TopicStatus.notStarted
                                          ? AppColors.secondary
                                          : AppColors.success,
                                      icon: Icons.checklist_outlined,
                                      isSelected: isSelected,
                                      onTap: () => _selectTopic(
                                          isSelected ? null : topic),
                                    );
                                  }).toList(),
                                ),
                              ],
                            );
                          }),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // NE ZAMAN — ana kartta, gerçek saate göre.
                  _Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Eyebrow(text: "NE ZAMAN"),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final kind in availableKinds)
                              _SubjectChip(
                                label:
                                    TaskTimeOptions.label(TaskWhen(kind), now),
                                color: AppColors.primary,
                                icon: kind == WhenKind.laterToday ||
                                        kind == WhenKind.tomorrow
                                    ? Icons.calendar_today_outlined
                                    : Icons.schedule_outlined,
                                isSelected: _when.kind == kind,
                                onTap: () =>
                                    setState(() => _when = TaskWhen(kind)),
                              ),
                            _SubjectChip(
                              label: _when.kind == WhenKind.custom
                                  ? TaskTimeOptions.label(_when, now)
                                  : "Özel",
                              color: AppColors.primary,
                              icon: Icons.edit_calendar_outlined,
                              isSelected: _when.kind == WhenKind.custom,
                              onTap: _pickCustom,
                            ),
                          ],
                        ),
                        if (!_when.isTimed) ...[
                          const SizedBox(height: 8),
                          Text(
                            "Saatsiz — o gün yapılacaklar listesinde durur.",
                            style: AppTextStyles.caption,
                          ),
                        ],
                        if (!_isEditing) ...[
                          const SizedBox(height: 20),
                          Divider(height: 1, color: AppColors.surfaceVariant),
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
                                onTap: () =>
                                    setState(() => _recurrence = 'none'),
                              ),
                              _SubjectChip(
                                label: "Her gün",
                                color: AppColors.primary,
                                isSelected: _recurrence == 'daily',
                                onTap: () =>
                                    setState(() => _recurrence = 'daily'),
                              ),
                              _SubjectChip(
                                label: "Her ${_weekdayName(_when.dueDay(now))}",
                                color: AppColors.primary,
                                isSelected: _recurrence == 'weekly',
                                onTap: () =>
                                    setState(() => _recurrence = 'weekly'),
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
                                  Icon(Icons.info_outline,
                                      size: 16, color: AppColors.warning),
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

                  // SÜRE + ÖNCELİK — gerçekten opsiyonel, kapalı katman.
                  TapScale(
                    onTap: () =>
                        setState(() => _detailsExpanded = !_detailsExpanded),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 14),
                      decoration: BoxDecoration(
                        color: AppColors.tonal(AppColors.primary),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              _detailsExpanded
                                  ? "Süre ve önceliği gizle"
                                  : _detailsSummary(),
                              style: AppTextStyles.bodySecondary.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          AnimatedRotation(
                            turns: _detailsExpanded ? 0.5 : 0,
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOut,
                            child: Icon(Icons.keyboard_arrow_down,
                                color: AppColors.primary, size: 20),
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
                        : Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: _Card(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Eyebrow(text: "SÜRE (OPSİYONEL)"),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    children: _durationOptions.map((minutes) {
                                      final isSelected =
                                          _selectedDuration == minutes;
                                      return _SubjectChip(
                                        label: "$minutes dk",
                                        color: AppColors.primary,
                                        icon: Icons.timer_outlined,
                                        isSelected: isSelected,
                                        // Seçili çipe tekrar dokun → süreyi kaldır.
                                        onTap: () => setState(() =>
                                            _selectedDuration =
                                                isSelected ? null : minutes),
                                      );
                                    }).toList(),
                                  ),
                                  const SizedBox(height: 20),
                                  Divider(
                                      height: 1,
                                      color: AppColors.surfaceVariant),
                                  const SizedBox(height: 20),
                                  const Eyebrow(text: "ÖNCELİK"),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    children:
                                        TaskPriority.values.map((priority) {
                                      return _SubjectChip(
                                        label: _priorityLabel(priority),
                                        color: _priorityColor(priority),
                                        icon: Icons.flag_outlined,
                                        isSelected:
                                            _selectedPriority == priority,
                                        onTap: () => setState(
                                            () => _selectedPriority = priority),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),
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
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.surfaceVariant),
      ),
      child: child,
    );
  }
}

class _SubjectChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;
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
    // computeLuminance() burada güvenilir değil — bkz. AppColors.onColor.
    final fgColor = isSelected ? AppColors.onColor(color) : color;

    return TapScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
              Icon(Icons.check, size: 16, color: fgColor),
              const SizedBox(width: 5),
            ] else if (icon != null) ...[
              Icon(icon, size: 16, color: fgColor),
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
