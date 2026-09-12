import 'topic_catalog.dart';

class SubjectAI {
  // Elle seçilmiş, yüksek güvenilirlikli anahtar kelimeler — bir eşleşme
  // 2 puan değerinde (bkz. predict). Yalnızca 6 ders kapsıyor; kalan 6 ders
  // (Coğrafya, Edebiyat, Felsefe, İngilizce, Din Kültürü, Geometri) ve bu
  // 6'nın da eksik kalan konu kelimeleri [_catalogKeywords] ile tamamlanır.
  static final Map<String, List<String>> keywords = {

    "Matematik": [
      "üçgen",
      "fonksiyon",
      "türev",
      "integral",
      "limit",
      "denklem",
      "polinom",
      "eşitsizlik",
      "logaritma",
      "trigonometri",
      "sin",
      "cos",
      "tan",
    ],

    "Geometri": [
      "geometri",
      "açı",
      "çember",
      "dörtgen",
      "çokgen",
      "benzerlik",
    ],

    "Fizik": [
      "vektör",
      "kuvvet",
      "hız",
      "ivme",
      "enerji",
      "hareket",
      "elektrik",
      "manyetik",
      "dalga",
      "optik",
      "momentum",
    ],

    "Kimya": [
      "atom",
      "molekül",
      "mol",
      "asit",
      "baz",
      "iyon",
      "reaksiyon",
      "bağ",
      "periyodik",
      "kimyasal",
    ],

    "Biyoloji": [
      "canlı",
      "yaşam",
      "hücre",
      "dna",
      "gen",
      "kalıtım",
      "fotosentez",
      "ekosistem",
      "organ",
      "mitoz",
      "mayoz",
    ],

    "Türkçe": [
      "paragraf",
      "fiil",
      "isim",
      "sıfat",
      "zarf",
      "edat",
      "anlam",
      "cümle",
      "yazım",
      "noktalama",
      "sözcük",
    ],

    "Edebiyat": [
      "edebiyat",
      "şiir",
      "roman",
      "hikaye",
      "tiyatro",
      "divan",
      "tanzimat",
    ],

    "Tarih": [
      "osmanlı",
      "savaş",
      "devlet",
      "inkılap",
      "atatürk",
      "antlaşma",
      "selçuklu",
      "cumhuriyet",
    ],

    "Coğrafya": [
      "coğrafya",
      "iklim",
      "harita",
      "nüfus",
      "yer şekilleri",
      "göç",
      "ekonomik faaliyet",
    ],

    "Felsefe": [
      "felsefe",
      "mantık",
      "bilgi felsefesi",
      "varlık felsefesi",
      "ahlak felsefesi",
    ],

    "İngilizce": [
      "tense",
      "grammar",
      "vocabulary",
      "ingilizce kelime",
      "paragraph completion",
    ],

    "Din Kültürü": [
      "din kültürü",
      "ibadet",
      "kuran",
      "peygamber",
      "ahlak ve değerler",
    ],

  };

  // topic_catalog.dart'taki gerçek YKS konu adlarından türetilir — 12 dersin
  // tam kapsamını, ikinci bir listeyi elle bakımlı tutmadan kullanır (tek
  // kaynak: TopicCatalog). Bir eşleşme yalnızca 1 puan (elle seçilmiş
  // kelimelerden daha az güvenilir — bazı konu adları geneldir) ve kısa/
  // genel kelimeler (< 5 harf, "sistemi/kanunu/dengesi" gibi tek başına
  // belirsiz son ekler) dışlanır.
  static final Map<String, List<String>> _catalogKeywords = _buildFromCatalog();

  static const Map<String, String> _catalogSubjectDisplayNames = {
    'matematik': 'Matematik',
    'geometri': 'Geometri',
    'fizik': 'Fizik',
    'kimya': 'Kimya',
    'biyoloji': 'Biyoloji',
    'türkçe': 'Türkçe',
    'edebiyat': 'Edebiyat',
    'tarih': 'Tarih',
    'coğrafya': 'Coğrafya',
    'felsefe': 'Felsefe',
    'ingilizce': 'İngilizce',
    'din kültürü': 'Din Kültürü',
  };

  static const Set<String> _genericWords = {
    'sistemi', 'sistem', 'dengesi', 'denge', 'kanunu', 'kanunları',
    'kavramı', 'kavramlar', 'bilgisi', 'giriş', 'temel', 'temel kavramlar',
    'hareket', 'yapı', 'çeşitleri', 'özellikleri', 'ilişkileri',
    // Uygulamanın kendi kelime dağarcığıyla çakışan konu adları — "Deneme -
    // Makale - Eleştiri" (Edebiyat) buradaki "deneme" (mock sınav) ile aynı
    // kelime; kullanıcı "deneme sınavı analizi" gibi ders-tarafsız bir
    // başlık yazınca yanlışlıkla Edebiyat'a düşmesin.
    'deneme',
  };

  static Map<String, List<String>> _buildFromCatalog() {
    final result = <String, List<String>>{};
    for (final entry in _catalogSubjectDisplayNames.entries) {
      final topics = TopicCatalog.forSubject(entry.key);
      final words = <String>{};
      for (final topic in topics) {
        for (final raw in topic.toLowerCase().split(RegExp(r'[\s\-–]+'))) {
          final w = raw.trim();
          if (w.length >= 5 && !_genericWords.contains(w)) words.add(w);
        }
      }
      if (words.isNotEmpty) result[entry.value] = words.toList();
    }
    return result;
  }

  static String? predict(String text) {
    text = text.toLowerCase();

    final subjects = {...keywords.keys, ..._catalogKeywords.keys};
    final scores = <String, int>{};

    for (final subject in subjects) {
      var score = 0;
      for (final word in keywords[subject] ?? const []) {
        if (text.contains(word)) score += 2;
      }
      for (final word in _catalogKeywords[subject] ?? const []) {
        if (text.contains(word)) score += 1;
      }
      scores[subject] = score;
    }

    String? result;
    var maxScore = 0;
    scores.forEach((subject, score) {
      if (score > maxScore) {
        maxScore = score;
        result = subject;
      }
    });

    return maxScore > 0 ? result : null;
  }
}