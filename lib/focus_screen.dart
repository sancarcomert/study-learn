// lib/focus_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';
import 'focus_provider.dart';

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
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _ticker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Saniyede bir kez tamamlanan, tamamlanınca kendini sıfırlayıp
    // tekrar başlatan bir controller. repeat() KULLANILMIYOR çünkü
    // repeat() frame başına (saniyede ~60 kez) değer güncelliyor ve
    // bu, Windows desktop'ta mouse tracker assertion'ını tetikliyordu.
    // Bu yapı gerçekten saniyede bir tetiklenir.
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );

    _ticker.addStatusListener(_onTickComplete);
    _ticker.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(focusTimerProvider.notifier).start(
            taskId: widget.taskId,
            duration: Duration(minutes: widget.initialMinutes),
          );
    });
  }

  void _onTickComplete(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;

    ref.read(focusTimerProvider.notifier).checkCompletion();
    if (mounted) setState(() {});

    _ticker
      ..reset()
      ..forward();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState appState) {
    if (appState == AppLifecycleState.resumed) {
      ref.read(focusTimerProvider.notifier).checkCompletion();
      if (mounted) setState(() {});
    }
  }

  void _exit() {
    _ticker.stop();
    Navigator.maybePop(context);
  }

  @override
  void dispose() {
    _ticker.removeStatusListener(_onTickComplete);
    _ticker.dispose();
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

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          _ticker.stop();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary,
            ),
            onPressed: _exit,
          ),
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
                      state.isCompleted ? '🎉' : _formatDuration(remaining),
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
                        _exit();
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
                      _exit();
                    },
                    child: const Text('Tamam'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}