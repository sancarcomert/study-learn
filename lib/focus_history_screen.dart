import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';
import 'focus_session_model.dart';
import 'focus_session_provider.dart';
import 'subject_provider.dart';
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
        .map((e) => (name: subjectName(e.key) ?? 'Silinmiş ders', minutes: e.value))
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
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
                ...sessions.map((s) => Padding(
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
                          child: Icon(Icons.delete_outline,
                              color: AppColors.danger),
                        ),
                        onDismissed: (_) {
                          final deleted = ref
                              .read(focusSessionProvider.notifier)
                              .deleteSession(s.id);
                          if (deleted != null) {
                            AppSnackBar.undo(
                              context,
                              '${_modeLabel(deleted.mode)} · '
                              '${deleted.minutes} dk silindi',
                              onUndo: () => ref
                                  .read(focusSessionProvider.notifier)
                                  .restoreSession(deleted),
                            );
                          }
                        },
                        child: _SessionRow(
                          session: s,
                          subjectName: subjectName(s.subjectId),
                        ),
                      ),
                    )),
              ],
            ),
    );
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
              color: isPomodoro ? AppColors.vibrantViolet : AppColors.vibrantSky,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
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
              color: isPomodoro ? AppColors.vibrantViolet : AppColors.vibrantSky,
            ),
          ),
        ],
      ),
    );
  }
}
