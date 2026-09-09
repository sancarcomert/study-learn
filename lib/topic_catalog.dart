/// YKS (TYT+AYT) için yaygın konu listeleri — "Yaygın konuları ekle" hızlı
/// eklemesi bunları kullanır. Kesin/ resmi müfredat değil; başlangıç listesi,
/// kullanıcı ekleyip çıkarabilir. Anahtar = ders adı (küçük harf, Türkçe).
class TopicCatalog {
  const TopicCatalog._();

  static const Map<String, List<String>> _bySubject = {
    'matematik': [
      'Temel Kavramlar', 'Sayı Basamakları', 'Bölme ve Bölünebilme',
      'EBOB - EKOK', 'Rasyonel Sayılar', 'Basit Eşitsizlikler',
      'Mutlak Değer', 'Üslü Sayılar', 'Köklü Sayılar', 'Çarpanlara Ayırma',
      'Oran - Orantı', 'Denklem Çözme', 'Problemler', 'Kümeler', 'Fonksiyonlar',
      'Polinomlar', 'İkinci Dereceden Denklemler', 'Permütasyon - Kombinasyon',
      'Olasılık', 'Trigonometri', 'Logaritma', 'Diziler', 'Limit ve Süreklilik',
      'Türev', 'İntegral',
    ],
    'geometri': [
      'Doğruda ve Üçgende Açılar', 'Dik Üçgen ve Öklid', 'İkizkenar - Eşkenar Üçgen',
      'Üçgende Alan', 'Üçgende Benzerlik', 'Açıortay - Kenarortay',
      'Çokgenler', 'Dörtgenler', 'Paralelkenar', 'Eşkenar Dörtgen - Yamuk',
      'Deltoid', 'Çember ve Daire', 'Çemberde Açı', 'Çemberde Uzunluk - Alan',
      'Katı Cisimler', 'Analitik Geometri', 'Dönüşüm Geometrisi', 'Vektörler',
    ],
    'fizik': [
      'Fizik Bilimine Giriş', 'Madde ve Özellikleri', 'Hareket ve Kuvvet',
      'Dinamik', 'İş - Güç - Enerji', 'Isı ve Sıcaklık', 'Basınç ve Kaldırma',
      'Elektrostatik', 'Elektrik Akımı', 'Manyetizma', 'Vektörler',
      'Bağıl Hareket', 'Newton Yasaları', 'İtme ve Momentum', 'Tork - Denge',
      'Düzgün Çembersel Hareket', 'Basit Harmonik Hareket', 'Dalgalar',
      'Optik', 'Modern Fizik',
    ],
    'kimya': [
      'Kimya Bilimi', 'Atom ve Periyodik Sistem', 'Kimyasal Türler Arası Etkileşim',
      'Maddenin Halleri', 'Doğa ve Kimya', 'Kimyanın Temel Kanunları',
      'Mol Kavramı', 'Kimyasal Hesaplamalar', 'Karışımlar', 'Asitler - Bazlar - Tuzlar',
      'Kimya Her Yerde', 'Modern Atom Teorisi', 'Gazlar', 'Sıvı Çözeltiler',
      'Kimyasal Tepkimelerde Enerji', 'Kimyasal Tepkimelerde Hız',
      'Kimyasal Denge', 'Asit - Baz Dengesi', 'Çözünürlük Dengesi',
      'Kimya ve Elektrik', 'Organik Kimya', 'Enerji Kaynakları',
    ],
    'biyoloji': [
      'Canlıların Ortak Özellikleri', 'Canlıların Temel Bileşenleri', 'Hücre',
      'Hücre Bölünmeleri', 'Kalıtım', 'Canlıların Sınıflandırılması',
      'Ekosistem Ekolojisi', 'Güncel Çevre Sorunları', 'Bitki Biyolojisi',
      'Sinir Sistemi', 'Endokrin Sistem', 'Duyu Organları', 'Destek ve Hareket Sistemi',
      'Sindirim Sistemi', 'Dolaşım Sistemi', 'Solunum Sistemi', 'Boşaltım Sistemi',
      'Üreme Sistemi ve Embriyonik Gelişim', 'Komünite ve Popülasyon Ekolojisi',
      'Nükleik Asitler', 'Genetik Şifre ve Protein Sentezi', 'Canlılarda Enerji Dönüşümleri',
    ],
    'türkçe': [
      'Sözcükte Anlam', 'Cümlede Anlam', 'Paragraf', 'Ses Bilgisi', 'Yazım Kuralları',
      'Noktalama İşaretleri', 'Sözcükte Yapı', 'İsimler', 'Sıfatlar', 'Zamirler',
      'Zarflar', 'Edat - Bağlaç - Ünlem', 'Fiiller', 'Fiilimsiler', 'Fiilde Çatı',
      'Sözcük Grupları', 'Cümlenin Ögeleri', 'Cümle Türleri', 'Anlatım Bozuklukları',
    ],
    'edebiyat': [
      'Güzel Sanatlar ve Edebiyat', 'Şiir Bilgisi', 'Söz Sanatları',
      'İslamiyet Öncesi Türk Edebiyatı', 'Halk Edebiyatı', 'Divan Edebiyatı',
      'Tanzimat Edebiyatı', 'Servet-i Fünun', 'Milli Edebiyat',
      'Cumhuriyet Dönemi Şiiri', 'Cumhuriyet Dönemi Romanı', 'Edebi Akımlar',
      'Roman', 'Hikaye', 'Tiyatro', 'Deneme - Makale - Eleştiri',
    ],
    'tarih': [
      'Tarih ve Zaman', 'İlk ve Orta Çağlarda Türk Dünyası', 'İslam Medeniyetinin Doğuşu',
      'Türklerin İslamiyeti Kabulü', 'Anadolu Selçuklu Devleti', 'Beylikten Devlete (1300-1453)',
      'Dünya Gücü Osmanlı (1453-1600)', 'Arayış Yılları (17. yy)', 'Diplomasi ve Değişim (18. yy)',
      'En Uzun Yüzyıl (1800-1922)', 'Milli Mücadele', 'Atatürkçülük ve İnkılaplar',
      'İki Savaş Arası Dönem', 'II. Dünya Savaşı', 'Soğuk Savaş Dönemi',
      'Yumuşama Dönemi', 'Küreselleşen Dünya',
    ],
    'coğrafya': [
      'Doğa ve İnsan', 'Dünyanın Şekli ve Hareketleri', 'Coğrafi Konum', 'Harita Bilgisi',
      'İklim Bilgisi', 'Basınç ve Rüzgarlar', 'Nem ve Yağış', 'İç Kuvvetler - Dış Kuvvetler',
      'Türkiye’nin Yer Şekilleri', 'Su - Toprak - Bitki', 'Nüfus', 'Göç',
      'Yerleşme', 'Ekonomik Faaliyetler', 'Tarım', 'Hayvancılık', 'Madenler ve Enerji',
      'Sanayi', 'Ulaşım', 'Ticaret - Turizm', 'Bölgeler', 'Çevre ve Toplum',
      'Doğal Afetler',
    ],
    'felsefe': [
      'Felsefeyle Tanışma', 'Bilgi Felsefesi', 'Varlık Felsefesi', 'Ahlak Felsefesi',
      'Sanat Felsefesi', 'Din Felsefesi', 'Siyaset Felsefesi', 'Bilim Felsefesi',
      'MÖ 6 - MS 2 Felsefesi', 'MS 2 - MS 15 Felsefesi', '15 - 17 Yüzyıl Felsefesi',
      '18 - 19 Yüzyıl Felsefesi', '20. Yüzyıl Felsefesi', 'Mantık',
    ],
    'ingilizce': [
      'Tenses', 'Modals', 'Passive Voice', 'Gerunds - Infinitives', 'Relative Clauses',
      'Noun Clauses', 'Conditionals', 'Reported Speech', 'Prepositions',
      'Conjunctions - Connectors', 'Phrasal Verbs', 'Vocabulary', 'Reading',
      'Cloze Test', 'Sentence Completion', 'Irrelevant Sentence',
      'Paragraph Completion', 'Dialogue Completion', 'Restatement', 'Translation',
    ],
    'din kültürü': [
      'Bilgi ve İnanç', 'İslam ve İbadet', 'Ahlak ve Değerler', 'Din ve Hayat',
      'Hz. Muhammed’in Hayatı', 'Kur’an ve Yorumu', 'İnançla İlgili Meseleler',
      'Yahudilik ve Hıristiyanlık', 'İslam Düşüncesinde Yorumlar',
      'Din - Kültür - Medeniyet', 'Güncel Dini Meseleler', 'Dünya Dinleri',
    ],
  };

  /// [subjectName] için katalog konuları — eşleşme yoksa boş liste.
  static List<String> forSubject(String subjectName) {
    final key = subjectName.toLowerCase().replaceAll('̇', '').trim();
    if (_bySubject.containsKey(key)) return _bySubject[key]!;
    // Kısmi eşleşme: "TYT Matematik", "AYT Fizik 1" gibi adlar.
    for (final entry in _bySubject.entries) {
      if (key.contains(entry.key)) return entry.value;
    }
    return const [];
  }

  static bool hasCatalog(String subjectName) => forSubject(subjectName).isNotEmpty;
}
