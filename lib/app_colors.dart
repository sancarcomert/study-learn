import 'package:flutter/material.dart';

// Midnight Dark + Champagne Gold (2026-09, sprint pivot — parşömen/lacivert
// editoryal sistemin yerini aldı). Token isimleri korundu.
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFFD4AF6A);
  static const Color accent = Color(0xFFD4AF6A);

  static const Color secondary = Color(0xFF7A7FB5);

  static const Color background = Color(0xFF0F1115);
  static const Color surface = Color(0xFF1A1C22);
  static const Color surfaceVariant = Color(0xFF22242C);

  static const Color ink = Color(0xFF0B0C10);

  static const Color textPrimary = Color(0xFFF0ECE1);
  static const Color textSecondary = Color(0xFFAFABA3);
  static const Color textMuted = Color(0xFF7C7871);

  static const Color success = Color(0xFF7FA089);
  static const Color warning = Color(0xFFC9915A);
  static const Color danger = Color(0xFFC0524A);
  static const Color info = Color(0xFF7A8FBF);

  static const Color priorityLow = info;
  static const Color priorityMedium = warning;
  static const Color priorityHigh = Color(0xFFC97A66);

  static const List<Color> subjectPalette = [
    Color(0xFFA79FC9),
    Color(0xFF8FB39A),
    Color(0xFF8FA8C9),
    Color(0xFFB98A5E),
    Color(0xFFC79797),
    Color(0xFF7FB3AC),
  ];

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.45),
          blurRadius: 24,
          spreadRadius: 0,
          offset: const Offset(0, 10),
        ),
      ];

  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.30),
          blurRadius: 14,
          offset: const Offset(0, 4),
        ),
      ];

  static Color tonal(Color base) => base.withOpacity(0.14);
}
