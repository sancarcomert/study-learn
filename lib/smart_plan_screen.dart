// lib/smart_plan_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';
import 'subject_provider.dart';
import 'task_provider.dart';
import 'task_model.dart';
import 'add_subject_sheet.dart';
import 'tap_scale.dart';
import 'widgets/eyebrow.dart';
import 'widgets/app_buttons.dart';
import 'widgets/animated_progress_ring.dart';
import 'widgets/app_snackbar.dart';

enum _PlanEntryStep { choose, form, result }

class SmartPlanScreen extends ConsumerStatefulWidget {
  const SmartPlanScreen({super.key});

  @override
  ConsumerState<SmartPlanScreen> createState() => _SmartPlanScreenState();
}

class _SmartPlanScreenState extends ConsumerState<SmartPlanScreen> {
  _PlanEntryStep _step = _PlanEntryStep.choose;

  bool _isExamMode = false;
  int _hoursAvailable = 2;
  String _energy = 'orta';
  bool _examPressure = false;
  String? _selectedSubjectId;
  final _topicsController = TextEditingController();
  final _examNameController = TextEditingController();
  DateTime _examDate = DateTime.now().add(const Duration(days: 7));

  bool _detailsExpanded = false;

  int _resultTaskCount = 0;
  int _resultPlannedMinutes = 0;
  int _resultRemainingMinutes = 0;
  List<String> _resultUnfitTitles = [];
  int _resultDaysUsed = 0;
  String _resultReason = '';

  @override
  void dispose() {
    _topicsController.dispose();
    _examNameController.dispose();
    super.dispose();
  }

  void _selectMode(bool examMode) {
    setState(() {
      _isExamMode = examMode;
      _step = _PlanEntryStep.form;
      _detailsExpanded = false;
    });
  }

  void _backToChoice() {
    setState(() {
      _step = _PlanEntryStep.choose;
    });
  }

