import 'dart:math';

import 'subject_model.dart';
import 'task_model.dart';

/// Günlük plan üretiminin SAF çekirdeği. Girdi alır, oluşturulacak
/// blokların listesini döndürür — hiçbir şey yazmaz, provider'a dokunmaz.
/// Çağıran taraf (coach_screen) blokları `taskProvider.addTask` ile kaydeder.
///
/// NOT: Bloklara saat ATANMAZ. Üretilen görevler gün-kapsamlı bir yapılacak
/// listesidir; sıralarını `order` alanı taşır. Kullanıcı belirli bir saat
/// söylediğinde saati coach_screen tek görev için kendisi koyar.
class PlanBuilder {
  const PlanBuilder._();

  static int durationFor(String energy) => switch (energy) {
        'yüksek' => 60,
        'düşük' => 25,
        _ => 45,
      };

  /// Blok süresi çarpanı — [subjectCompletionRates]'te bir oran varsa
  /// (StudyAdvisor.completionRateBySubject, ≥3 görevlik örneklem) kademeli
  /// ölçek (rate 0 → 0.5x, rate 1 → 1x) uygulanır; yoksa eski ikili
  /// [reducedCapacitySubjectIds] bayrağına (sabit 0.6x) düşer. İkisi de
  /// yoksa 1.0 (değişiklik yok).
  static double _durationFactor(
    String subjectId,
    Set<String> reducedCapacitySubjectIds,
    Map<String, double> subjectCompletionRates,
  ) {
    final rate = subjectCompletionRates[subjectId];
    if (rate != null) return (0.5 + 0.5 * rate).clamp(0.5, 1.0);
    if (reducedCapacitySubjectIds.contains(subjectId)) return 0.6;
    return 1.0;
  }

