/// Koç'un offline doğal dil anlama (NLU) katmanının veri modelleri.
///
/// NLU YALNIZ "öğrenci ne diyor / ne istiyor?" sorusuna cevap verir; "ne
/// yapmalı?" sorusunu mevcut Dodom mantığı (StudyAdvisor, NextTaskPicker,
/// TopicEvidence) cevaplar — bkz. nlu_responder.dart.
library;

/// Öğrenci cümlesinin anlaşılan asıl niyeti.
enum CoachIntent {
  // --- "Bana bir şey öner / ayarla" ailesi -----------------------------
  needPlan,
  needRecommendation,
  needStartPoint,
  whatToDoNow,
  studySessionRequest,
  subjectGuidance,
  topicGuidance,
  timeConstraint,

  // --- "Bir sorunum var" ailesi ---------------------------------------
  strugglingSubject,
  strugglingTopic,
  questionPerformanceProblem,
  mockExamProblem,
  examUrgency,
  behindSchedule,
  tooMuchWork,
  lowProgress,
  lowMotivation,
  progressConcern,
  generalProblem,

  // --- Diğer -----------------------------------------------------------
  positiveProgress,
  thanks,
  confirmation,
  unknown;

  /// Mevcut Coach zincirinin (teşekkür/onay) zaten ele aldığı, NLU'nun
  /// cevap üretmediği niyetler.
  bool get isLegacyOwned =>
      this == CoachIntent.thanks ||
      this == CoachIntent.confirmation ||
      this == CoachIntent.unknown;

  /// Öğrencinin bir SORUN dile getirdiği niyetler — düşük güvende bile
  /// "anlamadım" yerine açıklayıcı bir soruyla karşılanır.
  bool get isProblem => switch (this) {
        CoachIntent.strugglingSubject ||
        CoachIntent.strugglingTopic ||
        CoachIntent.questionPerformanceProblem ||
        CoachIntent.mockExamProblem ||
        CoachIntent.examUrgency ||
        CoachIntent.behindSchedule ||
        CoachIntent.tooMuchWork ||
        CoachIntent.lowProgress ||
        CoachIntent.lowMotivation ||
        CoachIntent.progressConcern ||
        CoachIntent.generalProblem =>
          true,
        _ => false,
      };

  /// Birbirine yakın puan aldıklarında güveni DÜŞÜRMEYEN aile ("ne
  /// çalışayım" ile "nereden başlayayım" aynı cevabı doğurur).
  bool get isRecommendationFamily => switch (this) {
        CoachIntent.needRecommendation ||
        CoachIntent.needStartPoint ||
        CoachIntent.whatToDoNow ||
        CoachIntent.studySessionRequest ||
        CoachIntent.subjectGuidance ||
        CoachIntent.topicGuidance ||
        CoachIntent.timeConstraint =>
          true,
        _ => false,
      };

  /// Aynı cümlede birden çok niyet yarıştığında sıralama önceliği (küçük =
  /// önce). Sorun niyetleri istek niyetlerinden önce gelir: "Yarın deneme var,
  /// matematikte hiçbir şey bilmiyorum" → asıl niyet examUrgency.
  int get priority => switch (this) {
        CoachIntent.examUrgency => 0,
        CoachIntent.mockExamProblem => 1,
        CoachIntent.behindSchedule => 2,
        CoachIntent.tooMuchWork => 3,
        CoachIntent.strugglingTopic => 4,
        CoachIntent.strugglingSubject => 5,
        CoachIntent.questionPerformanceProblem => 6,
        CoachIntent.lowProgress => 7,
        CoachIntent.lowMotivation => 8,
        CoachIntent.progressConcern => 9,
        CoachIntent.needPlan => 10,
        CoachIntent.needStartPoint => 11,
        CoachIntent.studySessionRequest => 12,
        CoachIntent.whatToDoNow => 13,
        CoachIntent.needRecommendation => 14,
        CoachIntent.topicGuidance => 15,
        CoachIntent.subjectGuidance => 16,
        CoachIntent.timeConstraint => 17,
        CoachIntent.generalProblem => 18,
        CoachIntent.positiveProgress => 19,
        CoachIntent.thanks => 20,
        CoachIntent.confirmation => 21,
        CoachIntent.unknown => 22,
      };
}

enum NluConfidence { none, low, medium, high }

/// Duygu/durum ipucu.
enum NluState {
  none,
  tired,
  unmotivated,
  anxious,
  overwhelmed,
  frustrated,
  hopeless,
  positive,
}

/// Aciliyet: sınav/deneme ne kadar yakında?
enum NluUrgency { none, thisWeek, tomorrow, today }

/// Sözü edilen sınavın türü.
enum NluExamKind { none, mockExam, realExam, schoolExam }

/// Öğrencinin ne tür bir istekte bulunduğu (cümle biçiminden).
enum NluRequestType {
  none,
  plan,
  recommendation,
  startPoint,
  session,
  progress,
  help,
}

