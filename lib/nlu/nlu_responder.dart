import '../format_minutes.dart';
import '../next_task_picker.dart';
import '../study_advisor.dart';
import '../study_intent.dart';
import '../subject_model.dart';
import '../task_model.dart';
import '../topic_evidence.dart';
import '../topic_model.dart';
import 'nlu_context.dart';
import 'nlu_models.dart';

enum NluActionKind {
  /// Focus'u (ders/konu/süre dolu) hemen başlat — Coach'un "Başla" düğmesi.
  startFocus,

  /// Dersin konu listesine git.
  openTopics,

  /// Coach'un mevcut günlük/haftalık plan akışını (PlanBuilder) devral.
  planDay,
}

class NluAction {
  final NluActionKind kind;
  final String label;
  final StudyIntent? intent;
  final String? subjectId;
  final String? subjectName;
  final int? minutes;
  final bool week;

  const NluAction.start(StudyIntent this.intent)
      : kind = NluActionKind.startFocus,
        label = 'Başla',
        subjectId = null,
        subjectName = null,
        minutes = null,
        week = false;

  const NluAction.openTopics(String this.subjectId, String this.subjectName)
      : kind = NluActionKind.openTopics,
        label = 'Konuya git',
        intent = null,
        minutes = null,
        week = false;

  const NluAction.plan({this.minutes, this.week = false})
      : kind = NluActionKind.planDay,
        label = 'Planı aç',
        intent = null,
        subjectId = null,
        subjectName = null;
}

class NluReply {
  /// Koç'un söyleyeceği cümle(ler). [NluActionKind.planDay] için boş olabilir.
  final String text;
  final NluAction? action;

  /// Cevabın hangi gerçek veriye dayandığı (`task`, `topicEvidence`,
  /// `advisor`, `overdue`, `today`, `deneme`, `none`…) — test ve hata ayıklama.
  final String source;

  const NluReply(this.text, {this.action, this.source = 'none'});
}

class _Pick {
  final SubjectModel? subject;
  final String? subjectName;
  final TopicModel? topic;
  final TaskModel? task;
  final StudySuggestion? suggestion;
  final String? reason;
  final String source;

  const _Pick({
    this.subject,
    this.subjectName,
    this.topic,
    this.task,
    this.suggestion,
    this.reason,
    required this.source,
  });

  String get label {
    if (task != null) return task!.title;
    final s = subject?.name ?? subjectName;
    final t = topic?.name;
    if (t != null && s != null) return '$s · $t';
    return t ?? s ?? '';
  }
}

/// NLU sonucunu MEVCUT Dodom mantığıyla eyleme çevirir: bugünkü plan
/// (NextTaskPicker), konu kanıtı (TopicEvidence), StudyAdvisor önerisi ve
/// ölçülmüş çalışma. Sabit/uydurma veri YOK — veri yoksa bunu söyler.
class NluResponder {
  const NluResponder._();

  /// Kısa "küçük adım" süresi (motivasyon/çalışamadım/az vakit durumlarında).
  static const int smallStepMinutes = 15;

  /// Bu niyet için cevap üretir; NLU'nun sahip olmadığı niyetlerde null
  /// (mevcut Coach zinciri devralır).
  static NluReply? reply(NluResult r, NluContext c) {
    final slots = r.slots;
    switch (r.intent) {
      case CoachIntent.needPlan:
        return NluReply(
          '',
          action: NluAction.plan(
            minutes: slots.timeMinutes,
            week: RegExp(r'\bhafta\w*|\b7 gun\b').hasMatch(r.normalized),
          ),
          source: 'plan',
        );
      case CoachIntent.needRecommendation:
      case CoachIntent.whatToDoNow:
      case CoachIntent.needStartPoint:
      case CoachIntent.studySessionRequest:
      case CoachIntent.subjectGuidance:
      case CoachIntent.topicGuidance:
      case CoachIntent.timeConstraint:
        return _recommend(r, c);
      case CoachIntent.strugglingSubject:
      case CoachIntent.strugglingTopic:
        return _struggle(r, c);
      case CoachIntent.questionPerformanceProblem:
        return _questions(r, c);
      case CoachIntent.mockExamProblem:
        return _mockExam(r, c);
      case CoachIntent.examUrgency:
        return _examUrgency(r, c);
      case CoachIntent.behindSchedule:
        return _behind(r, c);
      case CoachIntent.tooMuchWork:
        return _tooMuch(r, c);
      case CoachIntent.lowProgress:
        return _lowProgress(r, c);
      case CoachIntent.lowMotivation:
        return _lowMotivation(r, c);
      case CoachIntent.progressConcern:
        return _progress(r, c);
      case CoachIntent.positiveProgress:
        return _positive(r, c);
      case CoachIntent.generalProblem:
        return NluReply(clarify(r), source: 'none');
      case CoachIntent.thanks:
      case CoachIntent.confirmation:
      case CoachIntent.unknown:
        return null;
    }
  }

