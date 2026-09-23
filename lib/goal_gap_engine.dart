import 'user_stats_model.dart';

/// Bir hedef netin sınav yaklaştıkça ne kadar acil olduğu — kaba, açıklanabilir
/// kategoriler. Kesin bir "günde şu kadar net kazanırsın" formülü İCAT
/// EDİLMEZ (bkz. GoalGapEngine.priorityAmplifier'daki not).
enum GoalUrgency {
  /// Sınav tarihi girilmemiş VEYA hedef zaten ulaşılmış — aciliyet hesabı
  /// anlamsız.
  none,

  /// Sınava 90 günden fazla var.
  distant,

  /// Sınava 31-90 gün var.
  approaching,

  /// Sınava 30 gün ya da daha az var.
  urgent,

  /// Sınav tarihi geçmiş — hedef muhtemelen güncel değil, aciliyet
  /// hesaplanmaz.
  examPassed,
}

/// GOAL → CURRENT STATE → GAP zincirinin tek, saf/testable temsili. Bir sınav
/// türü ("TYT"/"AYT") için hedef net, en son ölçülen net ve aradaki farkı
/// tutar. Hiçbir provider'a dokunmaz, hiçbir varsayım İCAT ETMEZ — yalnız
/// çağıran tarafın verdiği (hedef, son net, önceki net, sınav tarihi)
/// değerlerden saf bir hesap çıkarır.
class GoalGap {
  final String examType;
  final double? target;
  final double? currentNet;
  final double? previousNet;
  final int? examDaysRemaining;
  final GoalUrgency urgency;

  const GoalGap({
    required this.examType,
    this.target,
    this.currentNet,
    this.previousNet,
    this.examDaysRemaining,
    this.urgency = GoalUrgency.none,
  });

  bool get hasTarget => target != null;
  bool get hasResult => currentNet != null;
  bool get examPassed => urgency == GoalUrgency.examPassed;

  /// Hedef - mevcut net. Hedef ya da sonuç yoksa null — "hesaplanamaz"
  /// durumu sessizce 0 gibi davranmaz, açıkça null döner.
  double? get gap =>
      (target != null && currentNet != null) ? target! - currentNet! : null;

  /// Bir önceki denemeye göre aynı hesap — GAP'in nasıl değiştiğini
  /// göstermek için (bkz. gapChange).
  double? get previousGap =>
      (target != null && previousNet != null) ? target! - previousNet! : null;

  /// Hedef zaten ulaşılmış/geçilmiş mi (gap <= 0)? Hesaplanamıyorsa false.
  bool get reached => (gap ?? 1) <= 0;

  /// Son iki deneme arasındaki net değişimi — pozitif = iyileşme.
  double? get netChange => (currentNet != null && previousNet != null)
      ? currentNet! - previousNet!
      : null;

  /// GAP'in son deneme ile ne kadar değiştiği — pozitif = fark kapandı
  /// (öğrenci hedefe yaklaştı), negatif = fark açıldı.
  double? get gapChange => (gap != null && previousGap != null)
      ? previousGap! - gap!
      : null;
}

/// GOAL GAP zincirinin saf hesap çekirdeği. Deneme/istatistik verisini OKUMAZ
/// — çağıran taraf (bkz. goal_gap_provider.dart) gerçek Hive verisinden
/// hedef/net/tarihi çıkarıp buraya verir. Böylece PHASE 12'deki tüm uç
/// durumlar (hedef yok, deneme yok, hedefe ulaşıldı, sınav geçti...) tek bir
/// yerde, widget'sız test edilebilir.
class GoalGapEngine {
  const GoalGapEngine._();

  static const int _urgentDays = 30;
  static const int _approachingDays = 90;