  /// [orderedSubjects] önerilen sıra (StudyAdvisor çıktısı + kalanlar).
  /// [explicitSubject] verilirse yalnızca o ders kullanılır.
  /// [topics] boş değilse görev sayısı = konu sayısı; her konu sırayla bir
  /// derse yazılır. [examDays] null değilse ve <= 30 ise öncelikler yükselir.
  ///
  /// [uncoveredTopics] (subjectId → işaretlenmemiş konu {ad, id} çiftleri):
  /// verildiğinde ve [topics] boşken, görev başlıkları o dersin gerçek boş
  /// konularından üretilir ("Matematik: Türev") ve üretilen [PlanBlock]
  /// gerçek konu id'sini taşır — görev tamamlanınca Konu Takip'te otomatik
  /// işaretlenebilsin diye (bkz. task_provider.toggleTaskCompletion).
  /// [fillToCapacity] true ise görev sayısı ders sayısıyla değil, kalan
  /// süreyle sınırlanır — Koç "sen ayarla" modunda dolu bir program
  /// çıkarmak için.
  ///
  /// [reducedCapacitySubjectIds] — StudyAdvisor.overcommittedSubjectIds'ten
  /// gelir: geçmişte planlanan görevlerinin çoğunu bitirememiş dersler.
  /// "Planlanan kapasite ≠ gerçekleşen kapasite" — bu derslere aynı sabit
  /// bloğu (ör. 45 dk) tekrar tekrar dayatmak yerine daha küçük, gerçekçi
  /// bir blok önerilir (bkz. _durationForSubject).
  static PlanResult build({
    required List<SubjectModel> orderedSubjects,
    SubjectModel? explicitSubject,
    List<String> topics = const [],
    Map<String, List<UncoveredTopic>> uncoveredTopics = const {},
    bool fillToCapacity = false,
    required int capacityMinutes,
    required String energy,
    int? examDays,
    Random? random,
    Set<String> reducedCapacitySubjectIds = const {},
    Map<String, double> subjectCompletionRates = const {},
    Map<String, List<UncoveredTopic>> examWeakTopics = const {},
    // "Neden bu görev?" (Faz 6/7) — StudyAdvisor.suggest()'in dersi SEÇERKEN
    // ürettiği gerekçe (jenerik olanlar HARİÇ, bkz. çağıran taraf). Somut bir
    // examWeakTopics gerekçesi varsa o KAZANIR (daha spesifik) — bu yalnız
    // onun yokluğunda, blok bir dersten geldiği için kullanılan bir yedek.
    Map<String, String> subjectReasons = const {},
  }) {
    final rng = random ?? Random();

    final targets = explicitSubject != null
        ? <SubjectModel>[explicitSubject]
        : List<SubjectModel>.from(orderedSubjects);

    if (targets.isEmpty) {
      return const PlanResult(blocks: [], unfitTitles: [], reason: '');
    }

    final examSoon = examDays != null && examDays >= 0 && examDays <= 30;

    final TaskPriority priority;
    if (examSoon) {
      priority = TaskPriority.high;
    } else if (energy == 'yüksek') {
      priority = TaskPriority.high;
    } else if (energy == 'düşük') {
      priority = TaskPriority.low;
    } else {
      priority = TaskPriority.medium;
    }

    var ordered = targets;
    if (examSoon) {
      ordered = List.of(targets)..shuffle(rng);
    } else if (energy == 'düşük') {
      ordered = targets.reversed.toList();
    }

    final duration = durationFor(energy);
    // Doğrudan dakika — önceden "saate yuvarla, sonra 60'la çarp" yapılıyordu
    // (ör. "20 dakikam var" → round(20/60)=0 → clamp(1,..)=1 saat = 60 dk),
    // kullanıcının söylediği kısa sürelerde plan gerçekte söylenenin 2-3
    // katı çıkıyordu (bkz. çağıran taraftaki clamp). Artık kayıpsız.
    final capacity = capacityMinutes;

    final int count;
    if (topics.isNotEmpty) {
      count = topics.length;
    } else if (fillToCapacity) {
      // Kalan süreyi doldur — ders sayısıyla sınırlama.
      count = (capacity ~/ duration).clamp(1, 20);
    } else {
      count = targets.length;
    }

    // Ders başına boş-konu imleci (round-robin) + GERÇEK deneme sonucundan
    // zayıf çıkan konu imleci (ayrı, öncelikli — bkz. examWeakTopics).
    final topicCursor = <String, int>{};
    final examWeakCursor = <String, int>{};
    var anyExamReview = false;
    ({String title, String? topicId, TopicDifficulty difficulty, String? reason})
        titleFor(SubjectModel subject, int i) {
      if (topics.isNotEmpty) {
        return (
          title: '${subject.name}: ${topics[i]}',
          topicId: null,
          difficulty: TopicDifficulty.medium,
          reason: subjectReasons[subject.id],
        );
      }
      // Deneme sonucunda GERÇEKTEN yanlış yapılan konu — kapsanmış (studied/
      // reviewed) olsa bile tekrar hak eder, bu yüzden uncoveredTopics'ten
      // ÖNCE kontrol edilir. Title'daki "(tekrar)" bu görevin neden var
      // olduğunu (kanıta dayalı bir tekrar, sıradan yeni bir konu değil)
      // açıkça söyler. difficulty=hard: bu, task.difficulty'nin tek
      // gerçek kaynağı (add_task ekranında elle seçim kaldırılmıştı,
      // bkz. ui-sprint-progress memory) — bir görevi "zor" işaretlemek
      // artık rastgele değil, GERÇEK bir sınav kanıtına dayanıyor, ve
      // RankSystem.xpBonusHardTask'ı ilk kez erişilebilir kılıyor.
      final weakPool = examWeakTopics[subject.id];
      if (weakPool != null && weakPool.isNotEmpty) {
        final widx = examWeakCursor[subject.id] ?? 0;
        if (widx < weakPool.length) {
          examWeakCursor[subject.id] = widx + 1;
          anyExamReview = true;
          final t = weakPool[widx];
          return (
            title: '${subject.name}: ${t.name} (tekrar)',
            topicId: t.id,
            difficulty: TopicDifficulty.hard,
            // En somut gerekçe — dersin genel StudyAdvisor gerekçesinden
            // (subjectReasons) daha spesifik, bu yüzden onu EZER.
            reason: 'Son denemende "${t.name}" konusundan yanlış yapmıştın.',
          );
        }
      }
      final pool = uncoveredTopics[subject.id];
      if (pool != null && pool.isNotEmpty) {
        final idx = topicCursor[subject.id] ?? 0;
        if (idx < pool.length) {
          topicCursor[subject.id] = idx + 1;
          final t = pool[idx];
          return (
            title: '${subject.name}: ${t.name}',
            topicId: t.id,
            difficulty: TopicDifficulty.medium,
            reason: subjectReasons[subject.id],
          );
        }
      }
      return (
        title: subject.name,
        topicId: null,
        difficulty: TopicDifficulty.medium,
        reason: subjectReasons[subject.id],
      );
    }

    var remaining = capacity;
    final blocks = <PlanBlock>[];
    final unfit = <String>[];
    var anyReduced = false;

    for (var i = 0; i < count; i++) {
      final subject = ordered[i % ordered.length];
      // Geçmişte bu dersin planlanan görevlerinin çoğu bitmemiş — aynı
      // sabit bloğu tekrar dayatmak yerine kademeli küçült (15 dk altına
      // inmez). Gerçekten küçülüyorsa (ör. 45→27) reason'da söylenir.
      final factor = _durationFactor(
          subject.id, reducedCapacitySubjectIds, subjectCompletionRates);
      final subjectDuration =
          (duration * factor).round().clamp(15, duration);
      if (subjectDuration < duration) anyReduced = true;

      if (subjectDuration > remaining) {
        unfit.add(
            topics.isNotEmpty ? '${subject.name}: ${topics[i]}' : subject.name);
        continue;
      }

      final t = titleFor(subject, i);
      blocks.add(PlanBlock(
        title: t.title,
        subjectId: subject.id,
        topicId: t.topicId,
        minutes: subjectDuration,
        order: blocks.length,
        priority: priority,
        difficulty: t.difficulty,
        reason: t.reason,
      ));

      remaining -= subjectDuration;
    }

    final String baseReason;
    if (examSoon) {
      baseReason = 'Sınava $examDays gün — öncelikler yükseltildi.';
    } else if (anyReduced) {
      baseReason = 'Bazı derslerde tamamlama oranın düşüktü — o bloklar daha '
          'küçük tutuldu, bitirmesi kolaylaşsın diye.';
    } else if (energy == 'düşük') {
      baseReason = 'Enerjin düşük — daha kısa bloklar seçildi.';
    } else if (energy == 'yüksek') {
      baseReason = 'Enerjin yüksek — uzun çalışma blokları seçildi.';
    } else {
      baseReason = 'Dengeli bir çalışma planı.';
    }
    // Deneme sonucundan gelen tekrar önerisi, hangi enerji/kapasite
    // gerekçesi geçerli olursa olsun her zaman EN ÖNE eklenir — bu,
    // "neden bu konu programda" sorusunun en somut cevabı.
    final reason = anyExamReview
        ? 'Son denemende yanlış yaptığın konu(lar) tekrar programa alındı. '
            '$baseReason'
        : baseReason;

    return PlanResult(blocks: blocks, unfitTitles: unfit, reason: reason);
  }