  /// Düşük güvenli ya da anlaşılamayan cümle için "biraz daha açık yaz" yönlendirmesi
  /// — kesin konuşmaz, yanlış niyete zorlamaz.
  static String clarify(NluResult r) {
    const examples =
        '"matematikte zorlanıyorum", "bugün 30 dakikam var ne çalışayım" '
        'ya da "planımda geride kaldım"';
    return 'Tam oturtamadım ama yardımcı olmak isterim. Biraz açar mısın — '
        'hangi ders/konu, ne oluyor ya da ne istiyorsun? Örneğin: $examples.';
  }

  // ======================================================================
  // Ortak yardımcılar
  // ======================================================================

  static int _rank(TopicEvidence? e) => switch (e?.state) {
        TopicEvidenceState.weakConfirmed => 0,
        TopicEvidenceState.strugglingRepeatedly => 1,
        TopicEvidenceState.struggling => 2,
        TopicEvidenceState.needsReview => 3,
        _ => 9,
      };

  static DateTime _today(NluContext c) =>
      DateTime(c.now.year, c.now.month, c.now.day);

  static String _sentence(String s) {
    final t = s.trim();
    if (t.isEmpty) return t;
    return t.endsWith('.') || t.endsWith('!') || t.endsWith('?') ? t : '$t.';
  }

  /// Bugünün bekleyen görevleri, ÖNERİLEN SIRAYLA (Home ile aynı motor).
  static List<TaskModel> _pendingToday(NluContext c) =>
      NextTaskPicker.remaining(c.tasks, c.now, evidenceByTopic: c.evidence);

  /// Vadesi geçmiş, tamamlanmamış görevler — kanıt > öncelik > en eski.
  static List<TaskModel> _overdue(NluContext c, {String? subjectId}) {
    final today = _today(c);
    final list = c.tasks
        .where((t) =>
            !t.isCompleted &&
            DateTime(t.dueDate.year, t.dueDate.month, t.dueDate.day)
                .isBefore(today) &&
            (subjectId == null || t.subjectId == subjectId))
        .toList();
    int pr(TaskPriority p) => switch (p) {
          TaskPriority.high => 0,
          TaskPriority.medium => 1,
          TaskPriority.low => 2,
        };
    list.sort((a, b) {
      final ra = NextTaskPicker.strongEvidenceRank(
          a.topicId == null ? null : c.evidence[a.topicId]);
      final rb = NextTaskPicker.strongEvidenceRank(
          b.topicId == null ? null : c.evidence[b.topicId]);
      if (ra != rb) return ra.compareTo(rb);
      final byPr = pr(a.priority).compareTo(pr(b.priority));
      if (byPr != 0) return byPr;
      return a.dueDate.compareTo(b.dueDate);
    });
    return list;
  }

  /// Dersin konuları içinde kanıtı en güçlü olan (deneme > üst üste zorlanma >
  /// zorlanma > tekrar zamanı). Kanıtı olan konu yoksa null.
  static TopicModel? _weakestTopic(NluContext c, String subjectId,
      {int maxRank = 3}) {
    TopicModel? best;
    var bestRank = 99;
    for (final t in c.topics) {
      if (t.subjectId != subjectId) continue;
      final rk = _rank(c.evidence[t.id]);
      if (rk <= maxRank && rk < bestRank) {
        best = t;
        bestRank = rk;
      }
    }
    return best;
  }

