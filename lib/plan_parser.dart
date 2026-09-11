import 'subject_ai.dart';
import 'subject_model.dart';

/// Serbest metinden ("yarın 2 saat matematik türev", "her pazartesi 45 dk
/// paragraf") görev alanlarını çıkaran YEREL ayrıştırıcı. LLM yok — sadece
/// düzenli ifade + Türkçe anahtar kelime sözlüğü + [SubjectAI].
///
/// Hiçbir yan etkisi yoktur: girdi + ders listesi alır, [ParsedPlan] döndürür.
/// Görev oluşturma çağıran tarafın işi (mevcut `taskProvider.addTask`).
class PlanParser {
  const PlanParser._();

  /// [input]'u ayrıştırır. [subjects] kullanıcının mevcut dersleri — ders adı
  /// eşleştirmesi için gerekir. [now] test edilebilirlik için enjekte edilir.
  static ParsedPlan parse(
    String input, {
    required List<SubjectModel> subjects,
    DateTime? now,
  }) {
    final reference = now ?? DateTime.now();
    final today = DateTime(reference.year, reference.month, reference.day);
    final raw = input.trim();
    if (raw.isEmpty) return const ParsedPlan.empty();

    final lower = _trLower(raw);

    // Ayrıştırma sırasında başlıktan silinecek ham metin parçaları — her biri
    // hangi alanı temsil ettiğini de taşır (bkz. [PlanSpanKind]), böylece
    // çağıran taraf (Koç ekranı) girdiyi canlı renklendirebilir.
    final consumed = <_Consumed>[];

    final duration = _parseDuration(lower, consumed);
    final recurrence = _parseRecurrence(lower, consumed);
    final time = _parseTime(lower, consumed);
    // Tekrar "her <gün>" ise tarih o güne sabitlenir; değilse serbest tarih.
    DateTime? date = _parseRecurringWeekday(lower, today, consumed);
    date ??= _parseDate(lower, today, consumed);

    final subjectMatch = _parseSubject(lower, raw, subjects, consumed);

    final title = _cleanTitle(raw, consumed, fallback: subjectMatch?.name);
    final spans = _locateSpans(raw, consumed);

    return ParsedPlan(
      title: title,
      subjectId: subjectMatch?.id,
      subjectName: subjectMatch?.name,
      date: date,
      durationMinutes: duration,
      recurrence: recurrence,
      hour: time?.hour,
      minute: time?.minute,
      spans: spans,
    );
  }

  // --- Saat ---------------------------------------------------------------

  static final RegExp _clock = RegExp(r'(\d{1,2}):(\d{2})');
  // Nokta biçimli saat, ama "1.30 saat" gibi ondalık süreyi DIŞLAR.
  static final RegExp _clockDot =
      RegExp(r'(\d{1,2})\.(\d{2})(?![\d\s]*(saat|sa)\b)');
  // "saat 3" → 03:00; ama "3 saat 15" (bileşik süre) yakalanmaz.
  static final RegExp _saatN = RegExp(r'(?<!\d\s)saat\s*(\d{1,2})');
  static final RegExp _nGibi =
      RegExp(r'(\d{1,2})\s*(gibi|te|ta|de|da)\b');

