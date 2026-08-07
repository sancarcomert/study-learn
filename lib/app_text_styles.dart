import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  static TextStyle heading1 = GoogleFonts.plusJakartaSans(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    letterSpacing: -0.8,
  );

  static TextStyle heading2 = GoogleFonts.plusJakartaSans(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static TextStyle heading3 = GoogleFonts.plusJakartaSans(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static TextStyle body = GoogleFonts.plusJakartaSans(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
    height: 1.4,
  );

  static TextStyle bodySecondary = GoogleFonts.plusJakartaSans(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
    height: 1.4,
  );

  static TextStyle button = GoogleFonts.plusJakartaSans(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: Colors.white,
  );

  static TextStyle caption = GoogleFonts.plusJakartaSans(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.textMuted,
  );

  // "BUGÜNÜN ODAĞI" / "BU HAFTA" gibi üst etiketler için tek stil
  // kaynağı — artık her ekranın kendi .copyWith() ile taklit etmesine
  // gerek yok.
  static TextStyle eyebrow = GoogleFonts.plusJakartaSans(
    fontSize: 12,
    fontWeight: FontWeight.w800,
    color: AppColors.textSecondary,
    letterSpacing: 1.1,
  );
}