import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,

      scaffoldBackgroundColor: AppColors.background,

      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppTextStyles.heading2,
        iconTheme: const IconThemeData(
          color: AppColors.textPrimary,
        ),
      ),

      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shadowColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),

      // NOT: stock NavigationBar teması burada tanımlı değil artık —
      // MainShell kendi özel alt nav bar'ını (ince outline ikon + altın
      // nokta göstergesi) doğrudan stilliyor, referans görseldeki
      // Material "pill indicator" değil bu desen (bkz. main_shell.dart).

      // Altın zemin üzerinde beyaz değil koyu (ink) metin/ikon — referans
      // görseldeki "Resume lesson" butonuyla aynı kontrast mantığı.
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.ink,
        elevation: 0,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.ink,
          minimumSize: const Size(double.infinity, 56),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceVariant,

        hintStyle: AppTextStyles.bodySecondary,

        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),

        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),

        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: AppColors.primary,
            width: 1.5,
          ),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceVariant,
        selectedColor: AppColors.primary.withOpacity(.12),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),

      dividerTheme: const DividerThemeData(
        thickness: .8,
        color: Color(0xFF2C2E36),
      ),

      // Silme onayı gibi dialoglar artık kartlarla aynı dile konuşuyor:
      // yuvarlak köşe, surface arka plan, sıfır elevation.
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        titleTextStyle: AppTextStyles.heading3,
        contentTextStyle: AppTextStyles.bodySecondary,
      ),

      // SnackBar floating + yuvarlak köşe. Zemin: koyu tema pivotunda "ink"
      // artık neredeyse siyah (sayfa zeminiyle ayırt edilemez), bu yüzden
      // yüzeyden bariz ayrışan surfaceVariant tonu kullanılıyor (karar C).
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceVariant,
        contentTextStyle: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      // Dialog içindeki TextButton'lar (Vazgeç/Sil gibi) artık
      // ColorScheme'in ürettiği rastgele tona değil, marka rengine bağlı.
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
        ),
      ),
    );
  }
}