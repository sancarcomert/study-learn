/// Rütbe merdiveni (docs/pusula_buyume_plani_2026.md §2 P0-2).
///
/// 6 sabit rütbe. Tamamen **türetilmiş** — kendi Hive kutusu yok, hiçbir
/// provider'a yazmaz. **Süre tabanlı hiçbir şey yok** → "kronometreyi açık
/// bırakıp rütbe atlama" mümkün değil.
///
/// XP kaynakları:
///   • görev tamamlama       → +10
///   • günü bitirme (hedef)  → +30   (ana kaynak — "her gün gel"i ödüllendirir)
///   • konu işaretleme       → +12
///
/// Rütbe eşikleri (kümülatif XP): 0 · 250 · 700 · 1600 · 3200 · 6000
class RankSystem {
  const RankSystem._();

  static const int xpPerTask = 10;
  static const int xpPerGoalDay = 30;
  static const int xpPerTopic = 12;

  /// 6 rütbenin başlangıç XP eşiği.
  static const List<int> thresholds = [0, 250, 700, 1600, 3200, 6000];

  /// Bir öğrencinin sınava hazırlık yolculuğundaki duruşu — zanaat/oyun
  /// terimi değil, akademik/işlevsel bir ilerleme sıfatı seçildi.
  static const List<String> names = [
    'Aday',
    'Gayretli',
    'Disiplinli',
    'Kararlı',
    'Uzman',
    'Zirve',
  ];

  /// Rütbe renkleri (ARGB int) — soğuktan sıcağa bir ilerleme rampası.
  /// UI `Color(RankSystem.colors[rank-1])` ile sarar; bu dosya saf Dart kalır.
  /// R6 (kor kırmızı) bilinçli istisna: uygulamada kırmızı "sil" demek ama
  /// burada buton değil, rütbe kimliği — karışmaz.
  static const List<int> colors = [
    0xFF74B98C, // Aday       — adaçayı yeşili
    0xFF54C6B8, // Gayretli   — deniz köpüğü
    0xFFE6BC5B, // Disiplinli — altın
    0xFFE68C44, // Kararlı    — turuncu
    0xFFDD6038, // Uzman      — mercan
    0xFFE5442E, // Zirve      — kor
  ];

  // Görev tamamlamanın "anlamına" göre ek XP — düz +10, hangi görevi
  // bitirdiğin fark etmeksizin aynıydı. İkisi de gerçek, zaten var olan
  // veriden (task.priority, task.postponeCount) türetiliyor, uydurma değil.
  static const int xpBonusHighPriority = 5; // öncelikli bir görev
  static const int xpBonusRecovered = 10; // 2+ kez ertelenmiş, sonunda bitti
  // Zor işaretlenmiş bir görevi bitirmek — task.difficulty önceden
  // kaydediliyordu ama hiçbir yerde okunmuyordu (ölü alan). Kolay/orta
  // görevle aynı XP'yi vermek zorluğu anlamsızlaştırıyordu.
  static const int xpBonusHardTask = 5;

  // Deneme neti kişisel rekoru geçince — tek başına XP kaynakları hep
  // "aktivite hacmi" (görev/gün/konu sayısı) ölçüyordu, GERÇEK akademik
  // ilerlemeye (deneme netinin yükselmesi) bağlı hiçbir XP yoktu. Net
  // puanı başına 4 XP, tek seferde en fazla 40 (aşırı/yanlış girilmiş bir
  // sıçramanın XP'yi anlamsızca şişirmesini önler). Yalnız YENİ kayıt
  // eklenince tetiklenir (düzenlemede değil — geri-ileri düzenleyerek
  // XP çiftlemeyi önler, bkz. add_deneme_screen._save).
  static const int xpPerNetImprovement = 4;
  static const int maxNetImprovementBonus = 40;

  static int netImprovementBonus(double improvement) {
    if (improvement <= 0) return 0;
    return (improvement * xpPerNetImprovement).round().clamp(
          0,
          maxNetImprovementBonus,
        );
  }

  static int xpFor({
    required int completedTasks,
    required int goalDays,
    required int coveredTopics,
    int bonusXp = 0,
  }) =>
      completedTasks * xpPerTask +
      goalDays * xpPerGoalDay +
      coveredTopics * xpPerTopic +
      bonusXp;

  static RankInfo fromXp(int xp) {
    final safe = xp < 0 ? 0 : xp;
    var rank = 1;
    for (var i = 1; i < thresholds.length; i++) {
      if (safe >= thresholds[i]) rank = i + 1;
    }

    final floor = thresholds[rank - 1];
    final atMax = rank >= thresholds.length;
    final ceil = atMax ? floor : thresholds[rank];

    return RankInfo(
      rank: rank,
      name: names[rank - 1],
      colorHex: colors[rank - 1],
      nextColorHex: atMax ? colors[rank - 1] : colors[rank],
      xp: safe,
      xpIntoRank: safe - floor,
      xpForRank: atMax ? 0 : ceil - floor,
      atMax: atMax,
    );
  }

  static RankInfo compute({
    required int completedTasks,
    required int goalDays,
    required int coveredTopics,
    int bonusXp = 0,
  }) =>
      fromXp(xpFor(
        completedTasks: completedTasks,
        goalDays: goalDays,
        coveredTopics: coveredTopics,
        bonusXp: bonusXp,
      ));
}

class RankInfo {
  final int rank; // 1..6
  final String name;
  final int colorHex;
  final int nextColorHex;
  final int xp;
  final int xpIntoRank;
  final int xpForRank;
  final bool atMax;

  const RankInfo({
    required this.rank,
    required this.name,
    required this.colorHex,
    required this.nextColorHex,
    required this.xp,
    required this.xpIntoRank,
    required this.xpForRank,
    required this.atMax,
  });

  double get progress =>
      atMax ? 1 : (xpIntoRank / xpForRank).clamp(0.0, 1.0);

  int get xpToNextRank =>
      atMax ? 0 : (xpForRank - xpIntoRank).clamp(0, 1 << 30);

  String get nextName => atMax ? name : RankSystem.names[rank];
}