  /// Önümüzdeki [days] güne yayılan bir çalışma programı (docs/rakip_analizi
  /// §6 B2). Tek günün tekrarı DEĞİL — her gün dersler döndürülür, böylece
  /// odak her gün değişir. İşaretlenmemiş konular ([uncoveredTopics]) hafta
  /// boyunca **bir kez** tüketilir (aynı konu her gün çıkmaz).
  ///
  /// Saat atanmaz; her günün blokları o günün gün-kapsamlı yapılacak listesi.
  /// Çağıran taraf her bloğu kendi gününün `dueDate`'iyle `addTask`'a yazar.
  static WeekPlanResult buildWeek({
    required List<SubjectModel> orderedSubjects,
    Map<String, List<UncoveredTopic>> uncoveredTopics = const {},
    required int minutesPerDay,
    required DateTime startDate,
    int days = 7,
    int? examDays,
    Random? random,
    Set<String> reducedCapacitySubjectIds = const {},
    Map<String, double> subjectCompletionRates = const {},
    Map<String, List<UncoveredTopic>> examWeakTopics = const {},
    // Bkz. build()'daki aynı parametre notu.
    Map<String, String> subjectReasons = const {},
  }) {
    final subjectsPool = List<SubjectModel>.from(orderedSubjects);
    if (subjectsPool.isEmpty || days < 1) {
      return const WeekPlanResult(days: [], reason: '');
    }

    final examSoon = examDays != null && examDays >= 0 && examDays <= 30;
    final priority = examSoon ? TaskPriority.high : TaskPriority.medium;
    const duration = 45; // 'orta' blok
    // Doğrudan dakika (bkz. build() içindeki aynı düzeltme notu).
    final perDayCapacity = minutesPerDay.clamp(15, 8 * 60);
    final blocksPerDay = (perDayCapacity ~/ duration).clamp(1, 6);

    // Ders başına boş-konu imleci — TÜM hafta boyunca ilerler. Deneme
    // sonucundan zayıf çıkan konular (bkz. build()'daki aynı mantık/yorum)
    // yine ÖNCELİKLİ ve ayrı bir imleçle tüketilir.
    final topicCursor = <String, int>{};
    final examWeakCursor = <String, int>{};
    var anyExamReview = false;
    ({String title, String? topicId, TopicDifficulty difficulty, String? reason})
        titleFor(SubjectModel s) {
      final weakPool = examWeakTopics[s.id];
      if (weakPool != null && weakPool.isNotEmpty) {
        final widx = examWeakCursor[s.id] ?? 0;
        if (widx < weakPool.length) {
          examWeakCursor[s.id] = widx + 1;
          anyExamReview = true;
          final t = weakPool[widx];
          return (
            title: '${s.name}: ${t.name} (tekrar)',
            topicId: t.id,
            difficulty: TopicDifficulty.hard,
            reason: 'Son denemende "${t.name}" konusundan yanlış yapmıştın.',
          );
        }
      }
      final pool = uncoveredTopics[s.id];
      if (pool != null && pool.isNotEmpty) {
        final idx = topicCursor[s.id] ?? 0;
        if (idx < pool.length) {
          topicCursor[s.id] = idx + 1;
          final t = pool[idx];
          return (
            title: '${s.name}: ${t.name}',
            topicId: t.id,
            difficulty: TopicDifficulty.medium,
            reason: subjectReasons[s.id],
          );
        }
      }
      return (
        title: s.name,
        topicId: null,
        difficulty: TopicDifficulty.medium,
        reason: subjectReasons[s.id],
      );
    }

    final dayPlans = <DayPlan>[];
    var totalUnfit = 0;
    var anyReduced = false;

    for (var d = 0; d < days; d++) {
      // Günü döndür: gün d, sıradaki d'inci dersten başlar.
      final rotated = [
        for (var i = 0; i < subjectsPool.length; i++)
          subjectsPool[(i + d) % subjectsPool.length],
      ];

      final blocks = <PlanBlock>[];
      var remaining = perDayCapacity;
      for (var b = 0; b < blocksPerDay; b++) {
        final subject = rotated[b % rotated.length];
        final factor = _durationFactor(
            subject.id, reducedCapacitySubjectIds, subjectCompletionRates);
        final subjectDuration =
            (duration * factor).round().clamp(15, duration);
        if (subjectDuration < duration) anyReduced = true;

        if (subjectDuration > remaining) {
          totalUnfit++;
          continue;
        }
        final t = titleFor(subject);
        blocks.add(PlanBlock(
          title: t.title,
          subjectId: subject.id,
          topicId: t.topicId,
          minutes: subjectDuration,
          order: b,
          priority: priority,
          difficulty: t.difficulty,
          reason: t.reason,
        ));
        remaining -= subjectDuration;
      }

      if (blocks.isNotEmpty) {
        dayPlans.add(DayPlan(
          date: DateTime(startDate.year, startDate.month, startDate.day)
              .add(Duration(days: d)),
          blocks: blocks,
        ));
      }
    }

    final baseReason = examSoon
        ? 'Sınava $examDays gün — haftalık program, öncelikler yüksek.'
        : anyReduced
            ? 'Bazı derslerde tamamlama oranın düşüktü — o bloklar daha '
                'küçük tutuldu. Önümüzdeki ${dayPlans.length} güne yayıldı.'
            : 'Önümüzdeki ${dayPlans.length} güne dengeli bir program.';
    final reason = anyExamReview
        ? 'Son denemende yanlış yaptığın konu(lar) tekrar programa alındı. '
            '$baseReason'
        : baseReason;

    return WeekPlanResult(
      days: dayPlans,
      reason: reason,
      unfitCount: totalUnfit,
    );
  }
}

