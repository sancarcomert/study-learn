import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';
import 'tap_scale.dart';
import 'subject_provider.dart';
import 'task_provider.dart';
import 'stats_provider.dart';
import 'user_stats_model.dart';
import 'widgets/app_buttons.dart';
import 'widgets/eyebrow.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _nameController = TextEditingController();
  final _customSubjectController = TextEditingController();
  String? _selectedSubject;
  int? _selectedGrade; // 9–12 = lise, 13 = Mezun

  static const List<(int, String)> _grades = [
    (9, '9'),
    (10, '10'),
    (11, '11'),
    (12, '12'),
    (UserStatsModel.mezun, 'Mezun'),
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
    _nameController.dispose();
    _customSubjectController.dispose();
    super.dispose();
  }

  void _startWithSubject() {
    final subjectName = _selectedSubject ?? _customSubjectController.text.trim();
    if (subjectName.isEmpty) return;

    final colorValue = AppColors.subjectPalette.first.toARGB32();
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

  void _skip() => _completeOnboarding();

  void _completeOnboarding() {
    // MainShell'e geçişi burada elle YAPMIYORUZ: app.dart zaten
    // statsProvider.hasCompletedOnboarding'i izliyor ve bu flag true
    // olunca home'u reaktif olarak MainShell'e çeviriyor.
    final stats = ref.read(statsProvider.notifier);

    final name = _nameController.text.trim();
    if (name.isNotEmpty) stats.updateUserName(name);

    if (_selectedGrade != null) {
      stats.setGradeLevel(_selectedGrade);
      // Sınıfa göre nazik bir varsayılan günlük hedef: 11–12 + mezun yoğun
      // dönemde, 2 görev/gün daha gerçekçi. 9–10 alışkanlık kuruyor → 1'de kal.
      if (UserStatsModel.isExamFocused(_selectedGrade)) {
        stats.updateDailyGoal(2);
      }
    }

    stats.markOnboardingCompleted();
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
                Text('Hoş geldin 👋', style: AppTextStyles.heading1),
                const SizedBox(height: 8),
                Text(
                  'Kısaca tanışalım, hemen başlıyoruz.',
                  style: AppTextStyles.bodySecondary,
                ),

                const SizedBox(height: 32),

                const Eyebrow(text: 'ADIN'),
                const SizedBox(height: 10),
                TextField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    hintText: 'Adın soyadın',
                  ),
                  onChanged: (_) => setState(() {}),
                ),

                const SizedBox(height: 28),

                const Eyebrow(text: 'SINIF'),
                const SizedBox(height: 10),
                Text(
                  'Planı ve tonu sana göre ayarlayalım.',
                  style: AppTextStyles.bodySecondary,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.surfaceVariant),
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _grades.map((g) {
                      final selected = _selectedGrade == g.$1;
                      return TapScale(
                        onTap: () => setState(
                            () => _selectedGrade = selected ? null : g.$1),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            // CTA hiyerarşisi: altın yalnız "Başlayalım"
                            // butonu için.
                            color: selected
                                ? AppColors.secondary
                                : AppColors.tonal(AppColors.secondary),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            g.$2,
                            style: AppTextStyles.body.copyWith(
                              color: selected
                                  ? AppColors.onColor(AppColors.secondary)
                                  : AppColors.secondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 28),

                const Eyebrow(text: 'HANGİ DERS'),
                const SizedBox(height: 10),
                Text(
                  'Başlamak için bir ders seç — sonra istediğini eklersin.',
                  style: AppTextStyles.bodySecondary,
                ),
                const SizedBox(height: 12),

                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.surfaceVariant),
                  ),
                  child: Wrap(
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
                                ? AppColors.secondary
                                : AppColors.tonal(AppColors.secondary),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            subject,
                            style: AppTextStyles.body.copyWith(
                              color: isSelected
                                  ? AppColors.onColor(AppColors.secondary)
                                  : AppColors.secondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 16),

                TextField(
                  controller: _customSubjectController,
                  decoration: const InputDecoration(
                    hintText: 'Ya da kendi dersini yaz',
                  ),
                  onChanged: (value) {
                    setState(() {
                      if (value.isNotEmpty) _selectedSubject = null;
                    });
                  },
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
