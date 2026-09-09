import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';
import 'stats_provider.dart';
import 'tap_scale.dart';
import 'widgets/eyebrow.dart';
import 'widgets/animated_progress_bar.dart';
import 'widgets/app_snackbar.dart';

/// Tek seferlik odak seansı — yerel kronometre. "Bitir"e basınca geçen
/// süre (tam dakika) TOPLAM ÇALIŞMA'ya eklenir. Pomodoro döngüsü (çalış/
/// mola) v1'de yok; sadece sayaç + hedef göstergesi.
class FocusScreen extends ConsumerStatefulWidget {
  final String? initialNote;
  final int? initialTargetMin;

  const FocusScreen({super.key, this.initialNote, this.initialTargetMin});

  @override
  ConsumerState<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends ConsumerState<FocusScreen> {
  Timer? _ticker;
  int _elapsedSec = 0;
  bool _running = false;
  late int _targetMin = widget.initialTargetMin ?? 25;

  late final TextEditingController _noteController =
      TextEditingController(text: widget.initialNote ?? '');

  static const List<int> _targetOptions = [15, 25, 30, 45, 60];

  @override
  void dispose() {
    _ticker?.cancel();
    _noteController.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_running) {
      _ticker?.cancel();
      setState(() => _running = false);
    } else {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _elapsedSec++);
      });
      setState(() => _running = true);
    }
  }

  void _finish() {
    _ticker?.cancel();
    final minutes = _elapsedSec ~/ 60;
    if (minutes >= 1) {
      ref.read(statsProvider.notifier).adjustStudyMinutes(minutes);
      AppSnackBar.success(context, '$minutes dk çalışma kaydedildi');
    }
    Navigator.of(context).pop();
  }

  String get _clock {
    final m = (_elapsedSec ~/ 60).toString().padLeft(2, '0');
    final s = (_elapsedSec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final targetSec = _targetMin * 60;
    final progress =
        targetSec == 0 ? 0.0 : (_elapsedSec / targetSec).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(title: Text('Odak', style: AppTextStyles.heading2)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Eyebrow(text: 'ODAK SEANSI'),
              const SizedBox(height: 12),
              TextField(
                controller: _noteController,
                decoration: const InputDecoration(
                  hintText: 'Ne üzerinde çalışıyorsun? (opsiyonel)',
                ),
              ),

              const Spacer(),

              Center(
                child: Text(
                  _clock,
                  style: AppTextStyles.heading1.copyWith(
                    fontSize: 64,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'hedef $_targetMin dk',
                  style: AppTextStyles.caption,
                ),
              ),
              const SizedBox(height: 20),
              AnimatedProgressBar(
                value: progress,
                color: AppColors.primary,
                backgroundColor: AppColors.surfaceVariant,
                height: 8,
                borderRadius: 8,
              ),

              const SizedBox(height: 24),
              Wrap(
                spacing: 8,
                alignment: WrapAlignment.center,
                children: _targetOptions.map((min) {
                  final selected = _targetMin == min;
                  return TapScale(
                    onTap: () => setState(() => _targetMin = min),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primary
                            : AppColors.tonal(AppColors.primary),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$min dk',
                        style: AppTextStyles.body.copyWith(
                          color: selected
                              ? AppColors.ink
                              : AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const Spacer(),

              Row(
                children: [
                  Expanded(
                    child: TapScale(
                      onTap: _toggle,
                      child: Container(
                        height: 64,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: AppColors.cardShadow,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _running
                                  ? Icons.pause
                                  : Icons.play_arrow,
                              size: 22,
                              color: AppColors.ink,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _running ? 'Duraklat' : 'Başlat',
                              style: AppTextStyles.button.copyWith(fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  TapScale(
                    onTap: _finish,
                    child: Container(
                      height: 64,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        'Bitir',
                        style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
