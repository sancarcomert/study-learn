/// Seviye / rütbe merdiveni (docs/pusula_buyume_plani_2026.md §2 P0-2).
///
/// Tamamen **türetilmiş** — kendi Hive kutusu yok, hiçbir provider'a yazmaz.
/// Girdi: gerçek aktivite sayaçları (tamamlanan görev, en uzun seri,
/// işaretlenen konu). **Süre tabanlı hiçbir şey yok** → "kronometreyi açık
/// bırakıp seviye atlama" mümkün değil. En uzun seri kullanılır (asla düşmez)
/// → seviye asla gerilemez.
///
/// XP = tamamlanan görev·10 + en uzun seri·20 + işaretli konu·12
/// Seviye eşiği: `totalXpForLevel(n) = 40·(n-1)²` (karekök eğrisi):
///   L1: 0 · L2: 40 · L3: 160 · L4: 360 · L5: 640 · L6: 1000 · L7: 1440 …
class LevelSystem {
  const LevelSystem._();

  static const int xpPerTask = 10;
  static const int xpPerStreakDay = 20;
  static const int xpPerTopic = 12;

  /// Rütbe bandlarının üst seviye sınırları — [_titleFor] ve
  /// [levelsToNextRank] ile aynı.
  static const List<int> _rankBounds = [2, 5, 9, 14];

  static int xpFor({
    required int completedTasks,
    required int longestStreak,
    required int coveredTopics,
  }) =>
      completedTasks * xpPerTask +
      longestStreak * xpPerStreakDay +
      coveredTopics * xpPerTopic;

  static int totalXpForLevel(int level) =>
      level <= 1 ? 0 : 40 * (level - 1) * (level - 1);

  static LevelInfo fromXp(int xp) {
    final safeXp = xp < 0 ? 0 : xp;
    var level = 1;
    while (totalXpForLevel(level + 1) <= safeXp) {
      level++;
    }
    final floor = totalXpForLevel(level);
    final ceil = totalXpForLevel(level + 1);
    return LevelInfo(
      level: level,
      title: _titleFor(level),
      xp: safeXp,
      xpIntoLevel: safeXp - floor,
      xpForNextLevel: ceil - floor,
      levelsToNextRank: levelsToNextRank(level),
    );
  }

  static LevelInfo compute({
    required int completedTasks,
    required int longestStreak,
    required int coveredTopics,
  }) =>
      fromXp(xpFor(
        completedTasks: completedTasks,
        longestStreak: longestStreak,
        coveredTopics: coveredTopics,
      ));

  static String _titleFor(int level) => switch (level) {
        <= 2 => 'Yolcu',
        <= 5 => 'Çırak',
        <= 9 => 'Kalfa',
        <= 14 => 'Usta',
        _ => 'Pusula',
      };

  /// Bir sonraki rütbeye kaç seviye kaldı (0 = zaten en üst rütbe "Pusula").
  static int levelsToNextRank(int level) {
    for (final b in _rankBounds) {
      if (level <= b) return b - level + 1;
    }
    return 0;
  }

  static const List<String> ranks = [
    'Yolcu',
    'Çırak',
    'Kalfa',
    'Usta',
    'Pusula',
  ];
}

class LevelInfo {
  final int level;
  final String title;
  final int xp;
  final int xpIntoLevel;
  final int xpForNextLevel;
  final int levelsToNextRank;

  const LevelInfo({
    required this.level,
    required this.title,
    required this.xp,
    required this.xpIntoLevel,
    required this.xpForNextLevel,
    required this.levelsToNextRank,
  });

  double get progress => xpForNextLevel <= 0
      ? 1
      : (xpIntoLevel / xpForNextLevel).clamp(0.0, 1.0);

  int get xpToNextLevel => (xpForNextLevel - xpIntoLevel).clamp(0, 1 << 30);

  bool get atTopRank => levelsToNextRank == 0;
}
