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

/// Bağlam TAZELİĞİ: düzeltme ("artır") yalnız gerçekten ilgili, taze bir
/// plan/öneriye bağlanır; araya yeni bir ana konu girince eski bağlam pasifleşir;
/// kısa onaylar bağlamı bozmaz; açık referans onu geri getirir.
void main() {
  setUp(openMemoryBoxes);
  tearDown(closeMemoryBoxes);

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  Future<ProviderContainer> pumpCoach(
    WidgetTester tester, {
    List<TaskModel> tasks = const [],
  }) async {
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

  String chat(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? '')
      .where((t) => t.length > 12)
      .join(String.fromCharCode(10));

  Finder said(String pattern) => find.byWidgetPredicate(
      (w) => w is Text && RegExp(pattern).hasMatch(w.data ?? ''));

  TaskModel task(String title, {int minutes = 25}) => TaskModel(
        id: 'task-$title',
        title: title,
        subjectId: 's-mat',
        dueDate: today,
        createdAt: DateTime(2026, 9, 1),
        estimatedMinutes: minutes,
      );

  Future<void> planHour(WidgetTester tester) async {
    await say(tester, 'Bana bugün için 1 saatlik plan yap');
    expect(said('Uygunsa "ekle" de'), findsOneWidget, reason: chat(tester));
  }

  Future<void> goalQuestion(WidgetTester tester) async {
    await say(tester, 'hedefime ne kadar kaldı');
    expect(said('Henüz bir hedef net belirlemedin'), findsOneWidget,
        reason: chat(tester));
  }

  final noRefinement = said('Yoğunluğu .* yaptım|Süreyi .* yaptım');

  testWidgets('T1: plan → "biraz ağır yap" → düzeltme çalışır', (tester) async {
    await pumpCoach(tester);
    await planHour(tester);
    await say(tester, 'biraz ağır yap');
    expect(said('Yoğunluğu orta → yüksek yaptım'), findsOneWidget,
        reason: chat(tester));
  });

  testWidgets('T2: plan → hedef sorusu → "artır" → eski plana BAĞLANMAZ',
      (tester) async {
    await pumpCoach(tester);
    await planHour(tester);
    await goalQuestion(tester);
    await say(tester, 'artır');

    expect(noRefinement, findsNothing, reason: chat(tester));
    expect(said('Neyi değiştirmemi istersin|hangi plan için'), findsOneWidget,
        reason: chat(tester));
  });

  testWidgets('T3: plan → "peki" (akış devamı) → "biraz ağır yap" hâlâ çalışır',
      (tester) async {
    await pumpCoach(tester);
    await planHour(tester);
    await say(tester, 'peki');
    await say(tester, 'biraz ağır yap');
    expect(said('Yoğunluğu orta → yüksek yaptım'), findsOneWidget,
        reason: chat(tester));
  });

  testWidgets(
      'T3b: plan → "tamam" (plan eklenir) → "biraz ağır yap" → eklenen plana '
      'dokunmadan aynı ayarlarla yeni öneri', (tester) async {
    final c = await pumpCoach(tester);
    await planHour(tester);
    await say(tester, 'tamam');
    final added = c.read(taskProvider).length;
    expect(added, greaterThan(0));

    await say(tester, 'biraz ağır yap');
    expect(said('aynı ayarlarla yeni bir öneri'), findsOneWidget,
        reason: chat(tester));
    expect(said('Yoğunluğu orta → yüksek yaptım'), findsOneWidget,
        reason: chat(tester));
    expect(c.read(taskProvider).length, added,
        reason: 'onaylanmadan görev eklenmemeli');
  });

  testWidgets('T4: yeni plan isteği eski bağlamı değiştirir', (tester) async {
    await pumpCoach(tester);
    await planHour(tester); // A: 1 saat
    await say(tester, 'Yarın için 2 saatlik plan yap'); // B: 2 saat
    await say(tester, 'artır');

    expect(said(r'Süreyi 2 saat → '), findsOneWidget, reason: chat(tester));
    expect(said(r'Süreyi 1 saat → '), findsNothing, reason: chat(tester));
  });

  testWidgets('T5: plan → deneme sorunu → "biraz artır" → plana bağlanmaz',
      (tester) async {
    await pumpCoach(tester);
    await planHour(tester);
    await say(tester, 'denemelerim neden kötü geliyor?');
    expect(said('Henüz deneme kaydın yok'), findsOneWidget,
        reason: chat(tester));
    await say(tester, 'biraz artır');

    expect(noRefinement, findsNothing, reason: chat(tester));
    expect(said('Neyi değiştirmemi istersin|hangi plan için'), findsOneWidget,
        reason: chat(tester));
  });

  testWidgets('T6: açık referans bayat bağlamı geri getirir', (tester) async {
    await pumpCoach(tester);
    await planHour(tester);
    await goalQuestion(tester);
    await say(tester, 'az önceki planı biraz artır');
    expect(said(r'Süreyi 1 saat → '), findsOneWidget, reason: chat(tester));
  });

  testWidgets('T6b: "o planı biraz hafiflet" de açık referanstır',
      (tester) async {
    await pumpCoach(tester);
    await planHour(tester);
    await goalQuestion(tester);
    await say(tester, 'o planı biraz hafiflet');
    expect(said('Yoğunluğu orta → düşük yaptım'), findsOneWidget,
        reason: chat(tester));
  });

  testWidgets('T6c: açık referans var ama plan hiç yok → uydurmaz, sorar',
      (tester) async {
    await pumpCoach(tester);
    await say(tester, 'az önceki planı biraz artır');
    expect(noRefinement, findsNothing, reason: chat(tester));
    expect(said('Neyi değiştirmemi istersin|değiştirecek bir plan'),
        findsOneWidget,
        reason: chat(tester));
  });

  testWidgets('T7: koç süre sorarken "3 saat" / "3 saat yap" akışın cevabıdır',
      (tester) async {
    await pumpCoach(tester);
    await say(tester, 'bana plan yap'); // koç günlük süreyi sorar
    await say(tester, '3 saat');
    expect(said('Neyi değiştirmemi|Yoğunluğu'), findsNothing,
        reason: chat(tester));
    expect(said('Not aldım — .*3 saat|bugün|bu hafta'), findsWidgets,
        reason: chat(tester));
  });

  testWidgets('T7b: "3 saat yap" akış içinde de süre cevabıdır',
      (tester) async {
    await pumpCoach(tester);
    await say(tester, 'bana plan yap');
    await say(tester, '3 saat yap');
    expect(said('Neyi değiştirmemi|Yoğunluğu'), findsNothing,
        reason: chat(tester));
    expect(said(r'Not aldım — 3 saat'), findsOneWidget, reason: chat(tester));
  });

  testWidgets(
      'T8: ardışık düzeltmeler: ikincisi ilkinin GÜNCEL sonucu üzerinde çalışır',
      (tester) async {
    await pumpCoach(tester);
    await say(tester, 'Bugün 60 dakikalık bir plan yap');
    await say(tester, 'biraz ağır yap');
    expect(said('Yoğunluğu orta → yüksek yaptım'), findsOneWidget,
        reason: chat(tester));
    // Yoğunluk artık en yüksekte: ikinci düzeltme bunu BİLİYOR (güncel durum).
    await say(tester, 'biraz daha ağır');
    expect(said('Yoğunluk zaten en yüksekte'), findsOneWidget,
        reason: chat(tester));
  });

  testWidgets('planın kendisi hakkındaki "neden" sorusu bağlamı öldürmez',
      (tester) async {
    await pumpCoach(tester);
    await planHour(tester);
    await say(tester, 'neden bunu çalışıyorum');
    await say(tester, 'biraz ağır yap');
    expect(said('Yoğunluğu orta → yüksek yaptım'), findsOneWidget,
        reason: chat(tester));
  });

  testWidgets('öneri bağlamı da bayatlar: öneri → selam → "1 saat daha ekle"',
      (tester) async {
    await pumpCoach(tester, tasks: [task('Matematik: Türev', minutes: 25)]);
    await say(tester, 'Bugün sadece 30 dakikam var ne çalışayım?');
    expect(said('30 dk|daralttım'), findsWidgets, reason: chat(tester));
    await say(tester, 'selam');
    await say(tester, '1 saat daha ekle');

    expect(noRefinement, findsNothing, reason: chat(tester));
    expect(said('Neyi değiştirmemi istersin|hangi plan için'), findsOneWidget,
        reason: chat(tester));
  });

  testWidgets('öneriden hemen sonra düzeltme hâlâ çalışır (taze bağlam)',
      (tester) async {
    await pumpCoach(tester, tasks: [task('Matematik: Türev', minutes: 25)]);
    await say(tester, 'Bugün sadece 30 dakikam var ne çalışayım?');
    await say(tester, '1 saat daha ekle');
    expect(said(r'Süreyi 30 dk → 1 sa 30 dk yaptım'), findsOneWidget,
        reason: chat(tester));
  });
}
