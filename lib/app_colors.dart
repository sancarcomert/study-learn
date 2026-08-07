import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Brand — referans tasarımdan alınan canlı palet (violet + yeşil
  // ana ikili). Az nötr, çok renk felsefesi — Duolingo/Kahoot tarzı
  // canlı, öğrenci kitlesine uygun.
  static const Color primary = Color(0xFF7F86FF);

  // İkincil marka rengi — referans paletteki yeşil.
  static const Color secondary = Color(0xFF49B583);
  static const Color accent = Color(0xFFFFBD69);

  // Backgrounds
  // Sıcak, hafif kırık beyaz — Home/Smart Plan'da kullanılan referans
  // tonu artık tek kaynaktan geliyor. Önceki değer #F8FAFC idi.
  static const Color background = Color(0xFFFAF9FF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF1F5F9);

  // Koyu/ikincil aksiyon rengi — Smart Plan sonuç butonu ve
  // WeekStrip "bugün" vurgusu artık bu tek token'ı paylaşıyor.
  static const Color ink = Color(0xFF14151A);

  // Text
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);

  // Status
  static const Color success = Color(0xFF49B583);
  static const Color warning = Color(0xFFFFBD69);
  // NOT: Referans palette 4 renk (violet/yeşil/amber/pembe-kırmızı)
  // veriyor ama sistemde bundan fazla anlam var (primary, danger,
  // priorityHigh hepsi ayrı ayrı net olmalı). Danger'ı bilinçli olarak
  // bu 4'ün dışında, koyu/net bir kırmızıda tuttum — "sil" gibi geri
  // dönüşü olmayan bir aksiyonun rengi asla başka bir anlamla
  // karışmamalı. Referansın pembe-kırmızısı (#FF4171) priorityHigh'a
  // verildi (aşağıda).
  static const Color danger = Color(0xFFB91C1C);
  static const Color info = Color(0xFF3B82F6);

  // Priorities
  static const Color priorityLow = Color(0xFF60A5FA);
  static const Color priorityMedium = Color(0xFFFBBF24);
  // Referans paletteki pembe-kırmızı — primary(violet)'ten ve
  // danger(koyu kırmızı)'dan net ayrışıyor.
  static const Color priorityHigh = Color(0xFFFF4171);

  // Subject colors — ilk 4'ü referans paletin ta kendisi, kalanlar
  // aynı canlılıkta çeşitlilik için.
  static const List<Color> subjectPalette = [
    Color(0xFF7F86FF),
    Color(0xFFFF4171),
    Color(0xFFFFBD69),
    Color(0xFF49B583),
    Color(0xFFEC4899),
    Color(0xFF8B5CF6),
    Color(0xFF14B8A6),
    Color(0xFF06B6D4),
  ];

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 24,
          spreadRadius: 0,
          offset: const Offset(0, 10),
        ),
      ];

  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.03),
          blurRadius: 14,
          offset: const Offset(0, 4),
        ),
      ];

  // Tonal (düşük opaklıklı) arka plan — "bu rengin açık/tonal versiyonu
  // nedir" sorusunun TEK cevabı. Sabit %8 opaklık; ekranlar artık kendi
  // opaklık sayısını icat etmiyor.
  static Color tonal(Color base) => base.withOpacity(0.08);
}