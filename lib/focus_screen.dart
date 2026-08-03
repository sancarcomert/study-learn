// lib/focus_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';
import 'focus_provider.dart';

/// Bir görev üzerinde odaklanma (Pomodoro) oturumu ekranı.
///
/// Kalan süreyi [FocusTimerState.remainingAt] üzerinden, saniyede bir
/// yeniden hesaplayarak gösterir. Uygulama arka plandan öne geldiğinde
/// (`AppLifecycleState.resumed`) kalan süre anında yeniden değerlendirilir
/// ve tamamlanma kontrolü yapılır — bu, ileride eklenecek bildirim akışıyla
/// aynı anda tutarlı çalışacak şekilde tasarlanmıştır.
class FocusScreen extends ConsumerStatefulWidget {
  final String taskId;
  final String taskTitle;
  final int initialMinutes;

  const FocusScreen({
    super.key,
    required this.taskId,
    required this.taskTitle,
    required this.initialMinutes,
  });

  @override
  ConsumerState<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends ConsumerState<FocusScreen>
    with WidgetsBindingObserver {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    ref.read(focusTimerProvider.notifier).start(
          taskId: widget.taskId,
          duration: Duration(minutes: widget.initialMinutes),
        );

    _startTicker();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      ref.read(focusTimerProvider.notifier).checkCompletion();
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState appState) {
    if (appState == AppLifecycleState.resumed) {
      ref.read(focusTimerProvider.notifier).checkCompletion();
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(focusTimerProvider);
    final remaining = state.remainingAt(DateTime.now());

    final total = state.totalDuration.inSeconds == 0
        ? 1
        : state.totalDuration.inSeconds;
    final progress = 1 - (remaining.inSeconds / total);

    return Scaffold(
      appBar: AppBar(
        title: Text('Odaklan', style: AppTextStyles.heading2),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              widget.taskTitle,
              style: AppTextStyles.bodySecondary,
              textAlign: TextAlign.center,
            ),

            const Spacer(),

            Container(
              width: 220,
              height: 220,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surface,
                boxShadow: AppColors.cardShadow,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 220,
                    height: 220,
                    child: CircularProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      strokeWidth: 8,
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      valueColor: AlwaysStoppedAnimation(
                        state.isCompleted
                            ? AppColors.success
                            : AppColors.primary,
                      ),
                    ),
                  ),
                  Text(
                    state.isCompleted
                        ? '🎉'
                        : _formatDuration(remaining),
                    style: AppTextStyles.heading1,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Text(
              state.isCompleted
                  ? 'Oturum tamamlandı!'
                  : state.isPaused
                      ? 'Duraklatıldı'
                      : 'Odaklanma zamanı',
              style: AppTextStyles.body,
            ),

            const Spacer(),

            if (!state.isCompleted)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  OutlinedButton(
                    onPressed: () {
                      ref.read(focusTimerProvider.notifier).cancel();
                      Navigator.pop(context);
                    },
                    child: const Text('İptal'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      final notifier = ref.read(focusTimerProvider.notifier);
                      if (state.isPaused) {
                        notifier.resume();
                      } else {
                        notifier.pause();
                      }
                    },
                    child: Text(state.isPaused ? 'Devam Et' : 'Duraklat'),
                  ),
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    ref.read(focusTimerProvider.notifier).reset();
                    Navigator.pop(context);
                  },
                  child: const Text('Tamam'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}