  static _Time? _parseTime(String lower, List<_Consumed> consumed) {
    final eveningHint = RegExp(r'akşam|aksam|gece|öğleden sonra|ogleden sonra')
        .hasMatch(lower);
    final morningHint = lower.contains('sabah') || lower.contains('öğlen') ||
        lower.contains('oglen');

    final hm = _clock.firstMatch(lower) ?? _clockDot.firstMatch(lower);
    if (hm != null) {
      final h = int.parse(hm.group(1)!);
      final m = int.parse(hm.group(2)!);
      if (h < 24 && m < 60) {
        consumed.add(_Consumed(hm.group(0)!, PlanSpanKind.time));
        return _Time(h, m);
      }
    }

    final sN = _saatN.firstMatch(lower);
    if (sN != null) {
      final h = int.parse(sN.group(1)!);
      if (h < 24) {
        consumed.add(_Consumed(sN.group(0)!, PlanSpanKind.time));
        return _Time(_resolveHour(h, eveningHint, morningHint), 0);
      }
    }

    final g = _nGibi.firstMatch(lower);
    if (g != null) {
      final h = int.parse(g.group(1)!);
      if (h >= 1 && h < 24) {
        consumed.add(_Consumed(g.group(0)!, PlanSpanKind.time));
        return _Time(_resolveHour(h, eveningHint, morningHint), 0);
      }
    }

    // "akşam 8", "sabah 9", "9 sabah" — gün-bölümü sözcüğüne bitişik sayı.
    // Sayının hemen ardından süre birimi gelirse ("akşam 1 saat") saat değil,
    // süredir — yakalama.
    final near = RegExp(
      r'(sabah|akşam|aksam|gece|öğlen|oglen)\s*(\d{1,2})(?!\s*(?:saat|sa|dk|dakika|dakka))|(\d{1,2})\s*(sabah|akşam|aksam|gece|öğlen|oglen)',
    ).firstMatch(lower);
    if (near != null) {
      final digits = near.group(2) ?? near.group(3)!;
      final h = int.parse(digits);
      if (h >= 1 && h < 24) {
        consumed.add(_Consumed(near.group(0)!, PlanSpanKind.time));
        return _Time(_resolveHour(h, eveningHint, morningHint), 0);
      }
    }

    if (RegExp(r'öğleden sonra|ogleden sonra').hasMatch(lower)) {
      consumed.add(const _Consumed('öğleden sonra', PlanSpanKind.time));
      consumed.add(const _Consumed('ogleden sonra', PlanSpanKind.time));
      return const _Time(14, 0);
    }
    if (lower.contains('sabah')) {
      consumed.add(const _Consumed('sabah', PlanSpanKind.time));
      return const _Time(9, 0);
    }
    if (RegExp(r'öğlen|oglen|öğle|ogle').hasMatch(lower)) {
      consumed.add(const _Consumed('öğlen', PlanSpanKind.time));
      consumed.add(const _Consumed('öğle', PlanSpanKind.time));
      return const _Time(12, 30);
    }
    if (lower.contains('akşam') || lower.contains('aksam')) {
      consumed.add(const _Consumed('akşam', PlanSpanKind.time));
      return const _Time(19, 0);
    }
    if (lower.contains('gece')) {
      consumed.add(const _Consumed('gece', PlanSpanKind.time));
      return const _Time(21, 0);
    }
    return null;
  }

  /// Yalın saat (1..8) ve sabah ipucu yoksa çalışma bağlamında öğleden
  /// sonra kabul edilir; akşam/gece ipucu varsa 12'den küçükse +12.
  static int _resolveHour(int h, bool eveningHint, bool morningHint) {
    if (eveningHint && h < 12) return h + 12;
    if (!morningHint && h >= 1 && h <= 8) return h + 12;
    return h;
  }

  // --- Süre -----------------------------------------------------------------

  static final RegExp _hoursDecimal =
      RegExp(r'(\d+)(?:[.,](\d+))?\s*(saat|sa)\b');
  static final RegExp _minutes = RegExp(r'(\d+)\s*(dakika|dk|dak)\b');
  static final RegExp _halfHour = RegExp(r'\byarım\s+saat\b');
  static final RegExp _wordHours =
      RegExp(r'\b(bir|iki|üç|uc|dört|dort|beş|bes)\s+(buçuk\s+)?saat\b');

  static const Map<String, int> _numberWords = {
    'bir': 1,
    'iki': 2,
    'üç': 3,
    'uc': 3,
    'dört': 4,
    'dort': 4,
    'beş': 5,
    'bes': 5,
  };

