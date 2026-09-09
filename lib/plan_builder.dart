import 'dart:math';

import 'subject_model.dart';
import 'task_model.dart';

/// Günlük plan üretiminin SAF çekirdeği. Girdi alır, oluşturulacak
/// blokların listesini döndürür — hiçbir şey yazmaz, provider'a dokunmaz.
/// Çağıran taraf (coach_screen) blokları `taskProvider.addTask` ile kaydeder.
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
  static PlanResult build({
    required List<SubjectModel> orderedSubjects,
    SubjectModel? explicitSubject,
    List<String> topics = const [],
    required int hoursAvailable,
    required String energy,
    int? examDays,
    DateTime? now,
    Random? random,
  }) {
    final start = now ?? DateTime.now();
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

    final count = topics.isNotEmpty ? topics.length : targets.length;
    final duration = durationFor(energy);
    final capacity = hoursAvailable * 60;

    var remaining = capacity;
    var offset = 0;
    final blocks = <PlanBlock>[];
    final unfit = <String>[];

    for (var i = 0; i < count; i++) {
      final subject = ordered[i % ordered.length];
      final title =
          topics.isNotEmpty ? '${subject.name}: ${topics[i]}' : subject.name;

      if (duration > remaining) {
        unfit.add(title);
        continue;
      }

      blocks.add(PlanBlock(
        title: title,
        subjectId: subject.id,
        minutes: duration,
        startTime: start.add(Duration(minutes: offset)),
        priority: priority,
      ));

      offset += duration;
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
  final DateTime startTime;
  final TaskPriority priority;

  const PlanBlock({
    required this.title,
    required this.subjectId,
    required this.minutes,
    required this.startTime,
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
