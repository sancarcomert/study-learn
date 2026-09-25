import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_planner/coach_screen.dart';
import 'package:study_planner/hive_boxes.dart';
import 'package:study_planner/subject_model.dart';
import 'package:study_planner/user_stats_model.dart';

import 'support/hive_memory.dart';

/// Delegate modunda ("plan yap") istenen süre elimizdeki ders/konu sayısıyla
/// doldurulamıyorsa (tek ders, konu takibi boş) bu SESSİZCE kırpılmamalı —
/// gerçek canlı testte bulundu: "1.5 saatlik plan yap" yalnız 45 dk'lık bir
/// plan üretiyordu ("Toplam 45 dk"), kullanıcı bunun neden 90 değil 45
/// olduğunu hiç öğrenmiyordu.
void main() {
  setUp(openMemoryBoxes);
  tearDown(closeMemoryBoxes);

  Future<ProviderContainer> pumpCoach(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 4200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await HiveBoxes.stats.put(
      'main',
      UserStatsModel(
        dailyGoal: 0,
        hasSeenNotificationPrompt: true,
        hasSeenTaskHints: true,
        hasSeenExactAlarmPrompt: true,
        lastCarryOverPromptDate: DateTime.now(),
      ),
    );
    // Bilerek TEK ders, hiç konu yok — canlı testte yakalanan durumun aynısı
    // (yeni onboard olmuş, henüz Konu Takip'e hiç dokunmamış bir öğrenci).
    await HiveBoxes.subjects.put(
      's-mat',
      SubjectModel(
        id: 's-mat',
        name: 'Matematik',
        colorValue: 0xFF6750A4,
        createdAt: DateTime(2026, 1, 1),
      ),
    );

    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: CoachScreen()),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    return container;
  }

  Future<void> say(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump(const Duration(milliseconds: 300));
  }

  String chat(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? '')
      .where((t) => t.length > 12)
      .join(String.fromCharCode(10));

  Finder said(String pattern) => find.byWidgetPredicate(
      (w) => w is Text && RegExp(pattern).hasMatch(w.data ?? ''));

  testWidgets(
      'tek ders + konu yokken "1.5 saatlik plan yap" → 90 dk istendiğini, '
      '45 dk ile sınırlı kaldığını AÇIKÇA söyler (sessizce kırpmaz)',
      (tester) async {
    await pumpCoach(tester);
    await say(tester, '1.5 saatlik plan yap');

    expect(said('Toplam 45 dk'), findsOneWidget, reason: chat(tester));
    expect(said('1 sa 30 dk istemiştin'), findsOneWidget, reason: chat(tester));
    expect(said('45 dk ile sınırlı kaldı'), findsOneWidget, reason: chat(tester));
  });

  testWidgets(
      'istenen süre zaten tam karşılanıyorsa (kapasiteye uygun tek ders) '
      'hiçbir kırpma notu eklenmez', (tester) async {
    await pumpCoach(tester);
    await say(tester, '45 dakikalık plan yap');

    expect(said('Toplam 45 dk'), findsOneWidget, reason: chat(tester));
    expect(said('istemiştin'), findsNothing, reason: chat(tester));
  });
}
