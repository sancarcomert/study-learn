import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';
import 'focus_session_model.dart';
import 'focus_session_provider.dart';
import 'subject_provider.dart';
import 'tap_scale.dart';
import 'topic_model.dart';
import 'topic_provider.dart';
import 'widgets/app_snackbar.dart';
import 'widgets/empty_state_card.dart';
import 'widgets/eyebrow.dart';

/// Odak seansı geçmişi (P0-6) — kaydedilen her seansı gör, yanlış/istemsiz
/// olanı sil. `focus_sessions` box'ı zaten vardı, ekranı yoktu.
///
/// Not: silme yalnız bu günlük kaydı (günlük/haftalık grafiklerin kaynağı)
/// kaldırır. Profil'deki kümülatif toplam — rütbe/seri gibi — geriye
/// gitmez; bilerek.
class FocusHistoryScreen extends ConsumerWidget {
  const FocusHistoryScreen({super.key});

  static String _modeLabel(String mode) =>
      mode == 'pomodoro' ? 'Pomodoro' : 'Serbest';

  /// Bir seansın hangi zaman grubuna düştüğü — düz, tarihsiz bir liste
  /// yerine "Bugün/Dün/Bu Hafta/Daha Eski" başlıklarıyla gruplamak için.
  /// `sessions` zaten en yeniden en eskiye sıralı geldiğinden (bkz.
  /// `focusSessionsDescendingProvider`) gruplar tek geçişte, sıralı çıkar.
  static String _dayBucket(DateTime today, DateTime endedAt) {
    final day = DateTime(endedAt.year, endedAt.month, endedAt.day);
    final diff = today.difference(day).inDays;
    if (diff <= 0) return 'Bugün';
    if (diff == 1) return 'Dün';
    if (diff <= 7) return 'Bu Hafta';
    return 'Daha Eski';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(focusSessionsDescendingProvider);
    final weekMin = ref.watch(focusThisWeekMinutesProvider);
    final bySubject = ref.watch(focusMinutesBySubjectProvider);
    final subjects = ref.watch(subjectProvider);
    String? subjectName(String? id) {
      if (id == null) return null;
      return subjects.where((s) => s.id == id).firstOrNull?.name;
    }

    final subjectTotals = bySubject.entries
        .map((e) =>
            (name: subjectName(e.key) ?? 'Silinmiş ders', minutes: e.value))
        .toList()
      ..sort((a, b) => b.minutes.compareTo(a.minutes));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Odak Geçmişi', style: AppTextStyles.heading2),
      ),
      body: sessions.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: EmptyStateCard(
                  icon: Icons.history_outlined,
                  message: 'Henüz odak seansı kaydın yok.\n'
                      'Bir seansı bitirince burada görünür.',
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: AppColors.softShadow,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.timer_outlined,
                          size: 18, color: AppColors.vibrantSky),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text('Bu hafta', style: AppTextStyles.body),
                      ),
                      Text(
                        '$weekMin dk',
                        style: AppTextStyles.heading3
                            .copyWith(color: AppColors.vibrantSky),
                      ),
                    ],
                  ),
                ),
                if (subjectTotals.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  const Eyebrow(text: 'HANGİ DERSE ÇALIŞTIN'),
                  const SizedBox(height: 4),
                  Text(
                    'Tüm zamanlar — ders seçerek başlattığın seanslar.',
                    style: AppTextStyles.caption,
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: AppColors.softShadow,
                    ),
                    child: Column(
                      children: [
                        for (var i = 0; i < subjectTotals.length; i++)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(subjectTotals[i].name,
                                      style: AppTextStyles.body),
                                ),
                                Text(
                                  '${subjectTotals[i].minutes} dk',
                                  style: AppTextStyles.body.copyWith(
                                    color: AppColors.vibrantSky,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                const Eyebrow(text: 'GEÇMİŞ'),
                const SizedBox(height: 4),
                Text(
                  'İstemeden kaydedilen ya da yanlış bir seansı silebilirsin.',
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: 12),
                ..._historyChildren(context, ref, sessions, subjectName),
              ],
            ),
    );
  }

  /// "GEÇMİŞ" listesini gün grubu başlıklarıyla (Bugün/Dün/Bu Hafta/Daha
  /// Eski) üretir — önceden tüm seanslar tarihsiz, düz bir yığındı; hangi
  /// kaydın ne zaman olduğunu anlamak için her satırın kendi küçük tarih
  /// yazısını okumak gerekiyordu.
  List<Widget> _historyChildren(
    BuildContext context,
    WidgetRef ref,
    List<FocusSession> sessions,
    String? Function(String?) subjectName,
  ) {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final children = <Widget>[];
    String? lastBucket;

    for (final s in sessions) {
      final bucket = _dayBucket(todayStart, s.endedAt);
      if (bucket != lastBucket) {
        if (lastBucket != null) children.add(const SizedBox(height: 14));
        children.add(Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            bucket.toUpperCase(),
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
        ));
        lastBucket = bucket;
      }
      children.add(Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Dismissible(
          key: ValueKey(s.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
              color: AppColors.tonal(AppColors.danger),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.delete_outline, color: AppColors.danger),
          ),
          onDismissed: (_) {
            final deleted =
                ref.read(focusSessionProvider.notifier).deleteSession(s.id);
            if (deleted != null) {
              AppSnackBar.undo(
                context,
                '${_modeLabel(deleted.mode)} · ${deleted.minutes} dk silindi',
                onUndo: () => ref
                    .read(focusSessionProvider.notifier)
                    .restoreSession(deleted),
              );
            }
          },
          child: TapScale(
            onTap: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              backgroundColor: AppColors.surface,
              showDragHandle: true,
              builder: (_) => _EditSessionSheet(session: s),
            ),
            child: _SessionRow(
              session: s,
              subjectName: subjectName(s.subjectId),
            ),
          ),
        ),
      ));
    }
    return children;
  }
}

