import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

// EDİTORYAL REDESIGN (2026-09): Referans görselde büyük/duygusal başlıklar
// ("Good morning, Maya.", "Your rhythm") her zaman serif; küçük/işlevsel
// metinler (meta bilgi, nav, buton) her zaman sans. Bu ayrım burada da
// aynen uygulandı: heading1/heading2 artık Lora (serif) — sayfa/bölüm
// başlıkları için "sessiz lüks" hissi. heading3 ve altı Plus Jakarta
// Sans'ta kalıyor — kart içi alt başlıklar, liste satırları, dialoglar
// referans görselde de kalın-sans okunuyordu, serif değil.
class AppTextStyles {
  AppTextStyles._();

  static TextStyle heading1 = GoogleFonts.lora(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: -0.3,
  );

  static TextStyle heading2 = GoogleFonts.lora(
    fontSize: 21,
    fontWeight: FontWeight.w600,
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
    color: AppColors.ink,
  );

  static TextStyle caption = GoogleFonts.plusJakartaSans(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.textMuted,
  );

  // "BUGÜNÜN ODAĞI" / "BU HAFTA" gibi üst etiketler için tek stil
  // kaynağı. Varsayılan renk artık altın vurgu — referans görselde
  // eyebrow etiketleri ("CRITICAL THINKING") hep vurgu renginde.
  // Ekranlar hâlâ .copyWith(color: ...) ile override edebilir.
  static TextStyle eyebrow = GoogleFonts.plusJakartaSans(
    fontSize: 12,
    fontWeight: FontWeight.w800,
    color: AppColors.primary,
    letterSpacing: 1.1,
  );
}
