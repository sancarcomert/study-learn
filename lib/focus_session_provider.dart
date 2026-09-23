import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'focus_session_model.dart';
import 'hive_boxes.dart';

const _uuid = Uuid();

class FocusSessionRepository {
  final _box = HiveBoxes.focusSessions;

  List<FocusSession> getAll() => _box.values.toList();

  Future<void> add(FocusSession s) => _box.put(s.id, s);

  Future<void> delete(String id) => _box.delete(id);
}

final focusSessionRepositoryProvider =
    Provider<FocusSessionRepository>((ref) => FocusSessionRepository());

class FocusSessionNotifier extends StateNotifier<List<FocusSession>> {
  final FocusSessionRepository _repo;

  FocusSessionNotifier(this._repo) : super(_repo.getAll());

  /// Tamamlanan bir odak dilimini kaydeder. [minutes] < 1 ise atlar.
  void log({
    required int minutes,
    required String mode,
    String? subjectId,
    String? topicId,
    String? note,
  }) {
    if (minutes < 1) return;
    _repo.add(FocusSession(
      id: _uuid.v4(),
      endedAt: DateTime.now(),
      minutes: minutes,
      mode: mode,
      subjectId: subjectId,
      topicId: topicId,
      note: (note == null || note.trim().isEmpty) ? null : note.trim(),
    ));
    state = _repo.getAll();
  }

  /// Siler ve "Geri Al" için bir kopyasını döndürür. Not: Profil'deki
  /// kümülatif `UserStatsModel.focusMinutes` toplamı bundan etkilenmez —
  /// rütbe/seri gibi o da geriye gitmez, yalnız bu günlük kayıt
  /// (günlük/haftalık grafiklerin kaynağı) siliniyor.
  FocusSession? deleteSession(String id) {
    final index = state.indexWhere((s) => s.id == id);
    if (index == -1) return null;
    final original = state[index];
    final snapshot = FocusSession(
      id: original.id,
      endedAt: original.endedAt,
      minutes: original.minutes,
      mode: original.mode,
      subjectId: original.subjectId,
      topicId: original.topicId,
      note: original.note,
    );
    _repo.delete(id);
    state = _repo.getAll();
    return snapshot;
  }

  void restoreSession(FocusSession session) {
    _repo.add(session);
    state = _repo.getAll();
  }
}

final focusSessionProvider =
    StateNotifierProvider<FocusSessionNotifier, List<FocusSession>>((ref) {
  return FocusSessionNotifier(ref.watch(focusSessionRepositoryProvider));
});

/// Tüm seanslar, en yeniden en eskiye — geçmiş ekranı için.
final focusSessionsDescendingProvider = Provider<List<FocusSession>>((ref) {
  final all = List<FocusSession>.from(ref.watch(focusSessionProvider));
  all.sort((a, b) => b.endedAt.compareTo(a.endedAt));
  return all;
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

/// subjectId → toplam odak dakikası (tüm zamanlar). Ders seçilmeden
/// başlatılan seanslar (subjectId null) dahil edilmez.
final focusMinutesBySubjectProvider = Provider<Map<String, int>>((ref) {
  final all = ref.watch(focusSessionProvider);
  final map = <String, int>{};
  for (final s in all) {
    final id = s.subjectId;
    if (id == null) continue;
    map[id] = (map[id] ?? 0) + s.minutes;
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

/// Geçen haftanın (Pazartesi–Pazar) toplam odak dakikası — bu haftayla
/// kıyaslayıp "daha çok mu az mı odaklandın" trendini göstermek için
/// (bkz. stats_insight_engine.dart). `tasksCompletedLastWeekProvider` ile
/// aynı hafta sınırı deseni (task_provider.dart).
final focusLastWeekMinutesProvider = Provider<int>((ref) {
  final byDay = ref.watch(focusMinutesByDayProvider);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final monday = today.subtract(Duration(days: today.weekday - 1));
  final lastMonday = monday.subtract(const Duration(days: 7));
  var total = 0;
  byDay.forEach((day, min) {
    if (!day.isBefore(lastMonday) && day.isBefore(monday)) total += min;
  });
  return total;
});

/// Bugüne kadar KAYDEDİLMİŞ (log'lanmış) odak dakikası — Odak ekranındaki
/// "bugün toplam" satırı için. Şu an sürmekte olan (henüz commit edilmemiş)
/// canlı seansın saniyelerini içermez; ekran kendi canlı süresini ayrıca
/// ekleyip gösterir.
final focusTodayMinutesProvider = Provider<int>((ref) {
  final byDay = ref.watch(focusMinutesByDayProvider);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return byDay[today] ?? 0;
});
