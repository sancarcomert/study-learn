import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'hive_boxes.dart';
import 'user_stats_model.dart';

final statsRepositoryProvider = Provider<UserStatsModel>((ref) {
  final box = HiveBoxes.stats;
  if (box.get('main') == null) {
    box.put('main', UserStatsModel());
  }
  return box.get('main')!;
});

class StatsNotifier extends StateNotifier<UserStatsModel> {
  StatsNotifier(this._stats) : super(_stats);
  final UserStatsModel _stats;

  // _stats'ı Hive'a kaydettikten sonra, Riverpod'un değişikliği fark etmesi
  // için state'e YENİ bir kopya atıyoruz (aynı referansı verirsek Riverpod
  // "değişiklik yok" sanıp ekranı güncellemez).
 void _emit() {
  state = UserStatsModel(
    currentStreak: _stats.currentStreak,
    longestStreak: _stats.longestStreak,
    lastCompletedDate: _stats.lastCompletedDate,
    dailyGoal: _stats.dailyGoal,
    freezesAvailable: _stats.freezesAvailable,
    totalCompletedTasks: _stats.totalCompletedTasks,
    totalStudyMinutes: _stats.totalStudyMinutes,
    hasCompletedOnboarding: _stats.hasCompletedOnboarding,
  );
}
  void markGoalCompletedToday() {
    print("STREAK GÜNCELLENİYOR");
    final today = DateTime.now();
    final todayDateOnly = DateTime(today.year, today.month, today.day);

    final lastDate = _stats.lastCompletedDate;

    if (lastDate != null &&
        lastDate.year == todayDateOnly.year &&
        lastDate.month == todayDateOnly.month &&
        lastDate.day == todayDateOnly.day) {
      return;
    }

    final yesterday = todayDateOnly.subtract(const Duration(days: 1));
    final wasYesterday = lastDate != null &&
        lastDate.year == yesterday.year &&
        lastDate.month == yesterday.month &&
        lastDate.day == yesterday.day;

    if (wasYesterday) {
      _stats.currentStreak += 1;
    } else {
      _stats.currentStreak = 1;
    }

    if (_stats.currentStreak > _stats.longestStreak) {
      _stats.longestStreak = _stats.currentStreak;
    }

    _stats.lastCompletedDate = todayDateOnly;
    _stats.totalCompletedTasks += 1;
    _stats.save();
    _emit();
  }

void checkStreakBroken() {
    final lastDate = _stats.lastCompletedDate;
    if (lastDate == null) return;

    final today = DateTime.now();
    final todayDateOnly = DateTime(today.year, today.month, today.day);
    final yesterday = todayDateOnly.subtract(const Duration(days: 1));

    final isToday = lastDate.year == todayDateOnly.year &&
        lastDate.month == todayDateOnly.month &&
        lastDate.day == todayDateOnly.day;
    final isYesterday = lastDate.year == yesterday.year &&
        lastDate.month == yesterday.month &&
        lastDate.day == yesterday.day;

    if (!isToday && !isYesterday) {
      if (_stats.freezesAvailable > 0) {
        // Dondurma hakkı var: seriyi koru, hakkı düş, "dün tamamlanmış" say
        _stats.freezesAvailable -= 1;
        _stats.lastCompletedDate = yesterday;
      } else {
        _stats.currentStreak = 0;
      }
      _stats.save();
      _emit();
    }
  }

  void updateDailyGoal(int newGoal) {
    if (newGoal < 1) return;
    _stats.dailyGoal = newGoal;
    _stats.save();
    _emit();
  }

  void markOnboardingCompleted() {
    _stats.hasCompletedOnboarding = true;
    _stats.save();
    _emit();
  }
}

final statsProvider = StateNotifierProvider<StatsNotifier, UserStatsModel>((ref) {
  final stats = ref.watch(statsRepositoryProvider);
  return StatsNotifier(stats);
});