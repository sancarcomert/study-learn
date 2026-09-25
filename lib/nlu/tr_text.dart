/// Türkçe metin normalleştirme — NLU'nun TEK metin ön işlemcisi.
///
/// Amaç: "Matematiğim", "matematigim", "MATEMATİĞİM", "matemaatiğim" gibi
/// yazım çeşitliliğinin hepsi aynı ASCII-katlanmış biçime insin; böylece
/// diyakritiksiz yazan öğrenci ("calisamadim", "yetismiyor") ile düzgün yazan
/// ("çalışamadım", "yetişmiyor") aynı kalıba düşer.
class TrText {
  const TrText._();

  static const Map<String, String> _fold = {
    'ç': 'c',
    'Ç': 'c',
    'ğ': 'g',
    'Ğ': 'g',
    'ı': 'i',
    'İ': 'i',
    'I': 'i',
    'ö': 'o',
    'Ö': 'o',
    'ş': 's',
    'Ş': 's',
    'ü': 'u',
    'Ü': 'u',
    'â': 'a',
    'Â': 'a',
    'î': 'i',
    'Î': 'i',
    'û': 'u',
    'Û': 'u',
  };

  /// Küçük harf + ASCII katlama + noktalamayı boşluğa çevirme + gereksiz
  /// tekrar eden harfleri sadeleştirme ("çoooook" → "cok"). Çıktı yalnız
  /// `a-z0-9_` ve tek boşluk içerir (`_` yer tutucu jetonlar için).
  static String fold(String input) {
    final b = StringBuffer();
    for (final rune in input.runes) {
      final ch = String.fromCharCode(rune);
      if (rune == 0x307) continue; // "İ".toLowerCase() sonrası birleşik nokta
      b.write(_fold[ch] ?? ch);
    }
    var s = b.toString().toLowerCase();
    // Kesme işareti/tire kelimeyi bölmesin: "matematik'te" → "matematikte".
    s = s.replaceAll(RegExp("['’`´]"), '');
    s = s.replaceAll(RegExp(r'[^a-z0-9_]+'), ' ');
    // 3+ aynı harf → 1 ("çoook", "yaaaa"); 2 aynı harf Türkçede meşru.
    s = s.replaceAllMapped(RegExp(r'([a-z])\1{2,}'), (m) => m[1]!);
    return s.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static List<String> tokens(String folded) =>
      folded.isEmpty ? const [] : folded.split(' ');

  /// Anlam taşımayan dolgu/hitap sözcükleri — eşleştirmede yok sayılır.
  /// "hiç" ve "çok" BİLEREK burada yok: olumsuzluk/şiddet taşırlar.
  static const Set<String> stopwords = {
    'ya',
    'yaa',
    'abi',
    'abla',
    'hocam',
    'kanka',
    'lan',
    'la',
    'valla',
    'yani',
    'iste',
    'galiba',
    'herhalde',
    'sanirim',
    'bence',
    'aslinda',
    'ki',
    'de',
    'da',
    'mi',
    'mu',
    'bu',
    'su',
    'o',
    'bir',
    'bi',
    've',
    'ile',
    'icin',
    'gibi',
    'diye',
    'hani',
    'sey',
    'hadi',
    'bak',
    'ayrica',
    'ben',
    'bana',
    'benim',
    'beni',
    'lutfen',
    'rica',
    'zaten',
    'falan',
    'filan',
    'ama',
    'fakat',
    'ise',
    'miyim',
    'miyiz',
    'musun',
    'misin',
  };

  /// İki jeton arasındaki benzerlik (0..1). Türkçe çekim eki bolluğu yüzünden
  /// kök öneki esas alınır; yazım hataları için tek harf farkı tolere edilir.
  static double tokenSimilarity(String a, String b) {
    if (a == b) return 1.0;
    final shorter = a.length <= b.length ? a : b;
    final longer = a.length <= b.length ? b : a;
    // "geri" ↔ "gerideyim", "calis" ↔ "calisiyorum".
    if (shorter.length >= 4 && longer.startsWith(shorter)) return 0.9;
    if (shorter.length >= 5 && _commonPrefix(a, b) >= 5) {
      // Aynı kök, farklı çekim ("calisamadim" ↔ "calisiyorum") — kısmi puan;
      // anlam ters olabilir, kesinliği kural katmanı verir.
      return 0.6;
    }
    if (a.length >= 5 && b.length >= 5 && (a.length - b.length).abs() <= 1) {
      if (_withinOneEdit(a, b)) return 0.85;
    }
    return 0.0;
  }

  static int _commonPrefix(String a, String b) {
    final n = a.length < b.length ? a.length : b.length;
    var i = 0;
    while (i < n && a.codeUnitAt(i) == b.codeUnitAt(i)) {
      i++;
    }
    return i;
  }

  /// Levenshtein ≤ 1 (ekleme/silme/değiştirme) ya da bitişik harf yer
  /// değiştirmesi ("matmatik" ↔ "matematik" ekleme; "calsiyorum" ↔ "calisiyorum").
  static bool _withinOneEdit(String a, String b) {
    if (a == b) return true;
    if (a.length == b.length) {
      var diff = 0;
      final idx = <int>[];
      for (var i = 0; i < a.length; i++) {
        if (a.codeUnitAt(i) != b.codeUnitAt(i)) {
          diff++;
          idx.add(i);
          if (diff > 2) return false;
        }
      }
      if (diff == 1) return true;
      if (diff == 2 &&
          idx[1] == idx[0] + 1 &&
          a.codeUnitAt(idx[0]) == b.codeUnitAt(idx[1]) &&
          a.codeUnitAt(idx[1]) == b.codeUnitAt(idx[0])) {
        return true; // bitişik yer değiştirme
      }
      return false;
    }
    final longer = a.length > b.length ? a : b;
    final shorter = a.length > b.length ? b : a;
    var i = 0;
    var j = 0;
    var skipped = false;
    while (i < longer.length && j < shorter.length) {
      if (longer.codeUnitAt(i) == shorter.codeUnitAt(j)) {
        i++;
        j++;
      } else {
        if (skipped) return false;
        skipped = true;
        i++;
      }
    }
    return true;
  }
}