  /// Tüm derslerdeki kanıtlı konular (güçlüden zayıfa), en çok [maxRank].
  static List<TopicModel> _weakTopics(NluContext c,
      {String? subjectId, int maxRank = 2}) {
    final list = c.topics
        .where((t) =>
            (subjectId == null || t.subjectId == subjectId) &&
            _rank(c.evidence[t.id]) <= maxRank)
        .toList();
    list.sort(
        (a, b) => _rank(c.evidence[a.id]).compareTo(_rank(c.evidence[b.id])));
    return list;
  }

  static TopicModel? _firstUnstarted(NluContext c, String subjectId) {
    for (final t in c.topics) {
      if (t.subjectId == subjectId && t.status == TopicStatus.notStarted) {
        return t;
      }
    }
    return null;
  }

  static _Pick _taskPick(NluContext c, TaskModel t) {
    final intent = c.taskIntent(t);
    return _Pick(
      subject: c.subjectById(t.subjectId),
      topic: c.topicById(t.topicId),
      task: t,
      reason: intent.reason,
      source: 'task',
    );
  }

  static _Pick _topicPick(NluContext c, TopicModel t, {String? source}) {
    final sentence = c.evidence[t.id]?.sentence;
    return _Pick(
      subject: c.subjectById(t.subjectId),
      topic: t,
      reason: sentence,
      source: source ?? (sentence != null ? 'topicEvidence' : 'topic'),
    );
  }

  /// Slot'lara + gerçek veriye göre "şimdi ne çalışmalı?" seçimi.
  /// [preferEvidence]: sorun cümlelerinde ("zorlanıyorum") kanıtlı konu,
  /// bugünkü göreve önceliklidir.
  static _Pick? _pick(NluResult r, NluContext c,
      {bool preferEvidence = false, bool useAdvisor = true}) {
    final s = r.slots;
    final pending = _pendingToday(c);

    // Kullanıcının kendi konusu anıldı.
    final topicId = s.topic?.id;
    if (topicId != null) {
      final t = c.topicById(topicId);
      if (t != null) {
        for (final task in pending) {
          if (task.topicId == t.id) return _taskPick(c, task);
        }
        return _topicPick(c, t);
      }
    }

    final subjectId = s.subjectId;
    if (subjectId != null) {
      final subject = c.subjectById(subjectId);
      if (subject != null) {
        _Pick? taskPick() {
          for (final task in pending) {
            if (task.subjectId == subjectId) return _taskPick(c, task);
          }
          return null;
        }

        _Pick? weakPick() {
          final w = _weakestTopic(c, subjectId);
          return w == null ? null : _topicPick(c, w);
        }

        final first = preferEvidence
            ? (weakPick() ?? taskPick())
            : (taskPick() ?? weakPick());
        if (first != null) return first;

        for (final sug
            in useAdvisor ? c.suggestions : const <StudySuggestion>[]) {
          if (sug.subjectId == subjectId) {
            return _Pick(
              subject: subject,
              topic: sug.topicName == null
                  ? null
                  : c.topics
                      .where((t) =>
                          t.subjectId == subjectId && t.name == sug.topicName)
                      .firstOrNull,
              suggestion: sug,
              reason:
                  sug.reason == StudyAdvisor.genericReason ? null : sug.reason,
              source: 'advisor',
            );
          }
        }
        final fresh = _firstUnstarted(c, subjectId);
        if (fresh != null) return _topicPick(c, fresh, source: 'topic');
        return _Pick(subject: subject, source: 'subject');
      }
    }
    // Ders anıldı ama kullanıcının dersleri arasında yok.
    if (s.subjectName != null) {
      return _Pick(subjectName: s.subjectName, source: 'unknownSubject');
    }

    // Ders yok: bugünün sıradaki görevi → kanıtlı konu → advisor.
    final next =
        NextTaskPicker.pick(c.tasks, c.now, evidenceByTopic: c.evidence);
    final weak = _weakTopics(c, maxRank: 1);
    if (preferEvidence && weak.isNotEmpty) {
      return _topicPick(c, weak.first);
    }
    if (next != null) return _taskPick(c, next);
    if (weak.isNotEmpty) return _topicPick(c, weak.first);
    if (useAdvisor && c.suggestions.isNotEmpty) {
      final sug = c.suggestions.first;
      return _Pick(
        subject: c.subjectById(sug.subjectId),
        topic: sug.topicName == null
            ? null
            : c.topics
                .where((t) =>
                    t.subjectId == sug.subjectId && t.name == sug.topicName)
                .firstOrNull,
        suggestion: sug,
        reason: sug.reason == StudyAdvisor.genericReason ? null : sug.reason,
        source: 'advisor',
      );
    }
    return null;
  }

