import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_planner/add_task_screen.dart';
import 'package:study_planner/subject_provider.dart';
import 'package:study_planner/task_provider.dart';
import 'package:study_planner/topic_provider.dart';

import 'support/hive_memory.dart';

/// Yolculuk C — görev oluşturma: konu seçilince başlık konudan gelir (aynı
/// bilgi iki kez sorulmaz), "ne zaman" gerçek saate göre ve ana kartta,
/// oluşan görev beklenen yerde (bugünün listesinde) görünür.
void main() {
  setUp(openMemoryBoxes);
  tearDown(closeMemoryBoxes);

  Future<ProviderContainer> openAddTask(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(subjectProvider.notifier).addSubject('Matematik', 0xFF6750A4);
    final subjectId = container.read(subjectProvider).first.id;
    container.read(topicProvider.notifier)
      ..addTopic(subjectId, 'Bölünebilme')
      ..addTopic(subjectId, 'Türev');

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AddTaskScreen()),
              ),
              child: const Text('aç'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();
    return container;
  }

  String titleText(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField).first).controller!.text;

  testWidgets('konu seçilince görev adı konudan gelir (Bölünebilme)',
      (tester) async {
    await openAddTask(tester);
    expect(titleText(tester), isEmpty);

    await tester.tap(find.text('Matematik'));
    await tester.pump();
    await tester.tap(find.text('Bölünebilme'));
    await tester.pump();

    expect(titleText(tester), 'Bölünebilme');
  });

  testWidgets('başka konu seçilince otomatik başlık güncellenir, kaldırılınca temizlenir',
      (tester) async {
    await openAddTask(tester);
    await tester.tap(find.text('Matematik'));
    await tester.pump();

    await tester.tap(find.text('Bölünebilme'));
    await tester.pump();
    await tester.tap(find.text('Türev'));
    await tester.pump();
    expect(titleText(tester), 'Türev');

    // seçili konuya tekrar dokun → seçim kalkar, otomatik başlık da gider.
    // (Başlık alanında da "Türev" yazıyor — yalnız çipi hedefle.)
    await tester.tap(find.descendant(
        of: find.byType(Wrap), matching: find.text('Türev')));
    await tester.pump();
    expect(titleText(tester), isEmpty);
  });

  testWidgets('öğrencinin kendi yazdığı başlık ASLA ezilmez', (tester) async {
    await openAddTask(tester);
    await tester.tap(find.text('Matematik'));
    await tester.pump();

    await tester.enterText(find.byType(TextField).first, 'Kendi başlığım');
    await tester.pump();
    await tester.tap(find.text('Türev'));
    await tester.pump();

    expect(titleText(tester), 'Kendi başlığım');
  });

  testWidgets(
      '"Ne zaman" ana kartta ve gerçek saate göre: Şimdi / 30 dk / 1 saat / '
      'bugün daha sonra / yarın / Özel; sabit 14:00 yok', (tester) async {
    await openAddTask(tester);

    // "Detaylar"ı açmadan görünür.
    expect(find.text('NE ZAMAN'), findsOneWidget);
    expect(find.text('Şimdi'), findsOneWidget);
    expect(find.textContaining('30 dk sonra'), findsOneWidget);
    expect(find.textContaining('1 saat sonra'), findsOneWidget);
    expect(find.text('Bugün daha sonra'), findsWidgets);
    expect(find.text('Yarın'), findsOneWidget);
    expect(find.text('Özel'), findsOneWidget);
    expect(find.text('14:00'), findsNothing);
    expect(find.text('19:00'), findsNothing);
    // Varsayılan bilinçli olarak saatsiz.
    expect(find.textContaining('Saatsiz'), findsOneWidget);
  });

  testWidgets(
      'YOLCULUK C: ders → konu → otomatik başlık → "Şimdi" → oluştur: görev bugünün '
      'listesinde, konuya bağlı, saati şu an', (tester) async {
    final c = await openAddTask(tester);
    final before = DateTime.now();

    await tester.tap(find.text('Matematik'));
    await tester.pump();
    await tester.tap(find.text('Bölünebilme'));
    await tester.pump();
    await tester.tap(find.text('Şimdi'));
    await tester.pump();
    await tester.tap(find.text('Görevi Ekle'));
    await tester.pumpAndSettle();

    final tasks = c.read(taskProvider);
    expect(tasks, hasLength(1));
    final t = tasks.single;
    expect(t.title, 'Bölünebilme');
    expect(t.topicId, c.read(topicProvider).firstWhere((x) => x.name == 'Bölünebilme').id);
    expect(t.subjectId, c.read(subjectProvider).first.id);
    // Bugün ve zamanlı: saat "kaydetme anı" (geçmişe kalmaz).
    final today = DateTime(before.year, before.month, before.day);
    expect(DateTime(t.dueDate.year, t.dueDate.month, t.dueDate.day), today);
    expect(t.scheduledTime, isNotNull);
    expect(t.scheduledTime!.isBefore(before.subtract(const Duration(minutes: 1))),
        isFalse);
    expect(t.scheduledTime!.difference(before).inMinutes.abs() <= 2, isTrue);
  });

  testWidgets('varsayılan (bugün daha sonra) saatsiz görev üretir — bilinçli saatsiz mümkün',
      (tester) async {
    final c = await openAddTask(tester);
    await tester.tap(find.text('Matematik'));
    await tester.pump();
    await tester.tap(find.text('Türev'));
    await tester.pump();
    await tester.tap(find.text('Görevi Ekle'));
    await tester.pumpAndSettle();

    final t = c.read(taskProvider).single;
    expect(t.title, 'Türev');
    expect(t.scheduledTime, isNull);
  });

  testWidgets('başlık boşsa ders adına düşer (bilinen bilgi tekrar sorulmaz)',
      (tester) async {
    final c = await openAddTask(tester);
    await tester.tap(find.text('Matematik'));
    await tester.pump();
    await tester.tap(find.text('Görevi Ekle'));
    await tester.pumpAndSettle();
    expect(c.read(taskProvider).single.title, 'Matematik');
  });

  testWidgets('Özel: tam tarih + saat seçilir ve görev o gün/saatte oluşur',
      (tester) async {
    final c = await openAddTask(tester);
    await tester.tap(find.text('Özel'));
    await tester.pumpAndSettle();
    // Tarih seçici → OK, saat seçici → OK.
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // Çip artık seçilen gün/saati gösteriyor ("Özel" değil).
    expect(find.text('Özel'), findsNothing);
    expect(find.textContaining('·'), findsWidgets);

    await tester.enterText(find.byType(TextField).first, 'Özel gün görevi');
    await tester.tap(find.text('Görevi Ekle'));
    await tester.pumpAndSettle();

    final t = c.read(taskProvider).single;
    expect(t.scheduledTime, isNotNull);
    expect(t.title, 'Özel gün görevi');
  });
}
