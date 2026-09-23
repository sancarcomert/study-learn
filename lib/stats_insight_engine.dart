import 'goal_gap_engine.dart';

/// İstatistik ekranının "NEDEN" katmanı — ham sayıları ("bu hafta 12 görev,
/// 180 dk odak") tek başına bırakmak yerine, geçen haftayla kıyaslayıp
/// GERÇEK bir yön (iyiye mi kötüye mi) çıkarır. [_InsightCard] (StudyAdvisor)
/// zaten "sırada ne var" sorusunu cevaplıyor — bu motor onun YANINA "neden
/// buradayım" sorusunu ekler, aynı motoru tekrar icat etmez.
///
/// Her [StatsInsight] gerçek bir hesaplanmış farktan gelir (bkz.
/// test/stats_insight_engine_test.dart) — kozmetik/rastgele metin yok.
class StatsInsight {
  final String title;
  final String body;

  const StatsInsight({required this.title, required this.body});
}

class StatsInsightEngine {
  const StatsInsightEngine._();

  /// Anlamlı sayılmayan küçük dalgalanmaları (gürültü) filtrelemek için
  /// eşikler — 1 görevlik ya da 15 dk'lık fark haftadan haftaya doğal
  /// varyasyon, "trend" değil.
  static const int _taskNoiseThreshold = 1;
  static const int _focusNoiseThreshold = 15;

  /// [completionRateBySubject] StudyAdvisor.completionRateBySubject'ten
  /// gelir (≥3 görevlik dersler için 0..1 oran). [subjectNamesById]
  /// görüntülenecek ders adı için.
  static List<StatsInsight> build({
    required int tasksThisWeek,
    required int tasksLastWeek,
    required int focusMinutesThisWeek,
    required int focusMinutesLastWeek,
    Map<String, double> completionRateBySubject = const {},
    Map<String, String> subjectNamesById = const {},
    Map<String, List<String>> examWeakTopicsBySubject = const {},
    // GOAL → GAP → RE-EVALUATION (Faz 6/9) — bkz. goal_gap_provider.dart.
    // Null ise (hedef girilmemiş) hiçbir hedef cümlesi eklenmez.
    GoalGap? goalGap,
    // "En çok bu farkı etkileyen ders" — weakestDenemeSubjectNameProvider'dan
    // gelir, YENİ bir hesap İCAT EDİLMEZ.
    String? weakestSubjectName,
    // "İyileşme anı" (Faz 8) — bkz. resolvedWeakTopicsBySubjectProvider.
    Map<String, List<String>> resolvedWeakTopicsBySubject = const {},
  }) {
    final insights = <StatsInsight>[];

    // GOAL → GAP hikayesinin başlangıcı — "nerede duruyorum, hedefe göre"
    // en tepede: diğer tüm içgörüler ("neden buradayım") bu bağlamın
    // devamı. Yalnız GERÇEK veri destekliyorsa üretilir (hedef yoksa hiç
    // eklenmez) — motivasyonel dolgu YOK, yalnız hesaplanmış fark.
    final goalInsight = _goalGapInsight(goalGap, weakestSubjectName);
    if (goalInsight != null) insights.add(goalInsight);

    // İyileşme anı (Faz 8) — bir konu önceki denemede zayıfken son
    // denemede artık işaretli değil. Kutlama DEĞİL, gözlemlenmiş bir sonuç.
    if (resolvedWeakTopicsBySubject.isNotEmpty) {
      final entry = resolvedWeakTopicsBySubject.entries.first;
      final name = subjectNamesById[entry.key] ?? 'Bu ders';
      final topics = entry.value;
      final topicText = topics.map((t) => '"$t"').join(', ');
      final label = topics.length == 1 ? 'konusu' : 'konuları';
      insights.add(StatsInsight(
        title: '$name için ilerleme',
        body: '$topicText $label artık son denemendeki zayıf konu '
            'listesinde değil.',
      ));
    }

    // Deneme sonucundan gelen tekrar önerisi — RESULT → INTERPRETATION →
    // PLAN döngüsünün İstatistik'te görünen tarafı. Davranışsal
    // (süre bazlı) sinyalle KARIŞTIRILMAZ; bu yalnız öğrencinin kendi
    // işaretlediği GERÇEK yanlış-konulardan gelir (bkz. deneme_provider.dart).
    if (examWeakTopicsBySubject.isNotEmpty) {
      final entry = examWeakTopicsBySubject.entries.first;
      final name = subjectNamesById[entry.key] ?? 'Bu ders';
      final topics = entry.value;
      final topicText = topics.map((t) => '"$t"').join(', ');
      final label = topics.length == 1 ? 'konusunda' : 'konularında';
      insights.add(StatsInsight(
        title: '$name için tekrar önerisi',
        body: 'Son denemende $topicText $label yanlış yapmıştın — Akıllı '
            'Plan bunu tekrar programa aldı.',
      ));
    }

    // Görev tamamlama trendi — geçen hafta hiç veri yoksa "iyileşme/düşüş"
    // anlamsız (kıyaslanacak bir şey yok), sessizce atlanır.
    if (tasksLastWeek > 0) {
      final delta = tasksThisWeek - tasksLastWeek;
      if (delta.abs() > _taskNoiseThreshold) {
        insights.add(delta > 0
            ? StatsInsight(
                title: 'Toparlanıyorsun',
                body: 'Geçen hafta $tasksLastWeek görev bitirmiştin, bu '
                    'hafta $tasksThisWeek — $delta fazla.',
              )
            : StatsInsight(
                title: 'Bu hafta biraz yavaşladın',
                body: 'Geçen hafta $tasksLastWeek görev bitirmiştin, bu '
                    'hafta $tasksThisWeek — ${-delta} eksik.',
              ));
      }
    }

    // Odak süresi trendi — aynı gerekçeyle geçen hafta verisi şart.
    if (focusMinutesLastWeek > 0) {
      final delta = focusMinutesThisWeek - focusMinutesLastWeek;
      if (delta.abs() > _focusNoiseThreshold) {
        insights.add(delta > 0
            ? StatsInsight(
                title: 'Daha çok odaklandın',
                body: 'Geçen hafta $focusMinutesLastWeek dk, bu hafta '
                    '$focusMinutesThisWeek dk odaklandın.',
              )
            : StatsInsight(
                title: 'Odak süren düştü',
                body: 'Geçen hafta $focusMinutesLastWeek dk, bu hafta '
                    '$focusMinutesThisWeek dk odaklandın.',
              ));
      }
    }

    // Akıllı Plan'ın SESSİZCE küçülttüğü blokların (PlanBuilder'daki
    // sürekli tamamlama-oranı uyarlaması) açıklaması — açıklanmazsa
    // öğrenci "neden daha az görev çıktı" diye anlam veremez.
    final shrunk = completionRateBySubject.entries
        .where((e) => e.value < 0.6)
        .toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    if (shrunk.isNotEmpty) {
      final worst = shrunk.first;
      final name = subjectNamesById[worst.key] ?? 'Bu ders';
      insights.add(StatsInsight(
        title: '$name için planın küçüldü',
        body: 'Son görevlerinin %${(worst.value * 100).round()}\'ini '
            'bitirdin — Akıllı Plan bu derste daha küçük bloklar öneriyor, '
            'bitirmesi kolaylaşsın diye.',
      ));
    }

    return insights;
  }