  Future<void> _pickExamDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _examDate,
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _examDate = picked);
  }

  String _energyHint(String level) {
    switch (level) {
      case 'düşük':
        return 'Daha kısa, sık aralıklı çalışma blokları önerilir';
      case 'yüksek':
        return 'Daha uzun, odaklı çalışma blokları önerilir';
      default:
        return 'Dengeli uzunlukta çalışma blokları önerilir';
    }
  }

  IconData _energyIcon(String level) {
    switch (level) {
      case 'düşük':
        return Icons.battery_2_bar_rounded;
      case 'yüksek':
        return Icons.battery_full_rounded;
      default:
        return Icons.battery_4_bar_rounded;
    }
  }

  void _generate() {
    final subjects = ref.read(subjectProvider);
    if (subjects.isEmpty) {
      AppSnackBar.error(context, 'Önce en az bir ders eklemelisin');
      return;
    }

    final targetSubjects = _selectedSubjectId != null
        ? subjects.where((s) => s.id == _selectedSubjectId).toList()
        : subjects;

    final topics = _topicsController.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    if (_isExamMode) {
      _generateExamPlan(targetSubjects, topics);
    } else {
      _generateDailyPlan(targetSubjects, topics);
    }
  }

  void _generateExamPlan(List targetSubjects, List<String> topics) {
    final examName = _examNameController.text.trim();
    if (examName.isEmpty || topics.isEmpty) {
      AppSnackBar.error(context, 'Sınav adı ve en az bir konu girmelisin');
      return;
    }

    final today = DateTime.now();
    final daysLeft = _examDate.difference(DateTime(today.year, today.month, today.day)).inDays;
    if (daysLeft < 1) return;

    final daysToUse = daysLeft < topics.length ? daysLeft : topics.length;

    for (int i = 0; i < topics.length; i++) {
      final subject = targetSubjects[i % targetSubjects.length];
      final dayOffset = (i % daysToUse) + 1;
      final taskDate = today.add(Duration(days: dayOffset));
      final scheduledTime = DateTime(
        taskDate.year,
        taskDate.month,
        taskDate.day,
        9,
        0,
      );

      ref.read(taskProvider.notifier).addTask(
            title: '$examName: ${topics[i]}',
            subjectId: subject.id,
            dueDate: taskDate,
            priority: TaskPriority.high,
            scheduledTime: scheduledTime,
          );
    }

    setState(() {
      _resultTaskCount = topics.length;
      _resultDaysUsed = daysToUse;
      _step = _PlanEntryStep.result;
    });
  }

  void _generateDailyPlan(List targetSubjects, List<String> topics) {
    TaskPriority priority;

    if (_examPressure) {
      priority = TaskPriority.high;
    } else if (_energy == 'yüksek') {
      priority = TaskPriority.high;
    } else if (_energy == 'düşük') {
      priority = TaskPriority.low;
    } else {
      priority = TaskPriority.medium;
    }
    final today = DateTime.now();

    List sortedSubjects = [...targetSubjects];

    if (_examPressure) {
      sortedSubjects.shuffle();
    } else if (_energy == 'düşük') {
      sortedSubjects = sortedSubjects.reversed.toList();
    }
    DateTime startTime = DateTime.now();
    int taskCount;
    if (topics.isNotEmpty) {
      taskCount = topics.length;
    } else {
      taskCount = targetSubjects.length;
    }
    DateTime currentTime = startTime;

    final duration = _energy == 'yüksek'
        ? 60
        : _energy == 'düşük'
            ? 25
            : 45;

    final capacityMinutes = _hoursAvailable * 60;
    int remainingMinutes = capacityMinutes;
    int plannedCount = 0;
    int plannedMinutes = 0;
    final List<String> unfitTitles = [];

    for (int i = 0; i < taskCount; i++) {
      final subject = sortedSubjects[i % sortedSubjects.length];

      final title = topics.isNotEmpty
          ? '${subject.name}: ${topics[i]}'
          : subject.name;

      if (duration > remainingMinutes) {
        unfitTitles.add(title);
        continue;
      }

      ref.read(taskProvider.notifier).addTask(
            title: title,
            subjectId: subject.id,
            dueDate: today,
            priority: priority,
            scheduledTime: currentTime,
            estimatedMinutes: duration,
            difficulty: TopicDifficulty.medium,
          );

      currentTime = currentTime.add(Duration(minutes: duration));

      remainingMinutes -= duration;
      plannedMinutes += duration;
      plannedCount++;
    }

    String reason = '';

    if (_examPressure) {
      reason = 'Sınav baskısına göre öncelikli plan hazırlandı 📚';
    } else if (_energy == 'düşük') {
      reason = 'Enerjin düşük olduğu için daha kısa bloklar seçildi 🌱';
    } else if (_energy == 'yüksek') {
      reason = 'Enerjin yüksek olduğu için uzun çalışma blokları seçildi 🔥';
    } else {
      reason = 'Dengeli bir çalışma planı hazırlandı ⚖️';
    }

    setState(() {
      _resultTaskCount = plannedCount;
      _resultPlannedMinutes = plannedMinutes;
      _resultRemainingMinutes = remainingMinutes;
      _resultUnfitTitles = unfitTitles;
      _resultReason = reason;
      _step = _PlanEntryStep.result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final subjects = ref.watch(subjectProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: _step == _PlanEntryStep.form
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: _backToChoice,
                tooltip: 'Modu değiştir',
              )
            : _step == _PlanEntryStep.result
                ? IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Kapat',
                  )
                : null,
        title: Text(
          _step == _PlanEntryStep.choose
              ? 'Akıllı Plan'
              : _step == _PlanEntryStep.result
                  ? 'Planın Hazır'
                  : (_isExamMode ? 'Sınava Hazırlan' : 'Günümü Planla'),
          style: AppTextStyles.heading2,
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) {
          final slide = Tween<Offset>(
            begin: const Offset(0.04, 0),
            end: Offset.zero,
          ).animate(animation);

          return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: slide, child: child),
          );
        },
        child: _step == _PlanEntryStep.choose
            ? _buildChoiceStep(context)
            : _step == _PlanEntryStep.form
                ? _buildFormStep(context, subjects)
                : _buildResultStep(context),
      ),
    );
  }

  Widget _buildChoiceStep(BuildContext context) {
    return Padding(
      key: const ValueKey('choice'),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow(text: 'AI ÇALIŞMA KOÇUN'),
          const SizedBox(height: 6),
          Text('Bugün ne planlayalım?', style: AppTextStyles.heading1),
          const SizedBox(height: 4),
          Text(
            'Sana uygun, gerçekçi bir plan hazırlayalım.',
            style: AppTextStyles.bodySecondary,
          ),
          const SizedBox(height: 24),

          _PlanOptionCard(
            emoji: '📅',
            title: 'Günümü Planla',
            tintColor: AppColors.primary,
            bullets: const [
              'Bugünkü çalışma hedeflerini oluşturur',
              'Enerji durumuna göre ayarlar',
            ],
            onTap: () => _selectMode(false),
          ),

          const SizedBox(height: 14),

          _PlanOptionCard(
            emoji: '🎯',
            title: 'Sınava Hazırlan',
            tintColor: AppColors.warning,
            bullets: const [
              'Sınav tarihine göre çalışma planı oluşturur',
              'Konu dağılımı yapar',
            ],
            onTap: () => _selectMode(true),
          ),
        ],
      ),
    );
  }

  Widget _buildFormStep(BuildContext context, List subjects) {
    return Padding(
      key: const ValueKey('form'),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ListView(
              children: [
                if (_isExamMode) ...[
                  const Eyebrow(text: 'SINAV BİLGİSİ'),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _examNameController,
                    decoration: const InputDecoration(
                      hintText: 'Sınav adı, örn. Matematik Vize',
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Sınav Tarihi', style: AppTextStyles.bodySecondary),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: _pickExamDate,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.tonal(AppColors.secondary),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_rounded,
                              size: 16, color: AppColors.secondary),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('dd MMMM yyyy', 'tr_TR').format(_examDate),
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.secondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text('Konular (virgülle ayır)', style: AppTextStyles.body),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _topicsController,
                    decoration: const InputDecoration(
                      hintText: 'örn. kuvvet, enerji, elektrik',
                    ),
                  ),
                ] else ...[
                  const Eyebrow(text: 'ENERJİN NASIL'),
                  const SizedBox(height: 10),

                  ...['düşük', 'orta', 'yüksek'].map((level) {
                    final isSelected = _energy == level;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _EnergyOptionCard(
                        icon: _energyIcon(level),
                        label: level[0].toUpperCase() + level.substring(1),
                        hint: _energyHint(level),
                        isSelected: isSelected,
                        onTap: () => setState(() => _energy = level),
                      ),
                    );
                  }),

                  const SizedBox(height: 22),

                  const Eyebrow(text: 'DERS (OPSİYONEL)'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ...subjects.map((s) {
                        final isSelected = _selectedSubjectId == s.id;
                        return _SubjectChip(
                          label: s.name,
                          isSelected: isSelected,
                          onTap: () => setState(
                              () => _selectedSubjectId = isSelected ? null : s.id),
                        );
                      }),
                      TapScale(
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => const AddSubjectSheet(),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.tonal(AppColors.textSecondary),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add_rounded,
                                  size: 16, color: AppColors.textSecondary),
                              const SizedBox(width: 4),
                              Text('Yeni Ders',
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  )),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),

                  const Eyebrow(text: 'KONULAR (OPSİYONEL)'),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _topicsController,
                    decoration: const InputDecoration(
                      hintText: 'örn. kuvvet, enerji, elektrik',
                    ),
                  ),
                ],

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
                          _detailsExpanded ? 'Detayları Gizle' : 'Detayları Ekle',
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
                          children: _isExamMode
                              ? [
                                  const SizedBox(height: 16),
                                  const Eyebrow(text: 'DERS (OPSİYONEL)'),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      ...subjects.map((s) {
                                        final isSelected =
                                            _selectedSubjectId == s.id;
                                        return _SubjectChip(
                                          label: s.name,
                                          isSelected: isSelected,
                                          onTap: () => setState(() =>
                                              _selectedSubjectId =
                                                  isSelected ? null : s.id),
                                        );
                                      }),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                ]
                              : [
                                  const SizedBox(height: 16),
                                  Text('Bugün kaç saatin var?',
                                      style: AppTextStyles.body),
                                  const SizedBox(height: 10),
                                  Slider(
                                    value: _hoursAvailable.toDouble(),
                                    min: 1,
                                    max: 8,
                                    divisions: 7,
                                    label: '$_hoursAvailable saat',
                                    activeColor: AppColors.primary,
                                    onChanged: (v) => setState(
                                        () => _hoursAvailable = v.round()),
                                  ),
                                  const SizedBox(height: 12),
                                  SwitchListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text('Yakında sınavım var',
                                        style: AppTextStyles.body),
                                    value: _examPressure,
                                    activeColor: AppColors.primary,
                                    onChanged: (v) =>
                                        setState(() => _examPressure = v),
                                  ),
                                  const SizedBox(height: 4),
                                ],
                        ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),

          const SizedBox(height: 12),
          PrimaryButton(
            label: 'Planımı Oluştur',
            icon: Icons.auto_awesome_rounded,
            onPressed: _generate,
          ),
        ],
      ),
    );
  }

  Widget _buildResultStep(BuildContext context) {
    final capacityMinutes = _hoursAvailable * 60;
    final usedRatio = _isExamMode || capacityMinutes == 0
        ? 1.0
        : (_resultPlannedMinutes / capacityMinutes).clamp(0.0, 1.0);

    final plannedHours = _resultPlannedMinutes ~/ 60;
    final plannedMins = _resultPlannedMinutes % 60;
    final remainingHours = _resultRemainingMinutes ~/ 60;
    final remainingMins = _resultRemainingMinutes % 60;

    return Padding(
      key: const ValueKey('result'),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AppColors.tonal(AppColors.primary),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Eyebrow(text: 'PLANIN HAZIR', color: AppColors.primary),
                      const SizedBox(height: 8),
                      Text(
                        '$_resultTaskCount görev hazırlandı',
                        style: AppTextStyles.heading2,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _isExamMode
                            ? '$_resultDaysUsed güne dağıtıldı'
                            : (_resultReason.isNotEmpty
                                ? _resultReason
                                : 'Planın hazır'),
                        style: AppTextStyles.bodySecondary,
                      ),
                    ],
                  ),
                ),
                if (!_isExamMode) ...[
                  const SizedBox(width: 12),
                  _CapacityRing(ratio: usedRatio),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),

          if (!_isExamMode) ...[
            _ResultInfoRow(
              icon: Icons.timer_outlined,
              label: 'Plan süresi',
              value: '${plannedHours}s ${plannedMins}dk',
            ),
            const SizedBox(height: 10),
            _ResultInfoRow(
              icon: Icons.hourglass_bottom_rounded,
              label: 'Kalan kapasite',
              value: '${remainingHours}s ${remainingMins}dk',
            ),
            if (_resultUnfitTitles.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.tonal(AppColors.warning),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline_rounded,
                            size: 16, color: AppColors.warning),
                        const SizedBox(width: 6),
                        Text(
                          '${_resultUnfitTitles.length} konu bu sefer sığmadı',
                          style: AppTextStyles.body.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _resultUnfitTitles.join(', '),
                      style: AppTextStyles.bodySecondary,
                    ),
                  ],
                ),
              ),
            ],
          ] else ...[
            _ResultInfoRow(
              icon: Icons.calendar_today_rounded,
              label: 'Dağıtılan gün sayısı',
              value: '$_resultDaysUsed gün',
            ),
          ],

          const Spacer(),

          DarkButton(
            label: 'Tamam, Ana Ekrana Dön',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

class _CapacityRing extends StatelessWidget {
  final double ratio;

  const _CapacityRing({required this.ratio});

  @override
  Widget build(BuildContext context) {
    return AnimatedProgressRing(
      value: ratio,
      color: AppColors.primary,
      backgroundColor: AppColors.primary.withOpacity(0.15),
      center: Text(
        '${(ratio * 100).round()}%',
        style: AppTextStyles.caption.copyWith(
          fontWeight: FontWeight.w800,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

class _PlanOptionCard extends StatelessWidget {
  final String emoji;
  final String title;
  final Color tintColor;
  final List<String> bullets;
  final VoidCallback onTap;

  const _PlanOptionCard({
    required this.emoji,
    required this.title,
    required this.tintColor,
    required this.bullets,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.tonal(tintColor),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tintColor.withOpacity(0.16),
                shape: BoxShape.circle,
              ),
              child: Text(emoji, style: const TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.heading3),
                  const SizedBox(height: 6),
                  ...bullets.map(
                    (b) => Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.circle, size: 4, color: AppColors.textSecondary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(b, style: AppTextStyles.bodySecondary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: tintColor),
          ],
        ),
      ),
    );
  }
}

class _EnergyOptionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String hint;
  final bool isSelected;
  final VoidCallback onTap;

  const _EnergyOptionCard({
    required this.icon,
    required this.label,
    required this.hint,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.tonal(AppColors.primary)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: isSelected ? null : AppColors.softShadow,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
              size: 22,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(hint, style: AppTextStyles.bodySecondary),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.primary, size: 20),
          ],
        ),
      ),
    );
  }
}

class _SubjectChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SubjectChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.tonal(AppColors.primary),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _ResultInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ResultInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.softShadow,
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Text(label, style: AppTextStyles.bodySecondary),
          const Spacer(),
          Text(
            value,
            style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}