import 'user_stats_model.dart';

/// YKS (TYT+AYT) için yaygın konu listeleri — "Yaygın konuları ekle" hızlı
/// eklemesi bunları kullanır. Kesin/resmi müfredat değil; başlangıç listesi,
/// kullanıcı ekleyip çıkarabilir. Anahtar = ders adı (küçük harf, Türkçe).
///
/// Her konu, (ad, sınıf) çifti olarak tutulur — [forSubject]'e [maxGrade]
/// verilirse yalnız o sınıfa kadar (dahil) görülen konular döner; bu da
/// kümülatif (P0-11): 9→{9}, 10→{9,10}, 11→{9,10,11}, 12/Mezun→hepsi.
/// Sınıf etiketleri genel bilinen TYT/AYT müfredat sıralamasına göre
/// best-effort verildi — resmi MEB metnine göre doğrulanmadı, tıpkı
/// listenin kendisi gibi kullanıcı düzeltebilir bir başlangıç noktası.
class TopicCatalog {
  const TopicCatalog._();

  static const Map<String, List<(String, int)>> _bySubject = {
    'matematik': [
      ('Temel Kavramlar', 9), ('Sayı Basamakları', 9),
      ('Bölme ve Bölünebilme', 9), ('EBOB - EKOK', 9),
      ('Rasyonel Sayılar', 9), ('Basit Eşitsizlikler', 9),
      ('Mutlak Değer', 9), ('Üslü Sayılar', 9), ('Köklü Sayılar', 9),
      ('Çarpanlara Ayırma', 9), ('Oran - Orantı', 9), ('Denklem Çözme', 9),
      ('Problemler', 9), ('Kümeler', 9),
      ('Fonksiyonlar', 10), ('Polinomlar', 10),
      ('İkinci Dereceden Denklemler', 10),
      ('Permütasyon - Kombinasyon', 10), ('Olasılık', 10),
      ('Trigonometri', 10),
      // Türkiye Yüzyılı Maarif Modeli (2025-26 itibarıyla kademeli
      // uygulanıyor) 10. sınıf matematiğine yeni bir tema olarak
      // "Analitik İnceleme" (koordinat düzleminde iki nokta arası uzaklık,
      // doğrunun eğimi, paralellik) ekledi — eskiden bu konu 11. sınıfta
      // işleniyordu. tymm.meb.gov.tr (resmi MEB portalı) ile doğrulandı.
      ('Analitik İnceleme (Koordinat Düzlemi)', 10),
      ('Logaritma', 11), ('Diziler', 11),
      ('Limit ve Süreklilik', 12), ('Türev', 12), ('İntegral', 12),
    ],
    'geometri': [
      ('Doğruda ve Üçgende Açılar', 9), ('Dik Üçgen ve Öklid', 9),
      ('İkizkenar - Eşkenar Üçgen', 9), ('Üçgende Alan', 9),
      ('Üçgende Benzerlik', 9), ('Açıortay - Kenarortay', 9),
      ('Çokgenler', 9), ('Dörtgenler', 9),
      ('Paralelkenar', 10), ('Eşkenar Dörtgen - Yamuk', 10),
      ('Deltoid', 10), ('Çember ve Daire', 10), ('Çemberde Açı', 10),
      ('Çemberde Uzunluk - Alan', 10), ('Dönüşüm Geometrisi', 10),
      ('Analitik Geometri', 11), ('Vektörler', 11),
      ('Katı Cisimler', 12),
    ],
    'fizik': [
      ('Fizik Bilimine Giriş', 9), ('Madde ve Özellikleri', 9),
      ('Hareket ve Kuvvet', 9), ('İş - Güç - Enerji', 9),
      ('Isı ve Sıcaklık', 9), ('Elektrostatik', 9),
      // "Akışkanlar" resmi Maarif Modeli'nde 9. sınıfın kendi ünitesi
      // (tymm.meb.gov.tr) — önceden yalnız "Basınç ve Kaldırma" adıyla
      // 10. sınıfta vardı, 9. sınıf hiç kapsamıyordu.
      ('Akışkanlar (Basınç ve Kaldırma)', 9),
      ('Elektrik Akımı', 10),
      ('Manyetizma', 10), ('Dalgalar', 10), ('Optik', 10),
      ('Dinamik', 11), ('Vektörler', 11), ('Bağıl Hareket', 11),
      ('Newton Yasaları', 11), ('İtme ve Momentum', 11),
      ('Tork - Denge', 11), ('Düzgün Çembersel Hareket', 11),
      ('Basit Harmonik Hareket', 11),
      ('Modern Fizik', 12),
    ],
    'kimya': [
      ('Kimya Bilimi', 9), ('Atom ve Periyodik Sistem', 9),
      ('Kimyasal Türler Arası Etkileşim', 9), ('Maddenin Halleri', 9),
      ('Doğa ve Kimya', 9),
      ('Kimyanın Temel Kanunları', 10), ('Mol Kavramı', 10),
      ('Kimyasal Hesaplamalar', 10), ('Karışımlar', 10),
      ('Asitler - Bazlar - Tuzlar', 10), ('Kimya Her Yerde', 10),
      ('Modern Atom Teorisi', 11), ('Gazlar', 11),
      ('Sıvı Çözeltiler', 11), ('Kimyasal Tepkimelerde Enerji', 11),
      ('Kimyasal Tepkimelerde Hız', 11), ('Kimyasal Denge', 11),
      ('Asit - Baz Dengesi', 12), ('Çözünürlük Dengesi', 12),
      ('Kimya ve Elektrik', 12), ('Organik Kimya', 12),
      ('Enerji Kaynakları', 12),
    ],
    'biyoloji': [
      ('Canlıların Ortak Özellikleri', 9), ('Canlıların Temel Bileşenleri', 9),
      ('Hücre', 9), ('Canlıların Sınıflandırılması', 9),
      ('Hücre Bölünmeleri', 10), ('Kalıtım', 10),
      ('Ekosistem Ekolojisi', 10), ('Güncel Çevre Sorunları', 10),
      ('Sinir Sistemi', 11), ('Endokrin Sistem', 11),
      ('Duyu Organları', 11), ('Destek ve Hareket Sistemi', 11),
      ('Sindirim Sistemi', 11), ('Dolaşım Sistemi', 11),
      ('Solunum Sistemi', 11), ('Boşaltım Sistemi', 11),
      ('Üreme Sistemi ve Embriyonik Gelişim', 11),
      ('Bitki Biyolojisi', 12), ('Komünite ve Popülasyon Ekolojisi', 12),
      ('Nükleik Asitler', 12), ('Genetik Şifre ve Protein Sentezi', 12),
      ('Canlılarda Enerji Dönüşümleri', 12),
    ],
    'türkçe': [
      ('Sözcükte Anlam', 9), ('Cümlede Anlam', 9), ('Paragraf', 9),
      ('Ses Bilgisi', 9), ('Yazım Kuralları', 9), ('Noktalama İşaretleri', 9),
      ('Sözcükte Yapı', 10), ('İsimler', 10), ('Sıfatlar', 10),
      ('Zamirler', 10), ('Zarflar', 10), ('Edat - Bağlaç - Ünlem', 10),
      ('Fiiller', 11), ('Fiilimsiler', 11), ('Fiilde Çatı', 11),
      ('Sözcük Grupları', 11),
      ('Cümlenin Ögeleri', 12), ('Cümle Türleri', 12),
      ('Anlatım Bozuklukları', 12),
    ],
    'edebiyat': [
      ('Güzel Sanatlar ve Edebiyat', 9), ('Şiir Bilgisi', 9),
      ('Söz Sanatları', 9),
      ('İslamiyet Öncesi Türk Edebiyatı', 10), ('Halk Edebiyatı', 10),
      ('Divan Edebiyatı', 10),
      ('Tanzimat Edebiyatı', 11), ('Servet-i Fünun', 11),
      ('Milli Edebiyat', 11), ('Edebi Akımlar', 11),
      ('Cumhuriyet Dönemi Şiiri', 12), ('Cumhuriyet Dönemi Romanı', 12),
      ('Roman', 12), ('Hikaye', 12), ('Tiyatro', 12),
      ('Deneme - Makale - Eleştiri', 12),
    ],
    'tarih': [
      ('Tarih ve Zaman', 9), ('İlk ve Orta Çağlarda Türk Dünyası', 9),
      ('İslam Medeniyetinin Doğuşu', 9), ('Türklerin İslamiyeti Kabulü', 9),
      ('Anadolu Selçuklu Devleti', 9),
      ('Beylikten Devlete (1300-1453)', 10), ('Dünya Gücü Osmanlı (1453-1600)', 10),
      ('Arayış Yılları (17. yy)', 10), ('Diplomasi ve Değişim (18. yy)', 10),
      ('En Uzun Yüzyıl (1800-1922)', 11),
      ('Milli Mücadele', 12), ('Atatürkçülük ve İnkılaplar', 12),
      ('İki Savaş Arası Dönem', 12), ('II. Dünya Savaşı', 12),
      ('Soğuk Savaş Dönemi', 12), ('Yumuşama Dönemi', 12),
      ('Küreselleşen Dünya', 12),
    ],
    'coğrafya': [
      ('Doğa ve İnsan', 9), ('Dünyanın Şekli ve Hareketleri', 9),
      ('Coğrafi Konum', 9), ('Harita Bilgisi', 9), ('İklim Bilgisi', 9),
      ('Basınç ve Rüzgarlar', 9), ('Nem ve Yağış', 9),
      ('İç Kuvvetler - Dış Kuvvetler', 9),
      ('Türkiye’nin Yer Şekilleri', 10), ('Su - Toprak - Bitki', 10),
      ('Nüfus', 10), ('Göç', 10), ('Yerleşme', 10),
      ('Ekonomik Faaliyetler', 11), ('Tarım', 11), ('Hayvancılık', 11),
      ('Madenler ve Enerji', 11), ('Sanayi', 11), ('Ulaşım', 11),
      ('Ticaret - Turizm', 11), ('Bölgeler', 11),
      ('Çevre ve Toplum', 12), ('Doğal Afetler', 12),
    ],
    'felsefe': [
      ('Felsefeyle Tanışma', 11), ('Bilgi Felsefesi', 11),
      ('Varlık Felsefesi', 11), ('Ahlak Felsefesi', 11),
      ('Sanat Felsefesi', 11), ('Din Felsefesi', 11),
      ('Siyaset Felsefesi', 11), ('Bilim Felsefesi', 11), ('Mantık', 11),
      ('MÖ 6 - MS 2 Felsefesi', 12), ('MS 2 - MS 15 Felsefesi', 12),
      ('15 - 17 Yüzyıl Felsefesi', 12), ('18 - 19 Yüzyıl Felsefesi', 12),
      ('20. Yüzyıl Felsefesi', 12),
    ],
    'ingilizce': [
      ('Tenses', 9), ('Prepositions', 9), ('Vocabulary', 9), ('Reading', 9),
      ('Modals', 10), ('Passive Voice', 10),
      ('Conjunctions - Connectors', 10), ('Phrasal Verbs', 10),
      ('Gerunds - Infinitives', 11), ('Relative Clauses', 11),
      ('Noun Clauses', 11), ('Conditionals', 11), ('Reported Speech', 11),
      ('Cloze Test', 12), ('Sentence Completion', 12),
      ('Irrelevant Sentence', 12), ('Paragraph Completion', 12),
      ('Dialogue Completion', 12), ('Restatement', 12), ('Translation', 12),
    ],
    'din kültürü': [
      // 9. sınıf, resmi Maarif Modeli programıyla (tymm.meb.gov.tr) 5 ünite
      // olarak doğrulandı — önceki 2 kalemlik liste eksikti.
      ('Allah-İnsan İlişkisi', 9), ('İslam’da İnanç Esasları', 9),
      ('İslam’da İbadetler', 9), ('İslam’da Ahlak İlkeleri', 9),
      ('Kur’an’a Göre Hz. Muhammed', 9),
      ('Ahlak ve Değerler', 10), ('Din ve Hayat', 10),
      ('Hz. Muhammed’in Hayatı', 11), ('Kur’an ve Yorumu', 11),
      ('İnançla İlgili Meseleler', 11),
      ('Yahudilik ve Hıristiyanlık', 12), ('İslam Düşüncesinde Yorumlar', 12),
      ('Din - Kültür - Medeniyet', 12), ('Güncel Dini Meseleler', 12),
      ('Dünya Dinleri', 12),
    ],
  };

