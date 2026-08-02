import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';
import 'subject_provider.dart';
import 'task_provider.dart';
import 'task_model.dart';
import 'add_subject_sheet.dart';

class SmartPlanScreen extends ConsumerStatefulWidget {
  const SmartPlanScreen({super.key});

  @override
  ConsumerState<SmartPlanScreen> createState() => _SmartPlanScreenState();
}

class _SmartPlanScreenState extends ConsumerState<SmartPlanScreen> {
  bool _isExamMode = false;
  int _hoursAvailable = 2;
  String _energy = 'orta';
  bool _examPressure = false;
  String? _selectedSubjectId;
  final _topicsController = TextEditingController();
  final _examNameController = TextEditingController();
  DateTime _examDate = DateTime.now().add(const Duration(days: 7));

  @override
  void dispose() {
    _topicsController.dispose();
    _examNameController.dispose();
    super.dispose();
  }

  Future<void> _pickExamDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _examDate,
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _examDate = picked);
  }

  void _generate() {
    final subjects = ref.read(subjectProvider);
    if (subjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Önce en az bir ders eklemelisin')),
      );
      return;
    }

    final targetSubjects = _selectedSubjectId != null
        ? subjects.where((s) => s.id == _selectedSubjectId).toList()
        : subjects;

    final topics = _topicsController.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    if (_isExamMode) {
      _generateExamPlan(targetSubjects, topics);
    } else {
      _generateDailyPlan(targetSubjects, topics);
    }
  }

  // Sınav modu: konuları bugünden sınav tarihine kadar olan günlere dağıtır
  void _generateExamPlan(List targetSubjects, List<String> topics) {
    final examName = _examNameController.text.trim();
    if (examName.isEmpty || topics.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sınav adı ve en az bir konu girmelisin')),
      );
      return;
    }

    final today = DateTime.now();
    final daysLeft = _examDate.difference(DateTime(today.year, today.month, today.day)).inDays;
    if (daysLeft < 1) return;

    final daysToUse = daysLeft < topics.length ? daysLeft : topics.length;

    for (int i = 0; i < topics.length; i++) {
      final subject = targetSubjects[i % targetSubjects.length];
      final dayOffset = (i % daysToUse) + 1;
      final taskDate = today.add(Duration(days: dayOffset));

      ref.read(taskProvider.notifier).addTask(
            title: '$examName: ${topics[i]}',
            subjectId: subject.id,
            dueDate: taskDate,
            priority: TaskPriority.high,
          );
    }

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${topics.length} konu $daysToUse güne dağıtıldı 🎯')),
    );
  }

  // Normal mod: bugün için, saat/enerjiye göre plan oluşturur
  void _generateDailyPlan(List targetSubjects, List<String> topics) {
 TaskPriority priority;

if (_examPressure) {
  priority = TaskPriority.high;
} else if (_energy == 'yüksek') {
  priority = TaskPriority.high;
} else if (_energy == 'düşük') {
  priority = TaskPriority.low;
} else {
  priority = TaskPriority.medium;
}
    final today = DateTime.now();
    // Akıllı sıralama: sınav varsa veya enerji düşükse dersleri düzenle
List sortedSubjects = [...targetSubjects];

if (_examPressure) {
  sortedSubjects.shuffle();
} else if (_energy == 'düşük') {
  sortedSubjects = sortedSubjects.reversed.toList();
}
DateTime startTime = DateTime.now();
    int taskCount;
if (topics.isNotEmpty) {
  // Kullanıcı konu seçtiyse her konu için 1 görev
  taskCount = topics.length;
} else {
  // Kullanıcı sadece ders seçtiyse her ders için 1 görev
  taskCount = targetSubjects.length;
}
DateTime currentTime = startTime;

    for (int i = 0; i < taskCount; i++) {
  final subject = sortedSubjects[i % sortedSubjects.length];

  final title = topics.isNotEmpty
      ? '${subject.name}: ${topics[i]}'
      : subject.name;

  final duration = _energy == 'yüksek'
      ? 60
      : _energy == 'düşük'
          ? 25
          : 45;

  ref.read(taskProvider.notifier).addTask(
    title: title,
    subjectId: subject.id,
    dueDate: today,
    priority: priority,
    scheduledTime: currentTime,
    estimatedMinutes: duration,
    difficulty: TopicDifficulty.medium,
  );

  currentTime = currentTime.add(
    Duration(minutes: duration),
  );
}
    

    Navigator.of(context).pop();
   String reason = '';

if (_examPressure) {
  reason = 'Sınav baskısına göre öncelikli plan hazırlandı 📚';
} else if (_energy == 'düşük') {
  reason = 'Enerjin düşük olduğu için daha kısa bloklar seçildi 🌱';
} else if (_energy == 'yüksek') {
  reason = 'Enerjin yüksek olduğu için uzun çalışma blokları seçildi 🔥';
} else {
  reason = 'Dengeli bir çalışma planı hazırlandı ⚖️';
}

ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text('$taskCount görev hazırlandı 🎯\n$reason'),
  ),
);
  }

  @override
  Widget build(BuildContext context) {
    final subjects = ref.watch(subjectProvider);

    return Scaffold(
      appBar: AppBar(title: Text('Akıllı Plan', style: AppTextStyles.heading2)),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Bu bir sınav planı', style: AppTextStyles.body),
              subtitle: Text('Konuları belirli bir tarihe kadar dağıt',
                  style: AppTextStyles.caption),
              value: _isExamMode,
              activeColor: AppColors.primary,
              onChanged: (v) => setState(() => _isExamMode = v),
            ),
            const SizedBox(height: 12),

            if (_isExamMode) ...[
              TextField(
                controller: _examNameController,
                decoration: const InputDecoration(hintText: 'Sınav adı, örn. Matematik Vize'),
              ),
              const SizedBox(height: 20),
              Text('Sınav Tarihi', style: AppTextStyles.bodySecondary),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: _pickExamDate,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    DateFormat('dd MMMM yyyy', 'tr_TR').format(_examDate),
                    style: AppTextStyles.body,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ] else ...[
              Text('Bugün kaç saatin var?', style: AppTextStyles.body),
              const SizedBox(height: 10),
              Slider(
                value: _hoursAvailable.toDouble(),
                min: 1,
                max: 8,
                divisions: 7,
                label: '$_hoursAvailable saat',
                activeColor: AppColors.primary,
                onChanged: (v) => setState(() => _hoursAvailable = v.round()),
              ),
              const SizedBox(height: 20),
              Text('Enerjin nasıl?', style: AppTextStyles.body),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: ['düşük', 'orta', 'yüksek'].map((level) {
                  final isSelected = _energy == level;
                  return ChoiceChip(
                    label: Text(level),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _energy = level),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Yakında sınavım var', style: AppTextStyles.body),
                value: _examPressure,
                activeColor: AppColors.primary,
                onChanged: (v) => setState(() => _examPressure = v),
              ),
              const SizedBox(height: 20),
            ],

            Text('Hangi ders? (opsiyonel)', style: AppTextStyles.body),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...subjects.map((s) {
                  final isSelected = _selectedSubjectId == s.id;
                  return ChoiceChip(
                    label: Text(s.name),
                    selected: isSelected,
                    onSelected: (_) => setState(
                        () => _selectedSubjectId = isSelected ? null : s.id),
                  );
                }),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 16, color: AppColors.primary),
                  label: const Text('Yeni Ders', style: TextStyle(color: AppColors.primary)),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const AddSubjectSheet(),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),

            Text(
              _isExamMode ? 'Konular (virgülle ayır)' : 'Konular (opsiyonel, virgülle ayır)',
              style: AppTextStyles.body,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _topicsController,
              decoration: const InputDecoration(hintText: 'örn. kuvvet, enerji, elektrik'),
            ),

            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _generate,
                child: const Text('Planımı Oluştur'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}