  static int _minutes(NluResult r, _Pick? p, {int? fallback, int? cap}) {
    final asked = r.slots.timeMinutes;
    final planned = p?.task?.estimatedMinutes;
    // Düzeltme ("1 saat daha ekle") süreyi HEDEF yapar; kısıt ("30 dk var")
    // ise üst sınırdır.
    if (asked != null && r.slots.timeIsTarget) return asked.clamp(5, 240);
    int m;
    if (asked != null && planned != null) {
      m = asked < planned ? asked : planned;
    } else {
      m = asked ?? planned ?? fallback ?? kDefaultFocusMinutes;
    }
    // "Küçük adım" durumlarında (motivasyon, çalışamadım) öğrenci açıkça süre
    // vermediyse görev tahmini ne kadar büyük olursa olsun kısa tutulur.
    if (cap != null && asked == null && m > cap) m = cap;
    return m.clamp(5, 240);
  }

  static StudyIntent _withMinutes(StudyIntent i, int minutes) => StudyIntent(
        source: i.source,
        subjectId: i.subjectId,
        topicId: i.topicId,
        taskId: i.taskId,
        title: i.title,
        targetMinutes: minutes,
        reason: i.reason,
      );

  static StudyIntent _intentFor(NluContext c, _Pick p, int minutes) {
    if (p.task != null) return _withMinutes(c.taskIntent(p.task!), minutes);
    if (p.suggestion != null) {
      final base = c.suggestionIntent(p.suggestion!);
      return _withMinutes(base, minutes);
    }
    if (p.topic != null) {
      return _withMinutes(
          StudyIntent.forTopic(p.topic!, reason: p.reason), minutes);
    }
    return StudyIntent(
      source: StudyIntentSource.free,
      subjectId: p.subject?.id,
      targetMinutes: minutes,
    );
  }

  /// Bir seçimden eylem: Focus başlat; hiçbir şey seçilemiyorsa null.
  static NluAction? _startAction(NluContext c, _Pick? p, int minutes) {
    if (p == null) return null;
    if (p.source == 'unknownSubject') return null;
    return NluAction.start(_intentFor(c, p, minutes));
  }

  static String _reasonTail(_Pick p) =>
      p.reason == null ? '' : ' ${_sentence(p.reason!)}';

  /// Seçimi "ne + neden + ne kadar" cümlesine çevirir.
  static String _describe(_Pick p, int minutes, {String? ending}) {
    final end = ending == null ? '' : ' $ending';
    switch (p.source) {
      case 'task':
        return 'Bugünkü planında "${p.task!.title}" var '
            '(${formatMinutes(minutes)}).${_reasonTail(p)}$end';
      case 'topicEvidence':
        return '${p.label} — ${_sentence(p.reason ?? '')} '
                '${formatMinutes(minutes)} ile başlayalım.$end'
            .replaceAll('  ', ' ');
      case 'advisor':
        final head = p.topic != null ? p.label : (p.subject?.name ?? '');
        return '$head — ${_sentence(p.reason ?? StudyAdvisor.genericReason)} '
                '${formatMinutes(minutes)} ile başlayalım.$end'
            .replaceAll('  ', ' ');
      case 'topic':
        return '${p.label} konusundan başlayabilirsin (henüz başlamadığın '
            'konulardan ilki). ${formatMinutes(minutes)} yeter.$end';
      case 'subject':
        return '${p.subject!.name} için ${formatMinutes(minutes)}lık serbest '
            'bir blok açabiliriz.$end';
      default:
        return p.label;
    }
  }

  static NluReply _noData(NluContext c) {
    if (c.subjects.isEmpty) {
      return const NluReply(
          'Önce en az bir ders eklemen lazım — Profil → Derslerim\'den '
          'ekleyip geri gelebilirsin.',
          source: 'none');
    }
    return const NluReply(
        'Şu an önerecek somut bir kayıt yok: bugüne görev, konu ya da deneme '
        'eklersen sana veriye dayalı bir sıra çıkarabilirim. İstersen "sen '
        'ayarla" de, günü ben kurayım.',
        source: 'none');
  }

