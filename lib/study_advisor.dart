import 'subject_model.dart';
import 'task_model.dart';

/// "Bugün ne çalışsam?" için YEREL öneri motoru. LLM yok — mevcut Hive
/// verisi (dersler + görevler + sınav tarihi) üzerinde kural tabanlı puanlama.
///
/// Salt okunur: veri alır, [StudySuggestion] listesi döndürür. Görev
/// oluşturmaz, hiçbir provider'a dokunmaz.
class StudyAdvisor {
  const StudyAdvisor._();

  /// [_reason]'ın hiçbir spesifik sinyal eşleşmediğinde döndüğü jenerik
  /// gerekçe — çağıran taraflar (ör. coach_screen açılış gözlemi) bunu
  /// "somut bir gözlem yok, genel öneri" ayrımı için kullanır.
  static const String genericReason = 'Dengeli ilerlemek için iyi bir seçim';

  /// En çok ihmal edilen / geride kalan dersleri gerekçesiyle sıralar.
  /// Bugün zaten görevi olan dersler elenir (tekrar önermek anlamsız).
  /// [coveragePercent] (subjectId → 0..1): yalnızca konusu olan dersler için
  /// Konu Takip kapsama oranı. Verildiğinde düşük kapsamlı dersler öne çıkar.
  /// [weakestDenemeSubjectId] verilirse (Deneme Takip'teki en düşük ortalama
  /// nete sahip bölümle eşleşen ders) o ders öne çıkar — Deneme Takip'i salt
  /// bir grafik olmaktan çıkarıp plana etki ettirir.
  /// [focusMinutesBySubject] (subjectId → toplam odak dakikası, tüm zamanlar)
  /// verilirse: kullanıcı Odak Seansı'nı en az bir kez kullanmışsa (herhangi
  /// bir derste dakika birikmişse), hiç odaklanılmamış ama görevi/konusu olan
  /// dersler hafif bir "gerçekten çalışmadın" sinyali alır. Odak hiç
  /// kullanılmadıysa (harita tamamen boşsa) kimse cezalandırılmaz — sinyal
  /// yalnız kullanıcının kendi alışkanlığına göre görecelidir.
  static List<StudySuggestion> suggest({
    required List<SubjectModel> subjects,
    required List<TaskModel> tasks,
    DateTime? examDate,
    DateTime? now,
    int limit = 3,
    Map<String, double> coveragePercent = const {},
    String? weakestDenemeSubjectId,
    Map<String, int> focusMinutesBySubject = const {},
    Set<String> staleReviewSubjectIds = const {},
    Set<String> worseningDenemeSubjectIds = const {},
    Map<String, List<String>> difficultTopicsBySubject = const {},
    String? selfReportedWeakSubjectId,
    Map<String, List<String>> examWeakTopicsBySubject = const {},
    // GOAL → GAP sinyali (bkz. goal_gap_engine.dart). 0..1 — hedefe ne kadar
    // uzak ve sınav ne kadar yakınsa o kadar büyük. BAĞLAMSAL bir çarpandır:
    // aşağıda yalnızca dersin ZATEN gerçek bir zayıflık kanıtı varsa etki
    // eder (bkz. hasRealWeaknessSignal) — güçlü/nötr bir dersi hedef farkı
    // yüzünden yapay olarak öne çıkarmaz.
    double goalGapAmplifier = 0.0,
  }) {
    if (subjects.isEmpty) return const [];

    final focusInUse =
        focusMinutesBySubject.values.any((minutes) => minutes > 0);

    final reference = now ?? DateTime.now();
    final today = DateTime(reference.year, reference.month, reference.day);
    final examDays = examDate == null ? null : _dayDiff(today, examDate);
    // 0–45 gün arası sınav → yaklaşan görevlerin puanına ek ağırlık.
    final examPressure = (examDays != null && examDays >= 0 && examDays <= 45)
        ? (1 - (examDays / 45)).clamp(0.0, 1.0)
        : 0.0;

    final results = <StudySuggestion>[];

    for (final s in subjects) {
      final subjectTasks = tasks.where((t) => t.subjectId == s.id).toList();

      final hasTaskToday = subjectTasks.any((t) => _isSameDay(t.dueDate, today));
      if (hasTaskToday) continue; // bugün zaten planlı

      final total = subjectTasks.length;
      final completed = subjectTasks.where((t) => t.isCompleted).length;
      final completionRate = total == 0 ? 0.0 : completed / total;

      // En son "değme" — en yakın tarihli görev (bugüne kadar). Hiç yoksa
      // dersin oluşturulma tarihinden bu yana geçen gün.
      final pastDueDates = subjectTasks
          .map((t) => t.dueDate)
          .where((d) => !d.isAfter(today))
          .toList();
      final int daysSinceTouch;
      if (pastDueDates.isEmpty) {
        daysSinceTouch = _dayDiff(
          DateTime(s.createdAt.year, s.createdAt.month, s.createdAt.day),
          today,
        ).clamp(0, 60);
      } else {
        pastDueDates.sort();
        daysSinceTouch = _dayDiff(pastDueDates.last, today).clamp(0, 60);
      }

      final hasPendingPriority = subjectTasks.any((t) =>
          !t.isCompleted &&
          t.priority == TaskPriority.high &&
          !t.dueDate.isAfter(today));

      final coverage = coveragePercent[s.id];
      final isWeakestDeneme = weakestDenemeSubjectId == s.id;
      final neverFocused = focusInUse &&
          (focusMinutesBySubject[s.id] ?? 0) == 0 &&
          (total > 0 || coverage != null);

      // Kronik erteleme — en çok ertelenmiş tamamlanmamış görev kaç kez
      // ertelendi. Tek bir erteleme (postponeCount==1) normal/gündelik,
      // sinyal değil; 2+ art arda erteleme gerçek bir kaçınma paterni.
      final maxPostpone = subjectTasks
          .where((t) => !t.isCompleted)
          .map((t) => t.postponeCount)
          .fold(0, (a, b) => a > b ? a : b);
      final isAvoided = maxPostpone >= 2;
      final needsReview = staleReviewSubjectIds.contains(s.id);
      final isWorsening = worseningDenemeSubjectIds.contains(s.id);
      final difficultTopics = difficultTopicsBySubject[s.id];
      final difficultTopic =
          (difficultTopics != null && difficultTopics.isNotEmpty)
              ? difficultTopics.first
              : null;
      final isSelfReportedWeak = selfReportedWeakSubjectId == s.id;
      // GERÇEK bir denemede yanlış yapılan, davranışsal (süre) sinyalinden
      // AYRI, kanıta dayalı akademik zayıflık — bkz. deneme_provider.dart.
      final examWeakTopics = examWeakTopicsBySubject[s.id];
      final examWeakTopic =
          (examWeakTopics != null && examWeakTopics.isNotEmpty)
              ? examWeakTopics.first
              : null;

      // --- Puan (0..~2.7) ---
      var score = 0.0;
      score += (daysSinceTouch.clamp(0, 21) / 21) * 0.50; // ihmal
      score += (1 - completionRate) * 0.25; // geride kalma
      if (total == 0) score += 0.15; // hiç dokunulmamış
      if (hasPendingPriority) score += 0.20 + examPressure * 0.15;
      if (coverage != null) score += (1 - coverage) * 0.35; // konu boşluğu
      if (isWeakestDeneme) score += 0.20; // deneme netinde en zayıf
      if (neverFocused) score += 0.15; // hiç gerçek odak seansı yok
      if (isAvoided) score += 0.25 + (maxPostpone.clamp(0, 5) * 0.03); // kaçınma
      if (needsReview) score += 0.12; // tekrar zamanı geçmiş konu var
      // Sabit düşük ortalamadan farklı, gerçek bir kötüleşme trendi — statik
      // "en zayıf" sinyalinden daha ağır (durağan zayıflık ≠ gerileme).
      if (isWorsening) score += 0.22;
      // Konu granülerliğinde en somut sinyal — belirli bir konu adı
      // gerekçede geçince öneri soyut ("bu ders geride") olmaktan çıkar.
      if (difficultTopic != null) score += 0.10;
      // Onboarding'deki kendi-bildirimi — hesaplanmış sinyallerden (deneme,
      // kapsama) daha düşük ağırlık: veri birikince onlar zaten baskın
      // çıkar, ilk günlerde (hiç veri yokken) tek kişiselleştirme kaynağı.
      if (isSelfReportedWeak) score += 0.10;
      // En yüksek ağırlık — tahmin/ortalama değil, öğrencinin GERÇEK bir
      // sınavda somut bir konudan yanlış yaptığının kanıtı.
      if (examWeakTopic != null) score += 0.28;

      // GOAL → GAP bağlamsal amplifikatörü (Faz 3) — YALNIZ ders zaten
      // kanıta dayalı bir zayıflık taşıyorsa devreye girer. examWeakTopic'in
      // (0.28) ve isAvoided'ın (0.25+) altında bir tavan (0.15) — hedef
      // farkı ASLA tek başına bir dersi öne çıkarmaz, yalnız var olan bir
      // sinyali güçlendirir.
      final hasRealWeaknessSignal = examWeakTopic != null ||
          isWorsening ||
          isWeakestDeneme ||
          needsReview ||
          isAvoided ||
          difficultTopic != null;
      if (hasRealWeaknessSignal && goalGapAmplifier > 0) {
        score += goalGapAmplifier * 0.15;
      }

      if (score <= 0.05) continue;

      results.add(StudySuggestion(
        subjectId: s.id,
        subjectName: s.name,
        score: score,
        reason: _reason(
          total: total,
          completionRate: completionRate,
          daysSinceTouch: daysSinceTouch,
          hasPendingPriority: hasPendingPriority,
          examDays: examDays,
          coverage: coverage,
          isWeakestDeneme: isWeakestDeneme,
          neverFocused: neverFocused,
          maxPostpone: isAvoided ? maxPostpone : 0,
          needsReview: needsReview,
          isWorsening: isWorsening,
          difficultTopic: difficultTopic,
          isSelfReportedWeak: isSelfReportedWeak,
          examWeakTopic: examWeakTopic,
        ),
      ));
    }

    results.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return a.subjectName.toLowerCase().compareTo(b.subjectName.toLowerCase());
    });

    return results.take(limit).toList();
  }

  static String _reason({
    required int total,
    required double completionRate,
    required int daysSinceTouch,
    required bool hasPendingPriority,
    required int? examDays,
    double? coverage,
    bool isWeakestDeneme = false,
    bool neverFocused = false,
    int maxPostpone = 0,
    bool needsReview = false,
    bool isWorsening = false,
    String? difficultTopic,
    bool isSelfReportedWeak = false,
    String? examWeakTopic,
  }) {
    // Kaçınma sinyali en açık/en erken gösterilen gerekçe — "N kez ertelendi"
    // öğrenciye kaçırdığı şeyin ne olduğunu net söylüyor, suçlamadan.
    if (maxPostpone >= 2) {
      return '$maxPostpone kez ertelendi — bugün küçük bir adım atalım mı?';
    }
    // Somut bir GERÇEK sınav kanıtı — tahmine/ortalamaya dayalı diğer tüm
    // sinyallerden (gerileme, kapsama, davranışsal zorluk) daha güçlü:
    // "hangi konudan" sorusuna kesin cevap veriyor.
    if (examWeakTopic != null) {
      return '"$examWeakTopic" konusunda denemede yanlış yapmıştın';
    }
    // Gerileme, sabit zayıflıktan daha acil — "hep zayıftın" değil "kötüye
    // gidiyorsun" mesajı erken müdahaleyi hak ediyor.
    if (isWorsening) {
      return 'Deneme netlerin bu derste geriliyor';
    }
    if (coverage != null && coverage < 0.6) {
      return 'Konuların %${(coverage * 100).round()}\'i işaretli — geride';
    }
    if (total == 0) {
      return 'Henüz hiç görev eklemedin';
    }
    if (hasPendingPriority) {
      return 'Bekleyen öncelikli görevin var';
    }
    if (isWeakestDeneme) {
      return 'Deneme netlerinde en zayıf olduğun ders';
    }
    if (neverFocused) {
      return 'Bu derse hiç odak seansı ayırmadın';
    }
    if (needsReview) {
      return 'Tekrar ettiğin bir konunun üstünden uzun süre geçti';
    }
    if (difficultTopic != null) {
      return '"$difficultTopic" konusu tahmininden çok daha uzun sürdü';
    }
    if (daysSinceTouch >= 7) {
      return '$daysSinceTouch gündür dokunmadın';
    }
    if (completionRate < 0.5 && total >= 3) {
      return 'Tamamlama oranın düşük (%${(completionRate * 100).round()})';
    }
    if (examDays != null && examDays >= 0 && examDays <= 30) {
      return 'Sınav yaklaşıyor — tekrar için iyi zaman';
    }
    if (isSelfReportedWeak) {
      return 'Kendin de bu derste zorlandığını söylemiştin';
    }
    return genericReason;
  }

  /// "Planlanan kapasite ≠ gerçekleşen kapasite" — bir dersin GEÇMİŞTE
  /// planlanan görevlerinin çoğunu bitiremediğini işaretler (>=3 görev,
  /// tamamlama oranı <%50 — [_reason]'daki "Tamamlama oranın düşük"
  /// eşiğiyle BİREBİR aynı, iki farklı sessiz eşik olmasın diye). PlanBuilder
  /// bu ID'ler için daha küçük bloklar önerir — aynı büyüklükte bloğu
  /// tekrar tekrar başarısızlıkla sonuçlanan bir derse dayatmak yerine.
  static Set<String> overcommittedSubjectIds({
    required List<SubjectModel> subjects,
    required List<TaskModel> tasks,
  }) {
    final result = <String>{};
    for (final s in subjects) {
      final subjectTasks = tasks.where((t) => t.subjectId == s.id).toList();
      final total = subjectTasks.length;
      if (total < 3) continue;
      final completed = subjectTasks.where((t) => t.isCompleted).length;
      if (completed / total < 0.5) result.add(s.id);
    }
    return result;
  }

  /// Sürekli tamamlama oranı (subjectId → 0..1, completed/total) — yalnız
  /// ≥[minTasks] görevi olan dersler için (küçük örneklemde gürültülü).
  /// [overcommittedSubjectIds]'in ikili bayrağının yerini alacak şekilde
  /// PlanBuilder'a geçilir: %51 tamamlama ile %99 tamamlama artık aynı
  /// muameleyi görmez, blok süresi orana göre kademeli küçülür/büyür.
  static Map<String, double> completionRateBySubject({
    required List<SubjectModel> subjects,
    required List<TaskModel> tasks,
    int minTasks = 3,
  }) {
    final result = <String, double>{};
    for (final s in subjects) {
      final subjectTasks = tasks.where((t) => t.subjectId == s.id).toList();
      final total = subjectTasks.length;
      if (total < minTasks) continue;
      final completed = subjectTasks.where((t) => t.isCompleted).length;
      result[s.id] = completed / total;
    }
    return result;
  }

  static int _dayDiff(DateTime from, DateTime to) {
    final a = DateTime(from.year, from.month, from.day);
    final b = DateTime(to.year, to.month, to.day);
    return b.difference(a).inDays;
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

/// [StudyAdvisor.suggest] öğesi — bir ders önerisi + insan-okunur gerekçe.
class StudySuggestion {
  final String subjectId;
  final String subjectName;
  final String reason;

  /// Sıralama için ham puan (~0..1.1). UI'da gösterilmez.
  final double score;

  const StudySuggestion({
    required this.subjectId,
    required this.subjectName,
    required this.reason,
    required this.score,
  });

  @override
  String toString() =>
      'StudySuggestion($subjectName, "$reason", ${score.toStringAsFixed(2)})';
}
