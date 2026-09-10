import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';
import 'widgets/achievement_card.dart';
import 'widgets/eyebrow.dart';
import 'widgets/exam_countdown.dart';
import 'widgets/activity_heatmap.dart';
import 'task_model.dart';
import 'task_provider.dart';
import 'subject_model.dart';
import 'subject_provider.dart';
import 'stats_provider.dart';
import 'topic_provider.dart';
import 'widgets/animated_progress_bar.dart';

/// Görevin "çalışıldığı gün" — tamamlanma tarihi (yoksa vade tarihi), saat sıfır.
DateTime _taskDay(TaskModel t) {
  final d = t.completedAt ?? t.dueDate;
  return DateTime(d.year, d.month, d.day);
}

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allTasks = ref.watch(taskProvider);
    final subjects = ref.watch(subjectProvider);
    final stats = ref.watch(statsProvider);
    final coverage = ref.watch(coverageBySubjectProvider);
    final coveredSubjects =
        subjects.where((s) => coverage[s.id]?.hasTopics ?? false).toList();

    final completedTasks = allTasks.where((t) => t.isCompleted).toList();
    final totalCompleted = completedTasks.length;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final thisMonday = today.subtract(Duration(days: today.weekday - 1));

    // Isı haritası: gün → tamamlanan görev sayısı
    final countsByDay = <DateTime, int>{};
    for (final t in completedTasks) {
      final d = _taskDay(t);
      countsByDay[d] = (countsByDay[d] ?? 0) + 1;
    }

    final weekCompleted = completedTasks
        .where((t) => !_taskDay(t).isBefore(thisMonday))
        .toList();
    final weekCount = weekCompleted.length;
    final activeDays = weekCompleted.map(_taskDay).toSet().length;
    return Scaffold(
      appBar: AppBar(title: Text('İstatistikler', style: AppTextStyles.heading2)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Eyebrow(text: 'BU HAFTA'),
          const SizedBox(height: 4),
          Text(
            'Pazartesiden bugüne kadar olan durumun.',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _WeekTile(
                  value: '$weekCount',
                  label: 'görev bitirdin',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _WeekTile(
                  value: '$activeDays/7',
                  label: 'gün çalıştın',
                ),
              ),
            ],
          ),

          const SizedBox(height: 28),
          const Eyebrow(text: 'SINAV'),
          const SizedBox(height: 12),
          _ExamDateCard(
            examDate: stats.examDate,
            onPick: () async {
              final notifier = ref.read(statsProvider.notifier);
              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);
              // Kayıtlı tarih geçmişse initialDate < firstDate olur ve
              // showDatePicker patlar — bu yüzden gelecekteyse onu, değilse
              // +90 günü başlangıç al.
              final stored = stats.examDate;
              final initial = (stored != null && !stored.isBefore(today))
                  ? stored
                  : today.add(const Duration(days: 90));
              final picked = await showDatePicker(
                context: context,
                initialDate: initial,
                firstDate: today,
                lastDate: DateTime(today.year + 3, today.month, today.day),
              );
              if (picked != null) notifier.setExamDate(picked);
            },
            onClear: () =>
                ref.read(statsProvider.notifier).setExamDate(null),
          ),

          const SizedBox(height: 28),

          // GÜNLÜK HEDEF AYARI
          const Eyebrow(text: 'GÜNLÜK HEDEF'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppColors.softShadow,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Günde tamamlanacak görev',
                    style: AppTextStyles.body,
                  ),
                ),
                Row(
                  children: [
                    _GoalButton(
                      icon: Icons.remove,
                      onTap: () => ref
                          .read(statsProvider.notifier)
                          .updateDailyGoal(stats.dailyGoal - 1),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        '${stats.dailyGoal}',
                        style: AppTextStyles.heading2,
                      ),
                    ),
                    _GoalButton(
                      icon: Icons.add,
                      onTap: () => ref
                          .read(statsProvider.notifier)
                          .updateDailyGoal(stats.dailyGoal + 1),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const Eyebrow(text: 'ÇALIŞMA TAKVİMİ'),
          const SizedBox(height: 4),
          Text(
            'Son 12 hafta. Her kare bir gün — o gün ne kadar çok '
            'görev bitirdiysen kare o kadar koyu (altın) olur. Amaç: '
            'takvimi boş bırakmamak, düzenli çalışmak.',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppColors.softShadow,
            ),
            child: totalCompleted == 0
                ? Text(
                    'Henüz görev bitirmedin. İlk görevini tamamlayınca '
                    'bugünün karesi burada yanar.',
                    style: AppTextStyles.bodySecondary)
                : ActivityHeatmap(countsByDay: countsByDay, weeks: 12),
          ),

          const SizedBox(height: 28),
          const Eyebrow(text: 'HANGİ DERSE ÇALIŞTIN'),
          const SizedBox(height: 4),
          Text(
            'Seçili dönemde her derste kaç görev bitirdin. En kısa çubuk '
            '= en az vakit ayırdığın ders.',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 12),
          _SubjectDistribution(tasks: completedTasks, subjects: subjects),

         const SizedBox(height: 28),
         const Eyebrow(text: 'BAŞARILAR'),
const SizedBox(height: 12),

AchievementCard(
  title: 'İlk Adım',
  description: 'İlk görevini tamamladın',
  icon: Icons.flag_outlined,
  unlocked: totalCompleted >= 1,
),

AchievementCard(
  title: 'Çalışkan Öğrenci',
  description: '50 görevi tamamla',
  icon: Icons.star_outline,
  unlocked: totalCompleted >= 50,
),

AchievementCard(
  title: 'Usta Planlayıcı',
  description: '100 görevi tamamla',
  icon: Icons.workspace_premium_outlined,
  unlocked: totalCompleted >= 100,
),

          const SizedBox(height: 28),
          const Eyebrow(text: 'KONU İLERLEMESİ'),
          const SizedBox(height: 4),
          Text(
            'Konu Takip\'te "çalışıldı" işaretlediğin konuların '
            'toplam müfredata oranı.',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 12),
          if (subjects.isEmpty)
            const _InfoBox(text: 'Henüz ders eklemedin.')
          else if (coveredSubjects.isEmpty)
            const _InfoBox(
              text:
                  'Konu Takip\'ten (Plan sekmesi) konu ekleyerek ders ilerlemeni burada gör.',
            )
          else
            ...coveredSubjects.map((s) {
              final c = coverage[s.id]!;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: AppColors.softShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(s.name, style: AppTextStyles.body),
                        Text('${c.covered}/${c.total} konu · %${c.percent}',
                            style: AppTextStyles.bodySecondary),
                      ],
                    ),
                    const SizedBox(height: 8),
                    AnimatedProgressBar(
                      value: c.ratio,
                      color: Color(s.colorValue),
                      backgroundColor: AppColors.background,
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _WeekTile extends StatelessWidget {
  final String value;
  final String label;

  const _WeekTile({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: AppTextStyles.heading2),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

/// Ders başına — seçili dönemde (bu hafta / bu ay) tamamlanan görev sayısı.
/// "Hangi dersi ihmal ediyorum" sorusuna yanıt.
class _SubjectDistribution extends StatefulWidget {
  final List<TaskModel> tasks; // yalnız tamamlananlar
  final List<SubjectModel> subjects;

  const _SubjectDistribution({required this.tasks, required this.subjects});

  @override
  State<_SubjectDistribution> createState() => _SubjectDistributionState();
}

class _SubjectDistributionState extends State<_SubjectDistribution> {
  bool _month = false; // false = bu hafta, true = bu ay

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = _month
        ? DateTime(now.year, now.month, 1)
        : today.subtract(Duration(days: today.weekday - 1));

    final counts = <String, int>{};
    for (final t in widget.tasks) {
      if (t.subjectId == null) continue;
      if (_taskDay(t).isBefore(start)) continue;
      counts[t.subjectId!] = (counts[t.subjectId!] ?? 0) + 1;
    }

    final rows = widget.subjects
        .map((s) => MapEntry(s, counts[s.id] ?? 0))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxCount =
        rows.isEmpty ? 0 : rows.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _PeriodChip(
              label: 'Bu hafta',
              selected: !_month,
              onTap: () => setState(() => _month = false),
            ),
            const SizedBox(width: 8),
            _PeriodChip(
              label: 'Bu ay',
              selected: _month,
              onTap: () => setState(() => _month = true),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (widget.subjects.isEmpty)
          const _InfoBox(text: 'Henüz ders eklemedin.')
        else if (maxCount == 0)
          _InfoBox(
            text: _month
                ? 'Bu ay bir derse bağlı görev tamamlamadın.'
                : 'Bu hafta bir derse bağlı görev tamamlamadın.',
          )
        else
          ...rows.map((e) {
            final ratio = maxCount == 0 ? 0.0 : e.value / maxCount;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppColors.softShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(e.key.name, style: AppTextStyles.body),
                      Text('${e.value} görev',
                          style: AppTextStyles.bodySecondary),
                    ],
                  ),
                  const SizedBox(height: 8),
                  AnimatedProgressBar(
                    value: ratio,
                    color: Color(e.key.colorValue),
                    backgroundColor: AppColors.background,
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}

class _PeriodChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PeriodChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : AppColors.tonal(AppColors.primary),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: selected ? AppColors.ink : AppColors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final String text;
  const _InfoBox({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.softShadow,
      ),
      child: Text(text, style: AppTextStyles.bodySecondary),
    );
  }
}

class _ExamDateCard extends StatelessWidget {
  final DateTime? examDate;
  final VoidCallback onPick;
  final VoidCallback onClear;

  const _ExamDateCard({
    required this.examDate,
    required this.onPick,
    required this.onClear,
  });

  static const _months = [
    'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
    'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara',
  ];

  @override
  Widget build(BuildContext context) {
    final date = examDate;
    return GestureDetector(
      onTap: onPick,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppColors.softShadow,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: AppColors.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.event_outlined,
                  size: 20, color: AppColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: date == null
                  ? Text('Sınav tarihi ekle',
                      style: AppTextStyles.body
                          .copyWith(fontWeight: FontWeight.w600))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          examCountdownLabel(daysUntilExam(date)),
                          style: AppTextStyles.body
                              .copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${date.day} ${_months[date.month - 1]} ${date.year}',
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
            ),
            if (date == null)
              const Icon(Icons.add, size: 20, color: AppColors.textSecondary)
            else
              GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.close,
                    size: 18, color: AppColors.textMuted),
              ),
          ],
        ),
      ),
    );
  }
}


class _GoalButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GoalButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
          color: AppColors.surfaceVariant,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: AppColors.primary),
      ),
    );
  }
}