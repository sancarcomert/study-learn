import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../app_text_styles.dart';
import '../tap_scale.dart';

/// Boş durum kartı — home_screen.dart ve subjects_screen.dart'ta
/// birbirinden bağımsız iki kopya olarak duruyordu. Artık tek kaynak
/// burası; ikisi de bu widget'ı kullanıyor.
class EmptyStateCard extends StatelessWidget {
  final IconData icon;
  final String message;
  final VoidCallback? onTap;

  /// Mesajın altına, ekstra bir eylem/CTA için opsiyonel slot (ör. "Yaygın
  /// konuları ekle" butonu) — konu listesi ekranındaki özel boş durumun bu
  /// paylaşılan widget'a taşınabilmesi için eklendi (P0-8).
  final Widget? extra;

  const EmptyStateCard({
    super.key,
    required this.icon,
    required this.message,
    this.onTap,
    this.extra,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.tonal(AppColors.primary),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySecondary,
          ),
          if (extra != null) ...[
            const SizedBox(height: 18),
            extra!,
          ],
        ],
      ),
    );

    return onTap != null ? TapScale(onTap: onTap, child: content) : content;
  }
}