class NluSubjectMention {
  /// Kullanıcının kendi ders kaydının id'si; ders kullanıcıda yoksa null.
  final String? id;
  final String name;
  const NluSubjectMention({this.id, required this.name});

  @override
  String toString() => 'Subject($name${id == null ? '' : '#$id'})';
}

class NluTopicMention {
  /// Kullanıcının kendi konu kaydı varsa id'si; yalnız katalogda geçen bir
  /// konuysa null (id UYDURULMAZ).
  final String? id;
  final String name;
  final String? subjectId;
  final String? subjectName;
  const NluTopicMention({
    this.id,
    required this.name,
    this.subjectId,
    this.subjectName,
  });

  @override
  String toString() => 'Topic($name${id == null ? '' : '#$id'})';
}

/// Cümleden çıkarılan boşluklar (slot'lar). Hepsi isteğe bağlıdır.
class NluSlots {
  final NluSubjectMention? subject;
  final NluTopicMention? topic;
  final int? timeMinutes;

  /// [timeMinutes] bir SINIR değil HEDEF süre ("1 saat daha ekle" gibi bir
  /// düzeltmeden geldi): cevap görev tahmininin altına sıkıştırmaz.
  final bool timeIsTarget;
  final NluUrgency urgency;
  final NluState state;
  final NluExamKind exam;
  final NluRequestType request;

  const NluSlots({
    this.subject,
    this.topic,
    this.timeMinutes,
    this.timeIsTarget = false,
    this.urgency = NluUrgency.none,
    this.state = NluState.none,
    this.exam = NluExamKind.none,
    this.request = NluRequestType.none,
  });

  static const NluSlots empty = NluSlots();

  NluSlots copyWith({
    NluSubjectMention? subject,
    NluTopicMention? topic,
    NluRequestType? request,
    int? timeMinutes,
    bool? timeIsTarget,
  }) =>
      NluSlots(
        subject: subject ?? this.subject,
        topic: topic ?? this.topic,
        timeMinutes: timeMinutes ?? this.timeMinutes,
        timeIsTarget: timeIsTarget ?? this.timeIsTarget,
        urgency: urgency,
        state: state,
        exam: exam,
        request: request ?? this.request,
      );

  /// Ders adı: doğrudan sözü edilen ders, yoksa sözü edilen konunun dersi.
  String? get subjectName => subject?.name ?? topic?.subjectName;
  String? get subjectId => subject?.id ?? topic?.subjectId;

  @override
  String toString() =>
      'Slots(subject: $subject, topic: $topic, time: $timeMinutes, '
      'urgency: $urgency, state: $state, exam: $exam, request: $request)';
}

/// Bir niyet adayının puanı ve onu destekleyen kanıt.
class NluCandidate {
  final CoachIntent intent;
  final double score;
  final double phraseScore;
  final double ruleScore;
  final String? matchedPhrase;
  final List<String> signals;

  const NluCandidate({
    required this.intent,
    required this.score,
    this.phraseScore = 0,
    this.ruleScore = 0,
    this.matchedPhrase,
    this.signals = const [],
  });

  @override
  String toString() => '${intent.name}:${score.toStringAsFixed(2)}';
}

class NluResult {
  final String raw;
  final String normalized;
  final CoachIntent intent;
  final NluConfidence confidence;
  final double score;

  /// Asıl niyetin dışında da geçerli sayılan niyetler (bileşik cümle).
  final List<CoachIntent> secondary;
  final NluSlots slots;
  final List<NluCandidate> candidates;

  /// Cümlede bilinen (çalışma sözlüğünde geçen) içerik jetonlarının oranı —
  /// 0'a yakınsa cümle büyük olasılıkla anlamsızdır ("asdfgh").
  final double knownTokenRatio;

  const NluResult({
    required this.raw,
    required this.normalized,
    required this.intent,
    required this.confidence,
    required this.score,
    required this.secondary,
    required this.slots,
    required this.candidates,
    required this.knownTokenRatio,
  });

  /// Aynı sonuç, başka niyet/slot'larla (düzeltme sonrası yeniden cevap için).
  NluResult copyWith({CoachIntent? intent, NluSlots? slots}) => NluResult(
        raw: raw,
        normalized: normalized,
        intent: intent ?? this.intent,
        confidence: confidence,
        score: score,
        secondary: secondary,
        slots: slots ?? this.slots,
        candidates: candidates,
        knownTokenRatio: knownTokenRatio,
      );

  bool get isConfident =>
      confidence == NluConfidence.high || confidence == NluConfidence.medium;

  bool get isUnknown => intent == CoachIntent.unknown;

  @override
  String toString() =>
      'NluResult(${intent.name}, ${confidence.name} ${score.toStringAsFixed(2)}'
      '${secondary.isEmpty ? '' : ', +${secondary.map((e) => e.name).join('/')}'}'
      ', $slots)';
}