  static int? _parseDuration(String lower, List<_Consumed> consumed) {
    final half = _halfHour.firstMatch(lower);
    if (half != null) {
      consumed.add(_Consumed(half.group(0)!, PlanSpanKind.duration));
      return 30;
    }

    final wordHour = _wordHours.firstMatch(lower);
    if (wordHour != null) {
      consumed.add(_Consumed(wordHour.group(0)!, PlanSpanKind.duration));
      final base = _numberWords[wordHour.group(1)!] ?? 1;
      final hasHalf = wordHour.group(2) != null;
      return base * 60 + (hasHalf ? 30 : 0);
    }

    final h = _hoursDecimal.firstMatch(lower);
    if (h != null) {
      consumed.add(_Consumed(h.group(0)!, PlanSpanKind.duration));
      final whole = int.tryParse(h.group(1)!) ?? 0;
      final fracDigits = h.group(2);
      var minutes = whole * 60;
      if (fracDigits != null && fracDigits.isNotEmpty) {
        final frac = double.tryParse('0.$fracDigits') ?? 0;
        minutes += (frac * 60).round();
      }
      return minutes > 0 ? minutes : null;
    }

    final m = _minutes.firstMatch(lower);
    if (m != null) {
      consumed.add(_Consumed(m.group(0)!, PlanSpanKind.duration));
      final value = int.tryParse(m.group(1)!) ?? 0;
      return value > 0 ? value : null;
    }

    return null;
  }

  // --- Tarih --------------------------------------------------------------

  // Uzun adlar önce: "cumartesi" içinde "cuma", "pazartesi" içinde "pazar" var.
  static const List<MapEntry<String, int>> _weekdays = [
    MapEntry('pazartesi', DateTime.monday),
    MapEntry('salı', DateTime.tuesday),
    MapEntry('sali', DateTime.tuesday),
    MapEntry('çarşamba', DateTime.wednesday),
    MapEntry('carsamba', DateTime.wednesday),
    MapEntry('perşembe', DateTime.thursday),
    MapEntry('persembe', DateTime.thursday),
    MapEntry('cumartesi', DateTime.saturday),
    MapEntry('cuma', DateTime.friday),
    MapEntry('pazar', DateTime.sunday),
  ];

  static final RegExp _inNDays = RegExp(r'(\d+)\s*gün\s*sonra');

  static DateTime? _parseDate(
      String lower, DateTime today, List<_Consumed> consumed) {
    if (RegExp(r'öbür\s*gün|öbürgün|obur\s*gun').hasMatch(lower)) {
      consumed.add(const _Consumed('öbür gün', PlanSpanKind.date));
      consumed.add(const _Consumed('öbürgün', PlanSpanKind.date));
      consumed.add(const _Consumed('obur gun', PlanSpanKind.date));
      return today.add(const Duration(days: 2));
    }
    if (lower.contains('yarın') || lower.contains('yarin')) {
      consumed.add(const _Consumed('yarın', PlanSpanKind.date));
      consumed.add(const _Consumed('yarin', PlanSpanKind.date));
      return today.add(const Duration(days: 1));
    }
    if (lower.contains('bugün') || lower.contains('bugun')) {
      consumed.add(const _Consumed('bugün', PlanSpanKind.date));
      consumed.add(const _Consumed('bugun', PlanSpanKind.date));
      return today;
    }
    // "bu akşam / bu sabah / bu gece / bu öğlen" — hepsi bugünü kasteder.
    // (Saati _parseTime ayrıca yakalar; burada yalnız günü sabitliyoruz.)
    if (RegExp(r'\bbu\s+(akşam|aksam|sabah|gece|öğlen|oglen|öğle|ogle)')
        .hasMatch(lower)) {
      return today;
    }
    if (RegExp(r'haftaya|(gelecek|önümüzdeki|onumuzdeki)\s+hafta')
        .hasMatch(lower)) {
      consumed.add(const _Consumed('haftaya', PlanSpanKind.date));
      consumed.add(const _Consumed('gelecek hafta', PlanSpanKind.date));
      consumed.add(const _Consumed('önümüzdeki hafta', PlanSpanKind.date));
      consumed.add(const _Consumed('onumuzdeki hafta', PlanSpanKind.date));
      return today.add(const Duration(days: 7));
    }

    final nDays = _inNDays.firstMatch(lower);
    if (nDays != null) {
      consumed.add(_Consumed(nDays.group(0)!, PlanSpanKind.date));
      final n = int.tryParse(nDays.group(1)!) ?? 0;
      if (n > 0) return today.add(Duration(days: n));
    }

    for (final entry in _weekdays) {
      if (_containsWord(lower, entry.key)) {
        consumed.add(_Consumed(entry.key, PlanSpanKind.date));
        return _nextWeekday(today, entry.value);
      }
    }

    return null;
  }

