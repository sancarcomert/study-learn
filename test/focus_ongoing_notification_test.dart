import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_planner/focus_screen.dart';
import 'package:study_planner/hive_boxes.dart';
import 'package:study_planner/study_intent.dart';
import 'package:study_planner/subject_model.dart';
import 'package:study_planner/user_stats_model.dart';

import 'support/hive_memory.dart';

/// P0-5: seans arka plana alınırken/dönerken kalıcı bildirim çağrıları
/// tetiklenir ve çökmez. `NotificationService` gerçek platform kanalı
/// gerektirdiği için (test VM'i Android değil) içeriğini burada değil,
/// yalnızca bu entegrasyonun güvenli olduğunu doğruluyoruz — asıl mantık
/// (Serbest yukarı/Pomodoro aşağı sayım hesapları) notification_service.dart
/// ve focus_anchor.dart'taki saf fonksiyonlarla zaten kapsanıyor.
void main() {
  setUp(openMemoryBoxes);
  tearDown(closeMemoryBoxes);

  testWidgets(
      'seans sürerken arka plana alınıp dönmek çökmez, çapa hâlâ doğru yazılır',
      (tester) async {
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
                      autoStart: true,
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
    expect(find.text('Duraklat'), findsOneWidget, reason: 'autoStart çalışmalı');

    // Arka plana al (Pomodoro/Serbest fark etmeksizin _showOngoingNotification
    // tetiklenir) → foreground'a dön (cancelOngoingFocus tetiklenir).
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    // Hâlâ çalışıyor, çökmedi — çapa güncel yazılmaya devam ediyor.
    expect(find.text('Duraklat'), findsOneWidget);
    expect(HiveBoxes.focusAnchor.get('current'), isNotNull);
  });
}