/// Konu Takip'ten işaretlenmemiş bir konu — ad + gerçek Hive id'si.
/// [PlanBuilder]'a yalnızca ad değil id de geçilir ki üretilen [PlanBlock]
/// tamamlanınca ilgili [TopicModel]'i otomatik işaretleyebilsin.
typedef UncoveredTopic = ({String name, String id});

class PlanBlock {
  final String title;
  final String subjectId;
  final int minutes;

  /// Listedeki sıra (0'dan). Saat değil — gün-kapsamlı sıralama ipucu.
  final int order;
  final TaskPriority priority;

  /// Bloğun bir Konu Takip konusundan üretildiyse o konunun id'si —
  /// görev tamamlanınca otomatik işaretlensin diye. Yoksa null.
  final String? topicId;

  /// Varsayılan medium — yalnız examWeakTopics'ten üretilen "(tekrar)"
  /// blokları hard işaretlenir (bkz. titleFor). task.difficulty'nin TEK
  /// gerçek kaynağı budur (add_task ekranındaki elle seçim kaldırılmıştı).
  final TopicDifficulty difficulty;

  /// "Neden bu görev?" (Faz 6/7) — somut bir sinyale dayanıyorsa dolu
  /// (examWeakTopics ya da StudyAdvisor'ın jenerik olmayan gerekçesi),
  /// yoksa null. Sahte/jenerik bir gerekçe ASLA üretilmez (bkz. titleFor).
  /// task.sourceReason'a birebir taşınır (bkz. coach_screen._commit).
  final String? reason;

