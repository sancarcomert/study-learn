import 'dart:math' as math;

import 'nlu_entities.dart';
import 'nlu_models.dart';
import 'nlu_phrase_matcher.dart';
import 'nlu_rules.dart';
import 'nlu_slots.dart';
import 'tr_text.dart';

/// Koç'un offline doğal dil anlama çekirdeği (LLM/ağ/ML YOK, tamamen
/// deterministik ve test edilebilir).
///
/// Boru hattı:
///   ham metin → normalize (TrText) → ders/konu/süre maskeleme →
///   kalıp sözlüğü benzerliği + kural sinyalleri → niyet puanları →
///   asıl niyet + ikincil niyetler → slot'lar → güven (HIGH/MEDIUM/LOW/NONE)
///
/// NLU YALNIZ "öğrenci ne diyor?" sorusunu yanıtlar. "Ne yapmalı?" sorusu
/// nlu_responder.dart'ta mevcut StudyAdvisor/NextTaskPicker/TopicEvidence
/// verisiyle cevaplanır.
class CoachNlu {
  const CoachNlu._();

  /// Eşik puanları (bkz. [_levelOf]).
  static const double highThreshold = 0.8;
  static const double mediumThreshold = 0.6;
  static const double lowThreshold = 0.35;

  /// "bu konu / bu ders" gibi işaret sözcüğü — önceki mesajdaki ders/konuya
  /// bağlanır (bağlam sürekliliği).
  static final RegExp _deictic =
      RegExp(r'\b(bu|su|o) (konu|ders)\w*|\borasi\w*|\bburasi\w*');

  static final RegExp _affirmWork =
      RegExp(r'\b(calistim|calisiyorum|calisirim|calistik)\b');
  static final RegExp _negFeeling =
      RegExp(r'\b(yorgun|bitkin|isteksiz|halsiz|sikkin|bikkin)\w* degil');
  static final RegExp _negWork =
      RegExp(r'\b(calisamad|calismad|calisamiy|calismiy|calisamam|hic)\w*');

