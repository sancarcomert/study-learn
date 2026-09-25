import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:study_planner/add_deneme_screen.dart';
import 'package:study_planner/app_theme.dart';
import 'package:study_planner/deneme_provider.dart';

import '../support/hive_memory.dart';

/// Deneme girişi: imkânsız değerler (soru sayısından fazla doğru/yanlış/boş)
/// kaydedilmemeli — net ortalamaları, trend ve "en zayıf ders" sinyali bunlara
/// dayanıyor.
void main() {
  setUpAll(() => initializeDateFormatting('tr_TR', null));
  setUp(openMemoryBoxes);
  tearDown(closeMemoryBoxes);

  Future<ProviderContainer> pumpForm(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: MaterialApp(theme: AppTheme.theme, home: const AddDenemeScreen()),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    return c;
  }

  Future<void> addMath(WidgetTester tester, String c, String w, String b) async {
    await tester.tap(find.text('Matematik').first);
    await tester.pump(const Duration(milliseconds: 300));
    final fields = find.byType(TextField);
    final n = fields.evaluate().length;
    // Son üç alan: doğru / yanlış / boş.
    await tester.enterText(fields.at(n - 3), c);
    await tester.enterText(fields.at(n - 2), w);
    await tester.enterText(fields.at(n - 1), b);
    await tester.pump();
  }

  testWidgets('TYT Matematik 40 soru: 45 doğru → reddedilir, kayıt yok',
      (tester) async {
    final c = await pumpForm(tester);
    await addMath(tester, '45', '0', '0');
    await tester.ensureVisible(find.text('Kaydet'));
    await tester.tap(find.text('Kaydet'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(c.read(denemeProvider), isEmpty);
    expect(find.textContaining('en fazla 40'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('toplam 43 (30+8+5) reddedilir', (tester) async {
    final c = await pumpForm(tester);
    await addMath(tester, '30', '8', '5');
    await tester.ensureVisible(find.text('Kaydet'));
    await tester.tap(find.text('Kaydet'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(c.read(denemeProvider), isEmpty);
    expect(find.textContaining('şu an 43'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('tam 40 (30+8+2) kabul edilir', (tester) async {
    final c = await pumpForm(tester);
    await addMath(tester, '30', '8', '2');
    await tester.ensureVisible(find.text('Kaydet'));
    await tester.tap(find.text('Kaydet'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(c.read(denemeProvider), hasLength(1));
    await tester.pump(const Duration(seconds: 4));
  });
}