  /// GOAL → CURRENT STATE → GAP cümlesi. Hedef girilmemişse (goalGap==null
  /// ya da hasTarget==false) null — hiçbir hedef mesajı gösterilmez (Faz 13
  /// Senaryo 5). Sahte kesinlik/formül YOK, yalnızca hesaplanmış fark.
  static StatsInsight? _goalGapInsight(
    GoalGap? goalGap,
    String? weakestSubjectName,
  ) {
    if (goalGap == null || !goalGap.hasTarget) return null;
    final type = goalGap.examType;
    final target = goalGap.target!;
    final targetText = _fmtNet(target);

    if (!goalGap.hasResult) {
      return StatsInsight(
        title: '$type hedefin kayıtlı',
        body: '$type için hedefin $targetText net. Henüz deneme eklemedin — '
            'ilk sonucunu girince hedefine olan mesafeni burada göreceksin.',
      );
    }

    final current = goalGap.currentNet!;
    final currentText = _fmtNet(current);
    final gap = goalGap.gap!;

    if (gap <= 0) {
      return StatsInsight(
        title: '$type hedefine ulaştın',
        body: 'Son $type sonucun $currentText net — $targetText net '
            'hedefini geçtin.',
      );
    }

    final buffer = StringBuffer(
      '$type hedefin $targetText net. Son sonucun $currentText net — '
      'aradaki fark ${_fmtNet(gap)} net.',
    );

    final gapChange = goalGap.gapChange;
    if (gapChange != null && gapChange.abs() >= 0.5) {
      buffer.write(gapChange > 0
          ? ' Önceki denemene göre fark ${_fmtNet(gapChange)} net kapandı.'
          : ' Önceki denemene göre fark ${_fmtNet(-gapChange)} net açıldı.');
    }

    if (weakestSubjectName != null) {
      buffer.write(
          ' $weakestSubjectName şu an bu farkı en çok etkileyen ders.');
    }

    if (goalGap.examPassed) {
      buffer.write(' Sınav tarihin geçmiş görünüyor — güncel bir tarih '
          'girmek ister misin?');
    }

    return StatsInsight(title: '$type hedefine mesafen', body: buffer.toString());
  }

  static String _fmtNet(double value) =>
      value == value.roundToDouble()
          ? value.toStringAsFixed(0)
          : value.toStringAsFixed(1);
}