  /// "her pazartesi", "her salı günü" → o güne ait bir sonraki tarih. Sadece
  /// "her" ile birlikte geçtiğinde tetiklenir; yalın "pazartesi" bunu değil
  /// [_parseDate]'i kullanır.
  static DateTime? _parseRecurringWeekday(
      String lower, DateTime today, List<_Consumed> consumed) {
    for (final entry in _weekdays) {
      final pattern = RegExp('her\\s+${entry.key}');
      if (pattern.hasMatch(lower)) {
        consumed.add(_Consumed('her ${entry.key}', PlanSpanKind.date));
        return _nextWeekday(today, entry.value);
      }
    }
    return null;
  }

  static DateTime _nextWeekday(DateTime today, int targetWeekday) {
    var delta = (targetWeekday - today.weekday) % 7;
    if (delta <= 0) delta += 7; // "bugün" değil, "önümüzdeki o gün"
    return today.add(Duration(days: delta));
  }

  // --- Tekrar -----------------------------------------------------------

  static String _parseRecurrence(String lower, List<_Consumed> consumed) {
    if (RegExp(r'her\s*gün|hergün|her\s+(sabah|akşam|aksam)').hasMatch(lower)) {
      consumed.add(const _Consumed('her gün', PlanSpanKind.recurrence));
      consumed.add(const _Consumed('hergün', PlanSpanKind.recurrence));
      consumed.add(const _Consumed('her sabah', PlanSpanKind.recurrence));
      consumed.add(const _Consumed('her akşam', PlanSpanKind.recurrence));
      return 'daily';
    }
    if (RegExp(r'her\s+hafta|haftalık|haftalik').hasMatch(lower)) {
      consumed.add(const _Consumed('her hafta', PlanSpanKind.recurrence));
      consumed.add(const _Consumed('haftalık', PlanSpanKind.recurrence));
      consumed.add(const _Consumed('haftalik', PlanSpanKind.recurrence));
      return 'weekly';
    }
    for (final entry in _weekdays) {
      if (RegExp('her\\s+${entry.key}').hasMatch(lower)) {
        return 'weekly';
      }
    }
    return 'none';
  }

  // --- Ders ------------------------------------------------------------

  static _SubjectMatch? _parseSubject(
    String lower,
    String raw,
    List<SubjectModel> subjects,
    List<_Consumed> consumed,
  ) {
    // 1) Kullanıcının kendi ders adlarıyla birebir/içerik eşleşmesi.
    for (final s in subjects) {
      final name = _trLower(s.name);
      if (name.isEmpty) continue;
      if (_containsWord(lower, name) || lower.contains(name)) {
        consumed.add(_Consumed(s.name, PlanSpanKind.subject));
        return _SubjectMatch(s.id, s.name);
      }
    }

    // 2) Anahtar kelime tahmini (Matematik, Fizik, ...). Kullanıcıda aynı adlı
    //    ders varsa id'sini bağla; yoksa sadece adı taşı.
    final predicted = SubjectAI.predict(raw);
    if (predicted != null) {
      for (final s in subjects) {
        if (_trLower(s.name) == _trLower(predicted)) {
          return _SubjectMatch(s.id, s.name);
        }
      }
      return _SubjectMatch(null, predicted);
    }

    return null;
  }

  // --- Başlık temizliği ------------------------------------------------

