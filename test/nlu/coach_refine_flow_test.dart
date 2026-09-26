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

/// Konuşma bağlamı: plan/öneri verildikten SONRA gelen kısa düzeltmeler
/// ("biraz ağır yap", "artır", "1 saat daha ekle") önceki sonuca uygulanır;
/// referans yoksa uydurulmaz; "matematik ağır geliyor" düzeltme sayılmaz.
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

  Future<void> planOneHour(WidgetTester tester) async {
    await say(tester, 'Bana bugün için 1 saatlik plan yap');
    expect(said('Uygunsa "ekle" de'), findsOneWidget, reason: chat(tester));
  }

  group('plan sonrası yoğunluk düzeltmesi', () {
    testWidgets('"Biraz ağır yap" → yoğunluk bir kademe yukarı, plan yenilenir',
        (tester) async {
      await pumpCoach(tester);
      await planOneHour(tester);
      await say(tester, 'Biraz ağır yap');

      expect(said(r'Yoğunluğu orta → yüksek yaptım \(blok 45 → 60 dk\)'),
          findsOneWidget,
          reason: chat(tester));
      // Plan yeniden önerildi (bir öneri daha görünüyor).
      expect(said('Uygunsa "ekle" de'), findsNWidgets(2));
      // Yeni bir plan İSTEĞİ sanılmadı (süre sorusu yok).
      expect(said('ne kadar vaktin var|saat çalışabilirsin'), findsNothing);
    });

    testWidgets('"Planı biraz hafiflet" → yoğunluk aşağı', (tester) async {
      await pumpCoach(tester);
      await planOneHour(tester);
      await say(tester, 'Planı biraz hafiflet');
      expect(said(r'Yoğunluğu orta → düşük yaptım \(blok 45 → 25 dk\)'),
          findsOneWidget,
          reason: chat(tester));
    });

    testWidgets('"Bu çok ağır olmuş" → hafiflet (büyük adım)', (tester) async {
      await pumpCoach(tester);
      await planOneHour(tester);
      await say(tester, 'Bu çok ağır olmuş');
      expect(said(r'Yoğunluğu orta → düşük yaptım'), findsOneWidget,
          reason: chat(tester));
    });

    testWidgets('yoğunluk zaten uçtaysa süre değiştirilir ve bu söylenir',
        (tester) async {
      await pumpCoach(tester);
      await planOneHour(tester);
      await say(tester, 'biraz ağır yap'); // orta → yüksek
      await say(tester, 'biraz daha ağır olsun'); // zaten en yüksek
      expect(said('Yoğunluk zaten en yüksekte'), findsOneWidget,
          reason: chat(tester));
    });
  });

  group('süre düzeltmesi', () {
    testWidgets('"1 saat daha ekle" → +60 dk', (tester) async {
      await pumpCoach(tester);
      await planOneHour(tester);
      await say(tester, '1 saat daha ekle');
      expect(said(r'Süreyi 1 saat → 2 saat yaptım'), findsOneWidget,
          reason: chat(tester));
    });

    testWidgets('"2 saat yerine 3 saat yap" → 180 dk', (tester) async {
      await pumpCoach(tester);
      await say(tester, 'Bana bugün için 2 saatlik plan yap');
      await say(tester, '2 saat yerine 3 saat yap');
      expect(said(r'Süreyi 2 saat → 3 saat yaptım'), findsOneWidget,
          reason: chat(tester));
    });

    testWidgets('"artır" / "azalt" plan varken son plana uygulanır',
        (tester) async {
      await pumpCoach(tester);
      await planOneHour(tester);
      await say(tester, 'artır');
      expect(said(r'Süreyi 1 saat → 1 sa 20 dk yaptım'), findsOneWidget,
          reason: chat(tester));
      await say(tester, 'azalt');
      expect(said(r'Süreyi 1 sa 20 dk → '), findsOneWidget,
          reason: chat(tester));
    });

    testWidgets('"30 dakika azalt" açık fark', (tester) async {
      await pumpCoach(tester);
      await planOneHour(tester);
      await say(tester, '30 dakika azalt');
      expect(said(r'Süreyi 1 saat → 30 dk yaptım'), findsOneWidget,
          reason: chat(tester));
      // 30 dk tek başına anlamlı bir blok (bkz. plan_builder.dart'taki
      // "kısa süre reddedilmez, küçültülür" düzeltmesi) — yeni, daha küçük
      // bir plan üretilir, eskisi korunmaz.
      expect(said(r'Fizik · 30 dk'), findsOneWidget, reason: chat(tester));
      // Not: bu düzeltme akışı süreyi her zaman >= 15 dk'ya yuvarladığı için
      // (bkz. coach_screen.dart _refineProposal clamp(15, ...)) ve
      // plan_builder.dart artık >= 15 dk'lık her isteği bir bloğa
      // dönüştürdüğü için, "azalt" ile "Önceki öneri geçerli" düşüşünü bu
      // yoldan tekrar tetiklemek artık mümkün değil — bilinçli bir iyileşme.
    });
  });

  group('referans yoksa uydurma yok', () {
    for (final s in [
      'Artır.',
      'Azalt.',
      'biraz ağır yap',
      '1 saat daha ekle'
    ]) {
      testWidgets('"$s" → açıklama ister', (tester) async {
        await pumpCoach(tester);
        await say(tester, s);
        expect(said('Neyi değiştirmemi istersin|değiştirecek bir plan'),
            findsOneWidget,
            reason: chat(tester));
        expect(said('yaptım'), findsNothing);
      });
    }
  });

  group('ayrım: kişisel zorlanma ≠ düzeltme', () {
    testWidgets('"Matematik ağır geliyor" → zorlanma, düzeltme DEĞİL',
        (tester) async {
      await pumpCoach(tester);
      await planOneHour(tester);
      await say(tester, 'Matematik ağır geliyor');
      expect(said('Yoğunluğu|yaptım'), findsNothing, reason: chat(tester));
      expect(said('Matematik zor gelebilir'), findsOneWidget,
          reason: chat(tester));
    });
  });

  group('öneri (NLU cevabı) sonrası düzeltme', () {
    testWidgets('30 dk daraltılmış öneri → "1 saat daha ekle" → 1 sa 30 dk',
        (tester) async {
      await pumpCoach(tester, tasks: [
        task('Matematik: Türev', minutes: 25),
        task('Matematik: Limit', minutes: 25),
        task('Matematik: Diziler', minutes: 25),
      ]);
      await say(tester, 'Bugün sadece 30 dakikam var ne çalışayım?');
      expect(said(r"30 dk'ya göre bugünkü planını daralttım"), findsOneWidget,
          reason: chat(tester));

      await say(tester, '1 saat daha ekle');
      expect(said(r'Süreyi 30 dk → 1 sa 30 dk yaptım'), findsOneWidget,
          reason: chat(tester));
      expect(
          said(r"1 sa 30 dk'ya göre bugünkü planını daralttım"), findsOneWidget,
          reason: chat(tester));
    });

    testWidgets(
        'tek görev önerisinde süre HEDEF olur (görev tahminine sıkışmaz)',
        (tester) async {
      await pumpCoach(tester, tasks: [task('Matematik: Türev', minutes: 25)]);
      await say(tester, 'bıktım artık');
      expect(said('15 dk'), findsWidgets, reason: chat(tester));
      await say(tester, 'biraz daha çalışayım');
      expect(said(r'Süreyi 15 dk → 25 dk yaptım'), findsOneWidget,
          reason: chat(tester));
    });
  });

  group('plan akışı bozulmaz', () {
    testWidgets('koç süre sorarken "3 saat yap" o sorunun cevabıdır',
        (tester) async {
      await pumpCoach(tester);
      await say(tester, 'matematik çalışacağım');
      await say(tester, '3 saat yap');
      expect(said('Neyi değiştirmemi'), findsNothing, reason: chat(tester));
      expect(said(r'Not aldım — .*3 saat'), findsOneWidget,
          reason: chat(tester));
    });

    testWidgets(
        '"ekle" hâlâ planı onaylar, sonra düzeltme eklenen plana dokunmaz',
        (tester) async {
      final c = await pumpCoach(tester);
      await planOneHour(tester);
      await say(tester, 'ekle');
      final added = c.read(taskProvider).length;
      expect(added, greaterThan(0));

      await say(tester, 'biraz artır');
      expect(said('listende duruyor'), findsOneWidget, reason: chat(tester));
      expect(c.read(taskProvider).length, added, reason: 'görev eklenmemeli');
    });

    testWidgets('"Fizik çıkar" onay bekleyen günden Fizik görevini çıkarır',
        (tester) async {
      final c = await pumpCoach(tester);
      await say(tester, 'Bana 2 saatlik bir plan yap');
      expect(said(r'Fizik · '), findsOneWidget, reason: chat(tester));
      await say(tester, 'fizik çıkar');
      expect(said('Fizik çıktı'), findsOneWidget, reason: chat(tester));

      await say(tester, 'ekle');
      final titles = c.read(taskProvider).map((t) => t.title).toList();
      expect(titles.any((t) => t.contains('Fizik')), isFalse,
          reason: '$titles');
      expect(titles, isNotEmpty);
    });

    testWidgets(
        '"neden bunu çalışıyorum" bekleyen PLANA dair cevap verir, '
        'alakasız bir öneriye atlamaz', (tester) async {
      await pumpCoach(tester);
      await say(tester, 'bana 2 saatlik plan yap');
      expect(said(r'Fizik · '), findsOneWidget, reason: chat(tester));

      await say(tester, 'neden bunu çalışıyorum?');
      // Ekrandaki plandan bir ders adı geçmeli — StudyAdvisor'ın plana hiç
      // girmeyen bambaşka bir önerisine/genel hedef cümlesine atlanmamalı
      // (önceki bug: bağlam kaybolup ilgisiz bir gerekçe dönüyordu). Açılış
      // selamlaması da benzer bir cümle söylemiş olabilir (findsWidgets) —
      // önemli olan son cevabın da bu kalıba uyması, hiç uymaması değil.
      expect(said(r'(Matematik|Fizik):'), findsWidgets, reason: chat(tester));
      // "Şu an elimde somut bir gerekçe yok" eski genel fallback ASLA
      // çıkmamalı — bu, bağlamın (yanlışlıkla) kaybolduğunun kanıtı olurdu.
      expect(said('elimde somut bir gerekçe yok'), findsNothing,
          reason: chat(tester));
    });
  });
}
