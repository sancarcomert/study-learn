import 'package:flutter_test/flutter_test.dart';
import 'package:study_planner/topic_evidence.dart';
import 'package:study_planner/topic_model.dart';

void main() {
  group('TopicEvidenceEngine.classify — öncelik sırası', () {
    test('kanıt yoksa rozet yok', () {
      final e = TopicEvidenceEngine.classify(
        isExamWeak: false,
        isRecentlyResolved: false,
        status: TopicStatus.notStarted,
        updatedAt: null,
      );
      expect(e.hasBadge, isFalse);
      expect(e.state, TopicEvidenceState.none);
      expect(e.label, isNull);
    });

    test('gerçek denemede zayıf → weakConfirmed, öğrenci diliyle', () {
      final e = TopicEvidenceEngine.classify(
        isExamWeak: true,
        isRecentlyResolved: false,
        status: TopicStatus.studied,
        updatedAt: null,
      );
      expect(e.state, TopicEvidenceState.weakConfirmed);
      expect(e.label, 'Zayıf — denemeden doğrulandı');
    });

    test('son denemede iyileşti → improving', () {
      final e = TopicEvidenceEngine.classify(
        isExamWeak: false,
        isRecentlyResolved: true,
        status: TopicStatus.reviewed,
        updatedAt: DateTime.now(),
      );
      expect(e.state, TopicEvidenceState.improving);
      expect(e.label, 'Düzeliyor');
    });

    test('tekrar edildi ama 14+ gündür dokunulmadı → needsReview', () {
      final now = DateTime(2026, 9, 22);
      final e = TopicEvidenceEngine.classify(
        isExamWeak: false,
        isRecentlyResolved: false,
        status: TopicStatus.reviewed,
        updatedAt: now.subtract(const Duration(days: 20)),
        now: now,
      );
      expect(e.state, TopicEvidenceState.needsReview);
      expect(e.label, 'Tekrar gerekli');
    });

    test('tekrar edildi ve YAKIN zamanda dokunuldu → rozet yok', () {
      final now = DateTime(2026, 9, 22);
      final e = TopicEvidenceEngine.classify(
        isExamWeak: false,
        isRecentlyResolved: false,
        status: TopicStatus.reviewed,
        updatedAt: now.subtract(const Duration(days: 3)),
        now: now,
      );
      expect(e.hasBadge, isFalse);
    });

    test('yalnız "çalışıldı" (reviewed değil) → needsReview asla tetiklenmez',
        () {
      final now = DateTime(2026, 9, 22);
      final e = TopicEvidenceEngine.classify(
        isExamWeak: false,
        isRecentlyResolved: false,
        status: TopicStatus.studied,
        updatedAt: now.subtract(const Duration(days: 100)),
        now: now,
      );
      expect(e.hasBadge, isFalse);
    });

    test(
        'ÇELİŞEN kanıt: hem zayıf hem "tekrar edildi + bayat" — weakConfirmed '
        'kazanır (en güçlü kanıt hiçbir şey tarafından ezilmez)', () {
      final now = DateTime(2026, 9, 22);
      final e = TopicEvidenceEngine.classify(
        isExamWeak: true,
        isRecentlyResolved: false,
        status: TopicStatus.reviewed,
        updatedAt: now.subtract(const Duration(days: 30)),
        now: now,
      );
      expect(e.state, TopicEvidenceState.weakConfirmed);
    });

    test(
        'ÇELİŞEN girdi: hem isExamWeak hem isRecentlyResolved true verilse '
        'bile (normalde yapısal olarak imkansız) weakConfirmed önceliklidir',
        () {
      final e = TopicEvidenceEngine.classify(
        isExamWeak: true,
        isRecentlyResolved: true,
        status: TopicStatus.studied,
        updatedAt: null,
      );
      expect(e.state, TopicEvidenceState.weakConfirmed);
    });

    test('improving, needsReview\'dan önceliklidir (ikisi de doğru olsa)',
        () {
      final now = DateTime(2026, 9, 22);
      final e = TopicEvidenceEngine.classify(
        isExamWeak: false,
        isRecentlyResolved: true,
        status: TopicStatus.reviewed,
        updatedAt: now.subtract(const Duration(days: 30)),
        now: now,
      );
      expect(e.state, TopicEvidenceState.improving);
    });
  });
}
