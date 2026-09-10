import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';
import 'widgets/achievement_card.dart';
import 'widgets/eyebrow.dart';
import 'widgets/exam_countdown.dart';
import 'task_provider.dart';
import 'subject_provider.dart';
import 'stats_provider.dart';
import 'topic_provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'widgets/animated_progress_bar.dart';
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

    // Tüm zamanlardaki (sadece bugün değil) tamamlanan görev sayısı
    final totalCompleted = allTasks.where((t) => t.isCompleted).length;

    return Scaffold(
      appBar: AppBar(title: Text('İstatistikler', style: AppTextStyles.heading2)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ÜST KISIM: 3 özet kart yan yana
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.local_fire_department_outlined,
                  iconColor: AppColors.warning,
                  value: '${stats.currentStreak}',
                  label: 'Mevcut Seri',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.emoji_events_outlined,
                  iconColor: AppColors.primary,
                  value: '${stats.longestStreak}',
                  label: 'En Uzun Seri',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.task_alt,
                  iconColor: AppColors.success,
                  value: '$totalCompleted',
                  label: 'Tamamlanan',
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.tonal(AppColors.primary),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.ac_unit, color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    stats.freezesAvailable > 0
                        ? '${stats.freezesAvailable} dondurma hakkın var — bir günü kaçırsan bile serin bozulmaz'
                        : 'Dondurma hakkın kalmadı — bir gün kaçırırsan serin sıfırlanır',
                    style: AppTextStyles.bodySecondary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
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
          const Eyebrow(text: 'SON 7 GÜN'),
          const SizedBox(height: 12),
          SizedBox(
            height: 140,
            child: BarChart(
              BarChartData(
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        const labels = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
                        return Text(labels[value.toInt()], style: AppTextStyles.caption);
                      },
                    ),
                  ),
                ),
                barGroups: List.generate(7, (index) {
                  final now = DateTime.now();
                  final monday = now.subtract(Duration(days: now.weekday - 1));
                  final day = DateTime(monday.year, monday.month, monday.day + index);
                  final count = allTasks.where((t) =>
                      t.isCompleted &&
                      t.dueDate.year == day.year &&
                      t.dueDate.month == day.month &&
                      t.dueDate.day == day.day).length;
                  return BarChartGroupData(x: index, barRods: [
                    BarChartRodData(
                      toY: count.toDouble(),
                      color: AppColors.primary,
                      width: 18,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ]);
                }),
              ),
              swapAnimationDuration: const Duration(milliseconds: 700),
              swapAnimationCurve: Curves.easeOutCubic,
            ),
          ),
          
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

          if (coveredSubjects.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Eyebrow(text: 'KONU KAPSAMASI'),
            const SizedBox(height: 12),
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
                        Text('${c.covered}/${c.total} · %${c.percent}',
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

const SizedBox(height: 20), // DERS BAZLI DAĞILIM
          const Eyebrow(text: 'DERS BAZLI İLERLEME'),
          const SizedBox(height: 12),
          if (subjects.isEmpty)
            Text(
              'Henüz ders eklemedin.',
              style: AppTextStyles.bodySecondary,
            )
          else
            ...subjects.map((subject) {
              final subjectTasks =
                  allTasks.where((t) => t.subjectId == subject.id).toList();
              final completed = subjectTasks.where((t) => t.isCompleted).length;
              final total = subjectTasks.length;
              final ratio = total == 0 ? 0.0 : completed / total;

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
                        Text(subject.name, style: AppTextStyles.body),
                        Text(
                          '$completed / $total',
                          style: AppTextStyles.bodySecondary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    AnimatedProgressBar(
                      value: ratio,
                      color: Color(subject.colorValue),
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

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 26),
          const SizedBox(height: 8),
          Text(value, style: AppTextStyles.heading2),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.caption,
          ),
        ],
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