  static NluReply _unknownSubject(_Pick p) => NluReply(
      '${p.subjectName} derslerin arasında görünmüyor — Profil → '
      'Derslerim\'den ekleyebilirsin, sonra ona göre öneri çıkarırım.',
      source: 'unknownSubject');

  /// Konu listesi/kanıtı olmayan dersler için: konu listesini aç.
  static NluReply _subjectOnly(_Pick p, int minutes, NluContext c,
      {String? lead}) {
    final s = p.subject!;
    final hasTopics = c.topics.any((t) => t.subjectId == s.id);
    if (!hasTopics) {
      return NluReply(
        '${lead == null ? '' : '$lead '}${s.name} için henüz konu '
        'eklemedin. Konu listesini açıp çalıştıklarını işaretlersen sana '
        'konu bazlı önerebilirim; şimdilik ${formatMinutes(minutes)}lık '
        'serbest bir blok başlatabiliriz.',
        action: NluAction.openTopics(s.id, s.name),
        source: 'subject',
      );
    }
    return NluReply(
      '${lead == null ? '' : '$lead '}${s.name} için şu an öne çıkan bir '
      'işaret yok. ${formatMinutes(minutes)}lık serbest bir blokla '
      'başlayalım.',
      action: NluAction.start(StudyIntent(
        source: StudyIntentSource.free,
        subjectId: s.id,
        targetMinutes: minutes,
      )),
      source: 'subject',
    );
  }

  // ======================================================================
  // İstek aileleri
  // ======================================================================

  static NluReply _recommend(NluResult r, NluContext c) {
    final s = r.slots;
    final askedTime = s.timeMinutes;
    final isTimeIntent = r.intent == CoachIntent.timeConstraint ||
        r.secondary.contains(CoachIntent.timeConstraint);

    // Süre kısıtı + ders belirtilmemiş + bugün planı var → planı DARALT.
    if (isTimeIntent && s.subjectId == null && s.subjectName == null) {
      final pending = _pendingToday(c);
      if (pending.isNotEmpty) return _narrowPlan(r, c, pending, askedTime);
    }

    final pick = _pick(r, c);
    if (pick == null) return _noData(c);
    if (pick.source == 'unknownSubject') return _unknownSubject(pick);

    final shortOnly = isTimeIntent && askedTime == null;
    final minutes = _minutes(r, pick,
        fallback: shortOnly ? smallStepMinutes : null,
        cap: shortOnly ? smallStepMinutes : null);
    if (pick.source == 'subject') return _subjectOnly(pick, minutes, c);

    final ending = switch (r.intent) {
      CoachIntent.whatToDoNow => 'Şimdi bununla başla.',
      CoachIntent.needStartPoint => 'Buradan başlayabilirsin.',
      CoachIntent.studySessionRequest => 'Hazırsan sayacı başlatıyorum.',
      _ => null,
    };
    var text = _describe(pick, minutes, ending: ending);
    if (askedTime != null &&
        pick.task?.estimatedMinutes != null &&
        askedTime < pick.task!.estimatedMinutes!) {
      text += ' Vaktin ${formatMinutes(askedTime)} olduğu için ilk '
          '${formatMinutes(askedTime)}\'lık kısmını hedefleyelim.';
    }
    return NluReply(text,
        action: _startAction(c, pick, minutes), source: pick.source);
  }

  /// "30 dakikam var" → bugünkü plandan sığanları seç, kalanı yarına bırak.
  static NluReply _narrowPlan(
      NluResult r, NluContext c, List<TaskModel> pending, int? askedTime) {
    final budget = askedTime ?? smallStepMinutes;
    final chosen = <TaskModel>[];
    var used = 0;
    for (final t in pending) {
      final est = t.estimatedMinutes ?? kDefaultFocusMinutes;
      if (chosen.isEmpty || used + est <= budget) {
        chosen.add(t);
        used += chosen.length == 1 && est > budget ? budget : est;
      }
    }
    final first = chosen.first;
    final firstMinutes = _minutes(r, _taskPick(c, first),
        fallback: askedTime == null ? smallStepMinutes : null,
        cap: askedTime == null ? smallStepMinutes : null);
    final leftover = pending.length - chosen.length;
    final titles = chosen.map((t) => '"${t.title}"').join(' + ');
    final buf = StringBuffer(
        '${formatMinutes(budget)}\'ya göre bugünkü planını daralttım: '
        '$titles (${formatMinutes(used)}).');
    if (leftover > 0) {
      buf.write(' Kalan $leftover görev yarına ya da daha müsait bir '
          'zamana kalabilir.');
    }
    return NluReply(
      buf.toString(),
      action: NluAction.start(_withMinutes(c.taskIntent(first), firstMinutes)),
      source: 'today',
    );
  }

