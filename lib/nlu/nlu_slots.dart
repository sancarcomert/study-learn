import 'nlu_models.dart';
import 'tr_text.dart';

/// Süre / aciliyet / duygu / sınav bağlamı slot'ları. Hepsi katlanmış (ASCII)
/// metin üzerinde çalışır; ders/konu slot'ları nlu_entities.dart'ta.
class NluSlotExtractor {
  const NluSlotExtractor._();

  // --- Süre -----------------------------------------------------------

  static const Map<String, int> _ones = {
    'bir': 1,
    'iki': 2,
    'uc': 3,
    'dort': 4,
    'bes': 5,
    'alti': 6,
    'yedi': 7,
    'sekiz': 8,
    'dokuz': 9,
  };
  static const Map<String, int> _tens = {
    'on': 10,
    'yirmi': 20,
    'otuz': 30,
    'kirk': 40,
    'elli': 50,
    'altmis': 60,
  };

  /// "otuz dakika", "kırk beş dk", "iki saat", "yarım saat", "1,5 saat",
  /// "1 saat 30 dk", "bi saat" → dakika. Süre yoksa ya da mantıksızsa null.
  static int? minutes(String raw) {
    final pre =
        raw.replaceAllMapped(RegExp(r'(\d)[.,](\d)'), (m) => '${m[1]}p${m[2]}');
    final toks = TrText.tokens(TrText.fold(pre));
    final norm = <String>[];
    for (var i = 0; i < toks.length; i++) {
      final t = toks[i];
      final next = i + 1 < toks.length ? toks[i + 1] : '';
      final unitFollows =
          RegExp(r'^(saat\w*|sa|dakika\w*|dk|dak\w*|bucuk)$').hasMatch(next);
      // "bi saat" → "1 saat"
      if (t == 'bi' && unitFollows) {
        norm.add('1');
        continue;
      }
      if (_tens.containsKey(t)) {
        var v = _tens[t]!;
        // "kırk beş" → 45; "on beş" → 15 ("on bir" → 11 değil: "on" + "bir"
        // konuşmada genelde ayrı sözcüktür).
        final joinsOnes =
            _ones.containsKey(next) && !(t == 'on' && next == 'bir');
        if (joinsOnes) {
          v += _ones[next]!;
          i++;
        }
        norm.add('$v');
        continue;
      }
      if (_ones.containsKey(t) && (t != 'bir' || unitFollows)) {
        norm.add('${_ones[t]}');
        continue;
      }
      norm.add(t);
    }
    final text = norm.join(' ');

    int? total;

    // "1p5 saat" (1,5 saat)
    final dec = RegExp(r'(\d+)p(\d+)\s*(?:saat|sa)\b').firstMatch(text);
    if (dec != null) {
      final h = double.parse('${dec[1]}.${dec[2]}');
      total = (h * 60).round();
    }

    // "1 bucuk saat"
    final half = RegExp(r'(\d+)\s*bucuk\s*(?:saat|sa)\b').firstMatch(text);
    if (total == null && half != null) {
      total = int.parse(half[1]!) * 60 + 30;
    }

    // "yarim saat"
    if (total == null && RegExp(r'\byarim\s*saat').hasMatch(text)) {
      total = 30;
    }

    // "2 saat" [+ "30 dk"]
    if (total == null) {
      final hm = RegExp(
              r'(\d+)\s*(?:saat\w*|sa\b)(?:\s+(?:ve\s+)?(\d+)\s*(?:dakika|dk|dak)\w*)?')
          .firstMatch(text);
      if (hm != null) {
        total =
            int.parse(hm[1]!) * 60 + (hm[2] == null ? 0 : int.parse(hm[2]!));
      }
    }

    // "30 dakika"
    if (total == null) {
      final mm = RegExp(r'(\d+)\s*(?:dakika|dk|dak)\w*').firstMatch(text);
      if (mm != null) total = int.parse(mm[1]!);
    }

    if (total == null || total < 5 || total > 720) return null;
    return total;
  }

  // --- Aciliyet -------------------------------------------------------

