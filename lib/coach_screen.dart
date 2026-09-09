import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';
import 'tap_scale.dart';
import 'add_subject_sheet.dart';
import 'plan_builder.dart';
import 'plan_parser.dart';
import 'study_advisor.dart';
import 'subject_model.dart';
import 'subject_provider.dart';
import 'task_model.dart';
import 'task_provider.dart';
import 'stats_provider.dart';
import 'widgets/app_buttons.dart';
import 'widgets/exam_countdown.dart';

/// Rehberli sohbet planlayıcı — eski form tabanlı SmartPlanScreen'in yerini
/// alır. Açık uçlu bir chatbot DEĞİL: koç önce konuşur, kullanıcı çiplerle
/// ve tek bir serbest metin alanıyla ilerler. Tüm mantık yerel
/// ([StudyAdvisor] + [PlanParser] + [PlanBuilder]); LLM yok.
class CoachScreen extends ConsumerStatefulWidget {
  const CoachScreen({super.key});

  @override
  ConsumerState<CoachScreen> createState() => _CoachScreenState();
}

enum _Phase { needSubject, hours, energy, topic, proposal, done }

class _CoachScreenState extends ConsumerState<CoachScreen> {
  final _scroll = ScrollController();
  final _topicController = TextEditingController();
  final List<_Turn> _turns = [];

  _Phase _phase = _Phase.hours;