  // ======================================================================
  // Sorun aileleri
  // ======================================================================

  static NluReply _struggle(NluResult r, NluContext c) {
    final s = r.slots;
    final pick = _pick(r, c, preferEvidence: true, useAdvisor: false);
    if (pick == null) return _noData(c);
    if (pick.source == 'unknownSubject') return _unknownSubject(pick);

    final minutes = _minutes(r, pick);
    final lead = s.topic != null
        ? '${s.topic!.name} birçok kişinin takıldığı yer.'
        : (s.subjectName != null
            ? '${s.subjectName} zor gelebilir, yalnız değilsin.'
            : 'Hangi ders/konuda zorlandığını yazarsan daha net söylerim; '
                'şimdilik kayıtlarına göre:');

    if (pick.source == 'subject') {
      return _subjectOnly(pick, minutes, c, lead: lead);
    }

    final String body;
    if (pick.reason != null) {
      body = _describe(pick, minutes);
    } else {
      body = 'Kayıtlarında burada zorlandığına dair henüz bir işaret yok; '
          '${pick.label} ile ${formatMinutes(minutes)}lık kısa bir '
          'başlangıç yapalım. Sonunda "zorlandım" dersen bunu not alırım.';
    }
    return NluReply('$lead $body',
        action: _startAction(c, pick, minutes), source: pick.source);
  }

  static NluReply _questions(NluResult r, NluContext c) {
    final pick = _pick(r, c, preferEvidence: true, useAdvisor: false);
    if (pick == null) return _noData(c);
    if (pick.source == 'unknownSubject') return _unknownSubject(pick);
    final minutes = _minutes(r, pick);
    if (pick.source == 'subject') return _subjectOnly(pick, minutes, c);
    return NluReply(
      'Yanlışlar genelde aynı yerde yığılır. Önce ${pick.label} için kısa bir '
      'tekrar bloğu açalım (${formatMinutes(minutes)}).${_reasonTail(pick)} '
      'Soruları kendi kaynağınla çözersin; süreyi ve takibi ben tutarım.',
      action: _startAction(c, pick, minutes),
      source: pick.source,
    );
  }

  static NluReply _mockExam(NluResult r, NluContext c) {
    final s = r.slots;
    final weakest = s.subjectName ?? c.weakestDenemeSubjectName;
    final weakTopics = _weakTopics(c,
        subjectId: s.subjectId, maxRank: 0); // yalnız deneme kanıtı
    final hasDeneme = c.weakestDenemeSubjectName != null ||
        weakTopics.isNotEmpty ||
        c.goalGapSentence != null;
    if (!hasDeneme) {
      return const NluReply(
          'Henüz deneme kaydın yok. Sonuçlarını Deneme Takip\'e girersen '
          'hangi derste/konuda net kaybettiğini görüp çalışmayı ona göre '
          'planlayabilirim.',
          source: 'none');
    }
    final buf = StringBuffer();
    if (weakest != null) {
      buf.write(s.subjectName != null
          ? '$weakest denemesinde takıldığını görüyorum.'
          : 'Denemelerinde en çok net kaybettiğin ders $weakest.');
    }
    if (c.goalGapSentence != null) buf.write(' ${c.goalGapSentence}');
    NluAction? action;
    if (weakTopics.isNotEmpty) {
      final t = weakTopics.first;
      final pick = _topicPick(c, t);
      final minutes = _minutes(r, pick);
      final names = weakTopics.take(2).map((t) => t.name).join(', ');
      buf.write(' Denemede yanlış yaptığın konular: $names. Önce '
          '${t.name} tekrarını kapatalım (${formatMinutes(minutes)}).');
      action = _startAction(c, pick, minutes);
    }
    return NluReply(buf.toString().trim(), action: action, source: 'deneme');
  }

