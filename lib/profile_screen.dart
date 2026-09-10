import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';
import 'level_provider.dart';
import 'level_system.dart';
import 'stats_provider.dart';
import 'subject_provider.dart';
import 'subjects_screen.dart';
import 'task_provider.dart';
import 'tap_scale.dart';
import 'user_stats_model.dart';
import 'widgets/animated_progress_bar.dart';
import 'widgets/data_backup_section.dart';
import 'widgets/eyebrow.dart';

void _showEditNameDialog(BuildContext context, WidgetRef ref, String? currentName) {
  final controller = TextEditingController(text: currentName ?? '');

  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('İsmini düzenle'),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: 30,
        decoration: const InputDecoration(hintText: 'Örn. Ahmet'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Vazgeç'),
        ),
        TextButton(
          onPressed: () {
            ref.read(statsProvider.notifier).updateUserName(controller.text);
            Navigator.pop(dialogContext);
          },
          child: const Text('Kaydet'),
        ),
      ],
    ),
  );
}

void _showGradePicker(BuildContext context, WidgetRef ref, int? current) {
  const options = [9, 10, 11, 12, UserStatsModel.mezun];
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Sınıfını seç'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final g in options)
            TapScale(
              onTap: () {
                ref.read(statsProvider.notifier).setGradeLevel(g);
                Navigator.pop(dialogContext);
              },
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: g == current
                      ? AppColors.primary
                      : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  UserStatsModel.gradeLabel(g),
                  style: AppTextStyles.body.copyWith(
                    color: g == current
                        ? AppColors.ink
                        : AppColors.textPrimary,
                    fontWeight:
                        g == current ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Vazgeç'),
        ),
      ],
    ),
  );
}

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(statsProvider);
    final subjects = ref.watch(subjectProvider);
    final allTasks = ref.watch(taskProvider);

    final completedCount = allTasks.where((t) => t.isCompleted).length;

    return Scaffold(
      appBar: AppBar(
        title: Text('Profil', style: AppTextStyles.heading2),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Üst kimlik kartı
          TapScale(
            onTap: () => _showEditNameDialog(context, ref, stats.userName),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppColors.cardShadow,
              ),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.tonal(AppColors.primary),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_outline,
                      color: AppColors.primary,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stats.userName ?? 'Öğrenci',
                          style: AppTextStyles.heading2,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          stats.gradeLevel != null
                              ? '${UserStatsModel.gradeLabel(stats.gradeLevel)} • ${subjects.length} ders • $completedCount görev'
                              : '${subjects.length} ders • $completedCount görev tamamlandı',
                          style: AppTextStyles.bodySecondary,
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.edit_outlined,
                    color: AppColors.textSecondary,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 28),

          const Eyebrow(text: 'SINIF'),
          const SizedBox(height: 10),
          TapScale(
            onTap: () => _showGradePicker(context, ref, stats.gradeLevel),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppColors.softShadow,
              ),
              child: Row(
                children: [
                  const Icon(Icons.school_outlined,
                      size: 20, color: AppColors.primary),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      UserStatsModel.gradeLabel(stats.gradeLevel),
                      style: AppTextStyles.body,
                    ),
                  ),
                  const Icon(Icons.chevron_right,
                      color: AppColors.textSecondary),
                ],
              ),
            ),
          ),

          const SizedBox(height: 28),

          const Eyebrow(text: 'DERSLERİM'),
          const SizedBox(height: 10),
          TapScale(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SubjectsScreen()),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppColors.softShadow,
              ),
              child: Row(
                children: [
                  const Icon(Icons.menu_book_outlined,
                      size: 20, color: AppColors.primary),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      subjects.isEmpty
                          ? 'Ders ekle ve düzenle'
                          : '${subjects.length} ders — düzenle / sil',
                      style: AppTextStyles.body,
                    ),
                  ),
                  const Icon(Icons.chevron_right,
                      color: AppColors.textSecondary),
                ],
              ),
            ),
          ),

          const SizedBox(height: 28),

          const Eyebrow(text: 'SEVİYE'),
          const SizedBox(height: 10),
          _LevelCard(level: ref.watch(levelProvider)),

          const SizedBox(height: 28),

          const Eyebrow(text: 'SERİ'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ProfileStatCard(
                  icon: Icons.local_fire_department_outlined,
                  iconColor: AppColors.warning,
                  value: '${stats.currentStreak}',
                  label: 'Mevcut Seri',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ProfileStatCard(
                  icon: Icons.emoji_events_outlined,
                  iconColor: AppColors.primary,
                  value: '${stats.longestStreak}',
                  label: 'En Uzun Seri',
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
                const Icon(Icons.ac_unit,
                    color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    stats.freezesAvailable > 0
                        ? '${stats.freezesAvailable} dondurma hakkın var'
                        : 'Dondurma hakkın kalmadı',
                    style: AppTextStyles.bodySecondary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          const Eyebrow(text: 'HEDEF'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                    'Günlük hedef',
                    style: AppTextStyles.body,
                  ),
                ),
                Text(
                  '${stats.dailyGoal} görev',
                  style: AppTextStyles.heading3,
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          const Eyebrow(text: 'ÇALIŞMA SÜRESİ'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppColors.softShadow,
            ),
            child: Column(
              children: [
                _StudyTimeRow(
                  icon: Icons.timer_outlined,
                  iconColor: AppColors.primary,
                  label: 'Odak seansı',
                  minutes: stats.focusMinutes,
                ),
                Divider(
                    height: 1,
                    color: AppColors.textSecondary.withValues(alpha: 0.12)),
                _StudyTimeRow(
                  icon: Icons.check_circle_outline,
                  iconColor: AppColors.secondary,
                  label: 'Tamamlanan görevler (tahmini)',
                  minutes: stats.totalStudyMinutes,
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          const DataBackupSection(),
        ],
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  final LevelInfo level;

  const _LevelCard({required this.level});

  @override
  Widget build(BuildContext context) {
    final nextRank = level.atTopRank
        ? 'En üst rütbedesin ✦'
        : '${LevelSystem.ranks[LevelSystem.ranks.indexOf(level.title) + 1]}'
            ' rütbesine ${level.levelsToNextRank} seviye';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('Seviye ${level.level}', style: AppTextStyles.heading2),
              const SizedBox(width: 10),
              Text(level.title,
                  style: AppTextStyles.body
                      .copyWith(color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: 4),
          Text(nextRank, style: AppTextStyles.caption),
          const SizedBox(height: 14),
          AnimatedProgressBar(
            value: level.progress,
            color: AppColors.primary,
            backgroundColor: AppColors.surfaceVariant,
            height: 8,
          ),
          const SizedBox(height: 8),
          Text(
            level.progress >= 1
                ? 'Bir sonraki seviyeye hazırsın 🎉'
                : 'Sonraki seviye: ${level.xpToNextLevel} XP · '
                    'her tamamlanan görev, korunan seri ve işaretlenen konu '
                    'XP kazandırır.',
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }
}

class _ProfileStatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  const _ProfileStatCard({
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

class _StudyTimeRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final int minutes;

  const _StudyTimeRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.minutes,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.tonal(iconColor),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label, style: AppTextStyles.bodySecondary),
          ),
          Text(
            '${minutes ~/ 60}s ${minutes % 60}dk',
            style: AppTextStyles.heading3,
          ),
        ],
      ),
    );
  }
}