  static const List<String> _fillers = [
    'çalışacağım',
    'çalışayım',
    'çalışmam',
    'çalışmak istiyorum',
    'çalışmak',
    'çalışma',
    'çalış',
    'yapacağım',
    'yapmam',
    'yapayım',
    'yapmam lazım',
    'yapmam gerek',
    'bakacağım',
    'bakmam lazım',
    'tekrar edeceğim',
    'tekrar edecem',
    'istiyorum',
    'isterim',
    'lazım',
    'planla',
    'planıma',
    'programa',
    'ekle',
    'koy',
  ];

  static String _cleanTitle(
    String raw,
    List<_Consumed> consumed, {
    String? fallback,
  }) {
    var out = raw;
    for (final piece in consumed) {
      out = _stripWord(out, piece.text);
    }
    for (final filler in _fillers) {
      out = _stripWord(out, filler);
    }
    out = out
        .replaceAll(RegExp(r'[-–—:,.]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // "ve" gibi tek başına kalan bağlaçları at.
    out = out
        .split(' ')
        .where((w) => w.isNotEmpty && w.toLowerCase() != 've')
        .join(' ')
        .trim();

    if (out.isEmpty) {
      if (fallback != null && fallback.trim().isNotEmpty) return fallback.trim();
      // Girdinin tamamı sinyal (tarih/süre/saat/tekrar) olarak tüketildiyse
      // ortada gerçek bir başlık yok — ham metni başlık sanma. Çağıran taraf
      // ders adına düşer. (Hiç sinyal tüketilmediyse metnin kendisi başlıktır.)
      if (consumed.isNotEmpty) return '';
      return raw.trim();
    }
    return out;
  }

  // --- Canlı vurgulama (Koç ekranı) -------------------------------------

  /// [consumed] parçalarının [raw] içindeki gerçek konumlarını bulur —
  /// büyük/küçük harf duyarsız, çakışmaları önceliğe göre (parser'ın kendi
  /// alan sırası: süre → tekrar → saat → tarih → ders) eler. Bazı [consumed]
  /// girdileri (ör. eşanlamlı "öbür gün"/"öbürgün" varyantları) [raw] içinde
  /// hiç geçmeyebilir — bulunamayanlar sessizce atlanır.
  static List<PlanSpan> _locateSpans(String raw, List<_Consumed> consumed) {
    final claimed = List<bool>.filled(raw.length, false);
    final spans = <PlanSpan>[];

    for (final piece in consumed) {
      if (piece.text.isEmpty) continue;
      final match =
          RegExp(RegExp.escape(piece.text), caseSensitive: false).firstMatch(raw);
      if (match == null) continue;
      final start = match.start;
      final end = match.end;
      final overlaps = claimed.sublist(start, end).any((c) => c);
      if (overlaps) continue;
      for (var i = start; i < end; i++) {
        claimed[i] = true;
      }
      spans.add(PlanSpan(start, end, piece.kind));
    }

    spans.sort((a, b) => a.start.compareTo(b.start));
    return spans;
  }

  // --- Yardımcılar ---------------------------------------------------

  /// Türkçe küçük harf: `İ` → `i` (birleşik nokta U+0307 kaldırılır).
  static String _trLower(String s) =>
      s.toLowerCase().replaceAll('̇', '').trim();

  static final RegExp _trWordChar = RegExp(r'[0-9a-zçğıöşü]', caseSensitive: false);

  /// [word]'ü [src] içinden yalnızca sözcük olarak (harf/rakam komşusu yoksa)
  /// siler. Dart'ın `\b`'si Türkçe harflerde güvenilir olmadığı için elle
  /// komşu denetimi yapılır.
  static String _stripWord(String src, String word) {
    if (word.isEmpty) return src;
    return src.replaceAllMapped(
      RegExp(RegExp.escape(word), caseSensitive: false),
      (m) {
        final before = m.start == 0 ? '' : src[m.start - 1];
        final after = m.end >= src.length ? '' : src[m.end];
        final okBefore = before.isEmpty || !_trWordChar.hasMatch(before);
        final okAfter = after.isEmpty || !_trWordChar.hasMatch(after);
        return (okBefore && okAfter) ? ' ' : m.group(0)!;
      },
    );
  }

  /// [needle]'ı kelime sınırıyla arar. Türkçe karakterler `\b` ile güvenilir
  /// olmadığından, çevresini boşluk/başlangıç/son/noktalama ile kontrol eder.
  static bool _containsWord(String haystack, String needle) {
    if (needle.isEmpty) return false;
    final idx = haystack.indexOf(needle);
    if (idx < 0) return false;
    final before = idx == 0 ? ' ' : haystack[idx - 1];
    final afterIdx = idx + needle.length;
    final after = afterIdx >= haystack.length ? ' ' : haystack[afterIdx];
    final boundary = RegExp(r'[\s.,;:!?()\-]');
    return boundary.hasMatch(before) && boundary.hasMatch(after);
  }
}

/// [PlanParser.parse] içinde bir alanın hangi ham metin parçasından geldiğini
/// (kind) taşıyan iç kayıt — başlık temizliği ve canlı vurgulama ikisi de
/// bunu kullanır.
class _Consumed {
  final String text;
  final PlanSpanKind kind;
  const _Consumed(this.text, this.kind);
}

/// Koç ekranının giriş kutusunda canlı vurgulama için alan türü.
enum PlanSpanKind { date, time, duration, recurrence, subject }

/// [raw] girdi içinde `[start, end)` aralığının hangi alana ait olarak
/// tanındığını taşır — UI bunu renklendirmek için kullanır.
class PlanSpan {
  final int start;
  final int end;
  final PlanSpanKind kind;
  const PlanSpan(this.start, this.end, this.kind);
}

/// [PlanParser.parse] çıktısı. Tüm alanlar opsiyonel — ne yakalandıysa o dolu.
class ParsedPlan {
  /// Temizlenmiş görev başlığı (tarih/süre/tekrar ifadeleri çıkarılmış).
  final String title;
  final String? subjectId;
  final String? subjectName;
  final DateTime? date;
  final int? durationMinutes;

  /// Gün içi başlangıç saati (24s) — yakalandıysa. Dakika ayrı tutulur.
  final int? hour;
  final int? minute;

  /// 'none' | 'daily' | 'weekly' — `taskProvider.addRecurringTask` ile aynı sözlük.
  final String recurrence;

  /// Ham girdi içinde hangi karakter aralığının hangi alana karşılık geldiği
  /// — Koç ekranındaki canlı vurgulama için (bkz. [PlanSpanKind]).
  final List<PlanSpan> spans;

  const ParsedPlan({
    required this.title,
    this.subjectId,
    this.subjectName,
    this.date,
    this.durationMinutes,
    this.hour,
    this.minute,
    this.recurrence = 'none',
    this.spans = const [],
  });

  const ParsedPlan.empty()
      : title = '',
        subjectId = null,
        subjectName = null,
        date = null,
        durationMinutes = null,
        hour = null,
        minute = null,
        recurrence = 'none',
        spans = const [];

  bool get hasTime => hour != null;

  /// Hiçbir yapılandırılmış sinyal yakalanmadı — çağıran taraf metni düz
  /// başlık olarak kullanabilir ya da kullanıcıdan netleştirme isteyebilir.
  bool get hasSignal =>
      subjectId != null ||
      subjectName != null ||
      date != null ||
      durationMinutes != null ||
      hour != null ||
      recurrence != 'none';

  @override
  String toString() =>
      'ParsedPlan(title: "$title", subject: $subjectName/$subjectId, '
      'date: $date, time: $hour:$minute, dur: $durationMinutes, rec: $recurrence)';
}

class _SubjectMatch {
  final String? id;
  final String name;
  const _SubjectMatch(this.id, this.name);
}

class _Time {
  final int hour;
  final int minute;
  const _Time(this.hour, this.minute);
}