  static NluReply _examUrgency(NluResult r, NluContext c) {
    final s = r.slots;
    final label = switch (s.exam) {
      NluExamKind.mockExam => 'deneme',
      NluExamKind.schoolExam => 'yazılı',
      _ => 'sınav',
    };
    final when = switch (s.urgency) {
      NluUrgency.today => 'Bugün',
      NluUrgency.tomorrow => 'Yarın',
      NluUrgency.thisWeek => 'Bu hafta',
      NluUrgency.none => null,
    };
    final opening = when != null
        ? '$when $label var.'
        : (s.exam == NluExamKind.realExam && c.examDays != null
            ? 'Sınava ${c.examDays} gün var.'
            : 'Sınav yaklaşıyor.');

    final weak = _weakTopics(c, subjectId: s.subjectId, maxRank: 1);
    final minutes = _minutes(r, null, fallback: 30);
    if (weak.isNotEmpty) {
      final pick = _topicPick(c, weak.first);
      final names = weak.take(2).map((t) => t.name).join(', ');
      final subjectName = c.subjectById(weak.first.subjectId)?.name;
      return NluReply(
        '$opening Yeni konuya girme; ${subjectName == null ? '' : '$subjectName: '}'
        '$names tekrarına odaklan (${_sentence(pick.reason ?? '')}) '
        'Önce ${weak.first.name} için ${formatMinutes(minutes)}.',
        action: _startAction(c, pick, minutes),
        source: 'topicEvidence',
      );
    }

    final pick = _pick(r, c, preferEvidence: true);
    if (pick == null || pick.source == 'unknownSubject') {
      return NluReply(
          '$opening Kayıtlarında net bir eksik işareti yok; genel tekrar için '
          'bir ders ve süre söylersen planı ona göre kurarım.',
          source: 'none');
    }
    if (pick.source == 'subject') {
      return _subjectOnly(pick, minutes, c, lead: opening);
    }
    return NluReply(
      '$opening Kayıtlarında net bir eksik işareti yok; genel tekrar için '
      '${pick.label} ile başla (${formatMinutes(minutes)}).${_reasonTail(pick)}',
      action: _startAction(c, pick, minutes),
      source: pick.source,
    );
  }

  static NluReply _behind(NluResult r, NluContext c) {
    final s = r.slots;
    var overdue = _overdue(c, subjectId: s.subjectId);
    if (overdue.isEmpty && s.subjectId != null) overdue = _overdue(c);

    if (overdue.isNotEmpty) {
      final top = overdue.first;
      final pick = _taskPick(c, top);
      final minutes = _minutes(r, pick);
      final names = overdue.take(2).map((t) => '"${t.title}"').join(', ');
      final n = overdue.length;
      return NluReply(
        '$n görevin geride kalmış ($names${n > 2 ? ', …' : ''}). Hepsine '
        'birden yüklenme: önce "${top.title}" ile ${formatMinutes(minutes)} '
        'çalış, gerisini sırayla toparlarız.',
        action: NluAction.start(_withMinutes(c.taskIntent(top), minutes)),
        source: 'overdue',
      );
    }

    final pick = _pick(r, c, preferEvidence: true);
    if (pick == null) return _noData(c);
    if (pick.source == 'unknownSubject') return _unknownSubject(pick);
    final minutes = _minutes(r, pick);
    const lead = 'Kayıtlarında gecikmiş görevin görünmüyor; yine de geride '
        'hissediyorsan en kritik yerden başlayalım.';
    if (pick.source == 'subject') {
      return _subjectOnly(pick, minutes, c, lead: lead);
    }
    return NluReply('$lead ${_describe(pick, minutes)}',
        action: _startAction(c, pick, minutes), source: pick.source);
  }