  static NluUrgency urgency(String f) {
    if (RegExp(r'\b(bugun|bu aksam|bu gece|birazdan|yarim saate|saat sonra)\b')
        .hasMatch(f)) {
      // "bugün 30 dakikam var" aciliyet değil süre bağlamı; aciliyet yalnız
      // sınav kelimesiyle birlikte anlamlı — burada yine de işaretlenir,
      // tüketen taraf sınav bağlamına bakar.
      return NluUrgency.today;
    }
    if (RegExp(r'\byarin\b').hasMatch(f)) return NluUrgency.tomorrow;
    final days = RegExp(r'\b(\d+) gun\b').firstMatch(f);
    if (days != null) {
      return int.parse(days[1]!) <= 7 ? NluUrgency.thisWeek : NluUrgency.none;
    }
    if (RegExp(r'\b(haftaya|bu hafta|hafta sonu|birkac gun|az kaldi|yaklasti|'
            r'cok yakin|yakinda)\b')
        .hasMatch(f)) {
      return NluUrgency.thisWeek;
    }
    return NluUrgency.none;
  }

  // --- Sınav bağlamı ---------------------------------------------------

  static NluExamKind exam(String f) {
    if (RegExp(r'\b(deneme\w*)\b').hasMatch(f)) return NluExamKind.mockExam;
    if (RegExp(
            r'\b(yazili\w*|vize\w*|final\w*|quiz|kontrol sinav\w*|okul sinav\w*)\b')
        .hasMatch(f)) {
      return NluExamKind.schoolExam;
    }
    if (RegExp(
            r'\b(yks\w*|tyt\w*|ayt\w*|ydt\w*|sinav\w*|universite sinav\w*)\b')
        .hasMatch(f)) {
      return NluExamKind.realExam;
    }
    return NluExamKind.none;
  }

  // --- Duygu / durum ---------------------------------------------------

  static final List<(NluState, RegExp)> _states = [
    (
      NluState.anxious,
      RegExp(r'\b(korku\w*|kaygi\w*|panik\w*|stres\w*|endise\w*|gergin\w*|'
          r'heyecan\w*|kalbim)\b')
    ),
    (
      NluState.overwhelmed,
      RegExp(r'\b(bunal\w*|bogul\w*|yetistiremiy\w*|cok yogun|altinda ez\w*|'
          r'yigildi\w*|dagildim|cok fazla|cok gorev|cok is)\b')
    ),
    (
      NluState.tired,
      RegExp(r'\b(yorgun\w*|yorul(?!ma)\w*|uykum\w*|bitkin\w*|halsiz\w*|'
          r'tukendim|tukeniyorum|tukenmis\w*)\b')
    ),
    (
      NluState.unmotivated,
      RegExp(r'\b(motivasyon\w*|isteksiz\w*|calisasim|icim gelmiy\w*|'
          r'istemiyor\w*|hevesim|sikil(?!m)\w*|sikici|bikt\w*|'
          r'canim istemiyor|erteliyorum|ertele\w*)\b')
    ),
    (
      NluState.frustrated,
      RegExp(r'\b(sinir\w*|nefret\w*|rezil|berbat|igrenc|sacma\w*|kizgin\w*|'
          r'kotu|dertli\w*)\b')
    ),
    (
      NluState.hopeless,
      RegExp(r'\b(umut\w*|pes\b|olmuyor|olmayacak|yapamayacagim|'
          r'basaramayacagim|bosuna|anlamsiz|hicbir sey bilmiyorum)\b')
    ),
    (
      NluState.positive,
      RegExp(r'\b(iyi gidiyor|super|harika|basardim|guzel gecti|mutluyum|'
          r'memnunum|bitirdim|tamamladim|verimli)\b')
    ),
  ];

  static NluState state(String f) {
    for (final (s, re) in _states) {
      final m = re.firstMatch(f);
      if (m == null) continue;
      // "yorgun değilim" → olumsuzlanmış durum sayılmaz. ("motivasyonum YOK"
      // ise durumun kendisidir; yalnız "değil" olumsuzlar.)
      final tail = f.substring(m.end);
      if (RegExp(r'^\s*(degil\w*)\b').hasMatch(tail)) continue;
      return s;
    }
    return NluState.none;
  }
}
