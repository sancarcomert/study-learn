import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';
import 'widgets/achievement_card.dart';
import 'task_provider.dart';
import 'subject_provider.dart';
import 'stats_provider.dart';
import 'package:fl_chart/fl_chart.dart';
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allTasks = ref.watch(taskProvider);
    final subjects = ref.watch(subjectProvider);
    final stats = ref.watch(statsProvider);

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
                  icon: Icons.local_fire_department_rounded,
                  iconColor: AppColors.warning,
                  value: '${stats.currentStreak}',
                  label: 'Mevcut Seri',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.emoji_events_rounded,
                  iconColor: AppColors.primary,
                  value: '${stats.longestStreak}',
                  label: 'En Uzun Seri',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.task_alt_rounded,
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
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.ac_unit_rounded, color: AppColors.primary, size: 18),
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

          const SizedBox(height: 28),

          // GÜNLÜK HEDEF AYARI
          Text('Günlük Hedef', style: AppTextStyles.heading2),
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
  Text('Son 7 Gün', style: AppTextStyles.heading2),
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
            ),
          ),
          
         Text('Başarılar', style: AppTextStyles.heading2),
const SizedBox(height: 12),

AchievementCard(
  title: 'İlk Adım',
  description: 'İlk görevini tamamladın',
  icon: Icons.flag_rounded,
  unlocked: totalCompleted >= 1,
),

AchievementCard(
  title: 'Çalışkan Öğrenci',
  description: '50 görevi tamamla',
  icon: Icons.star_rounded,
  unlocked: totalCompleted >= 50,
),

AchievementCard(
  title: 'Usta Planlayıcı',
  description: '100 görevi tamamla',
  icon: Icons.workspace_premium_rounded,
  unlocked: totalCompleted >= 100,
),

const SizedBox(height: 20), // DERS BAZLI DAĞILIM
          Text('Ders Bazlı İlerleme', style: AppTextStyles.heading2),
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
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 8,
                        backgroundColor: AppColors.background,
                        valueColor: AlwaysStoppedAnimation(
                          Color(subject.colorValue),
                        ),
                      ),
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
        decoration: BoxDecoration(
          color: AppColors.background,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: AppColors.primary),
      ),
    );
  }
}