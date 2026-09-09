import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';
import 'tap_scale.dart';
import 'subject_provider.dart';
import 'task_provider.dart';
import 'stats_provider.dart';
import 'widgets/app_buttons.dart';
import 'widgets/eyebrow.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  String? _selectedSubject;
  DateTime? _examDate;
  final _customSubjectController = TextEditingController();

  static const List<String> _monthsShort = [
    'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
    'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara',
  ];

  static const List<String> _commonSubjects = [
    'Matematik',
    'Fizik',
    'Kimya',
    'Tarih',
    'İngilizce',
  ];

  @override
  void dispose() {
    _customSubjectController.dispose();
    super.dispose();
  }

  void _startWithSubject() {
    final subjectName = _selectedSubject ?? _customSubjectController.text.trim();
    if (subjectName.isEmpty) return;

    final colorValue = AppColors.subjectPalette.first.value;

    ref.read(subjectProvider.notifier).addSubject(subjectName, colorValue);

    final newSubjects = ref.read(subjectProvider);
    final createdSubject = newSubjects.firstWhere(
      (s) => s.name == subjectName,
      orElse: () => newSubjects.last,
    );

    ref.read(taskProvider.notifier).addTask(
          title: '📌 Örnek: Konu tekrarı yap',
          subjectId: createdSubject.id,
          dueDate: DateTime.now(),
          estimatedMinutes: 30,
        );

    _completeOnboarding();
  }

  void _skip() {
    _completeOnboarding();
  }

  void _completeOnboarding() {
    // MainShell'e geçişi burada elle YAPMIYORUZ: app.dart zaten
    // statsProvider.hasCompletedOnboarding'i izliyor ve bu flag true
    // olunca home'u reaktif olarak MainShell'e çeviriyor. Elle
    // pushReplacement eklemek ikinci bir MainShell (çift IndexedStack,
    // çift timer, ölü State context) yaratıyordu.
    if (_examDate != null) {
      ref.read(statsProvider.notifier).setExamDate(_examDate);
    }
    ref.read(statsProvider.notifier).markOnboardingCompleted();
  }

  Future<void> _pickExamDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _examDate ?? now.add(const Duration(days: 90)),
      firstDate: now,
      lastDate: DateTime(now.year + 3, now.month, now.day),
    );
    if (picked != null && mounted) {
      setState(() => _examDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentSubject =
        _selectedSubject ?? _customSubjectController.text.trim();
    final hasSubject = currentSubject.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),

                const Eyebrow(text: 'BAŞLANGIÇ'),
                const SizedBox(height: 6),

                Text(
                  'Pusula\'ya hoş geldin 👋',
                  style: AppTextStyles.heading1,
                ),

                const SizedBox(height: 8),

                Text(
                  'Sana özel bir başlangıç hazırlayalım.',
                  style: AppTextStyles.bodySecondary,
                ),

                const SizedBox(height: 32),

                const Eyebrow(text: 'HANGİ DERS'),
                const SizedBox(height: 10),

                Text(
                  'Şu an hangi derse çalışıyorsun?',
                  style: AppTextStyles.body,
                ),

                const SizedBox(height: 12),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _commonSubjects.map((subject) {
                    final isSelected = _selectedSubject == subject;
                    return TapScale(
                      onTap: () {
                        setState(() {
                          if (_selectedSubject == subject) {
                            _selectedSubject = null;
                          } else {
                            _selectedSubject = subject;
                            _customSubjectController.clear();
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.tonal(AppColors.primary),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          subject,
                          style: AppTextStyles.body.copyWith(
                            // Altın zeminde beyaz değil koyu metin.
                            color: isSelected ? AppColors.ink : AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),

                TextField(
                  controller: _customSubjectController,
                  decoration: const InputDecoration(
                    hintText: 'Ya da kendi dersini yaz',
                  ),
                  onChanged: (value) {
                    setState(() {
                      if (value.isNotEmpty) {
                        _selectedSubject = null;
                      }
                    });
                  },
                ),

                const SizedBox(height: 28),

                const Eyebrow(text: 'SINAV TARİHİ (OPSİYONEL)'),
                const SizedBox(height: 10),
                TapScale(
                  onTap: _pickExamDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.event_outlined,
                            size: 18, color: AppColors.primary),
                        const SizedBox(width: 10),
                        Text(
                          _examDate == null
                              ? 'Sınav tarihini seç'
                              : '${_examDate!.day} ${_monthsShort[_examDate!.month - 1]} ${_examDate!.year}',
                          style: AppTextStyles.body.copyWith(
                            color: _examDate == null
                                ? AppColors.textSecondary
                                : AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        if (_examDate != null)
                          TapScale(
                            onTap: () => setState(() => _examDate = null),
                            child: const Icon(Icons.close,
                                size: 16, color: AppColors.textMuted),
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                PrimaryButton(
                  label: 'Başlayalım',
                  onPressed: hasSubject ? _startWithSubject : null,
                ),

                const SizedBox(height: 10),

                Center(
                  child: Text(
                    hasSubject
                        ? '$currentSubject dersiyle örnek bir görev oluşturacağız'
                        : 'Başlamak için en az 1 ders seçmelisin.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption,
                  ),
                ),

                const SizedBox(height: 8),

                Center(
                  child: TextButton(
                    onPressed: _skip,
                    child: Text(
                      'Şimdilik atla',
                      style: AppTextStyles.bodySecondary,
                    ),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}