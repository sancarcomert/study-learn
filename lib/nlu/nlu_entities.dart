import '../subject_model.dart';
import '../topic_catalog.dart';
import '../topic_model.dart';
import 'nlu_models.dart';
import 'tr_text.dart';

/// Yer tutucu jetonlar: cümledeki ders/konu adı yerine konur, böylece
/// "matematikte zorlanıyorum" ile "fizikte zorlanıyorum" aynı kalıba düşer.
const String kSubjectToken = '_ders_';
const String kTopicToken = '_konu_';

class _SubjectAlias {
  final String canonical; // görünen ad
  final String base; // katlanmış tam ad
  final List<String> prefixes;
  final Set<String> exact;
  const _SubjectAlias(this.canonical, this.base, this.prefixes, this.exact);
}

const List<_SubjectAlias> _aliases = [
  _SubjectAlias(
      'Matematik', 'matematik', ['matematik', 'matemat'], {'mat', 'matem'}),
  _SubjectAlias('Geometri', 'geometri', ['geometri'], {'geo', 'geom'}),
  _SubjectAlias('Fizik', 'fizik', ['fizik'], {'fiz'}),
  _SubjectAlias('Kimya', 'kimya', ['kimya'], {'kimy'}),
  _SubjectAlias('Biyoloji', 'biyoloji', ['biyoloji'], {'biyo', 'biy', 'bio'}),
  _SubjectAlias('Türkçe', 'turkce', ['turkce'], {'trkc'}),
  _SubjectAlias('Edebiyat', 'edebiyat', ['edebiyat'], {'edeb'}),
  _SubjectAlias('Tarih', 'tarih', ['tarih'], {}),
  _SubjectAlias('Coğrafya', 'cografya', ['cografya'], {'cog', 'cogr'}),
  _SubjectAlias('Felsefe', 'felsefe', ['felsefe'], {'felf', 'fels'}),
  _SubjectAlias('Din Kültürü', 'din kulturu', ['dinkulturu'], {'din', 'dkab'}),
  _SubjectAlias('İngilizce', 'ingilizce', ['ingilizce', 'ingiliz'], {'ing'}),
];

/// Tek kelimelik konu adlarında (ör. "Temel Kavramlar" → "temel") yanlış
/// pozitif üretecek kadar genel jetonlar.
const Set<String> _genericTopicTokens = {
  'temel',
  'giris',
  'madde',
  'hareket',
  'enerji',
  'kuvvet',
  'sayilar',
  'kavramlar',
  'bilimi',
  'bilimine',
  'cozme',
  'dunya',
  'genel',
  'deneme',
  'makale',
  'elestiri',
};

class _TopicEntry {
  final String name;
  final String? id;
  final String? subjectId;
  final String? subjectName;
  final List<List<String>> parts;
  const _TopicEntry(
      this.name, this.id, this.subjectId, this.subjectName, this.parts);
}

class NluEntityMatch {
  final NluSubjectMention? subject;
  final NluTopicMention? topic;

  /// Dersin geçtiği TÜM ders adları (ilk geçen [subject]).
  final List<NluSubjectMention> allSubjects;

  /// Ders/konu jetonları yer tutucuyla değiştirilmiş jeton listesi.
  final List<String> maskedTokens;

  const NluEntityMatch({
    required this.subject,
    required this.topic,
    required this.allSubjects,
    required this.maskedTokens,
  });
}

/// Cümledeki ders/konu adlarını MEVCUT verilerden bulur — konu UYDURMAZ.
/// Kaynaklar: kullanıcının dersleri/konuları (id'li) + uygulamanın kendi konu
/// kataloğu (id'siz; yalnız ad olarak anılır).
class NluEntityIndex {
  final List<SubjectModel> _userSubjects;
  final List<_TopicEntry> _topics;

  NluEntityIndex._(this._userSubjects, this._topics);

  /// Kullanıcı verisi olmadan, yalnız sabit ders takma adları + katalog —
  /// söz dağarcığı/kalıp maskelemesi için.
  static final NluEntityIndex fixed = NluEntityIndex.build();

  factory NluEntityIndex.build({
    List<SubjectModel> subjects = const [],
    List<TopicModel> topics = const [],
  }) {
    final entries = <_TopicEntry>[];
    final seen = <String>{};

    String? subjectNameOf(String subjectId) {
      for (final s in subjects) {
        if (s.id == subjectId) return s.name;
      }
      return null;
    }

    for (final t in topics) {
      final parts = _partsOf(t.name);
      if (parts.isEmpty) continue;
      seen.add('${t.subjectId}|${TrText.fold(t.name)}');
      entries.add(_TopicEntry(
          t.name, t.id, t.subjectId, subjectNameOf(t.subjectId), parts));
    }

    // Katalog: kullanıcının dersine bağlanabiliyorsa o dersin id'siyle, değilse
    // yalnız ders adıyla. Kullanıcı konusu olarak ZATEN kayıtlı olanlar atlanır.
    for (final a in _aliases) {
      final user = _matchUserSubject(subjects, a);
      for (final name in TopicCatalog.forSubject(a.canonical)) {
        if (user != null && seen.contains('${user.id}|${TrText.fold(name)}')) {
          continue;
        }
        final parts = _partsOf(name);
        if (parts.isEmpty) continue;
        entries.add(_TopicEntry(
            name, null, user?.id, user?.name ?? a.canonical, parts));
      }
    }
    return NluEntityIndex._(subjects, entries);
  }

