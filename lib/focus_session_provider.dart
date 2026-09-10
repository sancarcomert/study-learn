import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'focus_session_model.dart';
import 'hive_boxes.dart';

const _uuid = Uuid();

class FocusSessionRepository {
  final _box = HiveBoxes.focusSessions;

  List<FocusSession> getAll() => _box.values.toList();

  Future<void> add(FocusSession s) => _box.put(s.id, s);
}

final focusSessionRepositoryProvider =
    Provider<FocusSessionRepository>((ref) => FocusSessionRepository());

class FocusSessionNotifier extends StateNotifier<List<FocusSession>> {
  final FocusSessionRepository _repo;

  FocusSessionNotifier(this._repo) : super(_repo.getAll());

  /// Tamamlanan bir odak dilimini kaydeder. [minutes] < 1 ise atlar.
  void log({required int minutes, required String mode}) {
    if (minutes < 1) return;
    _repo.add(FocusSession(
      id: _uuid.v4(),
      endedAt: DateTime.now(),
      minutes: minutes,
      mode: mode,
    ));
    state = _repo.getAll();
  }
}

final focusSessionProvider =
    StateNotifierProvider<FocusSessionNotifier, List<FocusSession>>((ref) {
  return FocusSessionNotifier(ref.watch(focusSessionRepositoryProvider));
});

/// Gün (saat sıfır) → o gün ölçülen toplam odak dakikası.
final focusMinutesByDayProvider = Provider<Map<DateTime, int>>((ref) {
  final all = ref.watch(focusSessionProvider);
  final map = <DateTime, int>{};
  for (final s in all) {
    final d = DateTime(s.endedAt.year, s.endedAt.month, s.endedAt.day);
    map[d] = (map[d] ?? 0) + s.minutes;
  }
  return map;
});

/// Bu haftanın (Pazartesi–bugün) toplam odak dakikası.
final focusThisWeekMinutesProvider = Provider<int>((ref) {
  final byDay = ref.watch(focusMinutesByDayProvider);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final monday = today.subtract(Duration(days: today.weekday - 1));
  var total = 0;
  byDay.forEach((day, min) {
    if (!day.isBefore(monday)) total += min;
  });
  return total;
});
