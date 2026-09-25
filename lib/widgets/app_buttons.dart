import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../app_text_styles.dart';
import '../tap_scale.dart';

/// Birincil aksiyon butonu — altın gradyan + parıltı gölgesi, pill şekilli.
/// "Planımı Oluştur" gibi uygulamanın ana AI/aksiyon eylemleri için tek
/// kaynak. Home'daki kral butonla (_KingButton) aynı görsel dili paylaşır
/// (2026-09 canlı tasarım geçişi) — altın zemin üzerinde beyaz değil koyu
/// (ink) metin/ikon.
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
    final enabled = onPressed != null;
    // 2026-09-19: gold→violet pivotuyla artık zemin KOYU bir renk —
    // sabit ink metin gold'da doğruydu (açık zemin), violet'te neredeyse
    // okunmaz oluyordu. onColor() zeminin parlaklığına göre beyaz/ink
    // seçiyor (violet için beyaz).
    final onPrimary = AppColors.onColor(AppColors.primary);

    return TapScale(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        // Kral buton spesifikasyonu: 64dp yükseklik, tam pill (r32).
        // Home'daki _KingButton ile aynı ölçü — tek birincil dil.
        height: 64,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: enabled ? AppColors.primaryGradient : null,
          color: enabled ? null : AppColors.tonal(AppColors.textSecondary),
          borderRadius: BorderRadius.circular(32),
          boxShadow: enabled
              ? [...AppColors.cardShadow, AppColors.glow(AppColors.primary)]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 20,
                color: enabled ? onPrimary : AppColors.textMuted,
              ),
              const SizedBox(width: 10),
            ],
            Text(
              label,
              style: AppTextStyles.button.copyWith(
                color: enabled ? onPrimary : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Uygulamanın standart FAB'ı — düz altın daire yerine gradyan + parıltı
/// gölgesi, kral buton/PrimaryButton ile aynı birincil-aksiyon dili. Stock
/// `FloatingActionButton` yerine kullanılır (Home/Görevler/Dersler/Deneme
/// "ekle" FAB'ları hepsi bu widget'a taşındı).
class GradientFab extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String? tooltip;

  const GradientFab({
    super.key,
    required this.onPressed,
    this.icon = Icons.add,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final button = TapScale(
      onTap: onPressed,
      child: Container(
        width: 56,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          shape: BoxShape.circle,
          boxShadow: [
            ...AppColors.cardShadow,
            AppColors.glow(AppColors.primary),
          ],
        ),
        child: Icon(icon, color: AppColors.onColor(AppColors.primary)),
      ),
    );

    if (tooltip == null) return button;
    return Semantics(
      button: true,
      label: tooltip,
      excludeSemantics: true,
      child: Tooltip(message: tooltip!, child: button),
    );
  }
}
