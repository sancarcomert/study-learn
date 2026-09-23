import 'dart:math' as math;

/// Uygulama arka plandayken (ekran kilitli, başka uygulamada) sayılabilecek
/// çalışma süresinin sınırı.
///
/// Sorun: serbest mod, duvar saatiyle sayar ve seans arka planda "sürer". Bu,
/// telefonu kilitleyip çalışan öğrenci için doğru — ama bir seansı açık
/// bırakıp unutan öğrencinin 10 saatini "çalışma" diye kaydeder. Bu sahte
/// bir etkinlik kanıtıdır (toplam odak süresi, göreve harcanan gerçek süre ve
/// "süre tahminin çok üstünde" sinyali bundan bozulur).
///
/// Kural (deterministik, eşik "öğrenme" için değil VERİ SAĞLIĞI için): uygulama
/// arka plana alınırken hedefin ne kadarı tamamlanmışsa, kalan hedef + bir
/// tolerans kadar arka plan süresi sayılır; fazlası SAYILMAZ. Hedef bitince
/// kullanıcıya zaten bildirim gitmiştir — o noktadan sonra dönmediyse çalışmanın
/// sürdüğünü bilemeyiz. Uygulama açıkken (ön planda) geçen süre her zaman
/// tamamen sayılır.
class FocusAnchorMath {
  const FocusAnchorMath._();

  /// Hedef dolduktan sonra da sayılan arka plan toleransı.
  static const int graceSec = 10 * 60;

  /// [awaySec] arka plan süresinden SAYILMAYACAK saniye.
  /// [elapsedAtLeaveSec]: uygulama arka plana alınırken seansın geçen süresi.
  static int uncreditedAwaySec({
    required int elapsedAtLeaveSec,
    required int awaySec,
    required int targetSec,
  }) {
    final creditable = math.max<int>(0, targetSec - elapsedAtLeaveSec) + graceSec;
    return math.max<int>(0, awaySec - creditable);
  }

  /// Çapadan (arka plandayken yazılmış) serbest mod seansının SAYILAN geçen
  /// süresi. [lastActiveMs] yoksa (eski çapa) segmentin başlangıcı, "en son
  /// ön planda görüldüğü an" sayılır — yani en kötü durumda hedef+tolerans.
  static int creditedFreeElapsedSec({
    required int committedSec,
    required int segStartMs,
    int? lastActiveMs,
    required int nowMs,
    required int targetSec,
  }) {
    final leaveMs = math.max<int>(segStartMs, lastActiveMs ?? segStartMs);
    final elapsedAtLeave =
        committedSec + math.max<int>(0, (leaveMs - segStartMs) ~/ 1000);
    final away = math.max<int>(0, (nowMs - leaveMs) ~/ 1000);
    final raw = committedSec + math.max<int>(0, (nowMs - segStartMs) ~/ 1000);
    return raw -
        uncreditedAwaySec(
          elapsedAtLeaveSec: elapsedAtLeave,
          awaySec: away,
          targetSec: targetSec,
        );
  }
}
