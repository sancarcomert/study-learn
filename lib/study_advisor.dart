import 'subject_model.dart';
import 'task_model.dart';

/// "Bugün ne çalışsam?" için YEREL öneri motoru. LLM yok — mevcut Hive
/// verisi (dersler + görevler + sınav tarihi) üzerinde kural tabanlı puanlama.
///
/// Salt okunur: veri alır, [StudySuggestion] listesi döndürür. Görev
/// oluşturmaz, hiçbir provider'a dokunmaz.
class StudyAdvisor {
  const StudyAdvisor._();

  /// En çok ihmal edilen / geride kalan dersleri gerekçesiyle sıralar.
  /// Bugün zaten görevi olan dersler elenir (tekrar önermek anlamsız).
  /// [coveragePercent] (subjectId → 0..1): yalnızca konusu olan dersler için
  /// Konu Takip kapsama oranı. Verildiğinde düşük kapsamlı dersler öne çıkar.
  /// [weakestDenemeSubjectId] verilirse (Deneme Takip'teki en düşük ortalama
  /// nete sahip bölümle eşleşen ders) o ders öne çıkar — Deneme Takip'i salt
  /// bir grafik olmaktan çıkarıp plana etki ettirir.
  static List<StudySuggestion> suggest({
    required List<SubjectModel> subjects,
    required List<TaskModel> tasks,
    DateTime? examDate,
    DateTime? now,
    int limit = 3,
    Map<String, double> coveragePercent = const {},
    String? weakestDenemeSubjectId,
  }) {
    if (subjects.isEmpty) return const [];

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

      // --- Puan (0..~1.6) ---
      var score = 0.0;
      score += (daysSinceTouch.clamp(0, 21) / 21) * 0.50; // ihmal
      score += (1 - completionRate) * 0.25; // geride kalma
      if (total == 0) score += 0.15; // hiç dokunulmamış
      if (hasPendingPriority) score += 0.20 + examPressure * 0.15;
      if (coverage != null) score += (1 - coverage) * 0.35; // konu boşluğu
      if (isWeakestDeneme) score += 0.20; // deneme netinde en zayıf

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
  }) {
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
    if (daysSinceTouch >= 7) {
      return '$daysSinceTouch gündür dokunmadın';
    }
    if (completionRate < 0.5 && total >= 3) {
      return 'Tamamlama oranın düşük (%${(completionRate * 100).round()})';
    }
    if (examDays != null && examDays >= 0 && examDays <= 30) {
      return 'Sınav yaklaşıyor — tekrar için iyi zaman';
    }
    return 'Dengeli ilerlemek için iyi bir seçim';
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
