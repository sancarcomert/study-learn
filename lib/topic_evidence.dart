import 'focus_session_model.dart';
import 'topic_model.dart';

/// Öğrencinin bir konuda "zorlandım" demesinin ne kadar SAĞLAM bir sonuç
/// olduğu. Tek bir cevap yalnızca bir SİNYALDİR — konuyu "zayıf" yapmaz.
/// Daha güçlü sonuç, birbirini doğrulayan kanıtlardan gelir.
enum DifficultySignal {
  /// Zorlandığına dair güncel bir kanıt yok (hiç cevap yok, son cevap
  /// "normaldi/iyi gitti", ya da eski).
  none,

  /// Konudaki SON cevaplanmış çalışmada "zorlandım" denmiş — tek başına zayıf
  /// bir sinyal: yalnız hatırlatır, öneriyi hafifçe etkiler.
  recent,

  /// Birbirini doğrulayan kanıt var: art arda iki çalışmada "zorlandım" YA DA
  /// bir zorlanma cevabı + aynı konuda gerçek süre tahminin çok üstünde.
  /// Şimdi bir plana/öneriye somut bir gerekçe olabilecek kadar sağlam.
  repeated,
}

/// Bir konu satırında rozet olarak gösterilecek DURUM — yalnız gerçek bir
/// kanıt varsa [none] dışında bir değer alır. Öğrenciye gösterilen metin
/// [TopicEvidence.label]'da; bu enum yalnız sıralama/önceliği belirler.
enum TopicEvidenceState {
  none,
  weakConfirmed,
  // Öğrenci konuyu çalışırken "zorlandım" dedi — deneme kanıtından AYRI,
  // çalışma kaynaklı sinyal. [strugglingRepeatedly] birbirini doğrulayan kanıt
  // varken; [struggling] tek başına son cevapken.
  strugglingRepeatedly,
  struggling,
  improving,
  needsReview,
}

/// [TopicEvidenceEngine.classify] çıktısı — bir konu satırında gösterilecek
/// TEK, öğrenci-diliyle yazılmış kısa durum (rozet yoksa [label] null).
class TopicEvidence {
  final TopicEvidenceState state;
  final String? label;

  const TopicEvidence(this.state, this.label);

  bool get hasBadge => state != TopicEvidenceState.none;

  /// Focus ekranında / Home kartında "neden bu konu?" satırı olarak
  /// gösterilen, tam cümle hâli (rozet metninden farklı: rozet bir durum
  /// etiketi, bu bir açıklama). Kanıt yoksa null — sahte gerekçe üretilmez.
  String? get sentence => switch (state) {
        TopicEvidenceState.weakConfirmed => 'Son denemende burada zorlandın.',
        TopicEvidenceState.strugglingRepeatedly =>
          'Bu konuda üst üste zorlandığını söyledin.',
        TopicEvidenceState.struggling => 'Son çalışmanda burada zorlandın.',
        TopicEvidenceState.improving => 'Son denemene göre burası düzeliyor.',
        TopicEvidenceState.needsReview =>
          'Bu konuyu tekrar edeli uzun zaman oldu.',
        TopicEvidenceState.none => null,
      };

  static const TopicEvidence none = TopicEvidence(TopicEvidenceState.none, null);
}

/// Konu-seviyesi kanıt rozetinin TEK saf çekirdeği. Yeni bir sinyal İCAT
/// ETMEZ — yalnız zaten PlanBuilder/StudyAdvisor/Stats'ın kullandığı AYNI ham
/// verileri (deneme_provider.dart'taki examWeak/resolved konu id kümeleri,
/// Focus çalışma cevapları + TopicModel.status/updatedAt) tek, öncelik sıralı
/// bir öğrenci mesajına çevirir.
class TopicEvidenceEngine {
  const TopicEvidenceEngine._();

  /// [staleReviewSubjectIdsProvider] (topic_provider.dart) ile AYNI eşik —
  /// iki farklı "ne zaman bayat sayılır" tanımı olmasın diye.
  static const int staleReviewDays = 14;

  /// "Zorlandım" cevabının güncel sayıldığı pencere — bundan eski bir cevap
  /// artık bir sinyal değil.
  static const int difficultyWindowDays = 14;

