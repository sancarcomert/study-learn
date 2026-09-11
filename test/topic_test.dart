import 'package:flutter_test/flutter_test.dart';
import 'package:study_planner/topic_catalog.dart';
import 'package:study_planner/topic_model.dart';
import 'package:study_planner/topic_provider.dart';

TopicModel _t(TopicStatus s) => TopicModel(
      id: 's',
      subjectId: 'x',
      name: 'k',
      status: s,
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  group('TopicModel', () {
    test('durum döngüsü: başlanmadı → çalışıldı → tekrar → başlanmadı', () {
      expect(_t(TopicStatus.notStarted).nextStatus, TopicStatus.studied);
      expect(_t(TopicStatus.studied).nextStatus, TopicStatus.reviewed);
      expect(_t(TopicStatus.reviewed).nextStatus, TopicStatus.notStarted);
    });

    test('isCovered yalnız çalışıldı/tekrar için true', () {
      expect(_t(TopicStatus.notStarted).isCovered, isFalse);
      expect(_t(TopicStatus.studied).isCovered, isTrue);
      expect(_t(TopicStatus.reviewed).isCovered, isTrue);
    });
  });

  group('TopicCoverage', () {
    test('yüzde ve oran', () {
      const c = TopicCoverage(3, 12);
      expect(c.ratio, closeTo(0.25, 0.001));
      expect(c.percent, 25);
      expect(c.hasTopics, isTrue);
    });

    test('boş → 0, hasTopics false', () {
      const c = TopicCoverage(0, 0);
      expect(c.ratio, 0);
      expect(c.percent, 0);
      expect(c.hasTopics, isFalse);
    });
  });

  group('TopicCatalog', () {
    test('bilinen ders → dolu liste', () {
      expect(TopicCatalog.forSubject('Matematik'), isNotEmpty);
      expect(TopicCatalog.forSubject('matematik'), contains('Türev'));
    });

    test('kısmi eşleşme: "TYT Fizik" → Fizik listesi', () {
      expect(TopicCatalog.forSubject('TYT Fizik'), isNotEmpty);
    });

    test('İ harfi normalize: "İngilizce"', () {
      expect(TopicCatalog.forSubject('İngilizce'), isNotEmpty);
    });

    test('bilinmeyen ders → boş', () {
      expect(TopicCatalog.forSubject('Astroloji'), isEmpty);
      expect(TopicCatalog.hasCatalog('Astroloji'), isFalse);
    });

    test('maxGrade: kümülatif ve sınıf sınırını aşmıyor (P0-11)', () {
      final g9 = TopicCatalog.forSubject('Matematik', maxGrade: 9);
      final g10 = TopicCatalog.forSubject('Matematik', maxGrade: 10);
      final g12 = TopicCatalog.forSubject('Matematik', maxGrade: 12);
      final all = TopicCatalog.forSubject('Matematik');

      expect(g9, isNotEmpty);
      expect(g9, isNot(contains('Türev'))); // 12. sınıf konusu
      expect(g10, contains('Fonksiyonlar')); // 10. sınıf konusu
      expect(g10, isNot(contains('Türev')));
      expect(g12, contains('Türev'));
      expect(g12.length, all.length); // 12/mezun tüm listeyi görür

      // kümülatif: 9 ⊆ 10 ⊆ 12
      expect(g9.every((t) => g10.contains(t)), isTrue);
      expect(g10.every((t) => g12.contains(t)), isTrue);
    });

    test('maxGrade verilmezse eski davranış (tüm liste)', () {
      expect(
        TopicCatalog.forSubject('Matematik'),
        TopicCatalog.forSubject('Matematik', maxGrade: null),
      );
    });
  });
}
