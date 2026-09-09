// lib/smart_plan_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';
import 'subject_provider.dart';
import 'stats_provider.dart';
import 'task_provider.dart';
import 'task_model.dart';
import 'add_subject_sheet.dart';
import 'tap_scale.dart';
import 'widgets/eyebrow.dart';
import 'widgets/app_buttons.dart';
import 'widgets/animated_progress_ring.dart';
import 'widgets/app_snackbar.dart';
import 'widgets/exam_countdown.dart';

enum _PlanEntryStep { form, result }

/// Tek modlu günlük planlayıcı. Eskiden "Günümü Planla" / "Sınava Hazırlan"
/// diye iki mod vardı; ikisi de aynı çıktıyı (bir yığın görev) ürettiği için
/// birleştirildi. Sınav farkındalığı artık ayrı bir moddan değil,
/// `statsProvider.examDate`'ten geliyor: sınav yakınsa öncelikler otomatik
/// yükselir. Çok güne yayılan konu dağıtımı bilinçli olarak buradan çıkarıldı
/// (o iş ileride ayrıca değerlendirilecek "Konu Takip" modülüne ait).
class SmartPlanScreen extends ConsumerStatefulWidget {
  const SmartPlanScreen({super.key});

  @override
  ConsumerState<SmartPlanScreen> createState() => _SmartPlanScreenState();
}

class _SmartPlanScreenState extends ConsumerState<SmartPlanScreen> {
  _PlanEntryStep _step = _PlanEntryStep.form;

  int _hoursAvailable = 2;
  String _energy = 'orta';
  bool _examPressure = false;
  String? _selectedSubjectId;
  final _topicsController = TextEditingController();

  bool _detailsExpanded = false;

  int _resultTaskCount = 0;
  int _resultPlannedMinutes = 0;
  int _resultRemainingMinutes = 0;
  List<String> _resultUnfitTitles = [];
  String _resultReason = '';

  @override
  void dispose() {
    _topicsController.dispose();
    super.dispose();
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
        return Icons.battery_2_bar_outlined;
      case 'yüksek':
        return Icons.battery_full;
      default:
        return Icons.battery_4_bar_outlined;
    }
  }

  /// Sınav tarihi girilmişse kalan gün; yoksa null.
  int? get _examDaysLeft {
    final examDate = ref.read(statsProvider).examDate;
    if (examDate == null) return null;
    final d = daysUntilExam(examDate);
    return d < 0 ? null : d;
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

    final examDays = _examDaysLeft;
    // Sınava 30 gün ve altındaysa plan otomatik olarak "sınav modu"na geçer:
    // manuel anahtar olmasa da öncelikler yükseltilir.
    final examSoon = examDays != null && examDays <= 30;
    final examPressure = examSoon || _examPressure;

    TaskPriority priority;
    if (examPressure) {
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
    if (examPressure) {
      sortedSubjects.shuffle();
    } else if (_energy == 'düşük') {
      sortedSubjects = sortedSubjects.reversed.toList();
    }

    final int taskCount =
        topics.isNotEmpty ? topics.length : targetSubjects.length;

    DateTime currentTime = DateTime.now();

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

      final title =
          topics.isNotEmpty ? '${subject.name}: ${topics[i]}' : subject.name;

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

    String reason;
    if (examSoon) {
      reason = 'Sınava $examDays gün — öncelikler yükseltildi 📌';
    } else if (_examPressure) {
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
    final isResult = _step == _PlanEntryStep.result;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        automaticallyImplyLeading: !isResult,
        leading: isResult
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'Kapat',
              )
            : null,
        title: Text(
          isResult ? 'Planın Hazır' : 'Bugünü Planla',
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
        child: isResult
            ? _buildResultStep(context)
            : _buildFormStep(context, subjects),
      ),
    );
  }

  Widget _buildFormStep(BuildContext context, List subjects) {
    final examDays = _examDaysLeft;

    return Padding(
      key: const ValueKey('form'),
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
          const SizedBox(height: 20),

          if (examDays != null && examDays <= 30) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.tonal(AppColors.primary),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.event_outlined,
                      size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Sınava $examDays gün — plan öncelikleri buna göre yükseltilecek.',
                      style: AppTextStyles.bodySecondary.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          Expanded(
            child: ListView(
              children: [
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
                            Icon(Icons.add,
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
                            Icons.keyboard_arrow_down,
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
                          children: [
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
                              onChanged: (v) =>
                                  setState(() => _hoursAvailable = v.round()),
                            ),
                            const SizedBox(height: 12),
                            // Sınav tarihi zaten girilmişse manuel anahtara
                            // gerek yok — plan onu okuyup kendisi sıkılaştırıyor.
                            if (examDays == null)
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
            icon: Icons.auto_awesome_outlined,
            onPressed: _generate,
          ),
        ],
      ),
    );
  }

  Widget _buildResultStep(BuildContext context) {
    final capacityMinutes = _hoursAvailable * 60;
    final usedRatio = capacityMinutes == 0
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
                        _resultReason.isNotEmpty
                            ? _resultReason
                            : 'Planın hazır',
                        style: AppTextStyles.bodySecondary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _CapacityRing(ratio: usedRatio),
              ],
            ),
          ),

          const SizedBox(height: 20),

          _ResultInfoRow(
            icon: Icons.timer_outlined,
            label: 'Plan süresi',
            value: '${plannedHours}s ${plannedMins}dk',
          ),
          const SizedBox(height: 10),
          _ResultInfoRow(
            icon: Icons.hourglass_empty,
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
                      Icon(Icons.info_outline,
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
              const Icon(Icons.check_circle_outline,
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
            // Altın zeminde beyaz değil koyu metin — kontrast için.
            color: isSelected ? AppColors.ink : AppColors.primary,
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
