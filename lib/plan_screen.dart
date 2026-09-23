import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';
import 'coach_screen.dart';
import 'format_minutes.dart';
import 'deneme_provider.dart';
import 'deneme_screen.dart';
import 'focus_screen.dart';
import 'focus_session_provider.dart';
import 'konu_takip_screen.dart';
import 'topic_provider.dart';
import 'tap_scale.dart';
import 'stats_provider.dart';
import 'rank_provider.dart';
import 'profile_screen.dart';
import 'rank_ladder_screen.dart';
import 'widgets/eyebrow.dart';
import 'widgets/section_header.dart';
import 'widgets/app_header.dart';

/// Plan sekmesi — Koç/Konu Takip/Odak/Deneme'ye giriş noktası. Önceden dört
/// özdeş satırdı (aynı boyut, hiçbir canlı veri); Home'daki bento diliyle
/// tutarlı hale getirildi: Koç tek başına bir hero (asıl AI girişi), diğer
/// üçü Home'un bento kartlarıyla aynı eyebrow/değer/alt-metin düzeninde,
/// gerçek ilerleme verisiyle (kapsama %, bu hafta odak, son deneme neti).
class PlanScreen extends ConsumerWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coverage = ref.watch(coverageBySubjectProvider);
    final totalTopics = coverage.values.fold<int>(0, (s, c) => s + c.total);
    final totalCovered = coverage.values.fold<int>(0, (s, c) => s + c.covered);

    final focusThisWeek = ref.watch(focusThisWeekMinutesProvider);
    final latestDeneme = ref.watch(latestDenemeProvider);
    final stats = ref.watch(statsProvider);

    return Scaffold(
      body: SafeArea(
        child: ListView(
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
            eyebrow: 'PLANLAMA',
            title: 'Plan',
            subtitle: 'Çalışma koçu, konu takibi ve denemelerin tek yerde.',
          ),
          const SizedBox(height: 20),
          const SectionHeader(title: 'Bugünü Kur'),
          const SizedBox(height: 12),
          _CoachHero(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CoachScreen()),
            ),
          ),
          const SizedBox(height: 24),
          const SectionHeader(title: 'İlerlemeni Tut'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _PlanBentoCard(
                  icon: Icons.checklist_rtl_outlined,
                  title: 'Konu Takip',
                  tint: AppColors.primary,
                  value: totalTopics == 0
                      ? '—'
                      : '%${(totalCovered / totalTopics * 100).round()}',
                  sub: totalTopics == 0
                      ? 'konu ekle'
                      : '$totalCovered/$totalTopics işaretli',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const KonuTakipScreen()),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PlanBentoCard(
                  icon: Icons.timer_outlined,
                  title: 'Odak Seansı',
                  tint: AppColors.primary,
                  value: focusThisWeek == 0
                      ? '—'
                      : formatMinutes(focusThisWeek),
                  sub: focusThisWeek == 0 ? 'bu hafta boş' : 'bu hafta',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FocusScreen()),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _PlanBentoCard(
            icon: Icons.insights_outlined,
            title: 'Deneme Takip',
            tint: AppColors.eyebrowRose,
            fullWidth: true,
            value: latestDeneme == null
                ? '—'
                : latestDeneme.totalNet.toStringAsFixed(1),
            sub: latestDeneme == null
                ? 'TYT/AYT netini gir, trendini gör'
                : 'son ${latestDeneme.examType} neti',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DenemeScreen()),
            ),
          ),
        ],
        ),
      ),
    );
  }
}

/// Koç girişi — diğer üç kartın üstünde tek bir giriş, çünkü Koç plan
/// oluşturmanın kendisi (diğerleri ilerleme takibi). Bilinçli olarak
/// SADE: Home'un hero'su ("wow" olan tek yer) taklit edilmiyor — burada
/// düz kart + tek renkli ikon rozeti yeterli. 2026-09-16: gradyan zemin ve
/// ikon parıltısı kaldırıldı — her ekranın kendi "özel" anını iddia etmesi
/// hiçbirini özel bırakmıyordu (kullanıcı geri bildirimi).
class _CoachHero extends StatelessWidget {
  final VoidCallback onTap;
  const _CoachHero({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tint = AppColors.vibrantViolet;
    return TapScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: tint.withValues(alpha: 0.25)),
          boxShadow: AppColors.softShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.tonal(tint),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.auto_awesome_outlined, color: tint),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Çalışma Koçu', style: AppTextStyles.heading3),
                  const SizedBox(height: 4),
                  Text(
                    'Sohbetle bugünkü planını oluştur',
                    style: AppTextStyles.bodySecondary,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.arrow_forward_rounded,
                  size: 18, color: tint),
            ),
          ],
        ),
      ),
    );
  }
}

/// Home'daki _BentoCard ile aynı görsel dil (eyebrow + büyük değer + alt
/// metin, tint zeminde) — burada dokunulabilir bir giriş noktası olarak.
class _PlanBentoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color tint;
  final String value;
  final String sub;
  final VoidCallback onTap;
  final bool fullWidth;

  const _PlanBentoCard({
    required this.icon,
    required this.title,
    required this.tint,
    required this.value,
    required this.sub,
    required this.onTap,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      child: Container(
        width: fullWidth ? double.infinity : null,
        height: 130,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          // Koyu zeminde tint dolgusu ("cam" hissi) çalışıyor, ama açık
          // zeminde aynı alpha muddy/soluk bir pastel gibi duruyor — açık
          // temada beyaz yüzey + tint kenarlık/ikon rozeti (Profil'deki
          // _ProfileRow ile aynı dil) daha temiz okunuyor.
          color: AppColors.isDark ? tint.withValues(alpha: 0.20) : AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: tint.withValues(alpha: AppColors.isDark ? 0.45 : 0.3),
            width: 1,
          ),
          boxShadow: AppColors.softShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Eyebrow(text: title.toUpperCase(), color: tint),
                Container(
                  width: 30,
                  height: 30,
                  decoration:
                      BoxDecoration(color: tint, shape: BoxShape.circle),
                  child: Icon(icon, size: 16, color: AppColors.onColor(tint)),
                ),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: AppTextStyles.heading2,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (fullWidth) ...[
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(sub, style: AppTextStyles.caption),
                  ),
                ],
              ],
            ),
            if (!fullWidth) Text(sub, style: AppTextStyles.caption),
          ],
        ),
      ),
    );
  }
}
