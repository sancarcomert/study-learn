import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';
import 'focus_history_screen.dart';
import 'focus_session_provider.dart';
import 'notification_service.dart';
import 'stats_provider.dart';
import 'tap_scale.dart';
import 'widgets/eyebrow.dart';
import 'widgets/animated_progress_bar.dart';
import 'widgets/app_snackbar.dart';

/// Odak seansı — iki mod:
/// - **Serbest:** açık uçlu kronometre (sayar), hedef sadece görsel.
/// - **Pomodoro:** çalışma bloğu → 5 dk mola döngüsü, 4 turda bir 15 dk
///   uzun mola. Her tamamlanan çalışma bloğu anında `focusMinutes`'a yazılır.
///
/// Süre her yerde DUVAR-SAATİ farkıyla hesaplanır (tick sayarak değil) —
/// arka plan / jank'te kaymaz. Bağımlılık yok, bildirim/ses yok (v1).
class FocusScreen extends ConsumerStatefulWidget {
  final String? initialNote;
  final int? initialTargetMin;

  const FocusScreen({super.key, this.initialNote, this.initialTargetMin});

  @override
  ConsumerState<FocusScreen> createState() => _FocusScreenState();
}

enum _Mode { free, pomodoro }

enum _Phase { work, shortBreak, longBreak }

class _FocusScreenState extends ConsumerState<FocusScreen> {
  Timer? _ticker;
  bool _running = false;
  bool _leaving = false;

  _Mode _mode = _Mode.free;
  late int _blockMin = widget.initialTargetMin ?? 25;

  late final TextEditingController _noteController =
      TextEditingController(text: widget.initialNote ?? '');

  static const List<int> _blockOptions = [15, 25, 30, 45, 60];
  static const int _shortBreakSec = 5 * 60;
  static const int _longBreakSec = 15 * 60;

  // Serbest mod: yukarı sayan geçen süre.
  int _freeCommittedSec = 0;
  DateTime? _freeSegStart;
  bool _freeSaved = false;

  // Pomodoro: mevcut fazın geçen süresi + tur sayacı.
  _Phase _phase = _Phase.work;
  int _pomoCycle = 1; // üzerinde çalışılan / son biten çalışma bloğu no'su
  int _phaseAccumSec = 0;
  DateTime? _phaseSegStart;

  @override
  void dispose() {
    _ticker?.cancel();
    _noteController.dispose();
    super.dispose();
  }

  // ---- ortak ----

  int get _freeElapsedSec =>
      _freeCommittedSec +
      (_freeSegStart == null
          ? 0
          : DateTime.now().difference(_freeSegStart!).inSeconds);

  int get _phaseElapsedSec =>
      _phaseAccumSec +
      (_phaseSegStart == null
          ? 0
          : DateTime.now().difference(_phaseSegStart!).inSeconds);

