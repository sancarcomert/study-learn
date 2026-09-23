import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';
import 'subject_provider.dart';
import 'topic_provider.dart';
import 'topic_model.dart';
import 'subject_topics_screen.dart';
import 'stats_provider.dart';
import 'rank_provider.dart';
import 'profile_screen.dart';
import 'rank_ladder_screen.dart';
import 'tap_scale.dart';
import 'widgets/eyebrow.dart';
import 'widgets/empty_state_card.dart';
import 'widgets/animated_progress_bar.dart';
import 'widgets/app_header.dart';

/// Konu Takip özeti — dersler ve kapsama yüzdeleri. Bir derse dokununca o
/// dersin konu listesine ([SubjectTopicsScreen]) gider.
/// 2026-09-19: Mentora'nın "Dersler" ekranı referans alındı — üstte
/// Tümü/Devam eden/Tamamlanan filtre pilleri eklendi (mevcut coverage
/// yüzdesinden türetilen salt görsel bir filtre, yeni veri/işlev değil).
class KonuTakipScreen extends ConsumerStatefulWidget {
  const KonuTakipScreen({super.key});

  @override
  ConsumerState<KonuTakipScreen> createState() => _KonuTakipScreenState();
}

enum _CoverageFilter { all, inProgress, done }

class _KonuTakipScreenState extends ConsumerState<KonuTakipScreen> {
  _CoverageFilter _filter = _CoverageFilter.all;

