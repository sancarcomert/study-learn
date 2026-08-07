import 'package:flutter/material.dart';
import '../app_colors.dart';

/// Birincil aksiyon butonu — mor, pill şekilli. "Planımı Oluştur" gibi
/// uygulamanın ana AI/aksiyon eylemleri için tek kaynak.
class PrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;

  const PrimaryButton({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          // Disabled durumu artık Material'ın varsayılan gri tonuna
          // değil, tasarım sistemindeki nötr tonlara bağlı.
          disabledBackgroundColor: AppColors.tonal(AppColors.textSecondary),
          disabledForegroundColor: AppColors.textMuted,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(27),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: Colors.white),
              const SizedBox(width: 8),
            ],
            Text(label),
          ],
        ),
      ),
    );
  }
}

/// İkincil/kapatma aksiyonu — koyu (ink), pill şekilli. "Tamam, Ana
/// Ekrana Dön" gibi nötr ama önemli eylemler için tek kaynak.
class DarkButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const DarkButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.ink,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.tonal(AppColors.textSecondary),
          disabledForegroundColor: AppColors.textMuted,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(27),
          ),
        ),
        child: Text(label),
      ),
    );
  }
}