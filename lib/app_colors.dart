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

class AppColors {
  AppColors._();

  static AppThemeMode _mode = AppThemeMode.dark;

  static void setMode(AppThemeMode mode) => _mode = mode;
  static bool get isDark => _mode == AppThemeMode.dark;

  static Color get primary =>
      isDark ? const Color(0xFFD4AF6A) : const Color(0xFFB8863E);
  static Color get accent => primary;

  // 2026-09-18: eskiden indigo-mavi (0xFF7A7FB5/0xFF5B5FA0) — kullanıcı
  // geri bildirimi: "bazı sayfalarda mavi tonlar var, UI amatörlüğü, bir
  // bütünlük gerek". secondary neredeyse her ekranda "nötr dekoratif"
  // rolünde (nav, seçili gün, ikon rozetleri, Plan bento kartları) —
  // soğuk mavi-indigo, sıcak altın kimliğiyle çelişiyordu. Artık sıcak bir
  // erik/gül kurusu tonu — hâlâ gold'dan (CTA) ve vibrantViolet'ten
  // (yalnız Koç) net ayrışıyor ama artık "kurumsal mavi" değil.
  static Color get secondary =>
      isDark ? const Color(0xFF9B7A94) : const Color(0xFF7D5A76);

  static Color get background =>
      isDark ? const Color(0xFF0F1115) : const Color(0xFFFAF9F6);
  static Color get surface =>
      isDark ? const Color(0xFF1A1C22) : const Color(0xFFFFFFFF);
  static Color get surfaceVariant =>
      isDark ? const Color(0xFF22242C) : const Color(0xFFF1EEE7);

  // Altın zemin üzerindeki metin/ikon rengi — her iki temada da aynı
  // (buton dolgusu kendisi zaten sabit gold gradyanı, sayfa zeminine göre
  // değişmiyor).
  static const Color ink = Color(0xFF0B0C10);

  static Color get textPrimary =>
      isDark ? const Color(0xFFF0ECE1) : const Color(0xFF1E1C18);
  static Color get textSecondary =>
      isDark ? const Color(0xFFAFABA3) : const Color(0xFF6B665D);
  static Color get textMuted =>
      isDark ? const Color(0xFF7C7871) : const Color(0xFF9C958A);

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
  static Color get vibrantViolet =>
      isDark ? const Color(0xFFB388FF) : const Color(0xFF8355E0);
  static Color get vibrantAmber =>
      isDark ? const Color(0xFFFFC857) : const Color(0xFFD69A2E);

  // Doygunluğu artırıldı (2026-09, kullanıcı isteğiyle: "cıvıl cıvıl") —
  // aynı renk ailesi (mor/yeşil/mavi/turuncu/pembe/turkuaz) korunuyor,
  // önceki desatüre pastel tonların yerini daha canlı versiyonları aldı.
  static List<Color> get subjectPalette => isDark
      ? const [
          Color(0xFFA78BFA),
          Color(0xFF2DD4A8),
          Color(0xFF38BDF8),
          Color(0xFFFFB347),
          Color(0xFFFB7185),
          Color(0xFF2DD4BF),
        ]
      : const [
          Color(0xFF7C5CE0),
          Color(0xFF1B9C7A),
          Color(0xFF1E88C7),
          Color(0xFFD98A1E),
          Color(0xFFDD5A72),
          Color(0xFF1BA89C),
        ];

  // Kral buton gradyanı (2026-09) — Home'daki "Bugünü Planla" butonundan
  // çıkıp PrimaryButton'a (uygulama genelindeki tüm birincil CTA'lar) da
  // taşındı, tek kaynaktan.
  static LinearGradient get primaryGradient => LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: isDark
            ? const [Color(0xFFD4AF6A), Color(0xFFE8C989)]
            : const [Color(0xFFB8863E), Color(0xFFD4AF6A)],
      );

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

  // Açık temada siyah gölge koyu temadaki kadar yüksek alpha'da kalırsa
  // sert/ağır bir "yapışkan sticker" gölgesi gibi durur — beyaz zeminde
  // gölge zaten kendiliğinden daha görünür olduğu için alpha düşürüldü.
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.10),
          blurRadius: 24,
          spreadRadius: 0,
          offset: const Offset(0, 10),
        ),
      ];

  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.08),
          blurRadius: 14,
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
