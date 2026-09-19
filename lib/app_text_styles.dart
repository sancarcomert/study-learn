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

  // 2026-09-19: Mentora referansı ("Günaydın, Eda", "Dersler") düz, kalın
  // bir sans kullanıyor — serif (Lora) "sessiz lüks" kimliği bu pivotla
  // terk edildi. Plus Jakarta Sans zaten gömülü/offline olduğu için yeni
  // font eklenmedi, yalnızca ağırlık arttı.
  static TextStyle get heading1 => GoogleFonts.plusJakartaSans(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
        letterSpacing: -0.5,
        height: 1.18,
      );

  static TextStyle get heading2 => GoogleFonts.plusJakartaSans(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
        letterSpacing: -0.3,
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
  // kaynağı. Varsayılan renk marka vurgusu (violet) — bu stil onlarca
  // ekranda paylaşıldığı için varsayılanı rose'a çekmek (Figma'daki
  // eyebrow rengi) her yerde istenmeyen kırmızıya yol açtı (bkz.
  // app_colors.dart secondary notu). Ekranlar .copyWith(color: ...) ile
  // override edebilir — Mentora ekranlarında rose yerel olarak uygulanıyor.
  static TextStyle get eyebrow => GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: AppColors.primary,
        letterSpacing: 1.4,
      );
}
