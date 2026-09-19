import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';
import 'tap_scale.dart';
import 'widgets/achievement_card.dart';
import 'widgets/section_header.dart';
import 'widgets/metric_tile.dart';
import 'widgets/exam_countdown.dart';
import 'widgets/activity_heatmap.dart';
import 'deneme_model.dart';
import 'deneme_provider.dart';
import 'focus_session_provider.dart';
import 'task_model.dart';
import 'task_provider.dart';
import 'subject_model.dart';
import 'subject_provider.dart';
import 'stats_provider.dart';
import 'topic_provider.dart';
import 'widget_service.dart';
import 'widgets/animated_progress_bar.dart';
import 'widgets/empty_state_card.dart';

/// Görevin "çalışıldığı gün" — tamamlanma tarihi (yoksa vade tarihi), saat sıfır.
DateTime _taskDay(TaskModel t) {
  final d = t.completedAt ?? t.dueDate;
  return DateTime(d.year, d.month, d.day);
}

String _fmtMinutes(int m) {
  if (m <= 0) return '0 dk';
  final h = m ~/ 60;
  final mm = m % 60;
  if (h == 0) return '$mm dk';
  if (mm == 0) return '$h sa';
  return '$h sa $mm dk';
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

    final focusByDay = ref.watch(focusMinutesByDayProvider);
    final focusWeekMin = ref.watch(focusThisWeekMinutesProvider);

    // Isı haritası: gün → tamamlanan görev sayısı + (o gün odak seansı
    // yapıldıysa +1). "Sonuç değil çaba" — yalnız görev tamamlamadan
    // Pomodoro yapılan bir gün de haritada yanmalı, boş görünmemeli.
    final countsByDay = <DateTime, int>{};
    for (final t in completedTasks) {
      final d = _taskDay(t);
      countsByDay[d] = (countsByDay[d] ?? 0) + 1;
    }
    for (final entry in focusByDay.entries) {
      if (entry.value <= 0) continue;
      countsByDay[entry.key] = (countsByDay[entry.key] ?? 0) + 1;
    }

    final weekCompleted =
        completedTasks.where((t) => !_taskDay(t).isBefore(thisMonday)).toList();
    final weekCount = weekCompleted.length;
    // "X/7 gün çalıştın" da aynı mantıkla: görev bitirilen VEYA odaklanılan
    // gün, aktif gün sayılır.
    final activeDays = <DateTime>{
      ...weekCompleted.map(_taskDay),
      for (final entry in focusByDay.entries)
        if (entry.value > 0 && !entry.key.isBefore(thisMonday)) entry.key,
    }.length;
    final denemeCount = ref.watch(denemeProvider).length;
    final latestDeneme = ref.watch(latestDenemeProvider);
    return Scaffold(
      appBar:
          AppBar(title: Text('İstatistikler', style: AppTextStyles.heading2)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SectionHeader(
            title: 'Bu Hafta',
            subtitle: 'Pazartesiden bugüne kadar olan durumun.',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: MetricTile(
                  icon: Icons.check_circle_outline,
                  value: '$weekCount',
                  label: 'GÖREV BİTİRDİN',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: MetricTile(
                  icon: Icons.calendar_today_outlined,
                  value: '$activeDays/7',
                  label: 'GÜN ÇALIŞTIN',
                ),
              ),
            ],
          ),

          const SizedBox(height: 28),
          const SectionHeader(title: 'Sınav'),
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
              if (picked != null) {
                notifier.setExamDate(picked);
                // İlk kez sınav tarihi giriliyorsa, widget'ı ana ekrana
                // ekleme teklifi (bir kez). docs/rakip_analizi §6 B1.
                if (stored == null && context.mounted) {
                  await WidgetService.maybeOfferPin(context);
                }
              }
            },
            onClear: () => ref.read(statsProvider.notifier).setExamDate(null),
          ),

          const SizedBox(height: 28),

          // GÜNLÜK HEDEF AYARI
          const SectionHeader(title: 'Günlük Hedef'),
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
          const SectionHeader(
            title: 'Çalışma Takvimi',
            subtitle: 'Son 12 hafta. Her kare bir gün — görev bitirdiğin ya da '
                'odaklandığın günler kare o kadar koyu olur.',
          ),
          const SizedBox(height: 12),
          countsByDay.isEmpty
              ? const EmptyStateCard(
                  icon: Icons.calendar_month_outlined,
                  message: 'Henüz görev bitirmedin ya da odaklanmadın. '
                      'İlkini yapınca bugünün karesi burada yanar.',
                )
              : Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: AppColors.softShadow,
                  ),
                  child: ActivityHeatmap(countsByDay: countsByDay, weeks: 12),
                ),

          const SizedBox(height: 28),
          const SectionHeader(
            title: 'Odak Süresi',
            subtitle: 'Odak Seansı\'nda (Plan sekmesi) kronometreyle ölçülen '
                'süre. Aşağıda bu haftanın gün gün dağılımı.',
          ),
          const SizedBox(height: 12),
          focusWeekMin == 0
              ? const EmptyStateCard(
                  icon: Icons.timer_outlined,
                  message: 'Bu hafta henüz odak seansı yapmadın. '
                      'Plan → Odak Seansı\'ndan başlayabilirsin.',
                )
              : Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: AppColors.softShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bu hafta: ${_fmtMinutes(focusWeekMin)}',
                        style: AppTextStyles.body
                            .copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 14),
                      _FocusWeekBar(byDay: focusByDay),
                    ],
                  ),
                ),

          const SizedBox(height: 28),
          const SectionHeader(
            title: 'Hangi Derse Çalıştın',
            subtitle: 'Seçili dönemde her derste kaç görev bitirdin. En kısa '
                'çubuk = en az vakit ayırdığın ders.',
          ),
          const SizedBox(height: 12),
          _SubjectDistribution(tasks: completedTasks, subjects: subjects),

          const SizedBox(height: 28),
          const SectionHeader(
            title: 'Deneme Neti',
            subtitle: 'Son eklediğin TYT/AYT denemesi. Tümünü Plan → Deneme '
                'Takip\'te gör.',
          ),
          const SizedBox(height: 12),
          if (latestDeneme == null)
            const EmptyStateCard(
              icon: Icons.trending_up_outlined,
              message: 'Henüz deneme eklemedin. Plan → Deneme Takip\'ten '
                  'ilk netini girebilirsin.',
            )
          else
            _DenemeSummaryCard(entry: latestDeneme, count: denemeCount),

          const SizedBox(height: 28),
          const SectionHeader(title: 'Başarılar'),
          const SizedBox(height: 12),

          AchievementCard(
            title: 'İlk Adım',
            description: 'İlk görevini tamamla',
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
          const SectionHeader(
            title: 'Konu İlerlemesi',
            subtitle: 'Konu Takip\'te "çalışıldı" işaretlediğin konuların '
                'toplam müfredata oranı.',
          ),
          const SizedBox(height: 12),
          if (subjects.isEmpty)
            const EmptyStateCard(
              icon: Icons.menu_book_outlined,
              message: 'Henüz ders eklemedin.',
            )
          else if (coveredSubjects.isEmpty)
            const EmptyStateCard(
              icon: Icons.checklist_outlined,
              message: 'Konu Takip\'ten (Plan sekmesi) konu ekleyerek ders '
                  'ilerlemeni burada gör.',
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

/// Bu haftanın (Pzt–Paz) gün gün odak dakikası — küçük özel sütun grafiği.
class _FocusWeekBar extends StatelessWidget {
  final Map<DateTime, int> byDay;
  const _FocusWeekBar({required this.byDay});

  static const _labels = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final mins = List.generate(7, (i) {
      final d = DateTime(monday.year, monday.month, monday.day + i);
      return byDay[d] ?? 0;
    });
    final maxMin = mins.fold<int>(1, (a, b) => a > b ? a : b);
    final todayIdx = today.weekday - 1;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i == 6 ? 0 : 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 72,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                        heightFactor: (mins[i] / maxMin).clamp(0.04, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: mins[i] == 0
                                ? AppColors.surfaceVariant
                                : (i == todayIdx
                                    ? AppColors.vibrantSky
                                    : AppColors.vibrantSky
                                        .withValues(alpha: 0.55)),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(_labels[i],
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textMuted)),
                ],
              ),
            ),
          ),
      ],
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
    final maxCount = rows.isEmpty
        ? 0
        : rows.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.surfaceVariant),
          ),
          child: Row(
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
        ),
        const SizedBox(height: 14),
        if (widget.subjects.isEmpty)
          const EmptyStateCard(
            icon: Icons.menu_book_outlined,
            message: 'Henüz ders eklemedin.',
          )
        else if (maxCount == 0)
          EmptyStateCard(
            icon: Icons.bar_chart_outlined,
            message: _month
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
    return TapScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : AppColors.tonal(AppColors.primary),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: selected
                ? AppColors.onColor(AppColors.primary)
                : AppColors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _DenemeSummaryCard extends StatelessWidget {
  final DenemeEntry entry;
  final int count;
  const _DenemeSummaryCard({required this.entry, required this.count});

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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.tonal(AppColors.secondary),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              entry.examType,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.secondary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              count == 1 ? '1 deneme kaydettin' : '$count deneme kaydettin',
              style: AppTextStyles.body,
            ),
          ),
          Text(
            entry.totalNet.toStringAsFixed(2),
            style: AppTextStyles.heading3.copyWith(color: AppColors.primary),
          ),
        ],
      ),
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
    final date = examDate;
    return TapScale(
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
              decoration: BoxDecoration(
                color: AppColors.tonal(AppColors.primary),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.event_outlined,
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
              Icon(Icons.add, size: 20, color: AppColors.textSecondary)
            else
              TapScale(
                onTap: onClear,
                child: Icon(Icons.close,
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
    return TapScale(
      onTap: onTap,
      // Dış kutu 44x44 — mobil ergonomi için gerçek dokunma alanı; görsel
      // daire içeride 32x32 kalıyor, satır şişmiyor.
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: AppColors.primary),
        ),
      ),
    );
  }
}
