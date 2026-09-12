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
  static PlanResult build({
    required List<SubjectModel> orderedSubjects,
    SubjectModel? explicitSubject,
    List<String> topics = const [],
    Map<String, List<UncoveredTopic>> uncoveredTopics = const {},
    bool fillToCapacity = false,
    required int hoursAvailable,
    required String energy,
    int? examDays,
    Random? random,
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
    final capacity = hoursAvailable * 60;

    final int count;
    if (topics.isNotEmpty) {
      count = topics.length;
    } else if (fillToCapacity) {
      // Kalan süreyi doldur — ders sayısıyla sınırlama.
      count = (capacity ~/ duration).clamp(1, 20);
    } else {
      count = targets.length;
    }

    // Ders başına boş-konu imleci (round-robin).
    final topicCursor = <String, int>{};
    ({String title, String? topicId}) titleFor(SubjectModel subject, int i) {
      if (topics.isNotEmpty) {
        return (title: '${subject.name}: ${topics[i]}', topicId: null);
      }
      final pool = uncoveredTopics[subject.id];
      if (pool != null && pool.isNotEmpty) {
        final idx = topicCursor[subject.id] ?? 0;
        if (idx < pool.length) {
          topicCursor[subject.id] = idx + 1;
          final t = pool[idx];
          return (title: '${subject.name}: ${t.name}', topicId: t.id);
        }
      }
      return (title: subject.name, topicId: null);
    }

    var remaining = capacity;
    final blocks = <PlanBlock>[];
    final unfit = <String>[];

    for (var i = 0; i < count; i++) {
      final subject = ordered[i % ordered.length];

      if (duration > remaining) {
        unfit.add(
            topics.isNotEmpty ? '${subject.name}: ${topics[i]}' : subject.name);
        continue;
      }

      final t = titleFor(subject, i);
      blocks.add(PlanBlock(
        title: t.title,
        subjectId: subject.id,
        topicId: t.topicId,
        minutes: duration,
        order: blocks.length,
        priority: priority,
      ));

      remaining -= duration;
    }

    final String reason;
    if (examSoon) {
      reason = 'Sınava $examDays gün — öncelikler yükseltildi 📌';
    } else if (energy == 'düşük') {
      reason = 'Enerjin düşük — daha kısa bloklar seçildi 🌱';
    } else if (energy == 'yüksek') {
      reason = 'Enerjin yüksek — uzun çalışma blokları seçildi 🔥';
    } else {
      reason = 'Dengeli bir çalışma planı 🎯';
    }

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
    required int hoursPerDay,
    required DateTime startDate,
    int days = 7,
    int? examDays,
    Random? random,
  }) {
    final subjectsPool = List<SubjectModel>.from(orderedSubjects);
    if (subjectsPool.isEmpty || days < 1) {
      return const WeekPlanResult(days: [], reason: '');
    }

    final examSoon = examDays != null && examDays >= 0 && examDays <= 30;
    final priority = examSoon ? TaskPriority.high : TaskPriority.medium;
    const duration = 45; // 'orta' blok
    final perDayCapacity = hoursPerDay.clamp(1, 8) * 60;
    final blocksPerDay = (perDayCapacity ~/ duration).clamp(1, 6);

    // Ders başına boş-konu imleci — TÜM hafta boyunca ilerler.
    final topicCursor = <String, int>{};
    ({String title, String? topicId}) titleFor(SubjectModel s) {
      final pool = uncoveredTopics[s.id];
      if (pool != null && pool.isNotEmpty) {
        final idx = topicCursor[s.id] ?? 0;
        if (idx < pool.length) {
          topicCursor[s.id] = idx + 1;
          final t = pool[idx];
          return (title: '${s.name}: ${t.name}', topicId: t.id);
        }
      }
      return (title: s.name, topicId: null);
    }

    final dayPlans = <DayPlan>[];
    var totalUnfit = 0;

    for (var d = 0; d < days; d++) {
      // Günü döndür: gün d, sıradaki d'inci dersten başlar.
      final rotated = [
        for (var i = 0; i < subjectsPool.length; i++)
          subjectsPool[(i + d) % subjectsPool.length],
      ];

      final blocks = <PlanBlock>[];
      var remaining = perDayCapacity;
      for (var b = 0; b < blocksPerDay; b++) {
        if (duration > remaining) {
          totalUnfit++;
          continue;
        }
        final subject = rotated[b % rotated.length];
        final t = titleFor(subject);
        blocks.add(PlanBlock(
          title: t.title,
          subjectId: subject.id,
          topicId: t.topicId,
          minutes: duration,
          order: b,
          priority: priority,
        ));
        remaining -= duration;
      }

      if (blocks.isNotEmpty) {
        dayPlans.add(DayPlan(
          date: DateTime(startDate.year, startDate.month, startDate.day)
              .add(Duration(days: d)),
          blocks: blocks,
        ));
      }
    }

    final reason = examSoon
        ? 'Sınava $examDays gün — haftalık program, öncelikler yüksek 📌'
        : 'Önümüzdeki ${dayPlans.length} güne dengeli bir program 🗓️';

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

  const PlanBlock({
    required this.title,
    required this.subjectId,
    required this.minutes,
    required this.order,
    required this.priority,
    this.topicId,
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
