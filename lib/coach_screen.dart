import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';
import 'plan_builder.dart';
import 'plan_parser.dart';
import 'study_advisor.dart';
import 'subject_model.dart';
import 'subject_provider.dart';
import 'task_model.dart';
import 'task_provider.dart';
import 'topic_model.dart';
import 'topic_provider.dart';
import 'stats_provider.dart';
import 'widgets/app_buttons.dart';
import 'widgets/exam_countdown.dart';

/// Çalışma Koçu — serbest sohbetle plan kurar. Çip / çoktan seçmeli YOK:
/// koç doğal dille sorar, kullanıcı yazar, [PlanParser] ayrıştırır, eksik
/// kalanı koç tek tek ister. "Sen ayarla" denince koç günü kendi kurar
/// ([PlanBuilder]). Tüm mantık yerel — LLM yok.
class CoachScreen extends ConsumerStatefulWidget {
  const CoachScreen({super.key});

  @override
  ConsumerState<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends ConsumerState<CoachScreen> {
  final _scroll = ScrollController();
  final _input = TextEditingController();
  final List<_Turn> _turns = [];

  final _Draft _draft = _Draft();
  bool _delegate = false;
  bool _askedRecurrence = false;

  // Devralma modunda: bugün mü (false), önümüzdeki 7 gün mü (true), henüz
  // sorulmadı mı (null).
  bool? _wantsWeek;

  // Onaya sunulmuş plan (varsa). Tek görev ya da çok görevli gün planı.
  List<PlanBlock>? _pending;
  String _pendingRecurrence = 'none';
  bool _pendingIsDay = false;

  // Onaya sunulmuş haftalık program (varsa) — güne göre gruplu.
  WeekPlanResult? _pendingWeek;

  bool _hasInput = false;

  @override
  void initState() {
    super.initState();
    _input.addListener(() {
      final has = _input.text.trim().isNotEmpty;
      if (has != _hasInput) setState(() => _hasInput = has);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _intro());
  }

  @override
  void dispose() {
    _scroll.dispose();
    _input.dispose();
    super.dispose();
  }

  // --- Konuşma ------------------------------------------------------

  void _say(String text, {bool coach = true}) {
    setState(() => _turns.add(_Turn(coach: coach, text: text)));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _intro() {
    final stats = ref.read(statsProvider);
    final name = stats.userName?.trim();
    _say(name != null && name.isNotEmpty
        ? 'Selam $name 👋 Nasıl gidiyor?'
        : 'Selam 👋 Nasıl gidiyor?');

    final examDate = stats.examDate;
    final examLine = (examDate != null && daysUntilExam(examDate) >= 0)
        ? ' Sınava ${daysUntilExam(examDate)} gün var.'
        : '';
    _say('Nasıl planlayalım?$examLine Ne çalışmak istediğini ve ne kadar '
        'vaktin olduğunu yaz — ya da "sen ayarla" de, ben kurayım '
        '(bugüne ya da "bu hafta" dersen 7 güne).');
  }

  // --- Girdi işleme ----------------------------------------------

  static final _confirm = RegExp(
      r'^(ekle|tamam|evet|olur|kaydet|ekleyebilirsin|onayla|kabul)\b');
  static final _restart =
      RegExp(r'\b(baştan|bastan|iptal|vazgeç|vazgec|sıfırla|sifirla)\b');
  static final _finish = RegExp(
      r'\b(bitir|kapat|yeter|işim bitti|isim bitti|bu kadar|sağ ol|sag ol|teşekkür|tesekkur|yok(?: bu kadar)?)\b');
  static final _delegateRe = RegExp(
      r'\b(sen ayarla|sen yap|sen kur|sen karar|sana bırak|sana birak|sen bil|bilmiyorum|fark etmez|farketmez|önemli değil|onemli degil)\b');
  static final _weekIntentRe = RegExp(
      r'(bu hafta|haftalık program|haftalik program|haftalık plan|haftalik plan|hafta boyunca|7 gün|7 gun|yedi gün|yedi gun|bir haftalık|bir haftalik)');
  static final _todayIntentRe = RegExp(
      r'(sadece bugün|sadece bugun|sadece bu gün|bugün olsun|bugun olsun|tek gün|tek gun|sadece bugüne|sadece bugune)');

  void _onSend() {
    final raw = _input.text.trim();
    if (raw.isEmpty) return;
    _input.clear();
    FocusScope.of(context).unfocus();
    _say(raw, coach: false);

    final low = raw.toLowerCase().replaceAll('̇', '');

    if (_pending != null && _confirm.hasMatch(low)) {
      _commit();
      return;
    }
    if (_restart.hasMatch(low)) {
      _draft.reset();
      _pending = null;
      _pendingWeek = null;
      _delegate = false;
      _wantsWeek = null;
      _askedRecurrence = false;
      _say('Tamam, temizledim. Baştan anlat bakalım.');
      return;
    }
    if (_pending == null && _draft.isEmpty && _finish.hasMatch(low)) {
      _say('Kolay gelsin 👋');
      return;
    }

    if (_delegateRe.hasMatch(low)) _delegate = true;

    if (_delegate) {
      if (_weekIntentRe.hasMatch(low)) {
        _wantsWeek = true;
      } else if (_todayIntentRe.hasMatch(low)) {
        _wantsWeek = false;
      } else if (_draft.minutes != null && _wantsWeek == null) {
        // "bugün mü / bu hafta mı" sorusuna serbest cevap.
        if (low.contains('hafta')) {
          _wantsWeek = true;
        } else if (low.contains('bugün') ||
            low.contains('bugun') ||
            low.contains('gün') ||
            low.contains('gun')) {
          _wantsWeek = false;
        }
      }
    }

    final parsed = PlanParser.parse(raw, subjects: ref.read(subjectProvider));
    _merge(parsed, raw);

    // Onay beklerken gelen serbest metin = düzenleme; yeni bilgiyi al, planı
    // tazele.
    _pending = null;
    _advance();
  }

  void _merge(ParsedPlan p, String raw) {
    if (p.date != null) _draft.day = p.date;
    if (p.durationMinutes != null) _draft.minutes = p.durationMinutes;
    if (p.recurrence != 'none') _draft.recurrence = p.recurrence;
    if (p.hasTime) {
      _draft.hour = p.hour;
      _draft.minute = p.minute ?? 0;
    }
    if (p.subjectId != null) {
      _draft.subjectId = p.subjectId;
      _draft.subjectName = p.subjectName;
    } else if (p.subjectName != null) {
      _draft.subjectName = p.subjectName;
    }

    final t = p.title.trim();
    final sameAsSubject =
        t.toLowerCase() == (p.subjectName ?? '').toLowerCase();
    if (t.isNotEmpty && p.hasSignal && !sameAsSubject) {
      _draft.topic = t;
    } else if (!_draft.hasSubject && !p.hasSignal && t.isNotEmpty) {
      // Sinyalsiz düz cevap ("deneme analizi") → konu olarak kabul et.
      _draft.topic = raw.trim();
    }
  }

  // --- Akış kararı ---------------------------------------------

  int _q = 0;
  String _pick(List<String> options) => options[_q++ % options.length];

  void _advance() {
    final subjects = ref.read(subjectProvider);
    if (subjects.isEmpty) {
      _say('Önce en az bir ders eklemen lazım — sağ alttaki + ile '
          'ekleyip geri gelebilirsin.');
      return;
    }

    if (_delegate) {
      if (_draft.minutes == null) {
        _say(_pick([
          'Tamam, ben kurayım. Günde ortalama ne kadar vaktin var?',
          'Olur, devralıyorum. Günde kaç saatin var?',
        ]));
        return;
      }
      if (_wantsWeek == null) {
        _say('Sadece bugüne mi, yoksa önümüzdeki 7 güne bir program mı? '
            '("bugün" ya da "bu hafta")');
        return;
      }
      if (_wantsWeek!) {
        _proposeWeek();
      } else {
        _proposeDay();
      }
      return;
    }

    if (!_draft.hasSubject) {
      _say(_pick([
        'Ne çalışmak istiyorsun?',
        'Hangi derse / konuya bakalım?',
      ]));
      return;
    }
    if (_draft.minutes == null) {
      _say(_pick([
        'Ne kadar ayıralım buna?',
        'Kaç dakika / saat düşünüyorsun?',
      ]));
      return;
    }
    if (_draft.day == null) {
      _say(_pick([
        'Ne zaman? Bugün, yarın ya da bir gün söyle.',
        'Hangi gün olsun — bugün mü, yarın mı?',
      ]));
      return;
    }
    if (_draft.recurrence == 'none' && !_askedRecurrence) {
      _askedRecurrence = true;
      _say('Tek sefer mi, yoksa tekrar mı etsin? (ör. "her gün", '
          '"her pazartesi" ya da "tek sefer")');
      return;
    }

    _proposeSingle();
  }

  // --- Öneri ---------------------------------------------------

  static const _months = [
    'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
    'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara',
  ];

  static const _weekdayShort = [
    'Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz',
  ];

  String _dayLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = DateTime(d.year, d.month, d.day).difference(today).inDays;
    if (diff == 0) return 'Bugün';
    if (diff == 1) return 'Yarın';
    return '${d.day} ${_months[d.month - 1]}';
  }

  String _weekdayLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = DateTime(d.year, d.month, d.day).difference(today).inDays;
    if (diff == 0) return 'Bugün';
    if (diff == 1) return 'Yarın';
    return '${_weekdayShort[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}';
  }

  String _hhmm(int h, int m) =>
      '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

  String _recLabel(String r) => switch (r) {
        'daily' => ' · her gün',
        'weekly' => ' · her hafta',
        _ => '',
      };

  String _composeTitle() {
    final s = _draft.subjectName;
    final t = _draft.topic;
    if (s != null && t != null && t.toLowerCase() != s.toLowerCase()) {
      return '$s: $t';
    }
    return t ?? s ?? 'Çalışma';
  }

  void _proposeSingle() {
    final now = DateTime.now();
    final day = _draft.day ?? DateTime(now.year, now.month, now.day);
    final minutes = _draft.minutes ?? 45;

    _pending = [
      PlanBlock(
        title: _composeTitle(),
        subjectId: _draft.subjectId ?? '',
        minutes: minutes,
        order: 0,
        priority: TaskPriority.medium,
      ),
    ];
    _pendingRecurrence = _draft.recurrence;
    _pendingIsDay = false;

    final timePart =
        _draft.hour != null ? ' · ${_hhmm(_draft.hour!, _draft.minute ?? 0)}' : '';
    _say('Şöyle olsun mu?\n\n'
        '${_dayLabel(day)}$timePart${_recLabel(_draft.recurrence)}\n'
        '${_composeTitle()} · $minutes dk\n\n'
        '"ekle" yaz ya da neyi değiştireceğini söyle.');
  }

  void _proposeDay() {
    final subjects = ref.read(subjectProvider);
    final allTasks = ref.read(taskProvider);
    final examDate = ref.read(statsProvider).examDate;
    final examDays = examDate == null ? null : daysUntilExam(examDate);

    // Konu Takip verisi: kapsama oranları + ders başına boş konular.
    final coverage = ref.read(coverageBySubjectProvider);
    final coveragePercent = <String, double>{
      for (final e in coverage.entries)
        if (e.value.hasTopics) e.key: e.value.ratio,
    };
    final uncovered = <String, List<String>>{};
    for (final t in ref.read(topicProvider)) {
      if (t.status != TopicStatus.reviewed && t.status != TopicStatus.studied) {
        uncovered.putIfAbsent(t.subjectId, () => []).add(t.name);
      }
    }

    final advisorIds = StudyAdvisor.suggest(
      subjects: subjects,
      tasks: allTasks,
      examDate: examDate,
      limit: subjects.length,
      coveragePercent: coveragePercent,
    ).map((s) => s.subjectId).toList();

    final ordered = <SubjectModel>[
      for (final id in advisorIds) subjects.firstWhere((s) => s.id == id),
      for (final s in subjects)
        if (!advisorIds.contains(s.id)) s,
    ];

    final hours = (_draft.minutes! / 60).round().clamp(1, 12);
    final result = PlanBuilder.build(
      orderedSubjects: ordered,
      hoursAvailable: hours,
      energy: 'orta',
      examDays: examDays,
      uncoveredTopics: uncovered,
      fillToCapacity: uncovered.isNotEmpty,
    );

    if (result.isEmpty) {
      _say('Bu kadar vakitle bir blok bile çıkmadı. Biraz daha vakit yazar '
          'mısın?');
      _draft.minutes = null;
      return;
    }

    _pending = result.blocks;
    _pendingRecurrence = 'none';
    _pendingIsDay = true;

    final lines =
        result.blocks.map((b) => '•  ${b.title} · ${b.minutes} dk').join('\n');
    _say('${result.reason}\n\n$lines\n\n'
        'Toplam ${result.plannedMinutes} dk · ${result.blocks.length} görev.\n\n'
        '"ekle" de ya da değiştirmek istediğini söyle.');
  }

  void _proposeWeek() {
    final subjects = ref.read(subjectProvider);
    final allTasks = ref.read(taskProvider);
    final examDate = ref.read(statsProvider).examDate;
    final examDays = examDate == null ? null : daysUntilExam(examDate);

    // Konu Takip: kapsama oranları + ders başına işaretlenmemiş konular.
    final coverage = ref.read(coverageBySubjectProvider);
    final coveragePercent = <String, double>{
      for (final e in coverage.entries)
        if (e.value.hasTopics) e.key: e.value.ratio,
    };
    final uncovered = <String, List<String>>{};
    for (final t in ref.read(topicProvider)) {
      if (t.status != TopicStatus.reviewed && t.status != TopicStatus.studied) {
        uncovered.putIfAbsent(t.subjectId, () => []).add(t.name);
      }
    }

    final advisorIds = StudyAdvisor.suggest(
      subjects: subjects,
      tasks: allTasks,
      examDate: examDate,
      limit: subjects.length,
      coveragePercent: coveragePercent,
    ).map((s) => s.subjectId).toList();

    final ordered = <SubjectModel>[
      for (final id in advisorIds) subjects.firstWhere((s) => s.id == id),
      for (final s in subjects)
        if (!advisorIds.contains(s.id)) s,
    ];

    final n0 = DateTime.now();
    final today = DateTime(n0.year, n0.month, n0.day);
    final hoursPerDay = (_draft.minutes! / 60).round().clamp(1, 8);

    final week = PlanBuilder.buildWeek(
      orderedSubjects: ordered,
      uncoveredTopics: uncovered,
      hoursPerDay: hoursPerDay,
      startDate: today,
      examDays: examDays,
    );

    if (week.isEmpty) {
      _say('Program çıkmadı — günde biraz daha vakit yazar mısın?');
      _draft.minutes = null;
      return;
    }

    _pendingWeek = week;
    _pending = week.allBlocks;
    _pendingIsDay = true;
    _pendingRecurrence = 'none';

    final buf = StringBuffer()
      ..writeln(week.reason)
      ..writeln();
    for (final d in week.days) {
      buf.writeln('${_weekdayLabel(d.date)} · '
          '${d.blocks.map((b) => b.title).join(', ')}');
    }
    buf
      ..writeln()
      ..write('Toplam ${week.totalBlocks} görev, ${week.days.length} gün.\n\n'
          '"ekle" de ya da değiştirmek istediğini söyle.');
    _say(buf.toString());
  }

  void _commit() {
    // Haftalık program: her bloğu kendi gününün dueDate'iyle yaz.
    final week = _pendingWeek;
    if (week != null) {
      final notifier = ref.read(taskProvider.notifier);
      var count = 0;
      for (final day in week.days) {
        for (final b in day.blocks) {
          notifier.addTask(
            title: b.title,
            subjectId: b.subjectId.isEmpty ? null : b.subjectId,
            dueDate: day.date,
            priority: b.priority,
            estimatedMinutes: b.minutes,
            difficulty: TopicDifficulty.medium,
          );
          count++;
        }
      }
      _pendingWeek = null;
      _pending = null;
      _draft.reset();
      _delegate = false;
      _wantsWeek = null;
      _askedRecurrence = false;
      _say('$count görev ${week.days.length} güne yayıldı 👍 '
          'Başka bir şey var mı?');
      return;
    }

    final blocks = _pending;
    if (blocks == null) return;
    final notifier = ref.read(taskProvider.notifier);
    final n0 = DateTime.now();
    final today = DateTime(n0.year, n0.month, n0.day);

    // Saat YALNIZCA kullanıcı açıkça söylediyse ("saat 3", "akşam 8").
    final timeOfDay = _draft.hour != null
        ? TimeOfDay(hour: _draft.hour!, minute: _draft.minute ?? 0)
        : null;

    if (!_pendingIsDay && _pendingRecurrence != 'none') {
      final b = blocks.first;
      notifier.addRecurringTask(
        title: b.title,
        subjectId: b.subjectId.isEmpty ? null : b.subjectId,
        startDate: _draft.day ?? today,
        recurrenceRule: _pendingRecurrence,
        estimatedMinutes: b.minutes,
        scheduledTimeOfDay: timeOfDay,
      );
    } else {
      for (final b in blocks) {
        final due = _pendingIsDay ? today : (_draft.day ?? today);
        // Gün planı: saatsiz gün-kapsamlı görevler. Tek görev: yalnız
        // kullanıcı saat verdiyse zamanlı.
        final scheduled = (!_pendingIsDay && timeOfDay != null)
            ? DateTime(due.year, due.month, due.day, timeOfDay.hour,
                timeOfDay.minute)
            : null;
        notifier.addTask(
          title: b.title,
          subjectId: b.subjectId.isEmpty ? null : b.subjectId,
          dueDate: due,
          priority: b.priority,
          scheduledTime: scheduled,
          estimatedMinutes: b.minutes,
          difficulty: TopicDifficulty.medium,
        );
      }
    }

    final n = blocks.length;
    _pending = null;
    _draft.reset();
    _delegate = false;
    _wantsWeek = null;
    _askedRecurrence = false;
    _say(n == 1
        ? 'Eklendi 👍 Başka bir şey planlayalım mı?'
        : '$n görev eklendi 👍 Başka bir şey var mı?');
  }

  // --- UI -----------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Çalışma Koçu', style: AppTextStyles.heading2),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              itemCount: _turns.length,
              itemBuilder: (_, i) => _Bubble(turn: _turns[i]),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_pending != null) ...[
                    PrimaryButton(
                      label: 'Ekle',
                      icon: Icons.check,
                      onPressed: _commit,
                    ),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: AppColors.surfaceVariant, width: 1),
                          ),
                          child: TextField(
                            controller: _input,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _onSend(),
                            minLines: 1,
                            maxLines: 4,
                            style: AppTextStyles.body
                                .copyWith(color: AppColors.textPrimary),
                            decoration: const InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              hintText: 'Yaz…',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _hasInput ? _onSend : null,
                        tooltip: 'Gönder',
                        icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                        style: IconButton.styleFrom(
                          backgroundColor: _hasInput
                              ? AppColors.primary
                              : AppColors.surfaceVariant,
                          foregroundColor: _hasInput
                              ? AppColors.ink
                              : AppColors.textMuted,
                          minimumSize: const Size(48, 48),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Değişebilir plan taslağı — sohbet ilerledikçe dolar.
class _Draft {
  DateTime? day;
  int? minutes;
  int? hour;
  int? minute;
  String recurrence = 'none';
  String? subjectId;
  String? subjectName;
  String? topic;

  bool get hasSubject =>
      subjectId != null ||
      (subjectName != null && subjectName!.isNotEmpty) ||
      (topic != null && topic!.isNotEmpty);

  bool get isEmpty =>
      day == null &&
      minutes == null &&
      hour == null &&
      recurrence == 'none' &&
      subjectId == null &&
      subjectName == null &&
      topic == null;

  void reset() {
    day = null;
    minutes = null;
    hour = null;
    minute = null;
    recurrence = 'none';
    subjectId = null;
    subjectName = null;
    topic = null;
  }
}

class _Turn {
  final bool coach;
  final String text;
  const _Turn({required this.coach, required this.text});
}

class _Bubble extends StatelessWidget {
  final _Turn turn;
  const _Bubble({required this.turn});

  @override
  Widget build(BuildContext context) {
    final coach = turn.coach;
    return Align(
      alignment: coach ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        decoration: BoxDecoration(
          color: coach ? AppColors.surface : AppColors.tonal(AppColors.primary),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(coach ? 4 : 18),
            bottomRight: Radius.circular(coach ? 18 : 4),
          ),
          boxShadow: coach ? AppColors.softShadow : null,
        ),
        child: Text(
          turn.text,
          style: AppTextStyles.body
              .copyWith(color: AppColors.textPrimary, height: 1.35),
        ),
      ),
    );
  }
}
