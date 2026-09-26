import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:study_planner/focus_history_screen.dart';
import 'package:study_planner/focus_session_provider.dart';
import 'package:study_planner/hive_boxes.dart';
import 'package:study_planner/subject_model.dart';

import 'support/hive_memory.dart';

/// P0-6: Odak Geçmişi'nde yanlış girilen bir seansı DÜZENLEME — önceden
/// yalnız silme (+ geri al) vardı, yanlış ders/süre kaydını düzeltmenin tek
/// yolu silip elle yeni bir seans "uydurmak"tı (ki geçmişten yeni seans
/// başlatılamaz, bu yüzden fiilen imkansızdı).
void main() {
  setUpAll(() => initializeDateFormatting('tr_TR', null));
  setUp(openMemoryBoxes);
  tearDown(closeMemoryBoxes);

  Future<ProviderContainer> pumpHistory(WidgetTester tester) async {
    await HiveBoxes.subjects.put(
      's-mat',
      SubjectModel(
        id: 's-mat',
        name: 'Matematik',
        colorValue: 0xFF6750A4,
        createdAt: DateTime(2026, 1, 1),
      ),
    );
    await HiveBoxes.subjects.put(
      's-fizik',
      SubjectModel(
        id: 's-fizik',
        name: 'Fizik',
        colorValue: 0xFF00695C,
        createdAt: DateTime(2026, 1, 1),
      ),
    );
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(focusSessionProvider.notifier).log(
          minutes: 20,
          mode: 'serbest',
          subjectId: 's-mat',
        );

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: FocusHistoryScreen()),
    ));
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('yanlış ders/süre girilmiş seans düzenlenip düzeltilir',
      (tester) async {
    final c = await pumpHistory(tester);

    expect(find.text('Matematik'), findsWidgets);
    // "20 dk" hem tekil satırda hem "HANGİ DERSE ÇALIŞTIN" ders toplamında
    // görünür (tek seans olduğu için ikisi aynı sayı) — bilerek findsWidgets.
    expect(find.text('20 dk'), findsWidgets);

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Seansı düzenle'), findsOneWidget);

    await tester.tap(find.text('Fizik'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, '35');
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    final session = c.read(focusSessionProvider).single;
    expect(session.subjectId, 's-fizik');
    expect(session.minutes, 35);
    expect(find.text('35 dk'), findsWidgets);
    expect(find.text('Fizik'), findsWidgets);
  });

  testWidgets('geçersiz (boş/0) dakika ile kaydedilemez, eski değer kalır',
      (tester) async {
    final c = await pumpHistory(tester);

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '0');
    await tester.tap(find.text('Kaydet'));
    await tester.pump();

    // Sheet kapanmadı, hata mesajı gösterildi, veri değişmedi.
    expect(find.text('Seansı düzenle'), findsOneWidget);
    expect(c.read(focusSessionProvider).single.minutes, 20);
  });
}
