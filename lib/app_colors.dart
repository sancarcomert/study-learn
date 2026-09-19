import 'package:flutter/material.dart';

// Midnight Dark + Champagne Gold (2026-09, sprint pivot — parşömen/lacivert
// editoryal sistemin yerini aldı). Token isimleri korundu.
// 2026-09-16: primary kısa süreliğine turuncu/amber'a çekildi (Figma AI
// konsepti), sonra kullanıcı canlıda görünce geri istedi — "adam akıllı
// renk değil" geri bildirimiyle champagne gold'a DÖNDÜ. Rakip araştırması
// zaten gold'u destekliyordu (kimse sıcak koyu tema + altın kullanmıyor);
// turuncu konseptin geri kalanı (hero kart iskeleti, metrik kartları vb.)
// korunuyor, yalnız vurgu rengi değişti.
//
// 2026-09-18: açık tema eklendi. Gerekçe — rakip taraması genişletildiğinde
// hiçbir YKS rakibinin koyu tema kullanmadığı (biri hariç, o da soğuk/
// puanı düşük) ve bunun tesadüf olmayabileceği görüldü: çalışma
// uygulamaları uzun süre yoğun metin okutuyor, koyu zeminde açık metin
// uzun okumalarda göz yorgunluğu/halasyon riski taşıyor (Kindle gibi asıl
// işi okutmak olan uygulamalar bile koyu temayı varsayılan değil opsiyon
// yapıyor). "Kimsede yok" tek başına kanıt değildi — zorunlu tek-tema
// olarak koyu, gerçek bir risktenmiş. Çözüm: koyu kimliği (marka
// farklılaşması için hâlâ değerli) ATMAK değil, kullanıcıya seçenek
// sunmak. Açık temada altın vurgu KORUNUYOR (marka sürekliliği) ama
// çıplak metin/ikon olarak kullanıldığında beyaz zeminde yeterli kontrast
// için daha koyu bir "antika altın" tonuna çekildi — pastel adaçayı/krem
// kombinasyonuna KAYMADIK (o kombinasyon ayrı bir araştırmada 2026
// tasarım söyleminde klişe ilan edildiği görüldü), yalnız nötr bir beyaz
// zemin + kendi altın kimliğimiz kullanılıyor.
enum AppThemeMode { light, dark }

// 2026-09-19: "Mentora" Figma referansıyla ikinci büyük pivot — Midnight
// Dark + Champagne Gold kimliği tamamen emekli edildi, yerine "True Cloud"
// açık tema + Asil Violet vurgu geldi. Token isimleri yine korundu (primary/
// secondary/background/surface vb.) — yalnız değerler değişti. Gerekçe:
// kullanıcının kendi/temin ettiği Figma tasarımı (Mentora) referans alındı,
// hex kodları doğrudan o tasarımdan (violet-600 marka vurgusu, rose-600
// eyebrow/tarih rengi, saf beyaz kartlar + slate-100 kenarlık + ultra hafif
// gölge, ders başına pastel simge rengi). Koyu tema (kullanıcı tarafından
// referans verilmedi) analog olarak aynı violet kimliğine taşındı, yapısal
// (background/surface) değerlere dokunulmadı — yalnız vurgu rengi.
class AppColors {
  AppColors._();

  static AppThemeMode _mode = AppThemeMode.light;

  static void setMode(AppThemeMode mode) => _mode = mode;
  static bool get isDark => _mode == AppThemeMode.dark;