  static NluResult analyze(
    String raw, {
    NluEntityIndex? index,
    NluSlots? previous,
  }) {
    final p = NluPrepared.of(raw, index ?? NluEntityIndex.fixed);
    final matcher = NluPhraseMatcher.instance;

    if (p.folded.isEmpty) {
      return NluResult(
        raw: raw,
        normalized: '',
        intent: CoachIntent.unknown,
        confidence: NluConfidence.none,
        score: 0,
        secondary: const [],
        slots: NluSlots.empty,
        candidates: const [],
        knownTokenRatio: 0,
      );
    }

    final time = NluSlotExtractor.minutes(raw);
    var subject = p.entities.subject;
    var topic = p.entities.topic;
    if (subject == null &&
        topic == null &&
        previous != null &&
        _deictic.hasMatch(p.folded)) {
      subject = previous.subject;
      topic = previous.topic;
    }

    var slots = NluSlots(
      subject: subject,
      topic: topic,
      timeMinutes: time,
      urgency: NluSlotExtractor.urgency(p.folded),
      state: NluSlotExtractor.state(p.folded),
      exam: NluSlotExtractor.exam(p.folded),
    );

    final ruleCtx = NluRuleContext(p, slots, time);
    final phraseHits = matcher.match(p.contentTokens);
    final known = matcher.knownRatio(p.contentTokens);

    final affirmsWork =
        _affirmWork.hasMatch(p.folded) && !_negWork.hasMatch(p.folded);

    final candidates = <NluCandidate>[];
    for (final intent in CoachIntent.values) {
      if (intent == CoachIntent.unknown) continue;
      final rule = evaluateRules(intent, ruleCtx);
      var phrase = phraseHits[intent]?.score ?? 0.0;
      // "çalıştım" ile "çalışamadım" aynı kökü paylaşır; olumlu ifadeyi
      // olumsuz niyetlere sayma.
      if (affirmsWork &&
          (intent == CoachIntent.lowProgress ||
              intent == CoachIntent.lowMotivation)) {
        phrase *= 0.4;
      }
      var ruleScore = rule.score;
      if (intent == CoachIntent.lowMotivation &&
          _negFeeling.hasMatch(p.folded)) {
        phrase *= 0.3;
        ruleScore *= 0.3;
      }
      var score = math.max(ruleScore, 0.92 * phrase) +
          0.1 * math.min(ruleScore, phrase);
      if (intent == CoachIntent.generalProblem) score = math.min(score, 0.58);
      // "Denemede matematik yapamıyorum": deneme bağlamı zorlanmayı deneme
      // sorununa çevirir.
      if (slots.exam == NluExamKind.mockExam &&
          (intent == CoachIntent.strugglingSubject ||
              intent == CoachIntent.strugglingTopic)) {
        score *= 0.92;
      }
      score = score.clamp(0.0, 1.0);
      if (score <= 0) continue;
      candidates.add(NluCandidate(
        intent: intent,
        score: score,
        phraseScore: phrase,
        ruleScore: ruleScore,
        matchedPhrase: phraseHits[intent]?.phrase,
        signals: rule.signals,
      ));
    }
    candidates.sort((a, b) => b.score.compareTo(a.score));

    if (candidates.isEmpty || candidates.first.score < lowThreshold) {
      return NluResult(
        raw: raw,
        normalized: p.folded,
        intent: CoachIntent.unknown,
        confidence: NluConfidence.none,
        score: candidates.isEmpty ? 0 : candidates.first.score,
        secondary: const [],
        slots: slots,
        candidates: candidates,
        knownTokenRatio: known,
      );
    }

    // Asıl niyet: en yüksek puana çok yakın olanlar arasında ÖNCELİĞİ en
    // yüksek (sorun > istek) olan.
    final top = candidates.first;
    final pool = candidates.where((c) => c.score >= top.score - 0.06).toList()
      ..sort((a, b) {
        final byPriority = a.intent.priority.compareTo(b.intent.priority);
        return byPriority != 0 ? byPriority : b.score.compareTo(a.score);
      });
    var primary = pool.first;

    // Ders/konu slot'una göre incelt.
    var intent = primary.intent;
    if (intent == CoachIntent.strugglingSubject && slots.topic != null) {
      intent = CoachIntent.strugglingTopic;
    } else if (intent == CoachIntent.strugglingTopic && slots.topic == null) {
      intent = CoachIntent.strugglingSubject;
    } else if (intent == CoachIntent.subjectGuidance && slots.topic != null) {
      intent = CoachIntent.topicGuidance;
    } else if (intent == CoachIntent.topicGuidance &&
        slots.topic == null &&
        slots.subject != null) {
      intent = CoachIntent.subjectGuidance;
    }

    var confidence = _levelOf(primary.score);
    // Sözcüklerinin çoğu tanınmayan, zayıf eşleşmeli cümle ("asdfgh neyse
    // boşver") bir niyete ZORLANMAZ.
    if (known < 0.4 && confidence == NluConfidence.low) {
      return NluResult(
        raw: raw,
        normalized: p.folded,
        intent: CoachIntent.unknown,
        confidence: NluConfidence.none,
        score: primary.score,
        secondary: const [],
        slots: slots,
        candidates: candidates,
        knownTokenRatio: known,
      );
    }

    // Rakip: farklı SINIFTAN (sorun ↔ istek ↔ diğer) yakın bir aday güveni
    // düşürür. Aynı sınıftaki adaylar (ör. "ne çalışayım" ↔ "nereden
    // başlayayım") birbirini desteklediği için düşürmez.
    for (final c in candidates) {
      if (c.intent == primary.intent) continue;
      if (_classOf(c.intent) == _classOf(primary.intent)) continue;
      if (primary.score < 0.85 &&
          c.score >= 0.5 &&
          primary.score - c.score < 0.08) {
        confidence = _down(confidence);
        break;
      }
    }
    // İki bağımsız kanıt (kalıp + kural) da güçlüyse güven artar.
    if (primary.phraseScore >= 0.6 &&
        primary.ruleScore >= 0.6 &&
        confidence == NluConfidence.medium) {
      confidence = NluConfidence.high;
    }
    // Bilinmeyen kelimelerle dolu cümlede kesinlik iddia etme.
    if (known < 0.34 && confidence == NluConfidence.high) {
      confidence = NluConfidence.medium;
    }
    if (known < 0.2 && confidence == NluConfidence.medium) {
      confidence = NluConfidence.low;
    }

    final secondary = <CoachIntent>[
      for (final c in candidates)
        if (c.intent != primary.intent &&
            c.score >= 0.7 &&
            (c.ruleScore >= 0.6 || c.phraseScore >= 0.8) &&
            c.intent != CoachIntent.generalProblem)
          c.intent,
    ];

    slots = slots.copyWith(request: _requestOf(intent));

    return NluResult(
      raw: raw,
      normalized: p.folded,
      intent: intent,
      confidence: confidence,
      score: primary.score,
      secondary: secondary,
      slots: slots,
      candidates: candidates,
      knownTokenRatio: known,
    );
  }

  static NluConfidence _levelOf(double s) {
    if (s >= highThreshold) return NluConfidence.high;
    if (s >= mediumThreshold) return NluConfidence.medium;
    if (s >= lowThreshold) return NluConfidence.low;
    return NluConfidence.none;
  }

  static NluConfidence _down(NluConfidence c) => switch (c) {
        NluConfidence.high => NluConfidence.medium,
        NluConfidence.medium => NluConfidence.low,
        _ => c,
      };

  static int _classOf(CoachIntent i) {
    if (i.isProblem) return 0;
    if (i.isRecommendationFamily || i == CoachIntent.needPlan) return 1;
    return 2;
  }

  static NluRequestType _requestOf(CoachIntent i) => switch (i) {
        CoachIntent.needPlan => NluRequestType.plan,
        CoachIntent.needRecommendation ||
        CoachIntent.whatToDoNow ||
        CoachIntent.subjectGuidance ||
        CoachIntent.topicGuidance ||
        CoachIntent.timeConstraint =>
          NluRequestType.recommendation,
        CoachIntent.needStartPoint => NluRequestType.startPoint,
        CoachIntent.studySessionRequest => NluRequestType.session,
        CoachIntent.progressConcern => NluRequestType.progress,
        _ when i.isProblem => NluRequestType.help,
        _ => NluRequestType.none,
      };

  /// Sözlük + katalog dizinlerini önceden kurar (ilk mesajda ~150 ms takılma
  /// olmasın diye Coach açılırken çağrılır).
  static void warmUp() {
    NluEntityIndex.fixed;
    NluPhraseMatcher.instance;
  }

  /// Kelime dağarcığı istatistiği — testler/rapor için.
  static int get phraseCount => NluPhraseMatcher.instance.phraseCount;
  static int get intentCount => CoachIntent.values.length;

  /// Katlanmış metin (dış kullanım kolaylığı).
  static String normalize(String raw) => TrText.fold(raw);
}