  static SubjectModel? _matchUserSubject(
      List<SubjectModel> subjects, _SubjectAlias a) {
    for (final s in subjects) {
      final base = _userBase(s.name);
      if (base.startsWith(a.base.replaceAll(' ', '')) ||
          base == a.base.replaceAll(' ', '')) {
        return s;
      }
    }
    return null;
  }

  /// "TYT Matematik" → "matematik"; boşluksuz katlanmış ad.
  static String _userBase(String name) {
    final toks = TrText.tokens(TrText.fold(name))
        .where((t) => t != 'tyt' && t != 'ayt' && t != 'ydt')
        .toList();
    return toks.join('');
  }

  static String _stem(String tok) {
    for (final suf in const ['ler', 'lar']) {
      if (tok.endsWith(suf) && tok.length - suf.length >= 4) {
        return tok.substring(0, tok.length - suf.length);
      }
    }
    return tok;
  }

  static List<List<String>> _partsOf(String name) {
    final pieces = <String>[
      name,
      ...name.split(RegExp(r'[()\-–/,]|\s+ve\s+')),
    ];
    final out = <List<String>>[];
    for (final p in pieces) {
      final toks = TrText.tokens(TrText.fold(p))
          .where((t) => t != 've' && t != 'ile' && t.length >= 3)
          .map(_stem)
          .toList();
      if (toks.isEmpty) continue;
      if (toks.length == 1 &&
          (toks.first.length < 5 || _genericTopicTokens.contains(toks.first))) {
        continue;
      }
      if (!out.any((o) => o.join(' ') == toks.join(' '))) out.add(toks);
    }
    return out;
  }

  static bool _tokenHitsStem(String token, String stem) {
    if (token.length >= stem.length && token.startsWith(stem)) return true;
    // Yazım hatası: uzunlukları en fazla 1 farklı ve tek harf farkı. (Girdi
    // jetonu konu adının ÖNEKİ olamaz: "surekli" ≠ "süreklilik".)
    if (token.length >= 6 &&
        stem.length >= 6 &&
        (token.length - stem.length).abs() <= 1 &&
        !stem.startsWith(token)) {
      return TrText.tokenSimilarity(token, stem) >= 0.85;
    }
    return false;
  }

  // --- Ders -------------------------------------------------------------

  /// [token] bir ders adıysa (kullanıcının dersi ya da sabit takma ad) onu
  /// döndürür.
  NluSubjectMention? _subjectOfToken(String token) {
    if (token.length < 2 || token.startsWith('_')) return null;
    for (final s in _userSubjects) {
      final base = _userBase(s.name);
      if (base.length >= 4 && token.startsWith(base)) {
        return NluSubjectMention(id: s.id, name: s.name);
      }
    }
    for (final a in _aliases) {
      var hit = a.exact.contains(token) ||
          a.prefixes.any((p) => token.startsWith(p)) ||
          (token.length >= 6 && TrText.tokenSimilarity(token, a.base) >= 0.85);
      if (a.base == 'din kulturu' && token == 'din') hit = true;
      if (!hit) continue;
      final user = _matchUserSubject(_userSubjects, a);
      return NluSubjectMention(id: user?.id, name: user?.name ?? a.canonical);
    }
    return null;
  }

  // --- Konu + maske -------------------------------------------------------

  NluEntityMatch extract(List<String> tokens) {
    final subjectHits = <int, NluSubjectMention>{};
    for (var i = 0; i < tokens.length; i++) {
      final m = _subjectOfToken(tokens[i]);
      if (m != null) subjectHits[i] = m;
    }
    final subjects = subjectHits.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final firstSubject = subjects.isEmpty ? null : subjects.first.value;

    // Konu: en çok jetonu eşleşen bölüm; eşitlikte kullanıcının kendi konusu.
    _TopicEntry? best;
    Set<int> bestIdx = const {};
    var bestScore = 0;
    for (final e in _topics) {
      if (firstSubject != null && !_sameSubject(e, firstSubject)) continue;
      for (final part in e.parts) {
        final used = <int>{};
        var ok = true;
        for (final stem in part) {
          var found = -1;
          for (var i = 0; i < tokens.length; i++) {
            if (used.contains(i) || subjectHits.containsKey(i)) continue;
            if (_tokenHitsStem(tokens[i], stem)) {
              found = i;
              break;
            }
          }
          if (found < 0) {
            ok = false;
            break;
          }
          used.add(found);
        }
        if (!ok) continue;
        final score = part.length * 2 + (e.id != null ? 1 : 0);
        if (score > bestScore) {
          bestScore = score;
          best = e;
          bestIdx = used;
        }
      }
    }

    NluTopicMention? topic;
    if (best != null) {
      topic = NluTopicMention(
        id: best.id,
        name: best.name,
        subjectId: best.subjectId,
        subjectName: best.subjectName,
      );
    }

    final masked = <String>[];
    for (var i = 0; i < tokens.length; i++) {
      if (subjectHits.containsKey(i)) {
        masked.add(kSubjectToken);
      } else if (bestIdx.contains(i)) {
        masked.add(kTopicToken);
      } else {
        masked.add(tokens[i]);
      }
    }

    return NluEntityMatch(
      subject: firstSubject,
      topic: topic,
      allSubjects: [for (final s in subjects) s.value],
      maskedTokens: masked,
    );
  }

  bool _sameSubject(_TopicEntry e, NluSubjectMention s) {
    if (e.subjectId != null && s.id != null) return e.subjectId == s.id;
    final a = TrText.fold(e.subjectName ?? '');
    final b = TrText.fold(s.name);
    if (a.isEmpty) return true;
    return a.contains(b) || b.contains(a);
  }
}