class _SessionRow extends StatelessWidget {
  final FocusSession session;
  final String? subjectName;
  const _SessionRow({required this.session, this.subjectName});

  @override
  Widget build(BuildContext context) {
    final isPomodoro = session.mode == 'pomodoro';
    final modeLabel = isPomodoro ? 'Pomodoro' : 'Serbest';
    final title = subjectName ?? modeLabel;
    final subtitleParts = <String>[
      if (subjectName != null) modeLabel,
      DateFormat('d MMMM y · HH:mm', 'tr_TR').format(session.endedAt),
    ];
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
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.tonal(
                  isPomodoro ? AppColors.vibrantViolet : AppColors.vibrantSky),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPomodoro ? Icons.timelapse_outlined : Icons.timer_outlined,
              size: 18,
              color:
                  isPomodoro ? AppColors.vibrantViolet : AppColors.vibrantSky,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style:
                      AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitleParts.join(' · '),
                  style: AppTextStyles.caption,
                ),
                if (session.note != null && session.note!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    session.note!,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textMuted,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          Text(
            '${session.minutes} dk',
            style: AppTextStyles.heading3.copyWith(
              color:
                  isPomodoro ? AppColors.vibrantViolet : AppColors.vibrantSky,
            ),
          ),
          const SizedBox(width: 6),
          // Sessiz düzenleme ipucu — aksi halde satırın dokunulabilir
          // olduğunu gösteren hiçbir işaret yoktu (yalnız kaydırınca silme
          // çıkıyordu, düzenleme keşfedilemiyordu).
          Icon(Icons.edit_outlined, size: 15, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

/// Yanlış kaydedilmiş bir seansı düzeltme formu (P0-6). Silme + yeniden
/// oluşturma yerine tek adım: ders/konu/süre/not değiştirilir, seansın
/// TARİHİ/NASIL GEÇTİĞİ (feeling) ve modu (Serbest/Pomodoro) sabit kalır —
/// bunlar düzenlenecek bir "yazım hatası" değil, o seansın gerçek geçmişi.
class _EditSessionSheet extends ConsumerStatefulWidget {
  final FocusSession session;
  const _EditSessionSheet({required this.session});

  @override
  ConsumerState<_EditSessionSheet> createState() => _EditSessionSheetState();
}

class _EditSessionSheetState extends ConsumerState<_EditSessionSheet> {
  late String? _subjectId = widget.session.subjectId;
  late String? _topicId = widget.session.topicId;
  late final TextEditingController _minutesController =
      TextEditingController(text: widget.session.minutes.toString());
  late final TextEditingController _noteController =
      TextEditingController(text: widget.session.note ?? '');

  @override
  void dispose() {
    _minutesController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _save() {
    final minutes = int.tryParse(_minutesController.text.trim());
    if (minutes == null || minutes < 1) {
      AppSnackBar.error(context, 'Geçerli bir dakika gir');
      return;
    }
    ref.read(focusSessionProvider.notifier).updateSession(
          widget.session.id,
          minutes: minutes,
          subjectId: _subjectId,
          topicId: _topicId,
          note: _noteController.text,
        );
    Navigator.pop(context);
    AppSnackBar.success(context, 'Seans güncellendi');
  }

  Widget _chip({
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return TapScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: selected ? AppColors.onColor(color) : color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subjects = ref.watch(subjectProvider);
    final topics = _subjectId == null
        ? const <TopicModel>[]
        : ref.watch(topicsForSubjectProvider(_subjectId!));

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Seansı düzenle', style: AppTextStyles.heading3),
              const SizedBox(height: 16),
              Text('DERS', style: AppTextStyles.eyebrow),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _chip(
                    label: 'Derssiz',
                    selected: _subjectId == null,
                    color: AppColors.textSecondary,
                    onTap: () => setState(() {
                      _subjectId = null;
                      _topicId = null;
                    }),
                  ),
                  for (final s in subjects)
                    _chip(
                      label: s.name,
                      selected: _subjectId == s.id,
                      color: Color(s.colorValue),
                      onTap: () => setState(() {
                        _subjectId = s.id;
                        _topicId = null;
                      }),
                    ),
                ],
              ),
              if (topics.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text('KONU', style: AppTextStyles.eyebrow),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final t in topics)
                      _chip(
                        label: t.name,
                        selected: _topicId == t.id,
                        color: AppColors.primary,
                        onTap: () => setState(
                            () => _topicId = _topicId == t.id ? null : t.id),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              Text('DAKİKA', style: AppTextStyles.eyebrow),
              const SizedBox(height: 8),
              TextField(
                controller: _minutesController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: 'dakika'),
              ),
              const SizedBox(height: 16),
              Text('NOT', style: AppTextStyles.eyebrow),
              const SizedBox(height: 8),
              TextField(
                controller: _noteController,
                decoration: const InputDecoration(hintText: 'opsiyonel'),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onColor(AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Kaydet'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