  static List<(String, int)> _entriesFor(String subjectName) {
    final key = subjectName.toLowerCase().replaceAll('̇', '').trim();
    if (_bySubject.containsKey(key)) return _bySubject[key]!;
    // Kısmi eşleşme: "TYT Matematik", "AYT Fizik 1" gibi adlar.
    for (final entry in _bySubject.entries) {
      if (key.contains(entry.key)) return entry.value;
    }
    return const [];
  }

  /// [subjectName] için katalog konuları — eşleşme yoksa boş liste.
  /// [maxGrade] verilirse yalnız `grade <= maxGrade` olan konular döner
  /// (kümülatif). `null` (varsayılan) → tüm liste, eski davranış.
  static List<String> forSubject(String subjectName, {int? maxGrade}) {
    final entries = _entriesFor(subjectName);
    if (maxGrade == null) {
      return entries.map((e) => e.$1).toList();
    }
    return entries.where((e) => e.$2 <= maxGrade).map((e) => e.$1).toList();
  }

  static bool hasCatalog(String subjectName) =>
      _entriesFor(subjectName).isNotEmpty;

  /// Kullanıcının sınıfına göre kataloğun üst sınırı (P0-11, kümülatif).
  /// Sınıf belirtilmemişse `null` — sınırsız/tüm liste. Mezun, 12. sınıfla
  /// aynı üst sınırı görür (YKS'ye hazırlanan konular). Önceden yalnız
  /// subject_topics_screen.dart içinde private bir kopyası vardı; ders
  /// ekleme akışının da (add_subject_sheet.dart) aynı mantığa ihtiyacı
  /// olunca buraya, tek kaynağa taşındı.
  static int? maxGradeFor(int? grade) {
    if (grade == null) return null;
    return grade == UserStatsModel.mezun ? 12 : grade;
  }
}
