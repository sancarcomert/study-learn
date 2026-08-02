import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';
import 'subject_provider.dart';
import 'task_provider.dart';
import 'task_model.dart';

class AddExamScreen extends ConsumerStatefulWidget {
  const AddExamScreen({super.key});

  @override
  ConsumerState<AddExamScreen> createState() => _AddExamScreenState();
}

class _AddExamScreenState extends ConsumerState<AddExamScreen> {
  final _examNameController = TextEditingController();
  final _topicCountController = TextEditingController(text: '5');
  String? _selectedSubjectId;
  DateTime _examDate = DateTime.now().add(const Duration(days: 7));

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _examDate,
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _examDate = picked);
  }

  void _generatePlan() {
    final examName = _examNameController.text.trim();
    final topicCount = int.tryParse(_topicCountController.text.trim()) ?? 0;

    if (examName.isEmpty || topicCount < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sınav adı ve konu sayısını doğru gir')),
      );
      return;
    }

    final today = DateTime.now();
    final daysLeft = _examDate.difference(DateTime(today.year, today.month, today.day)).inDays;
    if (daysLeft < 1) return;

    // Konuları kalan günlere eşit dağıtıyoruz (round-robin)
    final daysToUse = daysLeft < topicCount ? daysLeft : topicCount;
    for (int i = 0; i < topicCount; i++) {
      final dayOffset = (i % daysToUse) + 1;
      final taskDate = today.add(Duration(days: dayOffset));
      ref.read(taskProvider.notifier).addTask(
            title: '$examName - Konu ${i + 1}',
            subjectId: _selectedSubjectId,
            dueDate: taskDate,
            priority: TaskPriority.high,
          );
    }

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$topicCount konu $daysToUse güne dağıtıldı 🎯')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subjects = ref.watch(subjectProvider);

    return Scaffold(
      appBar: AppBar(title: Text('Sınav Planla', style: AppTextStyles.heading2)),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _examNameController,
              decoration: const InputDecoration(hintText: 'Sınav adı, örn. Matematik Vize'),
            ),
            const SizedBox(height: 20),

            Text('Ders (opsiyonel)', style: AppTextStyles.bodySecondary),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: subjects.map((s) {
                final isSelected = _selectedSubjectId == s.id;
                return ChoiceChip(
                  label: Text(s.name),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _selectedSubjectId = isSelected ? null : s.id),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            Text('Sınav Tarihi', style: AppTextStyles.bodySecondary),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _pickDate,
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

            Text('Kaç konu var?', style: AppTextStyles.bodySecondary),
            const SizedBox(height: 10),
            TextField(
              controller: _topicCountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: 'Örn. 5'),
            ),

            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _generatePlan,
                child: const Text('Planı Oluştur'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}