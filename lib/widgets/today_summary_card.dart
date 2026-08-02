import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../app_text_styles.dart';

class TodaySummaryCard extends StatelessWidget {
  final int completedCount;
  final int totalCount;

  const TodaySummaryCard({
    super.key,
    required this.completedCount,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: AppColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Bugünün Özeti",
                  style: AppTextStyles.heading2,
                ),
                const SizedBox(height: 4),
                Text(
                   "$completedCount / $totalCount görev tamamlandı",
                  style: AppTextStyles.bodySecondary,
                ),
                const SizedBox(height: 10),

LinearProgressIndicator(
  value: totalCount == 0 ? 0 : completedCount / totalCount,
  minHeight: 8,
  borderRadius: BorderRadius.circular(10),
  backgroundColor: Colors.grey.withOpacity(0.2),
  color: AppColors.primary,
),
              ],
            ),
          ),
        ],
      ),
    );
  }
}