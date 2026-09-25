import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:study_planner/add_task_screen.dart';
import 'package:study_planner/app_theme.dart';
import 'package:study_planner/hive_boxes.dart';
import 'package:study_planner/subject_model.dart';
import 'package:study_planner/task_provider.dart';
import 'package:study_planner/user_stats_model.dart';

import '../support/hive_memory.dart';

/// Hızlı art arda dokunma: aynı işlem iki kez tetiklenirse kayıt çiftlenmemeli,
/// ekran iki kez kapatılıp altındaki ekran da kapanmamalı.
void main() {
  setUpAll(() => initializeDateFormatting('tr_TR', null));
  setUp(openMemoryBoxes);
  tearDown(closeMemoryBoxes);

  Future<ProviderContainer> pumpLauncher(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await HiveBoxes.stats.put(
      'main',
      UserStatsModel(
        hasCompletedOnboarding: true,
        hasSeenNotificationPrompt: true,
        hasSeenTaskHints: true,
        hasSeenExactAlarmPrompt: true,
        hasAddedFirstTask: true,
      ),
    );
    await HiveBoxes.subjects.put(
      's1',
      SubjectModel(
          id: 's1',
          name: 'Matematik',
          colorValue: 0xFF6750A4,
          createdAt: DateTime(2026, 1, 1)),
    );
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        theme: AppTheme.theme,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AddTaskScreen()),
                ),
                child: const Text('AÇ'),
              ),
            ),
          ),
        ),
      ),
    ));
    return c;
  }

  testWidgets('Görev ekle: "Ekle"ye iki kez hızlı basmak tek görev yazar ve '
      'altındaki ekranı kapatmaz', (tester) async {
    final c = await pumpLauncher(tester);
    await tester.tap(find.text('AÇ'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Hızlı görev');
    await tester.pump();

    final addButton = find.text('Görevi Ekle');
    expect(addButton, findsWidgets);
    // Aynı karede iki dokunuş (parmak çift dokundu).
    await tester.tap(addButton.first, warnIfMissed: false);
    await tester.tap(addButton.first, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(c.read(taskProvider).where((t) => t.title == 'Hızlı görev'),
        hasLength(1),
        reason: 'çift dokunuş çift kayıt üretmemeli');
    // Başlatıcı ekran hâlâ ekranda (ikinci pop onu kapatmamış).
    expect(find.text('AÇ'), findsOneWidget);
  });
}
