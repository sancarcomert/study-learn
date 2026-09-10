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
  /// [uncoveredTopics] (subjectId → işaretlenmemiş konu adları): verildiğinde
  /// ve [topics] boşken, görev başlıkları o dersin gerçek boş konularından
  /// üretilir ("Matematik: Türev"). [fillToCapacity] true ise görev sayısı
  /// ders sayısıyla değil, kalan süreyle sınırlanır — Koç "sen ayarla"
  /// modunda dolu bir program çıkarmak için.
  static PlanResult build({
    required List<SubjectModel> orderedSubjects,
    SubjectModel? explicitSubject,
    List<String> topics = const [],
    Map<String, List<String>> uncoveredTopics = const {},
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
    String titleFor(SubjectModel subject, int i) {
      if (topics.isNotEmpty) return '${subject.name}: ${topics[i]}';
      final pool = uncoveredTopics[subject.id];
      if (pool != null && pool.isNotEmpty) {
        final idx = topicCursor[subject.id] ?? 0;
        if (idx < pool.length) {
          topicCursor[subject.id] = idx + 1;
          return '${subject.name}: ${pool[idx]}';
        }
      }
      return subject.name;
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

      blocks.add(PlanBlock(
        title: titleFor(subject, i),
        subjectId: subject.id,
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
}

class PlanBlock {
  final String title;
  final String subjectId;
  final int minutes;

  /// Listedeki sıra (0'dan). Saat değil — gün-kapsamlı sıralama ipucu.
  final int order;
  final TaskPriority priority;

  const PlanBlock({
    required this.title,
    required this.subjectId,
    required this.minutes,
    required this.order,
    required this.priority,
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