  static GoalGap compute({
    required String examType,
    double? target,
    double? currentNet,
    double? previousNet,
    DateTime? examDate,
    DateTime? now,
  }) {
    int? daysRemaining;
    if (examDate != null) {
      final reference = now ?? DateTime.now();
      final today = DateTime(reference.year, reference.month, reference.day);
      final exam = DateTime(examDate.year, examDate.month, examDate.day);
      daysRemaining = exam.difference(today).inDays;
    }

    final hasOutstandingGap =
        target != null && currentNet != null && currentNet < target;

    GoalUrgency urgency;
    if (!hasOutstandingGap) {
      urgency = GoalUrgency.none;
    } else if (daysRemaining == null) {
      urgency = GoalUrgency.none;
    } else if (daysRemaining < 0) {
      urgency = GoalUrgency.examPassed;
    } else if (daysRemaining <= _urgentDays) {
      urgency = GoalUrgency.urgent;
    } else if (daysRemaining <= _approachingDays) {
      urgency = GoalUrgency.approaching;
    } else {
      urgency = GoalUrgency.distant;
    }

    return GoalGap(
      examType: examType,
      target: target,
      currentNet: currentNet,
      previousNet: previousNet,
      examDaysRemaining: daysRemaining,
      urgency: urgency,
    );
  }

  /// İkisi de hedeflenmişse (TYT+AYT) hangisinin "birincil" sayılacağı —
  /// sınav odaklı (11-12. sınıf/mezun, bkz. UserStatsModel.isExamFocused)
  /// bir öğrenci için AYT esas alınır, değilse TYT. Yalnız biri hedeflenmişse
  /// o döner; ikisi de hedeflenmemişse null (StudyAdvisor/Stats/Coach hiçbir
  /// hedef mesajı göstermez).
  static GoalGap? primary(GoalGap tyt, GoalGap ayt, {int? gradeLevel}) {
    final tytOk = tyt.hasTarget;
    final aytOk = ayt.hasTarget;
    if (!tytOk && !aytOk) return null;
    if (!aytOk) return tyt;
    if (!tytOk) return ayt;
    return UserStatsModel.isExamFocused(gradeLevel) ? ayt : tyt;
  }

  /// StudyAdvisor'a geçilecek 0..1 bağlamsal çarpan — GERÇEK akademik kanıtı
  /// (zayıf konu, gerileme, tekrar zamanı...) YOK SAYMAZ, yalnız bu
  /// sinyallerden biri ZATEN varsa ona ek ağırlık katar (bkz.
  /// study_advisor.dart, hasRealWeaknessSignal). Hedef yoksa, sonuç yoksa ya
  /// da hedefe zaten ulaşılmışsa 0 — "her şeyi acil" yapan anlamsız bir
  /// küresel sinyal DEĞİL.
  ///
  /// Kesin bir "günde N net kazanırsın" tahmini YOK — yalnız kaba, açıklanabilir
  /// bir büyüklük (gap büyüklüğü) × aciliyet kategorisi çarpımı.
  static double priorityAmplifier(GoalGap? goalGap) {
    if (goalGap == null) return 0.0;
    final gap = goalGap.gap;
    if (gap == null || gap <= 0) return 0.0;

    // 10+ net fark = tam büyüklük ağırlığı — StudyAdvisor'daki examPressure
    // (0-45 gün) gibi kaba/açıklanabilir bir ölçek, sahte hassasiyet değil.
    final magnitude = (gap / 10).clamp(0.0, 1.0);
    final urgencyWeight = switch (goalGap.urgency) {
      GoalUrgency.urgent => 1.0,
      GoalUrgency.approaching => 0.65,
      GoalUrgency.distant => 0.35,
      GoalUrgency.none => 0.5,
      // Sınav tarihi geçmiş — muhtemelen güncellenmemiş bir hedef, ileriye
      // dönük bir aciliyet sinyali vermek yanıltıcı olur.
      GoalUrgency.examPassed => 0.0,
    };
    return (magnitude * urgencyWeight).clamp(0.0, 1.0);
  }
}
