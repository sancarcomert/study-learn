import 'topic_model.dart';

/// Bir konu satırında rozet olarak gösterilecek DURUM — yalnız gerçek bir
/// kanıt varsa [none] dışında bir değer alır. Öğrenciye gösterilen metin
/// [TopicEvidence.label]'da; bu enum yalnız sıralama/önceliği belirler.
enum TopicEvidenceState { none, weakConfirmed, improving, needsReview }

/// [TopicEvidenceEngine.classify] çıktısı — bir konu satırında gösterilecek
/// TEK, öğrenci-diliyle yazılmış kısa durum (rozet yoksa [label] null).
class TopicEvidence {
  final TopicEvidenceState state;
  final String? label;

  const TopicEvidence(this.state, this.label);

  bool get hasBadge => state != TopicEvidenceState.none;

  static const TopicEvidence none = TopicEvidence(TopicEvidenceState.none, null);
}

/// Konu-seviyesi kanıt rozetinin TEK saf çekirdeği (Bölüm 1). Yeni bir sinyal
/// İCAT ETMEZ — yalnız zaten PlanBuilder/StudyAdvisor/Stats'ın kullandığı AYNI
/// ham verileri (deneme_provider.dart'taki examWeak/resolved konu id kümeleri
/// + TopicModel.status/updatedAt) tek, öncelik sıralı bir öğrenci mesajına
/// çevirir. Rozet metni her zaman aynı motorun (bkz. topic_evidence_provider.
/// dart) beslediği veriden gelir — ayrı bir "rozet mantığı" İCAT EDİLMEZ.
class TopicEvidenceEngine {
  const TopicEvidenceEngine._();

  /// [staleReviewSubjectIdsProvider] (topic_provider.dart) ile AYNI eşik —
  /// iki farklı "ne zaman bayat sayılır" tanımı olmasın diye.
  static const int staleReviewDays = 14;

  /// Öncelik sırası (en güçlüden en zayıfa), belirleyici:
  ///
  /// 1) [TopicEvidenceState.weakConfirmed] — bu konu GERÇEK bir denemede
  ///    hâlâ yanlış çıkıyor. Hiçbir şey bunu ezmez; StudyAdvisor'da da en
  ///    ağır sinyal budur (examWeakTopic).
  /// 2) [TopicEvidenceState.improving] — bu konu ÖNCEKİ denemede zayıftı,
  ///    SON denemede artık değil. NOT: bu, (1) ile YAPISAL olarak asla aynı
  ///    anda true olamaz — "weakConfirmed" = son denemenin zayıf kümesi,
  ///    "improving" = önceki zayıf kümesi EKSİ son zayıf küme; bir konu
  ///    ikisinde birden bulunamaz (bkz. deneme_provider.dart). Yine de
  ///    savunmacı olarak (1) önce kontrol edilir.
  /// 3) [TopicEvidenceState.needsReview] — konu "tekrar edildi" işaretli
  ///    ama [staleReviewDays]+ gündür dokunulmamış. Deneme kanıtından
  ///    BAĞIMSIZ, salt zamana dayalı bir hatırlatma — bu yüzden en düşük
  ///    öncelikte: taze bir deneme sinyali varsa (1 ya da 2) onun yanında
  ///    anlamını yitirir.
  /// 4) [TopicEvidenceState.none] — anlamlı bir kanıt yok, rozet YOK.
  static TopicEvidence classify({
    required bool isExamWeak,
    required bool isRecentlyResolved,
    required TopicStatus status,
    required DateTime? updatedAt,
    DateTime? now,
  }) {
    if (isExamWeak) {
      return const TopicEvidence(
        TopicEvidenceState.weakConfirmed,
        'Zayıf — denemeden doğrulandı',
      );
    }
    if (isRecentlyResolved) {
      return const TopicEvidence(TopicEvidenceState.improving, 'Düzeliyor');
    }
    if (status == TopicStatus.reviewed) {
      final reference = now ?? DateTime.now();
      final stale = updatedAt == null ||
          reference.difference(updatedAt).inDays >= staleReviewDays;
      if (stale) {
        return const TopicEvidence(
            TopicEvidenceState.needsReview, 'Tekrar gerekli');
      }
    }
    return TopicEvidence.none;
  }
}
