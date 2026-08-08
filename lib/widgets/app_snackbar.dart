import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../app_text_styles.dart';

/// Uygulama genelinde tutarlı SnackBar gösterimi için tek kaynak.
/// Daha önce başarı ("Görev eklendi") ve hata ("Ders adı boş olamaz")
/// mesajları birbirinden ayırt edilemiyordu — hepsi aynı düz kutuydu.
/// Artık her biri kendi ikonu ve vurgu rengiyle ayrışıyor. Temel stil
/// (koyu zemin, yuvarlak köşe, floating) app_theme.dart'taki
/// snackBarTheme'den geliyor, burada sadece ikon/renk ekleniyor.
class AppSnackBar {
  AppSnackBar._();

  static void success(BuildContext context, String message, {Duration? duration}) {
    _show(
      context,
      message,
      icon: Icons.check_circle_rounded,
      iconColor: AppColors.success,
      duration: duration,
    );
  }

  static void error(BuildContext context, String message, {Duration? duration}) {
    _show(
      context,
      message,
      icon: Icons.error_rounded,
      iconColor: AppColors.danger,
      duration: duration,
    );
  }

  static void info(BuildContext context, String message, {Duration? duration}) {
    _show(
      context,
      message,
      icon: Icons.info_rounded,
      iconColor: AppColors.info,
      duration: duration,
    );
  }

  // Silme sonrası "GERİ AL" aksiyonu içeren SnackBar. Silme ne başarı ne
  // hata olduğu için nötr bir ikon/renk kullanılıyor.
  static void undo(
    BuildContext context,
    String message, {
    required VoidCallback onUndo,
    Duration? duration,
  }) {
    _show(
      context,
      message,
      icon: Icons.delete_outline_rounded,
      iconColor: AppColors.textSecondary,
      duration: duration,
      action: SnackBarAction(
        label: 'GERİ AL',
        textColor: AppColors.primary,
        onPressed: onUndo,
      ),
    );
  }

  static void _show(
    BuildContext context,
    String message, {
    required IconData icon,
    required Color iconColor,
    Duration? duration,
    SnackBarAction? action,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: duration ?? const Duration(seconds: 4),
        action: action,
        content: Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: AppTextStyles.body.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}