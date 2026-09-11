import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';
import 'subject_provider.dart';
import 'topic_provider.dart';
import 'subject_topics_screen.dart';
import 'tap_scale.dart';
import 'widgets/eyebrow.dart';
import 'widgets/empty_state_card.dart';
import 'widgets/animated_progress_bar.dart';

/// Konu Takip özeti — dersler ve kapsama yüzdeleri. Bir derse dokununca o
/// dersin konu listesine ([SubjectTopicsScreen]) gider.
class KonuTakipScreen extends ConsumerWidget {
  const KonuTakipScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjects = ref.watch(subjectProvider);
    final coverage = ref.watch(coverageBySubjectProvider);

    final totalTopics =
        coverage.values.fold<int>(0, (s, c) => s + c.total);
    final totalCovered =
        coverage.values.fold<int>(0, (s, c) => s + c.covered);
    final overall = totalTopics == 0 ? 0.0 : totalCovered / totalTopics;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Konu Takip', style: AppTextStyles.heading2),
      ),
      body: subjects.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(20),
              child: EmptyStateCard(
                icon: Icons.checklist_rtl_outlined,
                message:
                    'Önce ders eklemelisin.\nProfil → Derslerim\'den ekleyebilirsin.',
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (totalTopics > 0) ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.tonal(AppColors.primary),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Eyebrow(
                            text: 'GENEL KAPSAMA', color: AppColors.primary),
                        const SizedBox(height: 8),
                        Text('%${(overall * 100).round()}',
                            style: AppTextStyles.heading1),
                        const SizedBox(height: 4),
                        Text('$totalCovered / $totalTopics konu işaretlendi',
                            style: AppTextStyles.bodySecondary),
                        const SizedBox(height: 14),
                        AnimatedProgressBar(
                          value: overall,
                          color: AppColors.primary,
                          backgroundColor: AppColors.surfaceVariant,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                const Eyebrow(text: 'DERSLER'),
                const SizedBox(height: 12),
                ...subjects.map((s) {
                  final c = coverage[s.id] ?? const TopicCoverage(0, 0);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _SubjectRow(
                      name: s.name,
                      color: Color(s.colorValue),
                      coverage: c,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SubjectTopicsScreen(
                            subjectId: s.id,
                            subjectName: s.name,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
    );
  }
}

class _SubjectRow extends StatelessWidget {
  final String name;
  final Color color;
  final TopicCoverage coverage;
  final VoidCallback onTap;

  const _SubjectRow({
    required this.name,
    required this.color,
    required this.coverage,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.surfaceVariant, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(name,
                      style: AppTextStyles.body
                          .copyWith(fontWeight: FontWeight.w700)),
                ),
                Text(
                  coverage.hasTopics
                      ? '${coverage.covered}/${coverage.total} · %${coverage.percent}'
                      : 'konu yok',
                  style: AppTextStyles.caption.copyWith(
                    color: coverage.hasTopics
                        ? AppColors.textSecondary
                        : AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right,
                    size: 18, color: AppColors.textMuted),
              ],
            ),
            if (coverage.hasTopics) ...[
              const SizedBox(height: 12),
              AnimatedProgressBar(
                value: coverage.ratio,
                color: color,
                backgroundColor: AppColors.surfaceVariant,
                height: 6,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
