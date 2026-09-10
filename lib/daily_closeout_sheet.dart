import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';
import 'daily_closeout_provider.dart';
import 'focus_session_provider.dart';
import 'stats_provider.dart';
import 'task_provider.dart';
import 'widgets/app_buttons.dart';
import 'widgets/app_snackbar.dart';

/// "Bugünü kapat" ritüeli (docs/rakip_analizi §6 B3). Akşam kısa özet +
/// yarına tek cümlelik niyet. Sakin bir kapanış — kutlama/konfeti yok.
void showDailyCloseoutSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _DailyCloseoutSheet(),
  );
}

class _DailyCloseoutSheet extends ConsumerStatefulWidget {
  const _DailyCloseoutSheet();

  @override
  ConsumerState<_DailyCloseoutSheet> createState() => _DailyCloseoutSheetState();
}

class _DailyCloseoutSheetState extends ConsumerState<_DailyCloseoutSheet> {
  late final TextEditingController _intent;

  @override
  void initState() {
    super.initState();
    final existing = ref.read(todayCloseoutProvider)?.intent ?? '';
    _intent = TextEditingController(text: existing);
  }

  @override
  void dispose() {
    _intent.dispose();
    super.dispose();
  }

  ({int completed, int focusMin, int streak}) _todaySnapshot() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final completed = ref
        .read(taskProvider)
        .where((t) =>
            t.isCompleted &&
            t.dueDate.year == today.year &&
            t.dueDate.month == today.month &&
            t.dueDate.day == today.day)
        .length;

    final focusMin = ref.read(focusMinutesByDayProvider)[today] ?? 0;
    final streak = ref.read(statsProvider).currentStreak;

    return (completed: completed, focusMin: focusMin, streak: streak);
  }

  void _close() {
    final s = _todaySnapshot();
    ref.read(dailyCloseoutProvider.notifier).close(
          completedTasks: s.completed,
          focusMinutes: s.focusMin,
          intent: _intent.text,
        );
    Navigator.of(context).pop();
    AppSnackBar.success(context, 'İyi dinlen 🌙 Yarın görüşürüz.');
  }

  @override
  Widget build(BuildContext context) {
    final s = _todaySnapshot();
    final alreadyClosed = ref.watch(todayCloseoutProvider) != null;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bugünü kapat', style: AppTextStyles.heading2),
          const SizedBox(height: 4),
          Text(
            'Kısa bir özet, sonra yarına tek cümle.',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _SummaryRow(
                  icon: Icons.check_circle_outline,
                  color: AppColors.success,
                  text: s.completed == 0
                      ? 'Bugün görev işaretlemedin'
                      : '${s.completed} görev bitirdin',
                ),
                if (s.focusMin > 0)
                  _SummaryRow(
                    icon: Icons.timer_outlined,
                    color: AppColors.primary,
                    text: '${s.focusMin} dk odaklandın',
                  ),
                if (s.streak > 0)
                  _SummaryRow(
                    icon: Icons.local_fire_department_outlined,
                    color: AppColors.warning,
                    text: '${s.streak} günlük seri',
                  ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          Text('Yarın için tek cümle', style: AppTextStyles.eyebrow),
          const SizedBox(height: 8),
          TextField(
            controller: _intent,
            autofocus: false,
            maxLength: 90,
            maxLines: 2,
            minLines: 1,
            textCapitalization: TextCapitalization.sentences,
            style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Örn. Sabah paragraf, akşam türev tekrarı',
              filled: true,
              fillColor: AppColors.surfaceVariant,
              counterStyle: AppTextStyles.caption,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 8),
          PrimaryButton(
            label: alreadyClosed ? 'Güncelle' : 'Günü kapat',
            icon: Icons.nightlight_outlined,
            onPressed: _close,
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _SummaryRow({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