  int _hours = 2;
  String _energy = 'orta';
  ParsedPlan? _parsed;
  PlanResult? _result;
  int _plannedCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startIntro());
  }

  @override
  void dispose() {
    _scroll.dispose();
    _topicController.dispose();
    super.dispose();
  }

  // --- Konuşma yardımcıları ------------------------------------------

  void _say(String text, {bool coach = true}) {
    setState(() => _turns.add(_Turn(coach: coach, text: text)));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _startIntro() {
    final subjects = ref.read(subjectProvider);
    if (subjects.isEmpty) {
      setState(() => _phase = _Phase.needSubject);
      _say('Başlamadan önce en az bir ders eklemelisin.');
      return;
    }

    final stats = ref.read(statsProvider);
    final allTasks = ref.read(taskProvider);
    final examDate = stats.examDate;
    final examDays = examDate == null ? null : daysUntilExam(examDate);

    final now = DateTime.now();
    final todayIncomplete = allTasks
        .where((t) =>
            !t.isCompleted &&
            t.dueDate.year == now.year &&
            t.dueDate.month == now.month &&
            t.dueDate.day == now.day)
        .length;

    final advisor = StudyAdvisor.suggest(
      subjects: subjects,
      tasks: allTasks,
      examDate: examDate,
      limit: 1,
    );

    final name = stats.userName?.trim();
    final parts = <String>[
      (name != null && name.isNotEmpty) ? 'Merhaba $name.' : 'Merhaba.',
      todayIncomplete == 0
          ? 'Bugün için planlı görevin yok.'
          : 'Bugün $todayIncomplete planlı görevin var.',
    ];
    if (examDays != null && examDays >= 0) {
      parts.add('Sınava $examDays gün.');
    }
    if (advisor.isNotEmpty) {
      parts.add(
        '${advisor.first.subjectName} — ${advisor.first.reason.toLowerCase()}; '
        'oradan başlayabiliriz.',
      );
    }

    _say(parts.join(' '));
    _say('Bugün ne kadar vaktin var?');
    setState(() => _phase = _Phase.hours);
  }

  // --- Adım geçişleri ----------------------------------------------

  void _pickHours(int h) {
    _say('$h saat', coach: false);
    _hours = h;
    _say('Enerjin nasıl?');
    setState(() => _phase = _Phase.energy);
  }

  void _pickEnergy(String label, String value) {
    _say(label, coach: false);
    _energy = value;
    _say('Belirli bir ders ya da konu var mı? Yazabilirsin ya da geç.');
    setState(() => _phase = _Phase.topic);
  }

  void _submitTopic() {
    final text = _topicController.text.trim();
    _topicController.clear();
    if (text.isEmpty) {
      _skipTopic();
      return;
    }
    _say(text, coach: false);
    _parsed = PlanParser.parse(text, subjects: ref.read(subjectProvider));
    _buildProposal();
  }

  void _skipTopic() {
    _say('Geç', coach: false);
    _parsed = null;
    _buildProposal();
  }

  void _buildProposal() {
    final subjects = ref.read(subjectProvider);
    final allTasks = ref.read(taskProvider);
    final examDate = ref.read(statsProvider).examDate;
    final examDays = examDate == null ? null : daysUntilExam(examDate);

    // Ders sırası: önce StudyAdvisor'ın önerdiği sıra, sonra kalanlar.
    final advisorIds = StudyAdvisor.suggest(
      subjects: subjects,
      tasks: allTasks,
      examDate: examDate,
      limit: subjects.length,
    ).map((s) => s.subjectId).toList();

    final ordered = <SubjectModel>[
      for (final id in advisorIds)
        subjects.firstWhere((s) => s.id == id),
      for (final s in subjects)
        if (!advisorIds.contains(s.id)) s,
    ];

    SubjectModel? explicit;
    final topics = <String>[];
    final parsed = _parsed;
    if (parsed != null) {
      if (parsed.subjectId != null) {
        explicit = subjects.firstWhere(
          (s) => s.id == parsed.subjectId,
          orElse: () => ordered.first,
        );
      }
      // Kalan başlık metnini tek konu etiketi olarak kullan (virgülle bölerek).
      for (final t in parsed.title.split(',')) {
        final trimmed = t.trim();
        if (trimmed.isNotEmpty &&
            (explicit == null ||
                trimmed.toLowerCase() != explicit.name.toLowerCase())) {
          topics.add(trimmed);
        }
      }
    }

    final result = PlanBuilder.build(
      orderedSubjects: ordered,
      explicitSubject: explicit,
      topics: topics,
      hoursAvailable: _hours,
      energy: _energy,
      examDays: examDays,
    );

    if (result.isEmpty) {
      _say('Bu ayarlarla sığan bir blok çıkmadı. Biraz daha vakit ya da '
          'yüksek enerji seçip tekrar deneyelim mi?');
      setState(() => _phase = _Phase.hours);
      _say('Bugün ne kadar vaktin var?');
      return;
    }

    _result = result;
    _plannedCount = result.blocks.length;

    final lines =
        result.blocks.map((b) => '•  ${b.title} · ${b.minutes} dk').join('\n');
    _say('${result.reason}\n\n$lines\n\n'
        'Toplam ${result.plannedMinutes} dk · $_plannedCount görev.');
    if (result.unfitTitles.isNotEmpty) {
      _say('${result.unfitTitles.length} tanesi bugüne sığmadı — sonra '
          'elle ekleyebilirsin.');
    }
    setState(() => _phase = _Phase.proposal);
  }

  void _confirmPlan() {
    final result = _result;
    if (result == null) return;

    final today = DateTime.now();
    final notifier = ref.read(taskProvider.notifier);
    for (final b in result.blocks) {
      notifier.addTask(
        title: b.title,
        subjectId: b.subjectId,
        dueDate: today,
        priority: b.priority,
        scheduledTime: b.startTime,
        estimatedMinutes: b.minutes,
        difficulty: TopicDifficulty.medium,
      );
    }

    _say('Planı ekle', coach: false);
    _say('$_plannedCount görev eklendi. Kolay gelsin 💪');
    setState(() => _phase = _Phase.done);
  }

  void _restart() {
    _say('Baştan', coach: false);
    _parsed = null;
    _result = null;
    setState(() => _phase = _Phase.hours);
    _say('Tamam. Bugün ne kadar vaktin var?');
  }

  Future<void> _openAddSubject() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddSubjectSheet(),
    );
    if (!mounted) return;
    if (ref.read(subjectProvider).isNotEmpty) {
      _startIntro();
    }
  }

  // --- UI ---------------------------------------------------------

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
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: _buildInput(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInput() {
    switch (_phase) {
      case _Phase.needSubject:
        return Row(
          children: [
            Expanded(
              child: PrimaryButton(
                label: 'Ders Ekle',
                icon: Icons.add,
                onPressed: _openAddSubject,
              ),
            ),
            const SizedBox(width: 10),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Kapat', style: AppTextStyles.bodySecondary),
            ),
          ],
        );

      case _Phase.hours:
        return _ChipRow(
          options: const [
            MapEntry('1 saat', 1),
            MapEntry('2 saat', 2),
            MapEntry('3 saat', 3),
            MapEntry('4+ saat', 4),
          ],
          onTap: (v) => _pickHours(v),
        );

      case _Phase.energy:
        return _ChipRow(
          options: const [
            MapEntry('Düşük', 'düşük'),
            MapEntry('Orta', 'orta'),
            MapEntry('Yüksek', 'yüksek'),
          ],
          onTap: (v) => _pickEnergy(
            v == 'düşük'
                ? 'Düşük'
                : v == 'yüksek'
                    ? 'Yüksek'
                    : 'Orta',
            v,
          ),
        );

      case _Phase.topic:
        return Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border:
                      Border.all(color: AppColors.surfaceVariant, width: 1),
                ),
                child: TextField(
                  controller: _topicController,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submitTopic(),
                  style: AppTextStyles.body
                      .copyWith(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: 'örn. fizik dalga, türev…',
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _submitTopic,
              icon: const Icon(Icons.arrow_upward_rounded, size: 18),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.ink,
                minimumSize: const Size(44, 44),
              ),
            ),
            TextButton(
              onPressed: _skipTopic,
              child: Text('Geç', style: AppTextStyles.bodySecondary),
            ),
          ],
        );

      case _Phase.proposal:
        return Row(
          children: [
            Expanded(
              child: PrimaryButton(
                label: 'Planı Ekle',
                icon: Icons.check,
                onPressed: _confirmPlan,
              ),
            ),
            const SizedBox(width: 10),
            TextButton(
              onPressed: _restart,
              child: Text('Baştan', style: AppTextStyles.bodySecondary),
            ),
          ],
        );

      case _Phase.done:
        return DarkButton(
          label: 'Bitir',
          onPressed: () => Navigator.of(context).pop(),
        );
    }
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
          color: coach
              ? AppColors.surface
              : AppColors.tonal(AppColors.primary),
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
          style: AppTextStyles.body.copyWith(
            color: AppColors.textPrimary,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}

/// Alt bardaki tek satırlık seçim çipleri. [T] seçilen değerin tipi.
class _ChipRow<T> extends StatelessWidget {
  final List<MapEntry<String, T>> options;
  final ValueChanged<T> onTap;

  const _ChipRow({required this.options, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final o in options) ...[
          Expanded(
            child: TapScale(
              onTap: () => onTap(o.value),
              child: Container(
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.tonal(AppColors.primary),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  o.key,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          if (o != options.last) const SizedBox(width: 8),
        ],
      ],
    );
  }
}
