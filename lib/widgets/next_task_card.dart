import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../app_text_styles.dart';
import '../task_model.dart';
import '../subject_model.dart';

class NextTaskCard extends StatelessWidget {
  final TaskModel? task;
  final List<SubjectModel> subjects;

  const NextTaskCard({
    super.key,
    required this.task,
    required this.subjects,
  });

  @override
  Widget build(BuildContext context) {
    if (task == null || task!.scheduledTime == null) {
      return Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(26),
          boxShadow: AppColors.cardShadow,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.event_available_rounded,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                "Planlanmış sonraki görev yok",
                style: AppTextStyles.body,
              ),
            ),
          ],
        ),
      );
    }

    final scheduled = task!.scheduledTime!;

  SubjectModel? subject;

for (final s in subjects) {
  if (s.id == task!.subjectId) {
    subject = s;
    break;
  }
}

    final endTime = scheduled.add(
      Duration(minutes: task!.estimatedMinutes ?? 0),
    );

    final now = DateTime.now();
    final difference = scheduled.difference(now);

    String status;

    if (task!.isCompleted) {
      status = "Tamamlandı 🎉";
    } else if (difference.inMinutes > 0) {
      status = "${difference.inMinutes} dakika sonra başlayacak";
    } else {
      status = "Başlama zamanı geldi";
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.schedule_rounded,
                  color: AppColors.primary,
                ),
              ),

              const SizedBox(width: 12),

              Text(
                "Sıradaki Görev",
                style: AppTextStyles.heading2,
              ),
            ],
          ),

          const SizedBox(height: 22),

          if (subject != null)
            Text(
              subject.name,
              style: AppTextStyles.bodySecondary.copyWith(
                color: Color(subject.colorValue),
                fontWeight: FontWeight.bold,
              ),
            ),

          const SizedBox(height: 6),

          Text(
            task!.title,
            style: AppTextStyles.heading1,
          ),

          const SizedBox(height: 20),

          Row(
            children: [
              const Icon(
                Icons.access_time_rounded,
                size: 18,
                color: AppColors.textSecondary,
              ),

              const SizedBox(width: 6),

              Text(
                "${scheduled.hour.toString().padLeft(2, '0')}:${scheduled.minute.toString().padLeft(2, '0')}",
                style: AppTextStyles.body,
              ),

              const SizedBox(width: 20),

              const Icon(
                Icons.timer_outlined,
                size: 18,
                color: AppColors.textSecondary,
              ),

              const SizedBox(width: 6),

              Text(
                "${task!.estimatedMinutes ?? 0} dk",
                style: AppTextStyles.body,
              ),
            ],
          ),

          const SizedBox(height: 14),

          Text(
            "Bitiş: ${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}",
            style: AppTextStyles.bodySecondary,
          ),

          const SizedBox(height: 14),

          Text(
            status,
            style: AppTextStyles.body.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}