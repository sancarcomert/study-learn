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
//
// 2026-09-18: hepsi `static TextStyle x = ...` (düz atama) İKEN açık/koyu
// tema eklendi — Dart'ta bu, initializer'ı yalnızca İLK erişimde çalıştırıp
// sonsuza kadar ÖNBELLEKLİYOR. AppColors.textPrimary/textMuted artık
// (mod'a göre değişen) dinamik getter olduğu için, ilk erişim hangi modda
// olduysa o renk EBEDİ olarak donuyordu — sonradan tema değiştirilince
// başlıklar (Lora heading'ler) yanlış/eski renkte kalıp yeni zeminde
// neredeyse görünmez oluyordu (koyu modun kaydedilen açık rengi, açık
// zeminde neredeyse beyaz-üstüne-beyaz). Çözüm: hepsini `get`'e çevirmek —
// AppColors ile birebir aynı desen, her erişimde güncel modu okur.
class AppTextStyles {
  AppTextStyles._();

  static TextStyle get heading1 => GoogleFonts.lora(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        letterSpacing: -0.4,
        height: 1.16,
      );

  static TextStyle get heading2 => GoogleFonts.lora(
        fontSize: 21,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        letterSpacing: -0.2,
        height: 1.2,
      );

  static TextStyle get heading3 => GoogleFonts.plusJakartaSans(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: -0.1,
        height: 1.25,
      );

  static TextStyle get body => GoogleFonts.plusJakartaSans(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
        height: 1.5,
      );

  static TextStyle get bodySecondary => GoogleFonts.plusJakartaSans(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
        height: 1.5,
      );

  static TextStyle get button => GoogleFonts.plusJakartaSans(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
        letterSpacing: 0.2,
      );

  static TextStyle get caption => GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.textMuted,
        height: 1.35,
      );

  // "BUGÜNÜN ODAĞI" / "BU HAFTA" gibi üst etiketler için tek stil
  // kaynağı. Varsayılan renk artık altın vurgu — referans görselde
  // eyebrow etiketleri ("CRITICAL THINKING") hep vurgu renginde.
  // Ekranlar hâlâ .copyWith(color: ...) ile override edebilir.
  static TextStyle get eyebrow => GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: AppColors.primary,
        letterSpacing: 1.4,
      );
}
