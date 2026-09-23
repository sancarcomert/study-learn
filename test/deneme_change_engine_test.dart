import 'package:flutter_test/flutter_test.dart';
import 'package:study_planner/deneme_change_engine.dart';
import 'package:study_planner/deneme_model.dart';
import 'package:study_planner/goal_gap_engine.dart';

DenemeEntry _entry(List<DenemeSectionScore> sections, {DateTime? date}) =>
    DenemeEntry(
      id: 'x',
      examType: 'TYT',
      date: date ?? DateTime(2026, 9, 1),
      sections: sections,
    );

void main() {
  group('mostChangedSubject', () {
    test('önceki deneme yoksa null', () {
      final current = _entry([DenemeSectionScore(subject: 'Matematik', correct: 20)]);
      expect(DenemeChangeEngine.mostChangedSubject(current, null), isNull);
    });

    test('ortak dersler arasında en büyük mutlak farkı bulur', () {
      final previous = _entry([
        DenemeSectionScore(subject: 'Matematik', correct: 15),
        DenemeSectionScore(subject: 'Fizik', correct: 10),
      ]);
      final current = _entry([
        DenemeSectionScore(subject: 'Matematik', correct: 16), // +1
        DenemeSectionScore(subject: 'Fizik', correct: 15), // +5
      ]);
      final result = DenemeChangeEngine.mostChangedSubject(current, previous);
      expect(result?.subjectName, 'Fizik');
      expect(result?.delta, 5);
    });

    test('0.5 net altındaki farklar gürültü sayılır', () {
      final previous = _entry([DenemeSectionScore(subject: 'Matematik', correct: 15)]);
      final current = _entry([DenemeSectionScore(subject: 'Matematik', correct: 15, wrong: 1)]);
      // net farkı 0.25 — eşiğin altında.
      expect(DenemeChangeEngine.mostChangedSubject(current, previous), isNull);
    });

    test('önceki denemede olmayan bir ders kıyaslanmaz', () {
      final previous = _entry([DenemeSectionScore(subject: 'Matematik', correct: 15)]);
      final current = _entry([DenemeSectionScore(subject: 'Kimya', correct: 20)]);
      expect(DenemeChangeEngine.mostChangedSubject(current, previous), isNull);
    });
  });

  group('summarize', () {
    test('hiçbir sinyal yoksa null', () {
      expect(DenemeChangeEngine.summarize(), isNull);
    });

    test('hedef gap değişimi en yüksek öncelik', () {
      final gap = GoalGapEngine.compute(
        examType: 'TYT',
        target: 70,
        currentNet: 64,
        previousNet: 61,
      );
      final out = DenemeChangeEngine.summarize(
        goalGap: gap,
        mostChangedSubject:
            const SubjectNetChange(subjectName: 'Fizik', delta: 5),
      );
      expect(out, contains('9'));
      expect(out, contains('6'));
      expect(out, isNot(contains('Fizik')));
    });

    test('hedefe bu denemeyle ulaşıldıysa özel cümle', () {
      final gap = GoalGapEngine.compute(
        examType: 'TYT',
        target: 70,
        currentNet: 72,
        previousNet: 65,
      );
      final out = DenemeChangeEngine.summarize(goalGap: gap);
      expect(out, contains('hedefine ulaştın'));
    });

    test('hedef yoksa en çok değişen ders devreye girer', () {
      const change = SubjectNetChange(subjectName: 'Fizik', delta: 5);
      final out = DenemeChangeEngine.summarize(mostChangedSubject: change);
      expect(out, contains('Fizik'));
      expect(out, contains('+5'));
    });

    test('iyileşen konu eklenir', () {
      final out = DenemeChangeEngine.summarize(
        resolvedSubjectTopics: {
          'id-mat': ['Türev'],
        },
      );
      expect(out, contains('"Türev"'));
      expect(out, contains('artık'));
    });

    test('yeni zayıf konu yalnız başka bir sinyal yoksa eklenir', () {
      final out = DenemeChangeEngine.summarize(
        newlyWeakSubjectTopics: {
          'id-mat': ['İntegral'],
        },
      );
      expect(out, contains('"İntegral"'));
      expect(out, contains('yeni bir zayıf konu'));
    });

    test('iyileşme ve gap değişimi birlikte gösterilebilir (en fazla 2 cümle)',
        () {
      final gap = GoalGapEngine.compute(
        examType: 'TYT',
        target: 70,
        currentNet: 64,
        previousNet: 61,
      );
      final out = DenemeChangeEngine.summarize(
        goalGap: gap,
        resolvedSubjectTopics: {
          'id-mat': ['Türev'],
        },
      );
      expect(out, contains('9'));
      expect(out, contains('Türev'));
    });
  });
}
