import 'package:flutter/material.dart';
import '../app_colors.dart';

/// Birincil aksiyon butonu — altın, pill şekilli. "Planımı Oluştur" gibi
/// uygulamanın ana AI/aksiyon eylemleri için tek kaynak. Altın zemin
/// üzerinde beyaz değil koyu (ink) metin/ikon kullanılıyor — referans
/// görseldeki "Resume lesson" butonuyla aynı kontrast mantığı.
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
      // Kral buton spesifikasyonu: 64dp yükseklik, tam pill (r32).
      // Home'daki _KingButton ile aynı ölçü — tek birincil dil.
      height: 64,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.ink,
          // Disabled durumu artık Material'ın varsayılan gri tonuna
          // değil, tasarım sistemindeki nötr tonlara bağlı.
          disabledBackgroundColor: AppColors.tonal(AppColors.textSecondary),
          disabledForegroundColor: AppColors.textMuted,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(32),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: AppColors.ink),
              const SizedBox(width: 10),
            ],
            Text(label),
          ],
        ),
      ),
    );
  }
}