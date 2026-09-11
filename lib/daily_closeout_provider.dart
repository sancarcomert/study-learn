import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'daily_closeout_model.dart';
import 'hive_boxes.dart';

/// "Bugünü kapat" ritüelinin kalıcılığı — `FocusSession` / `Topic` ile aynı
/// desen: kendi box'ı (`daily_closeouts`), mevcut provider/repository/model
/// dosyalarına dokunmaz.
class DailyCloseoutRepository {
  final _box = HiveBoxes.dailyCloseouts;

  List<DailyCloseout> getAll() => _box.values.toList();

  Future<void> put(DailyCloseout c) => _box.put(c.id, c);

  Future<void> delete(String id) => _box.delete(id);
}

final dailyCloseoutRepositoryProvider =
    Provider<DailyCloseoutRepository>((ref) => DailyCloseoutRepository());

class DailyCloseoutNotifier extends StateNotifier<List<DailyCloseout>> {
  final DailyCloseoutRepository _repo;

  DailyCloseoutNotifier(this._repo) : super(_repo.getAll());

  /// Bugünü kapatır. Aynı gün ikinci kez çağrılırsa üzerine yazar
  /// (kullanıcı özeti güncelleyebilir).
  void close({
    required int completedTasks,
    required int focusMinutes,
    required String intent,
  }) {
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    _repo.put(DailyCloseout(
      id: DailyCloseout.dayKey(day),
      date: day,
      intent: intent.trim(),
      completedTasks: completedTasks,
      focusMinutes: focusMinutes,
      closedAt: now,
    ));
    state = _repo.getAll();
  }

  /// "Aslında biraz daha çalışacağım" — bugünü yeniden açar (kaydı siler),
  /// Home'daki dinlenme modu kalkıp görev listesine döner.
  Future<void> reopenToday() async {
    final today = DateTime.now();
    final key =
        DailyCloseout.dayKey(DateTime(today.year, today.month, today.day));
    await _repo.delete(key);
    state = _repo.getAll();
  }
}

final dailyCloseoutProvider =
    StateNotifierProvider<DailyCloseoutNotifier, List<DailyCloseout>>((ref) {
  return DailyCloseoutNotifier(ref.watch(dailyCloseoutRepositoryProvider));
});

/// Bugün kapatıldıysa o kayıt, aksi halde null.
final todayCloseoutProvider = Provider<DailyCloseout?>((ref) {
  final all = ref.watch(dailyCloseoutProvider);
  final now = DateTime.now();
  final key = DailyCloseout.dayKey(DateTime(now.year, now.month, now.day));
  for (final c in all) {
    if (c.id == key) return c;
  }
  return null;
});

/// Dün yazılmış niyet (varsa) — sabah Home'da nazik hatırlatma için.
final yesterdayIntentProvider = Provider<String?>((ref) {
  final all = ref.watch(dailyCloseoutProvider);
  final now = DateTime.now();
  final yesterday = DateTime(now.year, now.month, now.day)
      .subtract(const Duration(days: 1));
  final key = DailyCloseout.dayKey(yesterday);
  for (final c in all) {
    if (c.id == key && c.intent.isNotEmpty) return c.intent;
  }
  return null;
});