  int get _phaseTargetSec {
    switch (_phase) {
      case _Phase.work:
        return _blockMin * 60;
      case _Phase.shortBreak:
        return _shortBreakSec;
      case _Phase.longBreak:
        return _longBreakSec;
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_mode == _Mode.pomodoro &&
          _running &&
          _phaseElapsedSec >= _phaseTargetSec) {
        _advancePhase(auto: true);
      }
      setState(() {});
    });
  }

  void _toggleRun() {
    if (_running) {
      // duraklat
      if (_mode == _Mode.free) {
        _freeCommittedSec = _freeElapsedSec;
        _freeSegStart = null;
      } else {
        _phaseAccumSec = _phaseElapsedSec;
        _phaseSegStart = null;
      }
      _ticker?.cancel();
      _cancelCompletionNotification();
      setState(() => _running = false);
    } else {
      final now = DateTime.now();
      if (_mode == _Mode.free) {
        _freeSegStart = now;
      } else {
        _phaseSegStart = now;
      }
      _running = true;
      _startTicker();
      _scheduleCompletionNotification();
      setState(() {});
    }
  }

  // ---- arka plan bildirimi: bölüm/hedef bitince tek seferlik, exact-mode ----

  void _scheduleCompletionNotification() {
    final int remainingSec;
    final String title;
    final String body;
    if (_mode == _Mode.free) {
      remainingSec = _blockMin * 60 - _freeElapsedSec;
      title = 'Hedefe ulaştın 🎯';
      final note = _noteController.text.trim();
      body = note.isEmpty ? 'Odak hedefine ulaştın.' : '$note · hedefe ulaştın.';
    } else if (_phase == _Phase.work) {
      remainingSec = _phaseTargetSec - _phaseElapsedSec;
      title = 'Çalışma bloğu bitti';
      body = 'Mola zamanı geldi 🎯';
    } else {
      remainingSec = _phaseTargetSec - _phaseElapsedSec;
      title = 'Mola bitti';
      body = 'Çalışmaya dön';
    }
    if (remainingSec <= 0) return;
    NotificationService.instance.scheduleNotification(
      id: 'focus_session',
      category: NotificationCategory.focusSession,
      title: title,
      body: body,
      dateTime: DateTime.now().add(Duration(seconds: remainingSec)),
      exact: true,
    );
  }

  void _cancelCompletionNotification() {
    NotificationService.instance.cancelNotification(
      'focus_session',
      NotificationCategory.focusSession,
    );
  }

  void _switchMode(_Mode m) {
    if (_running || m == _mode) return;
    _ticker?.cancel();
    _cancelCompletionNotification();
    setState(() {
      _mode = m;
      _running = false;
      _freeCommittedSec = 0;
      _freeSegStart = null;
      _freeSaved = false;
      _phase = _Phase.work;
      _pomoCycle = 1;
      _phaseAccumSec = 0;
      _phaseSegStart = null;
    });
  }

  // ---- pomodoro faz geçişi ----

  void _commitCurrentWorkBlock() {
    if (_phase != _Phase.work) return;
    final workedMin =
        math.min(_phaseElapsedSec, _blockMin * 60) ~/ 60;
    if (workedMin >= 1) {
      ref.read(statsProvider.notifier).addFocusMinutes(workedMin);
      ref
          .read(focusSessionProvider.notifier)
          .log(minutes: workedMin, mode: 'pomodoro');
    }
  }

  /// [auto] true ise sayaç bittiği için otomatik geçiş; false ise molayı
  /// kullanıcı elle geçti.
  void _advancePhase({bool auto = false}) {
    HapticFeedback.mediumImpact();
    final wasWork = _phase == _Phase.work;

    if (wasWork) {
      _commitCurrentWorkBlock();
      final isLong = _pomoCycle % 4 == 0;
      _phase = isLong ? _Phase.longBreak : _Phase.shortBreak;
      if (mounted) {
        AppSnackBar.info(
          context,
          isLong ? 'Uzun mola · 15 dk' : 'Mola · 5 dk',
        );
      }
    } else {
      _pomoCycle++;
      _phase = _Phase.work;
      if (mounted && auto) {
        AppSnackBar.info(context, '$_pomoCycle. tur — çalışmaya dön');
      }
    }

    _phaseAccumSec = 0;
    _phaseSegStart = _running ? DateTime.now() : null;
    if (_running) {
      _scheduleCompletionNotification();
    } else {
      _cancelCompletionNotification();
    }
    setState(() {});
  }

  // ---- çıkış ----

  void _saveIfNeeded() {
    _ticker?.cancel();
    _cancelCompletionNotification();
    if (_mode == _Mode.free) {
      _freeCommittedSec = _freeElapsedSec;
      _freeSegStart = null;
      final minutes = _freeCommittedSec ~/ 60;
      if (!_freeSaved && minutes >= 1) {
        _freeSaved = true;
        ref.read(statsProvider.notifier).addFocusMinutes(minutes);
        ref
            .read(focusSessionProvider.notifier)
            .log(minutes: minutes, mode: 'serbest');
        final note = _noteController.text.trim();
        AppSnackBar.success(
          context,
          note.isEmpty
              ? '$minutes dk odak süresi kaydedildi'
              : '$note · $minutes dk kaydedildi',
        );
      }
    } else {
      // pomodoro: tamamlanan bloklar zaten yazıldı; yalnız mevcut kısmi
      // çalışma bloğunu ekle.
      _commitCurrentWorkBlock();
      _phaseSegStart = null;
    }
    _running = false;
  }

  void _exit() {
    _saveIfNeeded();
    if (!mounted || _leaving) return;
    setState(() => _leaving = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  bool get _hasUnsavedProgress {
    if (_running) return true;
    if (_mode == _Mode.free) return _freeElapsedSec >= 60;
    return _phase == _Phase.work && _phaseElapsedSec >= 60;
  }

  // ---- görünüm ----

  String _fmt(int totalSec) {
    final s = totalSec.abs();
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$m:$ss';
  }

  String get _phaseLabel {
    switch (_phase) {
      case _Phase.work:
        return 'Çalışma · $_pomoCycle. tur';
      case _Phase.shortBreak:
        return 'Kısa mola';
      case _Phase.longBreak:
        return 'Uzun mola';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBreak = _mode == _Mode.pomodoro && _phase != _Phase.work;

    // ---- ana sayaç metni + ilerleme ----
    final String clock;
    final double progress;
    final bool reached;
    if (_mode == _Mode.free) {
      final e = _freeElapsedSec;
      final target = _blockMin * 60;
      clock = _fmt(e);
      progress = target == 0 ? 0 : (e / target).clamp(0.0, 1.0);
      reached = target > 0 && e >= target;
    } else {
      final remaining = _phaseTargetSec - _phaseElapsedSec;
      clock = _fmt(remaining < 0 ? 0 : remaining);
      progress = _phaseTargetSec == 0
          ? 0
          : (_phaseElapsedSec / _phaseTargetSec).clamp(0.0, 1.0);
      reached = false;
    }

    final accent = isBreak
        ? AppColors.success
        : (reached ? AppColors.success : AppColors.primary);

    return PopScope(
      canPop: _leaving || !_hasUnsavedProgress,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exit();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Odak', style: AppTextStyles.heading2),
          actions: [
            IconButton(
              tooltip: 'Geçmiş',
              icon: const Icon(Icons.history_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const FocusHistoryScreen()),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Eyebrow(text: 'ODAK SEANSI'),
                const SizedBox(height: 12),

                // mod seçici
                _ModeToggle(
                  mode: _mode,
                  enabled: !_running,
                  onChanged: _switchMode,
                ),

                const SizedBox(height: 16),
                TextField(
                  controller: _noteController,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    hintText: 'Ne üzerinde çalışıyorsun? (opsiyonel)',
                  ),
                ),

                const SizedBox(height: 40),

                Center(
                  child: Text(
                    clock,
                    style: AppTextStyles.heading1.copyWith(
                      fontSize: 64,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                      color: (isBreak || reached)
                          ? AppColors.success
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    _mode == _Mode.free
                        ? (reached ? 'hedefe ulaştın 🎯' : 'hedef $_blockMin dk')
                        : _phaseLabel,
                    style: AppTextStyles.caption.copyWith(
                      color: (isBreak || reached)
                          ? AppColors.success
                          : AppColors.textMuted,
                      fontWeight: FontWeight.w700,
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
                if (!isBreak)
                  Wrap(
                    spacing: 8,
                    alignment: WrapAlignment.center,
                    children: _blockOptions.map((min) {
                      final selected = _blockMin == min;
                      return TapScale(
                        onTap: _running
                            ? () {}
                            : () => setState(() => _blockMin = min),
                        child: Opacity(
                          opacity: _running ? 0.4 : 1,
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
                        ),
                      );
                    }).toList(),
                  )
                else
                  Center(
                    child: TapScale(
                      onTap: () => _advancePhase(auto: false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.tonal(AppColors.success),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Molayı geç',
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.success,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 40),

                Row(
                  children: [
                    Expanded(
                      child: TapScale(
                        onTap: _toggleRun,
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

class _ModeToggle extends StatelessWidget {
  final _Mode mode;
  final bool enabled;
  final ValueChanged<_Mode> onChanged;

  const _ModeToggle({
    required this.mode,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            _seg('Serbest', _Mode.free),
            _seg('Pomodoro', _Mode.pomodoro),
          ],
        ),
      ),
    );
  }

  Widget _seg(String label, _Mode value) {
    final selected = mode == value;
    return Expanded(
      child: TapScale(
        onTap: enabled ? () => onChanged(value) : null,
        child: Container(
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: AppTextStyles.body.copyWith(
              color: selected ? AppColors.ink : AppColors.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
