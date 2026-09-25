import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_planner/coach_screen.dart';
import 'package:study_planner/hive_boxes.dart';
import 'package:study_planner/subject_model.dart';
import 'package:study_planner/task_model.dart';
import 'package:study_planner/task_provider.dart';
import 'package:study_planner/user_stats_model.dart';

import '../support/hive_memory.dart';

/// Gerçek Coach ekranı + gerçek NLU: öğrencinin yazdığı cümle → niyet → mevcut
/// Dodom verisi → cevap + "Başla" eylemi; anlaşılmayan cümle uydurma plana
/// dönüşmez; plan akışının ortasındaki cevaplar bölünmez.
void main() {
  setUp(openMemoryBoxes);
  tearDown(closeMemoryBoxes);

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  Future<ProviderContainer> pumpCoach(
    WidgetTester tester, {
    List<TaskModel> tasks = const [],
  }) async {
    tester.view.physicalSize = const Size(900, 3600);
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
    for (final (id, name) in [('s-mat', 'Matematik'), ('s-fiz', 'Fizik')]) {
      await HiveBoxes.subjects.put(
        id,
        SubjectModel(
          id: id,
          name: name,
          colorValue: 0xFF6750A4,
          createdAt: DateTime(2026, 1, 1),
        ),
      );
    }
    for (final t in tasks) {
      await HiveBoxes.tasks.put(t.id, t);
    }

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

  /// Sohbetteki tüm metinler — hata mesajında neyin görüldüğünü göstermek için.
  String chat(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? '')
      .where((t) => t.length > 12)
      .join(String.fromCharCode(10));

  TaskModel task(String title, {int minutes = 25}) => TaskModel(
        id: 'task-$title',
        title: title,
        subjectId: 's-mat',
        dueDate: today,
        createdAt: DateTime(2026, 9, 1),
        estimatedMinutes: minutes,
      );

  testWidgets(
      '"Bugün sadece 30 dakikam var ne çalışayım?" → bugünkü plandan daraltılmış '
      'cevap + "Başla" → Focus (süre önceden dolu)', (tester) async {
    await pumpCoach(tester, tasks: [
      task('Matematik: Türev', minutes: 25),
      task('Matematik: Limit', minutes: 25),
    ]);

    await say(tester, 'Bugün sadece 30 dakikam var ne çalışayım?');

    expect(find.textContaining('30 dk\'ya göre bugünkü planını daralttım'),
        findsOneWidget);
    expect(find.text('Başla'), findsOneWidget);

    await tester.tap(find.text('Başla'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.text('ODAK SEANSI'), findsOneWidget);
    expect(find.text('Matematik · 25 dk'), findsOneWidget);
  });

  testWidgets(
      '"asdfgh neyse boşver" → uydurma konu/plan YOK; nazikçe daha net yazmasını ister',
      (tester) async {
    await pumpCoach(tester);
    await say(tester, 'asdfgh neyse boşver');

    expect(
        find.byWidgetPredicate((w) =>
            w is Text &&
            RegExp('anlayamadım|çıkaramadım').hasMatch(w.data ?? '')),
        findsOneWidget);
    // Eski davranış: cümle konu sanılıp "Buna ne kadar zaman ayıralım?" derdi.
    expect(find.textContaining('ne kadar zaman ayıralım'), findsNothing);
    expect(find.textContaining('Not aldım'), findsNothing);
    expect(find.text('Başla'), findsNothing);
  });

  testWidgets(
      '"berbat" → kesin konuşmadan açıklama ister, Matematik problemi yapmaz',
      (tester) async {
    await pumpCoach(tester);
    await say(tester, 'berbat');

    expect(find.textContaining('oturtamadım'), findsOneWidget);
    expect(find.textContaining('Matematik problemi'), findsNothing);
    expect(find.text('Başla'), findsNothing);
  });

  testWidgets('plan isteği mevcut plan akışına devredilir', (tester) async {
    await pumpCoach(tester);
    await say(tester, 'bana bir plan yap');

    // Devralma modu: koç önce günlük süreyi sorar (eski akışla aynı).
    expect(
        find.byWidgetPredicate((w) =>
            w is Text &&
            RegExp('ne kadar vaktin var|saat çalışabilirsin|'
                    'zaman ayırabiliyorsun')
                .hasMatch(w.data ?? '')),
        findsOneWidget);
  });

  testWidgets(
      'plan akışının ortasındaki "2 saat" cevabı NLU tarafından bölünmez',
      (tester) async {
    await pumpCoach(tester);
    await say(tester, 'matematik çalışacağım');
    await say(tester, '2 saat');

    // Süre alındı (Not aldım — ... 2 saat), sıradaki soru gün sorusu.
    expect(find.textContaining('2 saat'), findsWidgets);
    // Sıradaki soru GÜN sorusu (varyantlardan biri).
    expect(
        find.byWidgetPredicate((w) =>
            w is Text &&
            RegExp('Ne zaman|Hangi gün|Ne günü').hasMatch(w.data ?? '')),
        findsOneWidget);
    expect(find.textContaining('daralttım'), findsNothing);
  });

  testWidgets('eski zincir korunur: selamlaşma ve hedef sorusu',
      (tester) async {
    await pumpCoach(tester);
    await say(tester, 'selam');
    expect(
      find.byWidgetPredicate((w) =>
          w is Text && (w.data ?? '').contains(RegExp(r'Selam|Merhaba'))),
      findsWidgets,
    );

    await say(tester, 'hedefime ne kadar kaldı');
    expect(find.textContaining('Henüz bir hedef net belirlemedin'),
        findsOneWidget);
  });

  testWidgets(
      'bileşik cümle: "Yarın deneme var, matematikte hiçbir şey bilmiyorum"',
      (tester) async {
    await pumpCoach(tester, tasks: [task('Matematik: Türev')]);
    await say(tester, 'Yarın deneme var, matematikte hiçbir şey bilmiyorum');

    expect(find.textContaining('Yarın deneme var.'), findsOneWidget);
    expect(find.text('Başla'), findsOneWidget);
  });

  testWidgets(
      'NLU plan isteği → eski PlanBuilder akışı → "ekle" ile görevler gerçekten eklenir',
      (tester) async {
    final c = await pumpCoach(tester);
    await say(tester, 'bana 2 saatlik bir plan yap');
    // Süre NLU'dan geldi; bugün/hafta sorusu yerine doğrudan günlük plan.
    expect(find.textContaining('görev.'), findsOneWidget, reason: chat(tester));

    await say(tester, 'ekle');
    expect(c.read(taskProvider), isNotEmpty);
    expect(c.read(taskProvider), hasLength(2));
    expect(find.text('Şimdi Başla'), findsOneWidget, reason: chat(tester));
  });

  testWidgets(
      'eski zincir korunur: konu anlatımı isteği kapsam dışı cevabı alır',
      (tester) async {
    await pumpCoach(tester);
    await say(tester, 'türevi anlatır mısın');
    expect(
        find.byWidgetPredicate((w) =>
            w is Text &&
            RegExp('anlatmıyorum|anlatamam|Anlatım/çözüm')
                .hasMatch(w.data ?? '')),
        findsOneWidget,
        reason: chat(tester));
  });

  testWidgets('açık dinlenme talebi eski zincire bırakılır (zorlanmaz)',
      (tester) async {
    await pumpCoach(tester, tasks: [task('Matematik: Türev')]);
    await say(tester, 'bugün çalışmayacağım');
    expect(
        find.byWidgetPredicate((w) =>
            w is Text &&
            RegExp('izin ver|zorlamıyorum|bugün mola').hasMatch(w.data ?? '')),
        findsOneWidget,
        reason: chat(tester));
    expect(find.text('Başla'), findsNothing);
  });

  testWidgets('"bıktım artık" → NLU: küçük adım önerisi + Başla',
      (tester) async {
    await pumpCoach(tester, tasks: [task('Matematik: Türev', minutes: 40)]);
    await say(tester, 'bıktım artık');
    expect(find.textContaining('15 dk'), findsOneWidget);
    expect(find.text('Başla'), findsOneWidget);
  });
}