  const PlanBlock({
    required this.title,
    required this.subjectId,
    required this.minutes,
    required this.order,
    required this.priority,
    this.topicId,
    this.difficulty = TopicDifficulty.medium,
    this.reason,
  });
}

class PlanResult {
  final List<PlanBlock> blocks;
  final List<String> unfitTitles;
  final String reason;

  const PlanResult({
    required this.blocks,
    required this.unfitTitles,
    required this.reason,
  });

  int get plannedMinutes => blocks.fold(0, (s, b) => s + b.minutes);
  bool get isEmpty => blocks.isEmpty;
}

/// Tek bir günün planı — [WeekPlanResult] içinde.
class DayPlan {
  final DateTime date;
  final List<PlanBlock> blocks;

  const DayPlan({required this.date, required this.blocks});

  int get minutes => blocks.fold(0, (s, b) => s + b.minutes);
}

/// [PlanBuilder.buildWeek] çıktısı — güne göre gruplu bloklar.
class WeekPlanResult {
  final List<DayPlan> days;
  final String reason;
  final int unfitCount;

  const WeekPlanResult({
    required this.days,
    required this.reason,
    this.unfitCount = 0,
  });

  bool get isEmpty => days.isEmpty;
  int get totalBlocks => days.fold(0, (s, d) => s + d.blocks.length);
  List<PlanBlock> get allBlocks => [for (final d in days) ...d.blocks];
}
