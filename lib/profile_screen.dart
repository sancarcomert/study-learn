import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import 'about_screen.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';
import 'notification_service.dart';
import 'rank_ladder_screen.dart';
import 'rank_provider.dart';
import 'rank_system.dart';
import 'stats_provider.dart';
import 'subject_provider.dart';
import 'subjects_screen.dart';
import 'task_provider.dart';
import 'tap_scale.dart';
import 'user_stats_model.dart';
import 'widgets/data_backup_section.dart';
import 'widgets/section_header.dart';
import 'widgets/rank_bar.dart';
import 'widgets/rank_emblem.dart';

void _showEditNameDialog(
    BuildContext context, WidgetRef ref, String? currentName) {
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
                  // CTA hiyerarşisi: altın yalnız birincil aksiyon için.
                  color: g == current
                      ? AppColors.secondary
                      : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  UserStatsModel.gradeLabel(g),
                  style: AppTextStyles.body.copyWith(
                    color: g == current
                        ? AppColors.onColor(AppColors.secondary)
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
                      gradient: AppColors.primaryGradient,
                      shape: BoxShape.circle,
                      boxShadow: [AppColors.glow(AppColors.primary)],
                    ),
                    child: const Icon(
                      Icons.person_outline,
                      color: AppColors.ink,
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
                  Icon(
                    Icons.edit_outlined,
                    color: AppColors.textSecondary,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 28),

          // SINIF + DERSLERİM — önceden iki ayrı eyebrow/kart bloğuydu,
          // dikey yığılmayı azaltmak için tek "HESAP" grubuna toplandı.
          const SectionHeader(title: 'Hesap'),
          const SizedBox(height: 10),
          _ProfileRow(
            icon: Icons.school_outlined,
            tint: AppColors.secondary,
            label: UserStatsModel.gradeLabel(stats.gradeLevel),
            onTap: () => _showGradePicker(context, ref, stats.gradeLevel),
          ),
          const SizedBox(height: 10),
          _ProfileRow(
            icon: Icons.menu_book_outlined,
            tint: AppColors.secondary,
            label: subjects.isEmpty
                ? 'Ders ekle ve düzenle'
                : '${subjects.length} ders — düzenle / sil',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SubjectsScreen()),
            ),
          ),

          const SizedBox(height: 28),

          const SectionHeader(title: 'Rütbe'),
          const SizedBox(height: 10),
          TapScale(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RankLadderScreen()),
            ),
            child: _RankCard(info: ref.watch(rankProvider)),
          ),

          const SizedBox(height: 28),

          // SERİ + dondurma + HEDEF — üçü de "günlük tempo" hakkında,
          // tek grupta toplandı (önceden ayrı ayrı 3 eyebrow'du).
          const SectionHeader(title: 'Seri & Hedef'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ProfileStatCard(
                  icon: Icons.local_fire_department_outlined,
                  iconColor: AppColors.secondary,
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
              color: AppColors.secondary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(Icons.ac_unit,
                    color: AppColors.secondary, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stats.freezesAvailable > 0
                            ? '${stats.freezesAvailable} dondurma hakkın var'
                            : 'Dondurma hakkın kalmadı',
                        style: AppTextStyles.bodySecondary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Bir gün ara verirsen serini otomatik korur.',
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: AppColors.secondary.withValues(alpha: 0.22)),
              boxShadow: AppColors.softShadow,
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.flag_outlined,
                      size: 18, color: AppColors.secondary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text('Günlük hedef', style: AppTextStyles.body),
                ),
                Text(
                  '${stats.dailyGoal} görev',
                  style: AppTextStyles.heading3
                      .copyWith(color: AppColors.secondary),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          const SectionHeader(title: 'Çalışma Süresi'),
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
                  iconColor: AppColors.secondary,
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

          // BİLDİRİMLER + HAKKINDA — ikisi de "AYARLAR" başlığı altında;
          // Veri yedekleme kendi başlığını taşıdığı için (VERİLER) ayrı
          // bırakıldı, üst üste iki eyebrow görünmesin diye.
          const SectionHeader(title: 'Ayarlar'),
          const SizedBox(height: 10),
          _ThemeModeRow(
            mode: stats.themeMode,
            onChanged: (mode) =>
                ref.read(statsProvider.notifier).updateThemeMode(mode),
          ),
          const SizedBox(height: 10),
          const _NotificationStatusCard(),
          const SizedBox(height: 10),
          _ProfileRow(
            icon: Icons.shield_outlined,
            tint: AppColors.secondary,
            label: 'Verin sende — gizlilik ve şeffaflık',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AboutScreen()),
            ),
          ),

          const SizedBox(height: 28),

          const DataBackupSection(),
        ],
      ),
    );
  }
}

/// Profil'deki tıklanabilir tek satırlık ayar/gezinti kartı — SINIF,
/// DERSLERİM, HAKKINDA hepsi aynı çıplak Container'ı kopyalıyordu. Her
/// satır artık about_screen.dart'taki _InfoRow ile aynı dilde: dolu ikon
/// rozeti + kendi vurgu rengi, salt metin ikonu değil.
class _ProfileRow extends StatelessWidget {
  final IconData icon;
  final Color tint;
  final String label;
  final VoidCallback onTap;

