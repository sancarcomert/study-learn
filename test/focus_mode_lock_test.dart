import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_planner/focus_screen.dart';
import 'package:study_planner/hive_boxes.dart';
import 'package:study_planner/study_intent.dart';
import 'package:study_planner/subject_model.dart';
import 'package:study_planner/user_stats_model.dart';

import 'support/hive_memory.dart';

/// Canlı testte bulunan bug: Odak seansı DURAKLATILMIŞKEN Serbest↔Pomodoro
/// değiştirmek mümkündü ve o ana kadar ölçülmüş ama henüz geçmişe
/// yazılmamış dakikaları sessizce siliyordu (_switchMode hiç flush etmeden
/// tüm sayaç durumunu sıfırlıyordu). Düzeltme: mod seçici bir kez
/// Başlat'a basıldıktan sonra (duraklatılmış olsa bile) tamamen kilitlenir
/// — burada hem kilidi hem de kilit sayesinde verinin gerçekten
/// kaybolmadığını doğruluyoruz.
void main() {
  setUp(openMemoryBoxes);
  tearDown(closeMemoryBoxes);

  Future<ProviderContainer> openFocus(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await HiveBoxes.stats.put('main', UserStatsModel(hasSeenExactAlarmPrompt: true));
    await HiveBoxes.subjects.put(
      's-mat',
      SubjectModel(
        id: 's-mat',
        name: 'Matematik',
        colorValue: 0xFF6750A4,
        createdAt: DateTime(2026, 1, 1),
      ),
    );
    // 15 dk önce başlamış, hâlâ süren (duraklatılmamış) bir çapa — restore
    // sonrası ekran zaten "başlamış" (running) durumda açılır.
    await HiveBoxes.focusAnchor.put('current', {
      'mode': 'free',
      'phase': 'work',
      'blockMin': 25,
      'pomoCycle': 1,
      'committedSec': 15 * 60,
      'loggedSec': 0,
      'segStartMs': DateTime.now().millisecondsSinceEpoch,
      'subjectId': 's-mat',
      'topicId': null,
      'note': null,
      'runId': 'run-restored',
      'taskId': null,
      'reason': null,
    });

    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const FocusScreen(
                      intent: StudyIntent(
                        source: StudyIntentSource.free,
                        subjectId: 's-mat',
                      ),
                    ),
                  ),
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

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  testWidgets(
      'restore edilmiş (zaten başlamış) seansta mod seçici baştan kilitli',
      (tester) async {
    await openFocus(tester);

    // Serbest'e özgü bir süre çipi ("10 dk", Pomodoro seçeneklerinde yok) —
    // mod hâlâ Serbest olduğunun kanıtı.
    expect(find.text('10 dk'), findsOneWidget);

    await tester.tap(find.text('Pomodoro'));
    await settle(tester);

    expect(find.text('10 dk'), findsOneWidget,
        reason: 'kilitli mod seçici tıklansa da geçiş olmamalı');
  });

  testWidgets(
      'DURAKLATILMIŞKEN mod seçiciye dokunmak ne modu değiştirir ne de '
      'ölçülmüş dakikaları kaybeder (REGRESYON)', (tester) async {
    await openFocus(tester);

    await tester.tap(find.text('Duraklat'));
    await settle(tester);
    expect(find.text('Başlat'), findsOneWidget,
        reason: 'gerçekten duraklamış olmalı');

    // Bug buradaydı: _running=false (duraklatılmış) olunca mod seçici eskiden
    // tekrar aktifti.
    await tester.tap(find.text('Pomodoro'));
    await settle(tester);
    expect(find.text('10 dk'), findsOneWidget,
        reason: 'duraklatılmışken de mod kilitli kalmalı');

    await tester.tap(find.text('Bitir'));
    await settle(tester);

    // 15 dk hiç kaybolmadan sonuç sheet'ine ulaştı.
    expect(find.text('15 dk çalıştın'), findsOneWidget);
  });
}