  @override
  Widget build(BuildContext context) {
    final subjects = ref.watch(subjectProvider);
    final coverage = ref.watch(coverageBySubjectProvider);
    final topics = ref.watch(topicProvider);
    final stats = ref.watch(statsProvider);

    final totalTopics =
        coverage.values.fold<int>(0, (s, c) => s + c.total);
    final totalCovered =
        coverage.values.fold<int>(0, (s, c) => s + c.covered);
    final overall = totalTopics == 0 ? 0.0 : totalCovered / totalTopics;

    final visibleSubjects = subjects.where((s) {
      if (_filter == _CoverageFilter.all) return true;
      final c = coverage[s.id];
      // Hiç konu eklenmemiş bir ders ne "devam eden" ne "tamamlanan" —
      // önceden burada "inProgress" döndürülüyordu, yani kullanıcının hiç
      // dokunmadığı dersler yanıltıcı şekilde "Devam eden" filtresinde
      // beliriyordu. Yalnız "Tümü"nde görünsün.
      if (c == null || !c.hasTopics) return false;
      if (_filter == _CoverageFilter.done) return c.ratio >= 1.0;
      return c.ratio < 1.0;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      // Figma'daki "Dersler" ekranı bağımsız bir sekme değil — bu ekran
      // Plan sekmesinden push ediliyor, bu yüzden geri oku gerekli. Home ve
      // Koç'la aynı büyük başlık deseni korunuyor, yalnız AppBar şeffaf ve
      // başlıksız (geri oku dışında).
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          AppHeader(
            initial: (stats.userName?.trim().isNotEmpty ?? false)
                ? stats.userName!.trim()[0].toUpperCase()
                : null,
            rank: ref.watch(rankProvider).rank,
            onProfileTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
            onRankTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RankLadderScreen()),
            ),
          ),
          const SizedBox(height: 34),
          const AppTitleBlock(
            eyebrow: 'ÖĞRENME ALANIN',
            title: 'Dersler',
            subtitle: 'Kaldığın yerden devam et, ilerlemeni tek bakışta gör.',
          ),
          const SizedBox(height: 20),
          if (subjects.isEmpty)
            const EmptyStateCard(
              icon: Icons.checklist_rtl_outlined,
              message:
                  'Önce ders eklemelisin.\nProfil → Derslerim\'den ekleyebilirsin.',
            )
          else ...[
            // Figma sırası: alt açıklama → filtre pilleri → ders kartları.
            // "Genel Kapsama" özet kartı Figma'da yok (kendi eklediğimiz bir
            // değer) — pillerin ALTINA, kart listesinin üstüne alınarak
            // Figma'nın kendi akışı bozulmadan ek bir bonus olarak duruyor.
            Row(
              children: [
                _FilterPill(
                  label: 'Tümü',
                  selected: _filter == _CoverageFilter.all,
                  onTap: () => setState(() => _filter = _CoverageFilter.all),
                ),
                const SizedBox(width: 8),
                _FilterPill(
                  label: 'Devam eden',
                  selected: _filter == _CoverageFilter.inProgress,
                  onTap: () => setState(
                      () => _filter = _CoverageFilter.inProgress),
                ),
                const SizedBox(width: 8),
                _FilterPill(
                  label: 'Tamamlanan',
                  selected: _filter == _CoverageFilter.done,
                  onTap: () => setState(() => _filter = _CoverageFilter.done),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (totalTopics > 0) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.vibrantMint.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                      color: AppColors.vibrantMint.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Eyebrow(text: 'GENEL KAPSAMA', color: AppColors.vibrantMint),
                    const SizedBox(height: 8),
                    Text('%${(overall * 100).round()}',
                        style: AppTextStyles.heading1),
                    const SizedBox(height: 4),
                    Text('$totalCovered / $totalTopics konu işaretlendi',
                        style: AppTextStyles.bodySecondary),
                    const SizedBox(height: 14),
                    AnimatedProgressBar(
                      value: overall,
                      color: AppColors.vibrantMint,
                      backgroundColor: AppColors.surfaceVariant,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
            if (visibleSubjects.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Bu filtreye uyan ders yok.',
                  style: AppTextStyles.bodySecondary,
                  textAlign: TextAlign.center,
                ),
              ),
            ...visibleSubjects.map((s) {
              final c = coverage[s.id] ?? const TopicCoverage(0, 0);
              TopicModel? next;
              for (final t in topics) {
                if (t.subjectId == s.id && t.status == TopicStatus.notStarted) {
                  next = t;
                  break;
                }
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _SubjectRow(
                  name: s.name,
                  color: Color(s.colorValue),
                  coverage: c,
                  nextTopicName: next?.name,
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
        ],
      ),
    );
  }
}

class _SubjectRow extends StatelessWidget {
  final String name;
  final Color color;
  final TopicCoverage coverage;
  final String? nextTopicName;
  final VoidCallback onTap;

  const _SubjectRow({
    required this.name,
    required this.color,
    required this.coverage,
    required this.nextTopicName,
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
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Mentora referansı: nokta yerine pastel ikon kutusu.
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.tonal(color),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.menu_book_rounded, size: 19, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: AppTextStyles.body
                              .copyWith(fontWeight: FontWeight.w700)),
                      if (coverage.hasTopics) ...[
                        const SizedBox(height: 2),
                        Text(
                          '${coverage.total} konu · ${coverage.covered} tamamlandı',
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ],
                  ),
                ),
                Text(
                  coverage.hasTopics ? '%${coverage.percent}' : 'konu yok',
                  style: AppTextStyles.caption.copyWith(
                    color: coverage.hasTopics ? color : AppColors.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (!coverage.hasTopics) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right,
                      size: 18, color: AppColors.textMuted),
                ],
              ],
            ),
            if (coverage.hasTopics) ...[
              const SizedBox(height: 14),
              AnimatedProgressBar(
                value: coverage.ratio,
                color: color,
                backgroundColor: AppColors.surfaceVariant,
                height: 5,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      nextTopicName != null
                          ? 'Sıradaki: $nextTopicName'
                          : 'Tüm konular işaretlendi',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Tümü / Devam eden / Tamamlanan filtre pili — Mentora "Dersler" referansı.
class _FilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? Colors.transparent : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: selected ? AppColors.onColor(AppColors.primary) : AppColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
