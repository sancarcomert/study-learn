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

  // Dondurma hakkı sınırsız birikmesin diye üst sınır.
  static const int _maxFreezes = 3;
  // Kaç günlük kesintisiz seri bir dondurma hakkı kazandırır.
  static const int _freezeEarnIntervalDays = 7;

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
      userName: _stats.userName,
      hasSeenNotificationPrompt: _stats.hasSeenNotificationPrompt,
      examDate: _stats.examDate,
      focusMinutes: _stats.focusMinutes,
      hasSeenTaskHints: _stats.hasSeenTaskHints,
      gradeLevel: _stats.gradeLevel,
      hasSeenExactAlarmPrompt: _stats.hasSeenExactAlarmPrompt,
      hasAddedFirstTask: _stats.hasAddedFirstTask,
      targetNetTYT: _stats.targetNetTYT,
      targetNetAYT: _stats.targetNetAYT,
      lastCarryOverPromptDate: _stats.lastCarryOverPromptDate,
      lastCloseOutDismissDate: _stats.lastCloseOutDismissDate,
    );
  }

  /// Bugün zaten "önceki günden kalan görevleri taşı" sorulduysa (cevap ne
  /// olursa olsun) true — bkz. lastCarryOverPromptDate'teki not.
  bool get wasCarryOverPromptedToday {
    final last = _stats.lastCarryOverPromptDate;
    if (last == null) return false;
    final today = DateTime.now();
    return last.year == today.year &&
        last.month == today.month &&
        last.day == today.day;
  }

  void markCarryOverPromptedToday() {
    _stats.lastCarryOverPromptDate = DateTime.now();
    _stats.save();
    _emit();
  }

  /// Bugün zaten "Bugünü kapat" kartı "×" ile gizlendiyse true.
  bool get wasCloseOutDismissedToday {
    final last = _stats.lastCloseOutDismissDate;
    if (last == null) return false;
    final today = DateTime.now();
    return last.year == today.year &&
        last.month == today.month &&
        last.day == today.day;
  }

  void markCloseOutDismissedToday() {
    _stats.lastCloseOutDismissDate = DateTime.now();
    _stats.save();
    _emit();
  }

  void markGoalCompletedToday() {
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

    // Her 7 günlük kesintisiz seride +1 dondurma hakkı — Duolingo'daki
    // aşırı serbest af mekanizmasının aksine, hakkı kazanılabilir ama
    // nadir tutuyoruz (üst sınır _maxFreezes).
    if (_stats.currentStreak % _freezeEarnIntervalDays == 0 &&
        _stats.freezesAvailable < _maxFreezes) {
      _stats.freezesAvailable += 1;
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

  void markNotificationPromptSeen() {
    _stats.hasSeenNotificationPrompt = true;
    _stats.save();
    _emit();
  }

  void markTaskHintsSeen() {
    if (_stats.hasSeenTaskHints) return;
    _stats.hasSeenTaskHints = true;
    _stats.save();
    _emit();
  }

  void markExactAlarmPromptSeen() {
    if (_stats.hasSeenExactAlarmPrompt) return;
    _stats.hasSeenExactAlarmPrompt = true;
    _stats.save();
    _emit();
  }

  void markFirstTaskAdded() {
    if (_stats.hasAddedFirstTask) return;
    _stats.hasAddedFirstTask = true;
    _stats.save();
    _emit();
  }

  /// [examType] "TYT" ya da "AYT". [value] null verilirse hedef temizlenir.
  void setTargetNet(String examType, double? value) {
    if (examType == 'TYT') {
      _stats.targetNetTYT = value;
    } else {
      _stats.targetNetAYT = value;
    }
    _stats.save();
    _emit();
  }

  // Bir görev tamamlanıp geri alındığında toplam çalışma süresini günceller.
  // delta pozitifse ekler (görev tamamlandı), negatifse çıkarır (tamamlama
  // geri alındı). Sonuç asla negatife düşmez.
  void adjustStudyMinutes(int delta) {
    if (delta == 0) return;
    final updated = _stats.totalStudyMinutes + delta;
    _stats.totalStudyMinutes = updated < 0 ? 0 : updated;
    _stats.save();
    _emit();
  }

  // Kullanıcının Profile ekranında girdiği ismi kaydeder. Boş string
  // gelirse null'a çevrilir, böylece UI tarafında "Öğrenci" varsayılanı
  // devreye girer.
  void updateUserName(String name) {
    final trimmed = name.trim();
    _stats.userName = trimmed.isEmpty ? null : trimmed;
    _stats.save();
    _emit();
  }

  // Odak seansında ölçülen dakikayı focusMinutes'a ekler. totalStudyMinutes'a
  // DOKUNMAZ — o alan tamamlanan görev tahminini biriktirir, bu ise ölçülen
  // gerçek süreyi. İkisi Profile'da ayrı gösterilir.
  void addFocusMinutes(int minutes) {
    if (minutes <= 0) return;
    _stats.focusMinutes += minutes;
    _stats.save();
    _emit();
  }

  // Kullanıcının sınıfını kaydeder (9–12 = lise, 13 = Mezun, null = temizle).
  // Kişiselleştirme için: ton, günlük hedef varsayılanı, sınav odağı.
  void setGradeLevel(int? level) {
    if (level != null && (level < 9 || level > UserStatsModel.mezun)) return;
    _stats.gradeLevel = level;
    _stats.save();
    _emit();
  }

  // Hedeflenen sınav tarihini kaydeder. null geçilirse geri sayım kaldırılır.
  // Sadece gün hassasiyeti tutulur (saat/dakika sıfırlanır).
  void setExamDate(DateTime? date) {
    _stats.examDate =
        date == null ? null : DateTime(date.year, date.month, date.day);
    _stats.save();
    _emit();
  }
}

final statsProvider =
    StateNotifierProvider<StatsNotifier, UserStatsModel>((ref) {
  final stats = ref.watch(statsRepositoryProvider);
  return StatsNotifier(stats);
});