  static NluReply _tooMuch(NluResult r, NluContext c) {
    final pending = _pendingToday(c);
    final overdue = _overdue(c);
    if (pending.isEmpty && overdue.isEmpty) {
      return const NluReply(
          'Bugün listende bekleyen görev görünmüyor. Yük hissin başka bir '
          'yerden geliyorsa "sen ayarla" de, günü ben makul bir büyüklükte '
          'kurayım.',
          source: 'none');
    }
    final top = pending.isNotEmpty ? pending.first : overdue.first;
    final total = pending.fold<int>(0, (s, t) => s + (t.estimatedMinutes ?? 0));
    final pick = _taskPick(c, top);
    final minutes = _minutes(r, pick);
    final buf = StringBuffer();
    if (pending.isNotEmpty) {
      buf.write('Bugün ${pending.length} görevin var'
          '${total > 0 ? ' (toplam ${formatMinutes(total)})' : ''}');
      if (overdue.isNotEmpty) buf.write(', ${overdue.length} tane de geride');
      buf.write('.');
    } else {
      buf.write('${overdue.length} görevin geride.');
    }
    buf.write(' Hepsini aynı anda yapmak zorunda değilsin: önce '
        '"${top.title}" (${formatMinutes(minutes)}), kalanlar yarına '
        'kalabilir.');
    return NluReply(
      buf.toString(),
      action: NluAction.start(_withMinutes(c.taskIntent(top), minutes)),
      source: pending.isNotEmpty ? 'today' : 'overdue',
    );
  }

  static NluReply _lowProgress(NluResult r, NluContext c) {
    final pick = _pick(r, c);
    final minutes =
        _minutes(r, pick, fallback: smallStepMinutes, cap: smallStepMinutes);
    final aboutToday = r.slots.urgency == NluUrgency.today;
    final action = _startAction(c, pick, minutes);
    final line = pick == null || pick.source == 'unknownSubject'
        ? null
        : (pick.source == 'subject' ? pick.subject!.name : pick.label);
    final step = line == null
        ? ''
        : ' En küçük adım yeter: $line — ${formatMinutes(minutes)}.';

    if (aboutToday && c.studiedMinutesToday > 0) {
      return NluReply(
        'Aslında bugün ${formatMinutes(c.studiedMinutesToday)} çalışma '
        'kaydın var — hiç sıfır değil.$step',
        action: action,
        source: 'today',
      );
    }
    if (aboutToday) {
      return NluReply(
        'Bugün henüz çalışma kaydın yok ama gün bitmedi.$step',
        action: action,
        source: 'today',
      );
    }
    return NluReply(
      'Başlamak en zor kısım, o yüzden küçük tutalım.$step',
      action: action,
      source: pick?.source ?? 'none',
    );
  }

  static NluReply _lowMotivation(NluResult r, NluContext c) {
    final pick = _pick(r, c);
    final tired = r.slots.state == NluState.tired;
    final minutes =
        _minutes(r, pick, fallback: smallStepMinutes, cap: smallStepMinutes);
    final lead = tired
        ? 'Yorgun olduğunu duydum, bugün zorlamayalım.'
        : 'Bu his geçici; motivasyon çoğu zaman başladıktan sonra gelir.';
    if (pick == null || pick.source == 'unknownSubject') {
      return NluReply('$lead Bir ders adı ve ${formatMinutes(minutes)} '
          'söylersen çok küçük bir blok kurarım.');
    }
    final line = pick.source == 'subject' ? pick.subject!.name : pick.label;
    return NluReply(
      '$lead ${formatMinutes(minutes)}lık hafif bir blok yeter: $line. '
      'Olmazsa bırakırsın.',
      action: _startAction(c, pick, minutes),
      source: pick.source,
    );
  }

  static NluReply _progress(NluResult r, NluContext c) {
    final summary = c.progressSummary;
    final buf = StringBuffer(summary ??
        'Şu an ilerlemeni yorumlayacak kadar veri yok — birkaç gün daha '
            'çalışıp deneme eklersen gerçek bir tablo çıkarabilirim.');
    if (c.goalGapSentence != null &&
        (summary == null || !summary.contains(c.goalGapSentence!))) {
      buf.write(' ${c.goalGapSentence}');
    }
    return NluReply(buf.toString(), source: 'progress');
  }

  static NluReply _positive(NluResult r, NluContext c) {
    final pick = _pick(r, c);
    final studied = c.studiedMinutesToday > 0
        ? ' Bugün ${formatMinutes(c.studiedMinutesToday)} çalıştın.'
        : '';
    if (pick == null ||
        pick.source == 'unknownSubject' ||
        pick.source == 'subject') {
      return NluReply('Güzel, böyle devam!$studied');
    }
    final minutes = _minutes(r, pick);
    return NluReply(
      'Güzel, böyle devam!$studied Devam etmek istersen sırada: '
      '${pick.label} (${formatMinutes(minutes)}).',
      action: _startAction(c, pick, minutes),
      source: pick.source,
    );
  }
}
