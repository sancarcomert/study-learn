import 'package:flutter_test/flutter_test.dart';
import 'package:study_planner/goal_gap_engine.dart';
import 'package:study_planner/stats_insight_engine.dart';

void main() {
  test('geçen hafta verisi yoksa hiçbir trend çıkarılmaz', () {
    final out = StatsInsightEngine.build(
      tasksThisWeek: 5,
      tasksLastWeek: 0,
      focusMinutesThisWeek: 100,
      focusMinutesLastWeek: 0,
    );
    expect(out, isEmpty);
  });

  test('görev artışı → "Toparlanıyorsun"', () {
    final out = StatsInsightEngine.build(
      tasksThisWeek: 8,
      tasksLastWeek: 3,
      focusMinutesThisWeek: 0,
      focusMinutesLastWeek: 0,
    );
    expect(out.single.title, 'Toparlanıyorsun');
    expect(out.single.body, contains('3 görev'));
    expect(out.single.body, contains('8'));
  });

  test('görev düşüşü → "Bu hafta biraz yavaşladın"', () {
    final out = StatsInsightEngine.build(
      tasksThisWeek: 2,
      tasksLastWeek: 6,
      focusMinutesThisWeek: 0,
      focusMinutesLastWeek: 0,
    );
    expect(out.single.title, 'Bu hafta biraz yavaşladın');
  });

  test('1 görevlik fark gürültü sayılır, insight üretmez', () {
    final out = StatsInsightEngine.build(
      tasksThisWeek: 4,
      tasksLastWeek: 3,
      focusMinutesThisWeek: 0,
      focusMinutesLastWeek: 0,
    );
    expect(out, isEmpty);
  });

  test('odak süresi artışı/düşüşü 15 dk eşiğinden sonra sinyal olur', () {
    final flat = StatsInsightEngine.build(
      tasksThisWeek: 0,
      tasksLastWeek: 0,
      focusMinutesThisWeek: 110,
      focusMinutesLastWeek: 100,
    );
    expect(flat, isEmpty);

    final up = StatsInsightEngine.build(
      tasksThisWeek: 0,
      tasksLastWeek: 0,
      focusMinutesThisWeek: 150,
      focusMinutesLastWeek: 100,
    );
    expect(up.single.title, 'Daha çok odaklandın');

    final down = StatsInsightEngine.build(
      tasksThisWeek: 0,
      tasksLastWeek: 0,
      focusMinutesThisWeek: 50,
      focusMinutesLastWeek: 100,
    );
    expect(down.single.title, 'Odak süren düştü');
  });

  test('düşük tamamlama oranı → plan küçülme açıklaması, en düşük ders seçilir',
      () {
    final out = StatsInsightEngine.build(
      tasksThisWeek: 0,
      tasksLastWeek: 0,
      focusMinutesThisWeek: 0,
      focusMinutesLastWeek: 0,
      completionRateBySubject: {'id-fizik': 0.3, 'id-kimya': 0.9},
      subjectNamesById: {'id-fizik': 'Fizik', 'id-kimya': 'Kimya'},
    );
    expect(out.single.title, 'Fizik için planın küçüldü');
    expect(out.single.body, contains('%30'));
  });

  test('%60 ve üzeri tamamlama oranı için küçülme açıklaması üretilmez', () {
    final out = StatsInsightEngine.build(
      tasksThisWeek: 0,
      tasksLastWeek: 0,
      focusMinutesThisWeek: 0,
      focusMinutesLastWeek: 0,
      completionRateBySubject: {'id-fizik': 0.75},
      subjectNamesById: {'id-fizik': 'Fizik'},
    );
    expect(out, isEmpty);
  });

  test('birden fazla insight aynı anda üretilebilir', () {
    final out = StatsInsightEngine.build(
      tasksThisWeek: 8,
      tasksLastWeek: 3,
      focusMinutesThisWeek: 150,
      focusMinutesLastWeek: 100,
      completionRateBySubject: {'id-fizik': 0.3},
      subjectNamesById: {'id-fizik': 'Fizik'},
    );
    expect(out.length, 3);
  });

  test('deneme sonucundan gelen tekrar önerisi (tekil konu)', () {
    final out = StatsInsightEngine.build(
      tasksThisWeek: 0,
      tasksLastWeek: 0,
      focusMinutesThisWeek: 0,
      focusMinutesLastWeek: 0,
      examWeakTopicsBySubject: {
        'id-matematik': ['Türev'],
      },
      subjectNamesById: {'id-matematik': 'Matematik'},
    );
    expect(out.single.title, 'Matematik için tekrar önerisi');
    expect(out.single.body, contains('"Türev" konusunda'));
    expect(out.single.body, contains('Akıllı Plan bunu tekrar programa aldı'));
  });

  test('deneme sonucundan gelen tekrar önerisi (birden fazla konu, çoğul ek)',
      () {
    final out = StatsInsightEngine.build(
      tasksThisWeek: 0,
      tasksLastWeek: 0,
      focusMinutesThisWeek: 0,
      focusMinutesLastWeek: 0,
      examWeakTopicsBySubject: {
        'id-matematik': ['Türev', 'İntegral'],
      },
      subjectNamesById: {'id-matematik': 'Matematik'},
    );
    expect(out.single.body, contains('konularında'));
  });

  group('goal gap insight (Faz 6)', () {
    test('hedef yoksa hiçbir hedef mesajı eklenmez', () {
      final out = StatsInsightEngine.build(
        tasksThisWeek: 0,
        tasksLastWeek: 0,
        focusMinutesThisWeek: 0,
        focusMinutesLastWeek: 0,
      );
      expect(out, isEmpty);
    });

    test('hedef var, deneme yok → yalnız hedefi bildiren mesaj', () {
      final gap = GoalGapEngine.compute(examType: 'TYT', target: 70);
      final out = StatsInsightEngine.build(
        tasksThisWeek: 0,
        tasksLastWeek: 0,
        focusMinutesThisWeek: 0,
        focusMinutesLastWeek: 0,
        goalGap: gap,
      );
      expect(out.single.title, contains('hedefin kayıtlı'));
      expect(out.single.body, contains('70'));
      expect(out.single.body, contains('Henüz deneme eklemedin'));
    });

    test('hedefin altında → fark net olarak gösterilir', () {
      final gap = GoalGapEngine.compute(
        examType: 'TYT',
        target: 70,
        currentNet: 60,
      );
      final out = StatsInsightEngine.build(
        tasksThisWeek: 0,
        tasksLastWeek: 0,
        focusMinutesThisWeek: 0,
        focusMinutesLastWeek: 0,
        goalGap: gap,
      );
      expect(out.single.body, contains('70'));
      expect(out.single.body, contains('60'));
      expect(out.single.body, contains('10 net'));
    });

    test('hedefe tam ulaşıldı → "ulaştın" mesajı, motivasyonel dolgu yok', () {
      final gap = GoalGapEngine.compute(
        examType: 'TYT',
        target: 70,
        currentNet: 72,
      );
      final out = StatsInsightEngine.build(
        tasksThisWeek: 0,
        tasksLastWeek: 0,
        focusMinutesThisWeek: 0,
        focusMinutesLastWeek: 0,
        goalGap: gap,
      );
      expect(out.single.title, contains('ulaştın'));
      expect(out.single.body, isNot(contains('!')));
    });

    test('geçmiş denemeye göre fark kapandıysa bildirilir', () {
      final gap = GoalGapEngine.compute(
        examType: 'TYT',
        target: 70,
        currentNet: 64,
        previousNet: 61,
      );
      final out = StatsInsightEngine.build(
        tasksThisWeek: 0,
        tasksLastWeek: 0,
        focusMinutesThisWeek: 0,
        focusMinutesLastWeek: 0,
        goalGap: gap,
      );
      expect(out.single.body, contains('kapandı'));
    });

    test('en çok etkileyen ders verilmişse cümleye eklenir', () {
      final gap = GoalGapEngine.compute(
        examType: 'TYT',
        target: 70,
        currentNet: 60,
      );
      final out = StatsInsightEngine.build(
        tasksThisWeek: 0,
        tasksLastWeek: 0,
        focusMinutesThisWeek: 0,
        focusMinutesLastWeek: 0,
        goalGap: gap,
        weakestSubjectName: 'Matematik',
      );
      expect(out.single.body, contains('Matematik'));
    });

    test('AYT hedefi bağımsız çalışır', () {
      final gap = GoalGapEngine.compute(
        examType: 'AYT',
        target: 50,
        currentNet: 45,
      );
      final out = StatsInsightEngine.build(
        tasksThisWeek: 0,
        tasksLastWeek: 0,
        focusMinutesThisWeek: 0,
        focusMinutesLastWeek: 0,
        goalGap: gap,
      );
      expect(out.single.body, contains('AYT'));
    });
  });

  group('resolved weak topics / iyileşme anı (Faz 8)', () {
    test('bir konu artık zayıf işaretli değilse factual mesaj üretir', () {
      final out = StatsInsightEngine.build(
        tasksThisWeek: 0,
        tasksLastWeek: 0,
        focusMinutesThisWeek: 0,
        focusMinutesLastWeek: 0,
        resolvedWeakTopicsBySubject: {
          'id-matematik': ['Türev'],
        },
        subjectNamesById: {'id-matematik': 'Matematik'},
      );
      expect(out.single.body,
          contains('artık son denemendeki zayıf konu listesinde değil'));
      expect(out.single.body, contains('"Türev"'));
    });

    test('boşsa hiçbir ilerleme mesajı eklenmez', () {
      final out = StatsInsightEngine.build(
        tasksThisWeek: 0,
        tasksLastWeek: 0,
        focusMinutesThisWeek: 0,
        focusMinutesLastWeek: 0,
      );
      expect(out, isEmpty);
    });
  });
}
