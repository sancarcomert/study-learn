import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';
import 'focus_session_model.dart';
import 'focus_session_provider.dart';
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

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Odak Geçmişi', style: AppTextStyles.heading2),
      ),
      body: sessions.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(20),
              child: EmptyStateCard(
                icon: Icons.history_outlined,
                message: 'Henüz odak seansı kaydın yok.\n'
                    'Bir seansı bitirince burada görünür.',
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
                      const Icon(Icons.timer_outlined,
                          size: 18, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text('Bu hafta', style: AppTextStyles.body),
                      ),
                      Text(
                        '$weekMin dk',
                        style: AppTextStyles.heading3
                            .copyWith(color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
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
                          child: const Icon(Icons.delete_outline,
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
                        child: _SessionRow(session: s),
                      ),
                    )),
              ],
            ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  final FocusSession session;
  const _SessionRow({required this.session});

  @override
  Widget build(BuildContext context) {
    final isPomodoro = session.mode == 'pomodoro';
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
              color: AppColors.tonal(AppColors.primary),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPomodoro ? Icons.timelapse_outlined : Icons.timer_outlined,
              size: 18,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPomodoro ? 'Pomodoro' : 'Serbest',
                  style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('d MMMM y · HH:mm', 'tr_TR').format(session.endedAt),
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          Text(
            '${session.minutes} dk',
            style: AppTextStyles.heading3.copyWith(color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}