  // Asil violet — CTA'lar, aktif sekme, odak halkası/border, chat gönder
  // butonu. Tailwind violet-600 (#7C3AED) esas alındı; koyu temada okunurluk
  // için bir ton açık (violet-400).
  static Color get primary =>
      isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED);
  static Color get accent => primary;

  // 2026-09-19 düzeltme: rose-600'e çekilmişti (Figma eyebrow/tarih rengini
  // birebir yakalamak için) ama `secondary` uygulama genelinde 10+ dosyada
  // "nötr dekoratif vurgu" rolünde zaten kullanılıyordu (seçili pil, ikon
  // rozeti, öncelik göstergesi vb.) — rose'a çekilince hepsi istemeden
  // kırmızıya döndü. secondary eski nötr rolüne geri döndü; Figma'nın rose
  // eyebrow rengi artık AppTextStyles.eyebrow'un paylaşılan varsayılanı
  // DEĞİL, yalnız Mentora ekranlarına özel yerel bir renk.
  static Color get secondary =>
      isDark ? const Color(0xFF9B7A94) : const Color(0xFF7D5A76);

  static Color get background =>
      isDark ? const Color(0xFF0F1115) : const Color(0xFFF8FAFC);
  static Color get surface =>
      isDark ? const Color(0xFF1A1C22) : const Color(0xFFFFFFFF);
  static Color get surfaceVariant =>
      isDark ? const Color(0xFF22242C) : const Color(0xFFF1F5F9);

  // Kartların ince "slate-100" kenarlığı — Figma'da düz beyaz kartları
  // zeminden ayıran tek şey (gölge neredeyse görünmez, bkz. cardShadow).
  static Color get border =>
      isDark ? const Color(0xFF262A33) : const Color(0xFFF1F5F9);

  // Violet zemin üzerindeki metin/ikon rengi — buton dolgusu sabit violet
  // olduğu için sayfa zeminine göre değişmiyor.
  static const Color ink = Color(0xFF0B0C10);

  static Color get textPrimary =>
      isDark ? const Color(0xFFF0ECE1) : const Color(0xFF0F172A);
  static Color get textSecondary =>
      isDark ? const Color(0xFFAFABA3) : const Color(0xFF64748B);
  static Color get textMuted =>
      isDark ? const Color(0xFF7C7871) : const Color(0xFF94A3B8);

  static Color get success =>
      isDark ? const Color(0xFF7FA089) : const Color(0xFF4F7A5C);
  static Color get warning =>
      isDark ? const Color(0xFFC9915A) : const Color(0xFFA8703D);
  static Color get danger =>
      isDark ? const Color(0xFFC0524A) : const Color(0xFFA23C35);
  static Color get info =>
      isDark ? const Color(0xFF7A8FBF) : const Color(0xFF4F5F94);

  static Color get priorityLow => info;
  static Color get priorityMedium => warning;
  static Color get priorityHigh =>
      isDark ? const Color(0xFFC97A66) : const Color(0xFFA85A48);

  // Canlı/renkli vurgu paleti (2026-09, kullanıcı isteğiyle) — istatistik/
  // özet kartlarını tek nötr "surface" yerine kategoriye göre renklendirmek
  // için. subjectPalette'ten (dersler, bilinçli desatüre) ayrı: bunlar
  // doygun/enerjik, koyu zeminde gerçekten "cıvıl cıvıl" hissettirsin diye.
  // Açık temada aynı aileler korunuyor, yalnız beyaz zeminde yeterli
  // kontrast için koyulaştırıldı.
  static Color get vibrantMint =>
      isDark ? const Color(0xFF3DDC97) : const Color(0xFF1FA876);
  static Color get vibrantCoral =>
      isDark ? const Color(0xFFFF7A6B) : const Color(0xFFE05B4B);
  static Color get vibrantSky =>
      isDark ? const Color(0xFF4FC3F7) : const Color(0xFF1F8FCC);
  // 2026-09-19: artık `primary` ile aynı — Mentora referansında Çalışma
  // Koçu'nun kendi ayrı bir "Coach mor"u yok, uygulama genelindeki tek
  // violet marka rengini kullanıyor (bkz. Yapay Zeka Öğretmeni ekranı).
  // Token yalnızca 7 çağrı yerini kırmamak için tutuluyor.
  static Color get vibrantViolet => primary;
  static Color get vibrantAmber =>
      isDark ? const Color(0xFFFFC857) : const Color(0xFFD69A2E);

  // 2026-09-19: Mentora referansındaki ders ikon renkleriyle birebir —
  // Matematik (soft mor), Fizik (soft pembe), Kimya (soft turuncu), Mantık
  // (soft yeşil) + palet 6 rengi korumak için mavi/turkuaz eklendi. Yumuşak
  // "pastel kutu" arka planı bu renklerden AppColors.tonal() ile türetiliyor
  // (mevcut desen), ayrı bir "pastel bg" tokenına gerek yok.
  static List<Color> get subjectPalette => isDark
      ? const [
          Color(0xFFA78BFA),
          Color(0xFFFB7185),
          Color(0xFFFB923C),
          Color(0xFF34D399),
          Color(0xFF60A5FA),
          Color(0xFF2DD4BF),
        ]
      : const [
          Color(0xFF7C3AED),
          Color(0xFFDB2777),
          Color(0xFFEA580C),
          Color(0xFF059669),
          Color(0xFF2563EB),
          Color(0xFF0D9488),
        ];

  // Kral buton gradyanı (2026-09-19: gold yerine asil violet) — Home'daki
  // "Bugünü Planla" butonundan çıkıp PrimaryButton'a (uygulama genelindeki
  // tüm birincil CTA'lar) da taşındı, tek kaynaktan. İki durak da aynı
  // aileden (Figma'daki düz violet-600 hissini korumak için neredeyse
  // solid — çok hafif bir üst-alt parlaklık farkı var, yassı durmasın diye).
  static LinearGradient get primaryGradient => LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: isDark
            ? const [Color(0xFF8B5CF6), Color(0xFFA78BFA)]
            : const [Color(0xFF7C3AED), Color(0xFF6D28D9)],
      );

  // 2026-09-19: Home'un puan/seri kartı için paylaşılan tokenlar (önceden
  // home_screen.dart içinde yerel sabitlerdi) — Figma'daki sabit koyu lacivert
  // kart her iki temada da aynı, sayfa zeminine göre değişmiyor.
  static const Color heroDark = Color(0xFF12142A);
  static const Color heroDarkChip = Color(0xFF1F2240);

  /// Haftalık görev ilerleme çubuğu — Figma'da turuncu/kırmızı-turuncu,
  /// marka violetinden bilinçli olarak ayrı (kart zaten koyu+violet rozet
  /// içeriyor, ikinci bir vurgu rengi çubuğu öne çıkarıyor).
  static LinearGradient get progressOrange => const LinearGradient(
        colors: [Color(0xFFFB923C), Color(0xFFEF4444)],
      );

  /// Figma'daki tarih/bölüm eyebrow'u (rose-600) — yalnız Mentora
  /// ekranlarının kendi yerel kullanımı, AppTextStyles.eyebrow'un paylaşılan
  /// varsayılanını DEĞİŞTİRMİYOR (bkz. secondary/eyebrow notu yukarıda —
  /// aynı hatayı ikinci kez yapmamak için bilinçli ayrım).
  static Color get eyebrowRose =>
      isDark ? const Color(0xFFFB7185) : const Color(0xFFE11D48);

  /// Profil avatarının Figma'daki mercan/turuncu halkası.
  static const Color avatarRing = Color(0xFFFB7A5C);

  /// Bir rengin etrafına yumuşak, o renkte parıltı gölgesi — birincil
  /// CTA'ları düz kartlardan ayırmak için (cardShadow'un üstüne eklenir).
  /// 2026-09-16: yoğunluk düşürüldü (0.35→0.20 alpha, 28→16 blur) —
  /// kullanıcı geri bildirimi: her ekranda aynı parıltı "yüze vuruyordu",
  /// hiçbir yer özel hissettirmiyordu. Artık her CTA'da SESSİZCE duruyor;
  /// Home'un hero'su parıltıdan değil kompozisyondan (rozet+metrik+
  /// sparkline) öne çıkıyor.
  static BoxShadow glow(Color color) => BoxShadow(
        color: color.withValues(alpha: 0.20),
        blurRadius: 16,
        offset: const Offset(0, 6),
      );

  // 2026-09-19: açık temada Figma spesifikasyonu birebir —
  // `shadow-[0_8px_30px_rgba(0,0,0,0.02)]`, neredeyse görünmez, kartı
  // kenarlıktan (border) ayırmaya yetecek kadar. Koyu tema referansı
  // verilmedi, mevcut değer korundu.
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.02),
          blurRadius: isDark ? 24 : 30,
          spreadRadius: 0,
          offset: const Offset(0, 8),
        ),
      ];

  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.03),
          blurRadius: isDark ? 14 : 20,
          offset: const Offset(0, 4),
        ),
      ];

  static Color tonal(Color base) => base.withValues(alpha: isDark ? 0.14 : 0.12);

  /// Bir zeminin üzerine konacak metin/ikon rengi. Saf kontrast-oranı
  /// karşılaştırması (WCAG) denendi ama orta tonlar için (ör. secondary,
  /// warning) matematiksel "kazanan" ink çıkıyor olsa da beyaz zaten
  /// ekranda iyi okunuyordu — sayı ile göz farklı şey söylüyordu. Bunun
  /// yerine deneysel bir parlaklık eşiği: eşiğin altında (secondary,
  /// danger, warning, vibrantCoral/Violet gibi orta tonlar) beyaz zaten
  /// çalışıyordu, dokunma; eşiğin üstünde (primary/altın ve vibrantMint/
  /// Sky/Amber gibi gerçekten açık tonlar) beyaz neredeyse görünmez,
  /// ink gerekiyor.
  static Color onColor(Color background) =>
      background.computeLuminance() > 0.40 ? ink : Colors.white;
}
