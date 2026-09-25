import 'dart:math' as math;

import 'nlu_entities.dart';
import 'nlu_models.dart';
import 'nlu_phrases.dart';
import 'tr_text.dart';

/// Bir metnin NLU için hazırlanmış hâli: katlanmış metin + yer tutuculu,
/// dolgusuz jetonlar + bulunan ders/konu.
class NluPrepared {
  final String raw;

  /// Katlanmış (ASCII) tam metin — kural katmanı bunun üstünde çalışır.
  final String folded;

  /// Süre ifadeleri `_sure_` olmuş katlanmış metin.
  final String timeMasked;

  /// Ders → `_ders_`, konu → `_konu_`, süre → `_sure_`; dolgu sözcükleri atılmış.
  final List<String> contentTokens;
  final NluEntityMatch entities;

  const NluPrepared({
    required this.raw,
    required this.folded,
    required this.timeMasked,
    required this.contentTokens,
    required this.entities,
  });

  static final RegExp _timeExpr = RegExp(
    r'\b(?:(?:\d+(?:p\d+)?|bir|bi|iki|uc|dort|bes|alti|yedi|sekiz|dokuz|on|'
    r'yirmi|otuz|kirk|elli|altmis)(?:\s+(?:bir|iki|uc|dort|bes|alti|yedi|'
    r'sekiz|dokuz))?(?:\s+bucuk)?|yarim)\s*(?:saat\w*|dakika\w*|dk|dak\w*)'
    r'(?:\s+(?:ve\s+)?\d+\s*(?:dakika\w*|dk|dak\w*))?',
  );

  static NluPrepared of(String raw, NluEntityIndex index) {
    final pre =
        raw.replaceAllMapped(RegExp(r'(\d)[.,](\d)'), (m) => '${m[1]}p${m[2]}');
    final folded = TrText.fold(pre);
    final timeMasked = folded.replaceAll(_timeExpr, '_sure_');
    final tokens = TrText.tokens(timeMasked);
    final entities = index.extract(tokens);
    // Yer tutucuların yanında tekrarları da sadeleştir ("_ders_ _ders_").
    final content = <String>[];
    for (final t in entities.maskedTokens) {
      if (TrText.stopwords.contains(t)) continue;
      if (content.isNotEmpty && content.last == t && t.startsWith('_')) {
        continue;
      }
      content.add(t);
    }
    return NluPrepared(
      raw: raw,
      folded: folded,
      timeMasked: timeMasked,
      contentTokens: content,
      entities: entities,
    );
  }
}

class NluPhraseHit {
  final double score;
  final String phrase;
  const NluPhraseHit(this.score, this.phrase);
}

class _Entry {
  final CoachIntent intent;
  final String phrase;
  final List<String> tokens;
  const _Entry(this.intent, this.phrase, this.tokens);
}

/// Kalıp sözlüğü eşleştiricisi: girdi jetonlarının, her örnek cümlenin
/// jetonlarını (IDF ağırlıklı, çekim eki / yazım hatası toleranslı) ne kadar
/// kapsadığını ölçer. Örnek başına 0..1 puan; niyet başına en iyi örnek alınır.
class NluPhraseMatcher {
  final List<_Entry> _entries;
  final Map<String, double> _idf;
  final Set<String> vocabulary;

  NluPhraseMatcher._(this._entries, this._idf, this.vocabulary);

  static final NluPhraseMatcher instance = _build();

  /// Sözlükteki örnek sayısı.
  int get phraseCount => _entries.length;

  static NluPhraseMatcher _build() {
    final entries = <_Entry>[];
    final df = <String, int>{};
    final vocab = <String>{};
    NluPhrases.byIntent.forEach((intent, phrases) {
      for (final p in phrases) {
        final prepared = NluPrepared.of(p, NluEntityIndex.fixed);
        final toks = prepared.contentTokens;
        if (toks.isEmpty) continue;
        entries.add(_Entry(intent, p, toks));
        for (final t in toks.toSet()) {
          df[t] = (df[t] ?? 0) + 1;
        }
        vocab.addAll(toks);
      }
    });
    final n = entries.length;
    final idf = <String, double>{
      for (final e in df.entries)
        e.key: math.max(0.45, math.log((n + 1) / (e.value + 0.5)) / 2.2),
    };
    return NluPhraseMatcher._(entries, idf, vocab);
  }

  /// Yer tutucular sabit (yüksek) ağırlıklıdır: ders/konu geçmeyen bir cümle,
  /// ders/konu bekleyen bir kalıba "çok", "kötü" gibi ortak sözcüklerle
  /// yaklaşamasın.
  double _w(String t) => t.startsWith('_') ? 1.0 : (_idf[t] ?? 1.0);

  /// Girdi jetonlarından bilinen (sözlükte benzeri olan) içerik jetonlarının
  /// oranı. Yer tutucular her zaman bilinir.
  double knownRatio(List<String> tokens) {
    if (tokens.isEmpty) return 0;
    var known = 0;
    for (final t in tokens) {
      if (t.startsWith('_') || _isKnown(t)) known++;
    }
    return known / tokens.length;
  }

  bool _isKnown(String t) {
    if (vocabulary.contains(t)) return true;
    for (final v in vocabulary) {
      if (v.startsWith('_')) continue;
      if (TrText.tokenSimilarity(t, v) >= 0.7) return true;
    }
    return false;
  }

  /// Her niyet için en iyi örnek eşleşmesi (eşik altındakiler atılır).
  Map<CoachIntent, NluPhraseHit> match(List<String> input) {
    final result = <CoachIntent, NluPhraseHit>{};
    if (input.isEmpty) return result;
    final inputW = input.fold<double>(0, (s, t) => s + _w(t));

    for (final e in _entries) {
      final used = <int>{};
      var matched = 0.0;
      var matchedInput = 0.0;
      var total = 0.0;
      for (final pt in e.tokens) {
        final w = _w(pt);
        total += w;
        var best = 0.0;
        var bestIdx = -1;
        for (var i = 0; i < input.length; i++) {
          if (used.contains(i)) continue;
          final s = TrText.tokenSimilarity(pt, input[i]);
          if (s > best) {
            best = s;
            bestIdx = i;
          }
        }
        if (bestIdx >= 0) {
          used.add(bestIdx);
          matched += w * best;
          matchedInput += _w(input[bestIdx]);
        }
      }
      if (total == 0) continue;
      final coverage = matched / total;
      final inputCoverage = inputW == 0 ? 0.0 : matchedInput / inputW;
      // Örnek cümlenin tamamı yakalanmışsa da, girdi çok daha uzunsa (bileşik
      // cümle) güven biraz düşer ama sıfırlanmaz.
      var score = coverage * (0.8 + 0.2 * math.min(1.0, inputCoverage * 1.6));
      // Tek sözcüklü kalıp ("başlıyorum") uzun bir cümlenin içinde tesadüfen
      // geçebilir — yalnız kısa girdilerde tam güven verir.
      if (e.tokens.length == 1 && input.length > 2) score *= 0.5;
      // Kalıp ders/konu bekliyor ama girdide yoksa güven düşer.
      if (e.tokens.any((t) => t.startsWith('_') && !input.contains(t))) {
        score *= 0.6;
      }
      if (score < 0.4) continue;
      final prev = result[e.intent];
      if (prev == null || score > prev.score) {
        result[e.intent] = NluPhraseHit(score, e.phrase);
      }
    }
    return result;
  }
}
