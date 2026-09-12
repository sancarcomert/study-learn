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

  // Canlı/renkli vurgu paleti (2026-09, kullanıcı isteğiyle) — istatistik/
  // özet kartlarını tek nötr "surface" yerine kategoriye göre renklendirmek
  // için. subjectPalette'ten (dersler, bilinçli desatüre) ayrı: bunlar
  // doygun/enerjik, koyu zeminde gerçekten "cıvıl cıvıl" hissettirsin diye.
  static const Color vibrantMint = Color(0xFF3DDC97);
  static const Color vibrantCoral = Color(0xFFFF7A6B);
  static const Color vibrantSky = Color(0xFF4FC3F7);
  static const Color vibrantViolet = Color(0xFFB388FF);
  static const Color vibrantAmber = Color(0xFFFFC857);

  // Doygunluğu artırıldı (2026-09, kullanıcı isteğiyle: "cıvıl cıvıl") —
  // aynı renk ailesi (mor/yeşil/mavi/turuncu/pembe/turkuaz) korunuyor,
  // önceki desatüre pastel tonların yerini daha canlı versiyonları aldı.
  static const List<Color> subjectPalette = [
    Color(0xFFA78BFA),
    Color(0xFF2DD4A8),
    Color(0xFF38BDF8),
    Color(0xFFFFB347),
    Color(0xFFFB7185),
    Color(0xFF2DD4BF),
  ];

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.45),
          blurRadius: 24,
          spreadRadius: 0,
          offset: const Offset(0, 10),
        ),
      ];

  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.30),
          blurRadius: 14,
          offset: const Offset(0, 4),
        ),
      ];

  static Color tonal(Color base) => base.withValues(alpha: 0.14);

  /// Seçili bir çipin/butonun zemin rengine göre okunabilir metin/ikon
  /// rengi. Tek gerçek risk altın (primary) — o zeminde beyaz neredeyse
  /// görünmez, koyu (ink) gerekir; her yerde beyaz güvenli. Önceden bu
  /// mantık birkaç ekranda ayrı ayrı elle yazılmıştı (add_task_screen,
  /// focus_screen), diğer ekranlarda hiç düşünülmeden çıplak Colors.white
  /// kullanılıyordu — tek yerden yönetiliyor artık.
  static Color onColor(Color background) =>
      background == primary ? ink : Colors.white;
}
