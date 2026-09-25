import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:study_planner/focus_anchor.dart';
import 'package:study_planner/nlu/nlu_engine.dart';
import 'package:study_planner/nlu/nlu_modifier.dart';
import 'package:study_planner/plan_parser.dart';

/// Serbest metin girişleri (Coach, plan ayrıştırıcı) hiçbir girdide çökmemeli
/// ve makul sürede dönmeli; Focus süre matematiği tutarlı kalmalı.
void main() {
  final weird = <String>[
    '',
    ' ',
    '\n\n\t',
    '???!!!...',
    '😀😀😀',
    'a' * 5000,
    'matematik ' * 400,
    '١٢٣ مرحبا',
    'İİİıııİİİ ŞşĞğ ÜüÖöÇç',
    '0 saat 0 dk',
    '99999999999999999999 saat',
    '-5 dakika',
    '1e9 saat',
    '<script>alert(1)</script>',
    "'; DROP TABLE tasks; --",
    'yarın yarın yarın öbür gün haftaya',
    '25:99 de çalış',
    '32 Ocak 2026',
    '\u0000\u0001\u0002',
  ];

  test('NLU + modifier + PlanParser: tuhaf girdilerde çökmez', () {
    for (final w in weird) {
      final sw = Stopwatch()..start();
      expect(() => CoachNlu.analyze(w), returnsNormally, reason: '"$w"');
      expect(() => NluModifierParser.parse(w), returnsNormally, reason: '"$w"');
      expect(() => PlanParser.parse(w, subjects: const []), returnsNormally,
          reason: '"$w"');
      expect(sw.elapsedMilliseconds, lessThan(3000),
          reason: 'çok yavaş: "${w.length > 30 ? w.substring(0, 30) : w}"');
    }
  });

  test('rastgele Türkçe/ASCII gürültüsü: çökme yok, sonuç alanları tutarlı', () {
    final rnd = Random(3);
    const alphabet = 'abcçdefgğhıijklmnoöprsştuüvyz ?.,!0123456789';
    for (var i = 0; i < 1500; i++) {
      final len = rnd.nextInt(80);
      final s = String.fromCharCodes(
          List.generate(len, (_) => alphabet.codeUnitAt(rnd.nextInt(alphabet.length))));
      final r = CoachNlu.analyze(s);
      expect(r.score, inInclusiveRange(0.0, 1.0), reason: '"$s"');
      if (r.isConfident) {
        expect(r.intent.name, isNot('unknown'), reason: '"$s"');
      }
      final t = r.slots.timeMinutes;
      if (t != null) expect(t, inInclusiveRange(5, 720), reason: '"$s"');
    }
  });

  test('FocusAnchorMath: sayılan süre ham süreyi ve tavanı aşmaz, geriye gitmez',
      () {
    final rnd = Random(11);
    for (var i = 0; i < 3000; i++) {
      final committed = rnd.nextInt(3 * 3600);
      const segStart = 1000000;
      final nowMs = segStart + rnd.nextInt(30 * 3600) * 1000;
      final lastActive =
          rnd.nextBool() ? segStart + rnd.nextInt(30 * 3600) * 1000 : null;
      final target = (5 + rnd.nextInt(115)) * 60;
      final credited = FocusAnchorMath.creditedFreeElapsedSec(
        committedSec: committed,
        segStartMs: segStart,
        lastActiveMs: lastActive,
        nowMs: nowMs,
        targetSec: target,
      );
      final raw = committed + (nowMs - segStart) ~/ 1000;
      expect(credited, lessThanOrEqualTo(raw), reason: 'i=$i');
      expect(credited, greaterThanOrEqualTo(committed), reason: 'i=$i');
    }
  });
}
