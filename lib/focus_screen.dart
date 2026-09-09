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

/// Tek seferlik odak seansı — yerel kronometre. "Bitir"de (ya da seans
/// çalışırken geri çıkışta) geçen tam dakika `focusMinutes`'a eklenir.
/// Süre duvar-saati farkıyla hesaplanır (tick sayarak değil) — arka plana
/// alınca / jank olunca kaymaz. Pomodoro döngüsü v1'de yok.
class FocusScreen extends ConsumerStatefulWidget {
  final String? initialNote;
  final int? initialTargetMin;

  const FocusScreen({super.key, this.initialNote, this.initialTargetMin});

  @override
  ConsumerState<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends ConsumerState<FocusScreen> {
  Timer? _ticker;

  // Duraklatılmış segmentlerden biriken saniye + çalışan segmentin başlangıcı.
  // Geçen süre = _committedSec + (çalışıyorsa now - _segmentStart).
  int _committedSec = 0;
  DateTime? _segmentStart;

  bool _saved = false;
  bool _leaving = false;

  late int _targetMin = widget.initialTargetMin ?? 25;

  late final TextEditingController _noteController =
      TextEditingController(text: widget.initialNote ?? '');

  static const List<int> _targetOptions = [15, 25, 30, 45, 60];

  bool get _running => _segmentStart != null;

  int get _elapsedSec =>
      _committedSec +
      (_segmentStart == null
          ? 0
          : DateTime.now().difference(_segmentStart!).inSeconds);

  @override
  void dispose() {
    _ticker?.cancel();
    _noteController.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_running) {
      _committedSec = _elapsedSec;
      _segmentStart = null;
      _ticker?.cancel();
      setState(() {});
    } else {
      _segmentStart = DateTime.now();
      _ticker?.cancel();
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
      setState(() {});
    }
  }

  void _saveIfNeeded() {
    _ticker?.cancel();
    _committedSec = _elapsedSec;
    _segmentStart = null;
    final minutes = _committedSec ~/ 60;
    if (_saved || minutes < 1) return;
    _saved = true;
    ref.read(statsProvider.notifier).addFocusMinutes(minutes);
    final note = _noteController.text.trim();
    AppSnackBar.success(
      context,
      note.isEmpty
          ? '$minutes dk odak süresi kaydedildi'
          : '$note · $minutes dk kaydedildi',
    );
  }

  /// Kaydet + ekrandan çık. Hem "Bitir" butonu hem geri tuşu buraya gelir.
  /// _leaving bayrağı PopScope.canPop'u açar, böylece sonraki pop döngüye
  /// girmeden geçer.
  void _exit() {
    _saveIfNeeded();
    if (!mounted || _leaving) return;
    setState(() => _leaving = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  String get _clock {
    final total = _elapsedSec;
    final m = (total ~/ 60).toString().padLeft(2, '0');
    final s = (total % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final elapsedSec = _elapsedSec;
    final targetSec = _targetMin * 60;
    final reached = targetSec > 0 && elapsedSec >= targetSec;
    final progress =
        targetSec == 0 ? 0.0 : (elapsedSec / targetSec).clamp(0.0, 1.0);
    final accent = reached ? AppColors.success : AppColors.primary;

    return PopScope(
      // Anlamlı süre birikmişse (>= 1 dk) ya da sayaç çalışıyorsa geri
      // tuşunu yakala — sessizce kaybetme, kaydet ve öyle çık.
      canPop: _leaving || (!_running && elapsedSec < 60),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exit();
      },
      child: Scaffold(
        appBar: AppBar(title: Text('Odak', style: AppTextStyles.heading2)),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Eyebrow(text: 'ODAK SEANSI'),
                const SizedBox(height: 12),
                TextField(
                  controller: _noteController,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    hintText: 'Ne üzerinde çalışıyorsun? (opsiyonel)',
                  ),
                ),

                const SizedBox(height: 44),

                Center(
                  child: Text(
                    _clock,
                    style: AppTextStyles.heading1.copyWith(
                      fontSize: 64,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                      color: reached
                          ? AppColors.success
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    reached ? 'hedefe ulaştın 🎯' : 'hedef $_targetMin dk',
                    style: AppTextStyles.caption.copyWith(
                      color: reached ? AppColors.success : AppColors.textMuted,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                AnimatedProgressBar(
                  value: progress,
                  color: accent,
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
                            color:
                                selected ? AppColors.ink : AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 44),

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
                                _running ? Icons.pause : Icons.play_arrow,
                                size: 22,
                                color: AppColors.ink,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _running ? 'Duraklat' : 'Başlat',
                                style: AppTextStyles.button
                                    .copyWith(fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    TapScale(
                      onTap: _exit,
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
                          style: AppTextStyles.body
                              .copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
