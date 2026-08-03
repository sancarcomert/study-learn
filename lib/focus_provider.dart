// lib/focus_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bir odak (Pomodoro) oturumunun yaşam döngüsü durumları.
enum FocusSessionStatus { idle, running, paused, completed, cancelled }

/// Odak oturumunun değişmez (immutable) durumu.
///
/// Kalan süre bir sayaçla azaltılarak değil, [endTime] (bitiş zaman damgası)
/// üzerinden hesaplanır. Bu sayede uygulama arka plana alınıp geri gelse
/// bile kalan süre her zaman doğru hesaplanır — ileride eklenecek yerel
/// bildirim (bitişte tetiklenecek) de aynı [endTime] değerini kullanabilir.
class FocusTimerState {
  final String? taskId;
  final Duration totalDuration;
  final DateTime? endTime;
  final Duration? remainingWhenPaused;
  final FocusSessionStatus status;

  const FocusTimerState({
    this.taskId,
    this.totalDuration = Duration.zero,
    this.endTime,
    this.remainingWhenPaused,
    this.status = FocusSessionStatus.idle,
  });

  bool get isRunning => status == FocusSessionStatus.running;
  bool get isPaused => status == FocusSessionStatus.paused;
  bool get isActive => isRunning || isPaused;
  bool get isCompleted => status == FocusSessionStatus.completed;

  /// Verilen [now] anına göre kalan süre. UI, saniyede bir bunu okuyarak
  /// kendini yeniler; state'in kendisi her saniye değişmez.
  Duration remainingAt(DateTime now) {
    if (status == FocusSessionStatus.paused) {
      return remainingWhenPaused ?? Duration.zero;
    }
    if (endTime == null) return Duration.zero;
    final diff = endTime!.difference(now);
    return diff.isNegative ? Duration.zero : diff;
  }

  FocusTimerState copyWith({
    String? taskId,
    Duration? totalDuration,
    DateTime? endTime,
    bool clearEndTime = false,
    Duration? remainingWhenPaused,
    bool clearRemainingWhenPaused = false,
    FocusSessionStatus? status,
  }) {
    return FocusTimerState(
      taskId: taskId ?? this.taskId,
      totalDuration: totalDuration ?? this.totalDuration,
      endTime: clearEndTime ? null : (endTime ?? this.endTime),
      remainingWhenPaused: clearRemainingWhenPaused
          ? null
          : (remainingWhenPaused ?? this.remainingWhenPaused),
      status: status ?? this.status,
    );
  }
}

/// Odak oturumunun state makinesini yöneten notifier.
///
/// Bildirim ve istatistik/Hive entegrasyonu için genişletme noktaları
/// (`_scheduleCompletionNotification`, `_cancelScheduledNotification`,
/// `_onSessionCompleted`, `_onSessionCancelled`) bilinçli olarak boş
/// bırakılmıştır. İleride bu metodların gövdesi doldurulduğunda, notifier'ı
/// çağıran hiçbir kod (ekranlar dahil) değişmeyecektir.
class FocusTimerNotifier extends StateNotifier<FocusTimerState> {
  FocusTimerNotifier() : super(const FocusTimerState());

  void start({required String taskId, required Duration duration}) {
    final endTime = DateTime.now().add(duration);

    state = FocusTimerState(
      taskId: taskId,
      totalDuration: duration,
      endTime: endTime,
      status: FocusSessionStatus.running,
    );

    _scheduleCompletionNotification(endTime);
  }

  void pause() {
    if (!state.isRunning) return;

    final remaining = state.remainingAt(DateTime.now());

    state = state.copyWith(
      status: FocusSessionStatus.paused,
      remainingWhenPaused: remaining,
      clearEndTime: true,
    );

    _cancelScheduledNotification();
  }

  void resume() {
    if (!state.isPaused) return;

    final remaining = state.remainingWhenPaused ?? Duration.zero;
    final newEndTime = DateTime.now().add(remaining);

    state = state.copyWith(
      status: FocusSessionStatus.running,
      endTime: newEndTime,
      clearRemainingWhenPaused: true,
    );

    _scheduleCompletionNotification(newEndTime);
  }

  void cancel() {
    if (state.status == FocusSessionStatus.idle) return;

    _cancelScheduledNotification();
    _onSessionCancelled(state.taskId, state.totalDuration);

    state = const FocusTimerState();
  }

  /// Sayacın süresi dolduğunda çağrılır. UI tarafından periyodik olarak
  /// (örn. her saniye) veya uygulama arka plandan öne geldiğinde
  /// tetiklenmesi güvenlidir — idempotenttir, zaten tamamlanmışsa hiçbir şey
  /// yapmaz.
  void checkCompletion() {
    if (!state.isRunning) return;

    if (state.remainingAt(DateTime.now()) <= Duration.zero) {
      _complete();
    }
  }

  void _complete() {
    _cancelScheduledNotification();

    final taskId = state.taskId;
    final duration = state.totalDuration;

    state = state.copyWith(
      status: FocusSessionStatus.completed,
      clearEndTime: true,
    );

    _onSessionCompleted(taskId, duration);
  }

  void reset() {
    state = const FocusTimerState();
  }

  // ---------------------------------------------------------------------
  // Genişletme noktaları — şimdilik kasıtlı olarak boş.
  // ---------------------------------------------------------------------

  /// TODO(bildirim): [endTime] anında tetiklenecek yerel bir bildirim
  /// planla (flutter_local_notifications). Uygulama arka plandayken
  /// oturumun bittiğini kullanıcıya haber vermek için kullanılacak.
  void _scheduleCompletionNotification(DateTime endTime) {}

  /// TODO(bildirim): Daha önce planlanmış tamamlanma bildirimini iptal et
  /// (duraklatma veya iptal durumunda çağrılır).
  void _cancelScheduledNotification() {}

  /// TODO(istatistik/Hive): Tamamlanan oturumu kalıcı hale getir
  /// (taskId, süre, tamamlanma zamanı) — bir FocusSession Hive modeli
  /// eklendiğinde burası doldurulacak.
  void _onSessionCompleted(String? taskId, Duration duration) {}

  /// TODO(istatistik/Hive): İptal edilen/yarım kalan oturumları da
  /// analiz için kaydetmek istenirse burası kullanılacak.
  void _onSessionCancelled(String? taskId, Duration totalDuration) {}
}

final focusTimerProvider =
    StateNotifierProvider<FocusTimerNotifier, FocusTimerState>((ref) {
  return FocusTimerNotifier();
});