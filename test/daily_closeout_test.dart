import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:study_planner/daily_closeout_model.dart';
import 'package:study_planner/daily_closeout_provider.dart';
import 'package:study_planner/hive_boxes.dart';

/// B3 — "Bugünü kapat" ritüeli. Gün anahtarı, bugün/dün çözümü, üzerine yazma.
void main() {
  late Directory tempDir;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('pusula_closeout_test');
    Hive.init(tempDir.path);
    Hive.registerAdapter(DailyCloseoutAdapter());
  });

  tearDownAll(() async {
    await Hive.close();
    tempDir.deleteSync(recursive: true);
  });

  setUp(() => Hive.openBox<DailyCloseout>(HiveBoxes.dailyCloseoutsBoxName));
  tearDown(() => Hive.deleteBoxFromDisk(HiveBoxes.dailyCloseoutsBoxName));

  test('dayKey sıfır dolgulu ISO tarih', () {
    expect(DailyCloseout.dayKey(DateTime(2026, 9, 3)), '2026-09-03');
    expect(DailyCloseout.dayKey(DateTime(2026, 12, 25, 23, 59)), '2026-12-25');
  });

  test('close() bugünü kaydeder, todayCloseoutProvider onu döndürür', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);

    expect(c.read(todayCloseoutProvider), isNull);

    c.read(dailyCloseoutProvider.notifier).close(
          completedTasks: 4,
          focusMinutes: 50,
          intent: '  Yarın paragraf  ',
        );

    final today = c.read(todayCloseoutProvider);
    expect(today, isNotNull);
    expect(today!.completedTasks, 4);
    expect(today.focusMinutes, 50);
    expect(today.intent, 'Yarın paragraf'); // trim
  });

  test('aynı gün ikinci close üzerine yazar (tek kayıt)', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);

    final notifier = c.read(dailyCloseoutProvider.notifier);
    notifier.close(completedTasks: 1, focusMinutes: 0, intent: 'ilk');
    notifier.close(completedTasks: 2, focusMinutes: 10, intent: 'düzeltme');

    expect(c.read(dailyCloseoutProvider).length, 1);
    expect(c.read(todayCloseoutProvider)!.intent, 'düzeltme');
  });

  test('yesterdayIntentProvider dün yazılan niyeti verir', () {
    final now = DateTime.now();
    final yesterday =
        DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
    HiveBoxes.dailyCloseouts.put(
      DailyCloseout.dayKey(yesterday),
      DailyCloseout(
        id: DailyCloseout.dayKey(yesterday),
        date: yesterday,
        intent: 'Türev bitecek',
        completedTasks: 3,
        focusMinutes: 40,
        closedAt: yesterday.add(const Duration(hours: 22)),
      ),
    );

    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(yesterdayIntentProvider), 'Türev bitecek');
  });

  test('boş niyetli dünkü kayıt hatırlatma üretmez', () {
    final now = DateTime.now();
    final yesterday =
        DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
    HiveBoxes.dailyCloseouts.put(
      DailyCloseout.dayKey(yesterday),
      DailyCloseout(
        id: DailyCloseout.dayKey(yesterday),
        date: yesterday,
        intent: '',
        completedTasks: 0,
        focusMinutes: 0,
        closedAt: yesterday,
      ),
    );

    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(yesterdayIntentProvider), isNull);
  });
}
