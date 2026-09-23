import 'topic_model.dart';

/// Bir konunun [TopicStatus]'unun TEK doğruluk kaynağı: olay tabanlı geçiş
/// kuralı. Durum artık bir arayüz jestinin ("satıra dokun, sıradaki duruma
/// geç") ya da bir ekranın yan etkisinin sonucu DEĞİL; yalnızca gerçek bir
/// ÇALIŞMA OLAYI kaydedilince değişir.
///
/// Anlamlar:
/// - [TopicStatus.notStarted]: bu konuda kaydedilmiş hiçbir çalışma olayı yok.
/// - [TopicStatus.studied]: bir çalışma olayı kaydedildi (ölçülmüş Focus
///   çalışması ya da o konuya bağlı bir görevin tamamlandığı beyanı). Bu bir
///   ÇABA/ETKİNLİK kaydıdır; "anlaşıldı" ya da "öğrenildi" DEĞİLDİR.
/// - [TopicStatus.reviewed]: ÖNCEKİ olaydan AYRI ikinci bir çalışma olayı
///   kaydedildi — konu yeniden ele alındı. Aynı olayın ikinci kez sayılması
///   tekrar SAYILMAZ (bkz. [applyStudyActivity]'teki idempotentlik).
///
/// Bir çalışma olayı asla "performans arttı" demez — o yalnız gerçek bir
/// denemeden gelir (bkz. topic_evidence.dart / deneme_provider.dart).
class TopicProgress {
  const TopicProgress._();

  /// Saklanan olay anahtarı üst sınırı — en eskiler düşer. Anahtarlar yalnız
  /// "bu olay zaten sayıldı mı" sorusuna yarar; sınırsız büyümesin.
  static const int maxKeys = 50;

  /// Bir Focus çalışmasının (bir ya da çok dilimden oluşan) olay anahtarı.
  static String focusRunKey(String runId) => 'run:$runId';

  /// Bir görevin tamamlanma beyanının olay anahtarı.
  static String taskKey(String taskId) => 'task:$taskId';

  /// [eventKey] olayını uygular.
  /// - Anahtar zaten kayıtlıysa: hiçbir şey değişmez (aynı olay iki kez sayılmaz,
  ///   aç-kapa yapılan bir görev tamamlaması da ilerletmez).
  /// - Yeni anahtar: notStarted→studied, studied→reviewed, reviewed→reviewed.
  ///   Tek olay = en çok TEK adım.
  static TopicProgressResult applyStudyActivity({
    required TopicStatus status,
    required List<String> keys,
    required String eventKey,
  }) {
    if (keys.contains(eventKey)) {
      return TopicProgressResult(status: status, keys: keys, isNewEvent: false);
    }
    final next = switch (status) {
      TopicStatus.notStarted => TopicStatus.studied,
      TopicStatus.studied => TopicStatus.reviewed,
      TopicStatus.reviewed => TopicStatus.reviewed,
    };
    final nextKeys = [...keys, eventKey];
    if (nextKeys.length > maxKeys) {
      nextKeys.removeRange(0, nextKeys.length - maxKeys);
    }
    return TopicProgressResult(status: next, keys: nextKeys, isNewEvent: true);
  }
}

class TopicProgressResult {
  final TopicStatus status;
  final List<String> keys;

  /// Bu çağrı yeni bir olay mıydı (anahtar ilk kez görüldü).
  final bool isNewEvent;

  const TopicProgressResult({
    required this.status,
    required this.keys,
    required this.isNewEvent,
  });
}
