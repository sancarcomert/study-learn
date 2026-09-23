import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_planner/focus_screen.dart';
import 'package:study_planner/focus_session_model.dart';
import 'package:study_planner/focus_session_provider.dart';
import 'package:study_planner/hive_boxes.dart';
import 'package:study_planner/study_intent.dart';
import 'package:study_planner/subject_model.dart';
import 'package:study_planner/task_model.dart';
import 'package:study_planner/task_provider.dart';
import 'package:study_planner/topic_evidence_provider.dart';
import 'package:study_planner/topic_model.dart';
import 'package:study_planner/topic_provider.dart';
import 'package:study_planner/user_stats_model.dart';

import 'support/hive_memory.dart';

/// Focus artık "zamanlayıcı + Bitir" değil: bağlamı (ne + neden + ne kadar)
/// gösterir, bitince "nasıl geçti" sorar, bağlı görevi GERÇEK süreyle
/// tamamlar ve cevap sonraki öneri/rozetleri değiştirir. Gerçek ekran.
void main() {
  setUp(openMemoryBoxes);
  tearDown(closeMemoryBoxes);

  const reason = 'Son denemende burada zorlandın.';

  /// Focus'u bir "başlatıcı" rotadan açar (kök rota pop edilemez).
  /// [elapsedMinutes] > 0 ise ölçülmüş bir çalışmayı çapa üzerinden geri
  /// yükler — gerçek dakikalar beklemeden.
  Future<ProviderContainer> openFocus(
    WidgetTester tester, {
    int? elapsedMinutes,
    bool withTask = true,
    StudyIntent? intent,
    bool anchorHasTask = true,
  }) async {
    tester.view.physicalSize = const Size(900, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await HiveBoxes.stats.put(
        'main', UserStatsModel(hasSeenExactAlarmPrompt: true));
    await HiveBoxes.subjects.put(
      's-mat',
      SubjectModel(
        id: 's-mat',
        name: 'Matematik',
        colorValue: 0xFF6750A4,
        createdAt: DateTime(2026, 1, 1),
      ),
    );
    await HiveBoxes.topics.put(
      't-b',
      TopicModel(
        id: 't-b',
        subjectId: 's-mat',
        name: 'Bölünebilme',
        createdAt: DateTime(2026, 9, 1),
      ),
    );
    final now = DateTime.now();
    if (withTask) {
      await HiveBoxes.tasks.put(
        'task-1',
        TaskModel(
          id: 'task-1',
          title: 'Bölünebilme',
          subjectId: 's-mat',
          topicId: 't-b',
          dueDate: DateTime(now.year, now.month, now.day),
          createdAt: DateTime(2026, 9, 1),
          estimatedMinutes: 25,
        ),
      );
    }
    if (elapsedMinutes != null) {
      await HiveBoxes.focusAnchor.put('current', {
        'mode': 'free',
        'phase': 'work',
        'blockMin': 25,
        'pomoCycle': 1,
        'committedSec': elapsedMinutes * 60,
        'loggedSec': 0,
        'segStartMs': DateTime.now().millisecondsSinceEpoch,
        'subjectId': 's-mat',
        'topicId': 't-b',
        'note': 'Bölünebilme',
        'runId': 'run-restored',
        'taskId': (withTask && anchorHasTask) ? 'task-1' : null,
        'reason': reason,
      });
    }

    final container = ProviderContainer();
    addTearDown(container.dispose);

    final launchIntent = intent ??
        StudyIntent(
          source: withTask ? StudyIntentSource.task : StudyIntentSource.topic,
          subjectId: 's-mat',
          topicId: 't-b',
          taskId: withTask ? 'task-1' : null,
          title: 'Bölünebilme',
          targetMinutes: 25,
          reason: reason,
        );

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => FocusScreen(intent: launchIntent)),
                ),
                child: const Text('aç'),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('aç'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    return container;
  }

  /// Çalışırken halka animasyonu sürekli kare ürettiği için pumpAndSettle
  /// bitmez; sabit sayıda kare ilerletiriz.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  testWidgets(
      'seans ÖNCESİ bağlam: ne + kaç dk + NEDEN (öneri gerekçesi olduğu gibi)',
      (tester) async {
    final c = await openFocus(tester);

    expect(find.text('ODAK SEANSI'), findsOneWidget);
    expect(find.text('Bölünebilme'), findsWidgets);
    expect(find.text('Matematik · 25 dk'), findsOneWidget);
    expect(find.text(reason), findsOneWidget);
    // Niyet ≠ kanıt: sadece ekranı açmak hiçbir kayıt/durum üretmez.
    expect(c.read(focusSessionProvider), isEmpty);
    expect(c.read(topicProvider).single.status, TopicStatus.notStarted);
  });

  testWidgets('seans SIRASINDA sakin: alan/seçiciler gizli, bağlam kartı kalır',
      (tester) async {
    await openFocus(tester, elapsedMinutes: 5);

    expect(find.text('Ne üzerinde çalışıyorsun? (opsiyonel)'), findsNothing);
    expect(find.text('Matematik · 25 dk'), findsOneWidget);
    expect(find.text(reason), findsOneWidget,
        reason: 'gerekçe seans sürerken de görünür kalır');
  });

  testWidgets(
      'YOLCULUK D/E: Bitir → "Zorlandım" + görevi tamamla → tek adım "çalışıldı" '
      '(REGRESYON: tekrar edildi DEĞİL), gerçek süre, cevap, rozet', (tester) async {
    final c = await openFocus(tester, elapsedMinutes: 15);

    await tester.tap(find.text('Bitir'));
    await settle(tester);

    // Sheet: gerçek süre + soru + üç net cevap
    expect(find.text('15 dk çalıştın'), findsOneWidget);
    expect(find.text('Nasıl geçti?'), findsOneWidget);
    expect(find.text('Zorlandım'), findsOneWidget);
    expect(find.text('Normaldi'), findsOneWidget);
    expect(find.text('İyi gitti'), findsOneWidget);
    // 15 dk < 25 dk hedef → görev varsayılan olarak "tamamlandı" DEĞİL
    expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isFalse);

    await tester.tap(find.text('Görevi tamamlandı say'));
    await tester.pump();
    await tester.tap(find.text('Zorlandım'));
    await settle(tester);

    // 1) cevap çalışmaya (tüm dilimlerine) yazıldı, dakikalar kayıtlı
    final sessions = c.read(focusSessionProvider);
    expect(sessions, isNotEmpty);
    expect(sessions.every((s) => s.feeling == FocusFeeling.hard), isTrue);
    expect(sessions.fold<int>(0, (a, s) => a + s.minutes), 15);
    expect(sessions.every((s) => s.taskId == 'task-1'), isTrue);
    expect(sessions.every((s) => s.runId == 'run-restored'), isTrue);

    // 2) görev tamamlandı, gerçek süre canonical kaynaktan
    final task = c.read(taskProvider).single;
    expect(task.isCompleted, isTrue);
    expect(task.actualMinutes, 15);

    // 3) REGRESYON: tek gerçek çalışma → tek adım
    expect(c.read(topicProvider).single.status, TopicStatus.studied);

    // 4) tek cevap = hafif sinyal (konu "zayıf" değil)
    expect(c.read(topicEvidenceProvider)['t-b']!.label,
        'Son çalışmanda zorlandın');

    // 5) öğrenciye söylenen cümle gerçekten olacak şeyi söylüyor
    expect(find.text('Not aldım. Bu konuya tekrar bakarken hatırlatırım.'),
        findsOneWidget);
  });

  testWidgets('"Şimdilik geç": cevap/görev yazılmaz — dakikalar (etkinlik) yine kayıtlı',
      (tester) async {
    final c = await openFocus(tester, elapsedMinutes: 15);

    await tester.tap(find.text('Bitir'));
    await settle(tester);
    await tester.tap(find.text('Şimdilik geç'));
    await settle(tester);

    final sessions = c.read(focusSessionProvider);
    expect(sessions.fold<int>(0, (a, s) => a + s.minutes), 15);
    expect(sessions.every((s) => s.feeling == null), isTrue,
        reason: 'cevaplanmayan "iyi geçti" DEĞİLDİR');
    expect(c.read(taskProvider).single.isCompleted, isFalse);
    expect(find.textContaining('Not aldım'), findsNothing);
  });

  testWidgets(
      'süre ÖLÇÜLMÜŞ ETKİNLİKTİR, öğrenme kanıtı değil: 5 dk da olsa konu "çalışıldı" '
      '(etkinlik), ama zayıf/güçlü hiçbir sonuç üretilmez', (tester) async {
    final c = await openFocus(tester, elapsedMinutes: 5);

    await tester.tap(find.text('Bitir'));
    await settle(tester);
    expect(find.text('5 dk çalıştın'), findsOneWidget);
    await tester.tap(find.text('Şimdilik geç'));
    await settle(tester);

    expect(c.read(topicProvider).single.status, TopicStatus.studied);
    expect(c.read(topicEvidenceProvider)['t-b']!.hasBadge, isFalse,
        reason: 'dakika sayısı bir kanıt rozeti üretmez');
  });

  testWidgets('1 dakikadan kısa "Bitir": hiçbir şey sorulmaz/kaydedilmez',
      (tester) async {
    final c = await openFocus(tester, elapsedMinutes: 0);

    await tester.tap(find.text('Bitir'));
    await settle(tester);

    expect(find.text('Nasıl geçti?'), findsNothing);
    expect(c.read(focusSessionProvider), isEmpty);
    expect(c.read(topicProvider).single.status, TopicStatus.notStarted);
  });

  testWidgets('bağlı görev yoksa "görevi tamamla" seçeneği hiç çıkmaz',
      (tester) async {
    await openFocus(tester, elapsedMinutes: 15, withTask: false);

    await tester.tap(find.text('Bitir'));
    await settle(tester);

    expect(find.byType(CheckboxListTile), findsNothing);
    expect(find.text('Nasıl geçti?'), findsOneWidget);
  });

  testWidgets('hedefe ulaşıldıysa görev varsayılan olarak "tamamlandı" işaretli gelir',
      (tester) async {
    await openFocus(tester, elapsedMinutes: 26);

    await tester.tap(find.text('Bitir'));
    await settle(tester);

    expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isTrue);
  });

  testWidgets(
      'Home\'daki "Odak devam ediyor" bandından dönüş (bağlamsız FocusScreen): görev '
      'bağı ve gerekçe çapadan geri gelir', (tester) async {
    await openFocus(
      tester,
      elapsedMinutes: 15,
      intent: StudyIntent.free, // banner yalnız FocusScreen() açar
    );

    // Gerekçe çapadan gelir ve görünür.
    expect(find.text(reason), findsOneWidget);

    await tester.tap(find.text('Bitir'));
    await settle(tester);
    // Görev bağı korunmuş: "görevi tamamlandı say" seçeneği var.
    expect(find.byType(CheckboxListTile), findsOneWidget);
  });
}
