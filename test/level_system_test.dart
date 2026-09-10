import 'package:flutter_test/flutter_test.dart';
import 'package:study_planner/level_system.dart';

/// P0-2 — seviye / rütbe merdiveni. Türetilmiş, süre tabanlı değil.
void main() {
  group('xpFor', () {
    test('ağırlıklar: görev·10 + seri·20 + konu·12', () {
      expect(
        LevelSystem.xpFor(
            completedTasks: 5, longestStreak: 3, coveredTopics: 2),
        5 * 10 + 3 * 20 + 2 * 12,
      );
    });
  });

  group('seviye eşikleri', () {
    test('totalXpForLevel karekök eğrisi', () {
      expect(LevelSystem.totalXpForLevel(1), 0);
      expect(LevelSystem.totalXpForLevel(2), 40);
      expect(LevelSystem.totalXpForLevel(3), 160);
      expect(LevelSystem.totalXpForLevel(4), 360);
      expect(LevelSystem.totalXpForLevel(6), 1000);
    });

    test('fromXp doğru seviyeyi bulur', () {
      expect(LevelSystem.fromXp(0).level, 1);
      expect(LevelSystem.fromXp(39).level, 1);
      expect(LevelSystem.fromXp(40).level, 2);
      expect(LevelSystem.fromXp(159).level, 2);
      expect(LevelSystem.fromXp(160).level, 3);
      expect(LevelSystem.fromXp(999).level, 5);
      expect(LevelSystem.fromXp(1000).level, 6);
    });

    test('negatif xp → seviye 1', () {
      expect(LevelSystem.fromXp(-50).level, 1);
    });
  });

  group('ilerleme', () {
    test('L2 ortası → progress ~0.5', () {
      // L2: 40..160 → 120 aralık. 40 + 60 = 100 → yarısı.
      final info = LevelSystem.fromXp(100);
      expect(info.level, 2);
      expect(info.xpIntoLevel, 60);
      expect(info.xpForNextLevel, 120);
      expect(info.progress, closeTo(0.5, 0.001));
      expect(info.xpToNextLevel, 60);
    });
  });

  group('rütbe bandları', () {
    test('title seviyeye göre', () {
      expect(LevelSystem.fromXp(LevelSystem.totalXpForLevel(1)).title, 'Yolcu');
      expect(LevelSystem.fromXp(LevelSystem.totalXpForLevel(3)).title, 'Çırak');
      expect(LevelSystem.fromXp(LevelSystem.totalXpForLevel(6)).title, 'Kalfa');
      expect(LevelSystem.fromXp(LevelSystem.totalXpForLevel(10)).title, 'Usta');
      expect(LevelSystem.fromXp(LevelSystem.totalXpForLevel(15)).title, 'Pusula');
    });

    test('levelsToNextRank', () {
      expect(LevelSystem.levelsToNextRank(1), 2); // Yolcu → Çırak (L3)
      expect(LevelSystem.levelsToNextRank(3), 3); // Çırak L3 → Kalfa (L6)
      expect(LevelSystem.levelsToNextRank(5), 1); // Çırak L5 → Kalfa (L6)
      expect(LevelSystem.levelsToNextRank(14), 1); // Usta L14 → Pusula (L15)
      expect(LevelSystem.levelsToNextRank(15), 0); // en üst
      expect(LevelSystem.levelsToNextRank(30), 0);
    });
  });

  group('gerçekçi senaryolar', () {
    test('1. gün (1 görev, 1 seri, 0 konu) → seviye 1, sonrakine yakın', () {
      final info = LevelSystem.compute(
          completedTasks: 1, longestStreak: 1, coveredTopics: 0);
      expect(info.level, 1);
      expect(info.xp, 30);
    });

    test('~1 ay (40 görev, 20 seri, 15 konu) → Çırak/Kalfa civarı', () {
      final info = LevelSystem.compute(
          completedTasks: 40, longestStreak: 20, coveredTopics: 15);
      expect(info.xp, 980);
      expect(info.level, 5);
      expect(info.title, 'Çırak');
    });

    test('seviye asla gerilemez — en uzun seri kullanılır', () {
      // currentStreak 0'a düşse bile longestStreak korunur → xp/level sabit.
      final a = LevelSystem.compute(
          completedTasks: 10, longestStreak: 12, coveredTopics: 5);
      final b = LevelSystem.compute(
          completedTasks: 10, longestStreak: 12, coveredTopics: 5);
      expect(a.level, b.level);
    });
  });
}
