import 'package:flutter_test/flutter_test.dart';
import 'package:study_planner/rank_system.dart';

/// P0-2 — 6 rütbeli merdiven. Türetilmiş, süre tabanlı değil.
void main() {
  group('xpFor', () {
    test('görev·10 + günü bitirme·30 + konu·12', () {
      expect(
        RankSystem.xpFor(completedTasks: 5, goalDays: 3, coveredTopics: 2),
        5 * 10 + 3 * 30 + 2 * 12,
      );
    });
  });

  group('rütbe eşikleri', () {
    test('6 rütbe: 0 / 250 / 700 / 1600 / 3200 / 6000', () {
      expect(RankSystem.thresholds, [0, 250, 700, 1600, 3200, 6000]);
      expect(RankSystem.names.length, 6);
      expect(RankSystem.colors.length, 6);
    });

    test('fromXp doğru rütbeyi bulur', () {
      expect(RankSystem.fromXp(0).rank, 1);
      expect(RankSystem.fromXp(249).rank, 1);
      expect(RankSystem.fromXp(250).rank, 2);
      expect(RankSystem.fromXp(699).rank, 2);
      expect(RankSystem.fromXp(700).rank, 3);
      expect(RankSystem.fromXp(1599).rank, 3);
      expect(RankSystem.fromXp(3200).rank, 5);
      expect(RankSystem.fromXp(6000).rank, 6);
      expect(RankSystem.fromXp(99999).rank, 6);
    });

    test('negatif xp → rütbe 1', () {
      expect(RankSystem.fromXp(-100).rank, 1);
    });

    test('isim ve renk rütbeyle eşleşir', () {
      expect(RankSystem.fromXp(0).name, 'Yolcu');
      expect(RankSystem.fromXp(250).name, 'Çırak');
      expect(RankSystem.fromXp(6000).name, 'Pusula');
      expect(RankSystem.fromXp(6000).colorHex, RankSystem.colors[5]);
    });
  });

  group('ilerleme', () {
    test('Çırak ortası → progress ~0.5', () {
      // Çırak: 250..700 → 450 aralık. 250 + 225 = 475 → yarısı.
      final r = RankSystem.fromXp(475);
      expect(r.rank, 2);
      expect(r.xpIntoRank, 225);
      expect(r.xpForRank, 450);
      expect(r.progress, closeTo(0.5, 0.001));
      expect(r.xpToNextRank, 225);
      expect(r.nextName, 'Kalfa');
    });

    test('en üst rütbede progress 1, xpToNext 0', () {
      final r = RankSystem.fromXp(8000);
      expect(r.atMax, isTrue);
      expect(r.progress, 1);
      expect(r.xpToNextRank, 0);
      expect(r.nextName, 'Pusula');
    });
  });

  group('gerçekçi senaryolar', () {
    test('1. gün (1 görev + 1 hedef günü) → Yolcu, 40 XP', () {
      final r = RankSystem.compute(
          completedTasks: 1, goalDays: 1, coveredTopics: 0);
      expect(r.xp, 40);
      expect(r.rank, 1);
    });

    test('~1 hafta → Çırak', () {
      final r = RankSystem.compute(
          completedTasks: 7, goalDays: 7, coveredTopics: 2);
      expect(r.xp, 70 + 210 + 24); // 304
      expect(r.name, 'Çırak');
    });

    test('~1 ay → Kalfa', () {
      final r = RankSystem.compute(
          completedTasks: 30, goalDays: 28, coveredTopics: 15);
      expect(r.xp, 300 + 840 + 180); // 1320
      expect(r.name, 'Kalfa');
    });

    test('rütbe asla gerilemez — girdi sayaçları hep artar', () {
      final a = RankSystem.compute(
          completedTasks: 20, goalDays: 15, coveredTopics: 8);
      final b = RankSystem.compute(
          completedTasks: 25, goalDays: 15, coveredTopics: 8);
      expect(b.xp, greaterThan(a.xp));
      expect(b.rank, greaterThanOrEqualTo(a.rank));
    });
  });
}