  /// Öğrencinin çalışma sonu cevaplarından, konu başına [DifficultySignal].
  ///
  /// - Sinyal KONUDAKİ SON cevaplanmış çalışmaya (run) bakar: o "normaldi/iyi
  ///   gitti" ise sinyal kalkar (ayrı bir "çözüldü" bayrağı gerekmez).
  /// - Son çalışma "zorlandım": ÖNCEKİ cevaplanmış çalışma da (pencere içinde)
  ///   "zorlandım" ise ya da konu [overranTopicIds]'te (aynı konuda gerçek süre
  ///   tahminin çok üstünde çıktı — davranışsal kanıt) ise [DifficultySignal
  ///   .repeated]; değilse yalnız [DifficultySignal.recent].
  /// - Cevap verilmemiş (feeling == null) çalışmalar hiçbir şeyi değiştirmez.
  /// - Bir çalışma = bir oy: Pomodoro'nun 3 bloğu "üst üste 3 kez" sayılmaz.
  static Map<String, DifficultySignal> difficultySignals(
    Iterable<FocusSession> sessions, {
    Set<String> overranTopicIds = const {},
    DateTime? now,
  }) {
    final reference = now ?? DateTime.now();

    // topicId → runKey → (feeling, en geç bitiş)
    final runs = <String, Map<String, ({int feeling, DateTime at})>>{};
    for (final s in sessions) {
      final topicId = s.topicId;
      final feeling = s.feeling;
      if (topicId == null || feeling == null) continue;
      final byRun = runs.putIfAbsent(topicId, () => {});
      final prev = byRun[s.runKey];
      if (prev == null || s.endedAt.isAfter(prev.at)) {
        byRun[s.runKey] = (feeling: feeling, at: s.endedAt);
      }
    }

    final result = <String, DifficultySignal>{};
    runs.forEach((topicId, byRun) {
      final ordered = byRun.values.toList()
        ..sort((a, b) => b.at.compareTo(a.at)); // en yeni önce
      final latest = ordered.first;
      if (latest.feeling != FocusFeeling.hard) return;
      if (reference.difference(latest.at).inDays >= difficultyWindowDays) {
        return;
      }
      final previousHard = ordered.length > 1 &&
          ordered[1].feeling == FocusFeeling.hard &&
          reference.difference(ordered[1].at).inDays < difficultyWindowDays;
      result[topicId] = (previousHard || overranTopicIds.contains(topicId))
          ? DifficultySignal.repeated
          : DifficultySignal.recent;
    });
    return result;
  }

  /// Bir öneri/plan gerekçesi cümlesi — Advisor ve PlanBuilder AYNI metni
  /// kullansın diye tek yerde.
  static String difficultyReason(String topicName, DifficultySignal signal) =>
      signal == DifficultySignal.repeated
          ? '"$topicName" konusunda üst üste zorlandığını söyledin'
          : 'Son çalışmanda "$topicName" konusunda zorlandığını söylemiştin';

  /// Öncelik sırası (en güçlüden en zayıfa), belirleyici:
  ///
  /// 1) [TopicEvidenceState.weakConfirmed] — bu konu GERÇEK bir denemede
  ///    hâlâ yanlış çıkıyor. Hiçbir şey bunu ezmez.
  /// 2) [TopicEvidenceState.strugglingRepeatedly] / [TopicEvidenceState
  ///    .struggling] — öğrenci bu konuyu çalışırken "zorlandım" dedi
  ///    (denemeden bağımsız, daha taze). Yalnız birbirini doğrulayan kanıtla
  ///    "üst üste" denir; tek cevap yalnız "son çalışmanda zorlandın"dır —
  ///    konuyu "zayıf" ilan etmez.
  /// 3) [TopicEvidenceState.improving] — bu konu ÖNCEKİ denemede zayıftı,
  ///    SON denemede artık değil.
  /// 4) [TopicEvidenceState.needsReview] — konu "tekrar edildi" işaretli ama
  ///    [staleReviewDays]+ gündür dokunulmamış. Salt zamana dayalı hatırlatma.
  /// 5) [TopicEvidenceState.none] — anlamlı bir kanıt yok, rozet YOK.
  static TopicEvidence classify({
    required bool isExamWeak,
    required bool isRecentlyResolved,
    DifficultySignal difficulty = DifficultySignal.none,
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
    if (difficulty == DifficultySignal.repeated) {
      return const TopicEvidence(
        TopicEvidenceState.strugglingRepeatedly,
        'Üst üste zorlandın',
      );
    }
    if (difficulty == DifficultySignal.recent) {
      return const TopicEvidence(
        TopicEvidenceState.struggling,
        'Son çalışmanda zorlandın',
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
