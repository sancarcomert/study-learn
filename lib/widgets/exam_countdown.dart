import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../app_text_styles.dart';

/// Bugünden [examDate]'e kalan tam gün sayısı. Geçmişse negatif döner.
int daysUntilExam(DateTime examDate) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(examDate.year, examDate.month, examDate.day);
  return target.difference(today).inDays;
}

String examCountdownLabel(int days) {
  if (days < 0) return 'Sınav geçti';
  if (days == 0) return 'Sınav bugün';
  if (days == 1) return 'Sınava 1 gün';
  return 'Sınava $days gün';
}

/// Home header'ının altında görünen ince geri sayım rozeti. Sınav tarihi
/// yoksa hiç render edilmez (çağıran taraf null kontrolü yapar).
class ExamCountdownChip extends StatelessWidget {
  final DateTime examDate;

  const ExamCountdownChip({super.key, required this.examDate});

  @override
  Widget build(BuildContext context) {
    final days = daysUntilExam(examDate);
    if (days < 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.tonal(AppColors.primary),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_outlined, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            examCountdownLabel(days),
            style: AppTextStyles.caption.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