  const _ProfileRow({
    required this.icon,
    required this.tint,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: tint.withValues(alpha: 0.22)),
          boxShadow: AppColors.softShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: tint),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label, style: AppTextStyles.body),
            ),
            Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

/// Ayarlar'daki görünüm (açık/koyu tema) satırı — ikon rozeti + etiket +
/// sağda iki küçük seçim hapı, _ProfileRow ile aynı kart dilinde ama
/// gezinti yerine yerinde (inline) bir tercih.
class _ThemeModeRow extends StatelessWidget {
  final String mode;
  final ValueChanged<String> onChanged;

  const _ThemeModeRow({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isLight = mode == 'light';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.22)),
        boxShadow: AppColors.softShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isLight ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              size: 18,
              color: AppColors.secondary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text('Görünüm', style: AppTextStyles.body),
          ),
          _ThemeChip(
            label: 'Açık',
            selected: isLight,
            onTap: () => onChanged('light'),
          ),
          const SizedBox(width: 6),
          _ThemeChip(
            label: 'Koyu',
            selected: !isLight,
            onTap: () => onChanged('dark'),
          ),
        ],
      ),
    );
  }
}

class _ThemeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.16)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.5)
                : AppColors.textMuted.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: selected ? AppColors.primary : AppColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _RankCard extends StatelessWidget {
  final RankInfo info;

  const _RankCard({required this.info});

  @override
  Widget build(BuildContext context) {
    final color = Color(info.colorHex);

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
            children: [
              RankEmblem(rank: info.rank, size: 64),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(info.name, style: AppTextStyles.heading2),
                        const Spacer(),
                        Text('${info.rank}/6',
                            style:
                                AppTextStyles.caption.copyWith(color: color)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      info.atMax
                          ? 'En üst rütbedesin'
                          : '${info.nextName} için ${info.xpToNextRank} XP',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          RankBar(info: info, height: 18),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child:
                    Text('Toplam ${info.xp} XP', style: AppTextStyles.caption),
              ),
              Text('Tüm rütbeler',
                  style: AppTextStyles.caption.copyWith(color: color)),
              Icon(Icons.chevron_right, size: 16, color: color),
            ],
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
        color: iconColor.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: iconColor.withValues(alpha: 0.45)),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: iconColor, shape: BoxShape.circle),
            child: Icon(icon, color: AppColors.onColor(iconColor), size: 20),
          ),
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

/// Bildirim/odak seansı hatırlatmalarının canlı izin durumu. Home ve Odak
/// ekranlarındaki izin diyalogları kullanıcı başına yalnızca bir kez
/// çıkıyor — reddedilirse ya da sistem popup'ı kapatılırsa bildirimler
/// kalıcı ve sessizce kapalı kalıyordu, kullanıcının fark edip düzeltmesi
/// için hiçbir yol yoktu. Bu kart durumu her açılışta gerçekten sorar
/// (kayıtlı bir bayrağa değil) ve kapalıysa doğrudan sistem ayarına götürür.
class _NotificationStatusCard extends StatefulWidget {
  const _NotificationStatusCard();

  @override
  State<_NotificationStatusCard> createState() =>
      _NotificationStatusCardState();
}

class _NotificationStatusCardState extends State<_NotificationStatusCard>
    with WidgetsBindingObserver {
  bool? _notificationsOn;
  bool? _exactAlarmOn;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Kullanıcı sistem Ayarlar'dan dönünce durumu tazele.
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final notif =
        await NotificationService.instance.hasNotificationPermission();
    final exact = await NotificationService.instance.hasExactAlarmPermission();
    if (!mounted) return;
    setState(() {
      _notificationsOn = notif;
      _exactAlarmOn = exact;
    });
  }

  Future<void> _fix() async {
    if (_notificationsOn == false) {
      await openAppSettings();
    } else if (_exactAlarmOn == false) {
      // Bu özel izin türünde .request() doğrudan doğru sistem ekranını açar.
      await NotificationService.instance.requestExactAlarmPermission();
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = _notificationsOn == null || _exactAlarmOn == null;
    final allOn = _notificationsOn == true && _exactAlarmOn == true;

    return TapScale(
      onTap: loading || allOn ? null : _fix,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppColors.softShadow,
        ),
        child: Row(
          children: [
            Icon(
              allOn
                  ? Icons.notifications_active_outlined
                  : Icons.notifications_off_outlined,
              size: 20,
              color: allOn ? AppColors.success : AppColors.warning,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loading
                        ? 'Kontrol ediliyor…'
                        : allOn
                            ? 'Hatırlatmalar açık'
                            : 'Hatırlatmalar kapalı',
                    style: AppTextStyles.body,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    loading
                        ? ' '
                        : allOn
                            ? 'Odak seansı ve görev hatırlatmaları zamanında gelecek.'
                            : 'Odak seansı bitince ya da görev vakti gelince '
                                'haber veremeyiz. Açmak için dokun.',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
            if (!loading && !allOn)
              Icon(Icons.chevron_right,
                  size: 20, color: AppColors.textMuted),
          ],
        ),
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
