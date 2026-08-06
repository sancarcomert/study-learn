// lib/widgets/smart_plan_banner.dart
import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../app_text_styles.dart';
import '../smart_plan_screen.dart';
import '../tap_scale.dart';

class SmartPlanBanner extends StatelessWidget {
  const SmartPlanBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SmartPlanScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.success.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.success.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: AppColors.success,
                size: 18,
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Text(
                'Bugünü akıllı planla',
                style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}