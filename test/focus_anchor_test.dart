import 'package:flutter_test/flutter_test.dart';
import 'package:study_planner/focus_anchor.dart';

/// Unutulan zamanlayıcının sahte "çalışma süresi" üretmesini engelleyen kural.
void main() {
  const target = 25 * 60;

  test('kısa arka plan: hiçbir şey kırpılmaz', () {
    expect(
      FocusAnchorMath.uncreditedAwaySec(
          elapsedAtLeaveSec: 15 * 60, awaySec: 5 * 60, targetSec: target),
      0,
    );
  });

  test('hedef + tolerans dolduktan sonraki arka plan süresi sayılmaz', () {
    // 10 dk çalışıp ayrıldı; hedefe 15 dk + 10 dk tolerans = 25 dk sayılır.
    expect(
      FocusAnchorMath.uncreditedAwaySec(
          elapsedAtLeaveSec: 10 * 60, awaySec: 9 * 3600, targetSec: target),
      9 * 3600 - 25 * 60,
    );
  });

  test('hedefi zaten aşmış seans yalnız tolerans kadar sayılır', () {
    expect(
      FocusAnchorMath.uncreditedAwaySec(
          elapsedAtLeaveSec: 40 * 60, awaySec: 60 * 60, targetSec: target),
      60 * 60 - FocusAnchorMath.graceSec,
    );
  });

  test('çapa: sayılan süre = ön plan + kırpılmış arka plan', () {
    const min = 60 * 1000;
    const now = 100 * 60 * min;
    final credited = FocusAnchorMath.creditedFreeElapsedSec(
      committedSec: 0,
      segStartMs: now - 700 * min, // 700 dk önce başladı
      lastActiveMs: now - 690 * min, // 10 dk çalıştı, sonra ayrıldı
      nowMs: now,
      targetSec: target,
    );
    expect(credited, 35 * 60); // 10 + (25-10) + 10
  });
}
