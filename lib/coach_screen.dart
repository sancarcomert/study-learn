import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'add_task_screen.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';
import 'focus_screen.dart';
import 'plan_builder.dart';
import 'plan_parser.dart';
import 'study_advisor.dart';
import 'subject_model.dart';
import 'subject_provider.dart';
import 'task_model.dart';
import 'task_provider.dart';
import 'topic_model.dart';
import 'topic_provider.dart';
import 'stats_provider.dart';
import 'deneme_provider.dart';
import 'focus_session_provider.dart';
import 'subject_ai.dart';
import 'tap_scale.dart';
import 'widgets/app_buttons.dart';
import 'widgets/exam_countdown.dart';

/// Çalışma Koçu — serbest sohbetle plan kurar. Çip / çoktan seçmeli YOK:
/// koç doğal dille sorar, kullanıcı yazar, [PlanParser] ayrıştırır, eksik
/// kalanı koç tek tek ister. "Sen ayarla" denince koç günü kendi kurar
/// ([PlanBuilder]). Tüm mantık yerel — LLM yok.
class CoachScreen extends ConsumerStatefulWidget {
  const CoachScreen({super.key});

  @override
  ConsumerState<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends ConsumerState<CoachScreen> {
  final _scroll = ScrollController();
  final _input = _HighlightingController();
  final List<_Turn> _turns = [];

  final _Draft _draft = _Draft();
  bool _delegate = false;
  bool _askedRecurrence = false;

  // Devralma modunda: bugün mü (false), önümüzdeki 7 gün mü (true), henüz
  // sorulmadı mı (null).
  bool? _wantsWeek;

  // Onaya sunulmuş plan (varsa). Tek görev ya da çok görevli gün planı.
  List<PlanBlock>? _pending;
  String _pendingRecurrence = 'none';
  bool _pendingIsDay = false;

  // Onaya sunulmuş haftalık program (varsa) — güne göre gruplu.
  WeekPlanResult? _pendingWeek;

  // "Farklı yap" / "değiştir" dendiğinde gün/hafta planını görünür şekilde
  // değiştirmek için ders sırasını döndürme sayacı (bkz. _proposeDay/Week).
  int _regenerateOffset = 0;

  bool _hasInput = false;

  @override
  void initState() {
    super.initState();
    _input.addListener(() {
      final has = _input.text.trim().isNotEmpty;
      if (has != _hasInput) setState(() => _hasInput = has);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _intro());
  }

  @override
  void dispose() {
    _scroll.dispose();
    _input.dispose();
    super.dispose();
  }

  // --- Konuşma ------------------------------------------------------

  void _say(String text, {bool coach = true}) {
    setState(() => _turns.add(_Turn(coach: coach, text: text)));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _intro() {
    final stats = ref.read(statsProvider);
    final name = stats.userName?.trim();
    final n = (name != null && name.isNotEmpty) ? ' $name' : '';
    _say(_pick([
      'Selam$n. Nasıl gidiyor?',
      'Merhaba$n, bugün keyifler nasıl?',
      'Selam$n, hazırsan başlayalım.',
    ]));

    final examDate = stats.examDate;
    final examLine = (examDate != null && daysUntilExam(examDate) >= 0)
        ? ' Sınava ${daysUntilExam(examDate)} gün var.'
        : '';
    _say('Ne çalışmak istediğini ve ne kadar vaktin olduğunu tek cümleyle '
        'yaz.$examLine İstemiyorsan "sen ayarla" de, ben kurayım.');
  }

  // --- Girdi işleme ----------------------------------------------

  static final _confirm =
      RegExp(r'^(ekle|tamam|evet|olur|kaydet|ekleyebilirsin|onayla|kabul)\b');
  static final _restart =
      RegExp(r'\b(baştan|bastan|iptal|vazgeç|vazgec|sıfırla|sifirla)\b');
  static final _finish = RegExp(
      r'\b(bitir|kapat|yeter|işim bitti|isim bitti|bu kadar|sağ ol|sag ol|teşekkür|tesekkur|yok(?: bu kadar)?)\b');
  static final _delegateRe = RegExp(
      r'\b(sen ayarla|sen yap|sen kur|sen karar|sana bırak|sana birak|sen bil|bilmiyorum|fark etmez|farketmez|önemli değil|onemli degil|'
      // "plan yap" gibi genel istekler — eskiden bunlar ders/konu adı
      // sanılıp taslağa "konu" olarak yazılıyordu (bkz. _merge). Artık
      // devralma moduna (PlanBuilder) yönlendiriliyor.
      r'plan yap|plan oluştur|plan olustur|planla beni|planla bugünü|planla bugunu|'
      r'program yap|program oluştur|program olustur|program kur|'
      r'günümü planla|gunumu planla|haftamı planla|haftami planla|'
      r'bana plan yap|bir plan yap|plan kur|otomatik plan|hazır plan|hazir plan)\b');
  static final _weekIntentRe = RegExp(
      r'(bu hafta|haftalık program|haftalik program|haftalık plan|haftalik plan|hafta boyunca|7 gün|7 gun|yedi gün|yedi gun|bir haftalık|bir haftalik)');
  static final _todayIntentRe = RegExp(
      r'(sadece bugün|sadece bugun|sadece bu gün|bugün olsun|bugun olsun|tek gün|tek gun|sadece bugüne|sadece bugune)');
  // Onaylanmış bir plan varken "farklı yap / değiştir / bir daha dene" gibi
  // bir istek — deterministik PlanBuilder aynı girdiyle aynı çıktıyı
  // verdiğinden, ders sırasını döndürüp (_regenerateOffset) görünür bir
  // fark yaratıyoruz (bkz. _proposeDay/_proposeWeek).
  static final _regenerateRe = RegExp(
      r'\b(farklı yap|farkli yap|başka türlü|baska turlu|değiştir|degistir|'
      r'başka bir şey öner|baska bir sey oner|aynısını yapma|aynisini yapma|'
      r'farklı bir şey|farkli bir sey|başka öneri|baska oneri|'
      r'başka bir plan|baska bir plan|bir daha dene|tekrar dene|'
      r'bi daha yap|bir daha yap|olmadı başka|olmadi baska)\b');

  // --- Duygu durumu / sınır testi / günlük sohbet tespiti ----------------
  // Gerçek bir LLM DEĞİL (CLAUDE.md: "LLM YOK") — yalnız kelime KÖKLERİNİ
  // (çekim ekinden bağımsız, substring ile) yakalayıp önceden yazılmış,
  // duruma uygun bir yerel cevap seçiyor. Açık uçlu anlama yok. Kökler
  // bilerek tam kelime değil — Türkçe çekim çeşitliliği yüzünden ("yoruldum"
  // / "yoruluyorum" / "yorulmuşum" hepsi "yorul" kökünü paylaşır) tam
  // kelime listesi çok dar kalırdı.
  static const List<String> _burnoutPhrases = [
    'bıktım', 'biktim', 'bıkkın', 'bikkin',
    'yorul', 'yorgun',
    'çalışasım', 'calisasim',
    'çalışamı', 'calisami',
    'bırakıyor', 'birakiyor', 'bırakacağ', 'birakacag',
    'pes ediyorum', 'pes ettim', 'pes edece',
    'motivasyon', 'isteksiz',
    'elimden gelmiyor',
    'sıkıl', 'sikil',
    'bezdim', 'bezmiş', 'bezmis',
    'tükendim', 'tukendim', 'tükenmiş', 'tukenmis',
    'napayım artık', 'naapayım artık', 'ne yapayım artık',
    'yılgın', 'yilgin', 'yıldım', 'yildim',
    'usan', 'bunal', 'bunaldım', 'bunaldim',
    'tıkandım', 'tikandim',
    'dayanamıyorum', 'dayanamiyorum',
    'gücüm kalmadı', 'gucum kalmadi',
    'takatim kalmadı', 'takatim kalmadi',
    'enerjim yok', 'hevesim yok', 'hevesim kırıldı', 'hevesim kirildi',
    'içim çekmiyor', 'icim cekmiyor',
    'isteğim yok', 'istegim yok',
    'şevkim kırıldı', 'sevkim kirildi',
    'moralim bozuk', 'moralim sıfır', 'moralim sifir', 'moral bozukluğu',
    'moral bozuklugu',
    'çökmüş durumdayım', 'cokmus durumdayim',
    'bittim', 'tükeniyorum', 'tukeniyorum',
    'yıprandım', 'yiprandim',
    'aşırı yoruldum', 'asiri yoruldum',
    'kapasitem doldu',
    'tıkanmış hissediyorum', 'tikanmis hissediyorum',
    'devam edemiyorum', 'devam edemeyeceğim', 'devam edemeyecegim',
    'vazgeçesim geldi', 'vazgecesim geldi',
    'bırakasım geliyor', 'birakasim geliyor',
    'çekilmez oldu', 'cekilmez oldu',
    'kaldıramıyorum', 'kaldiramiyorum',
    'omuzlarımda yük', 'omuzlarimda yuk',
    'ağır geliyor', 'agir geliyor', 'fazla geliyor',
    'stresliyim', 'stres oldu', 'stresten patlayacağım',
    'stresten patlayacagim', 'çok stresliyim', 'cok stresliyim',
    'baskı altındayım', 'baski altindayim',
    'yükleniyor', 'yukleniyor',
    'psikolojim bozuk',
    'ruh halim kötü', 'ruh halim kotu',
    'kendimi kötü hissediyorum', 'kendimi kotu hissediyorum',
    'depresif', 'depresyon', 'tükenmişlik', 'tukenmislik', 'burnout',
    'iflas ettim', 'tamamen bittim',
    'hiç gücüm yok', 'hic gucum yok', 'hiç isteğim yok', 'hic istegim yok',
    'uyku uyuyamıyorum', 'uyku uyuyamiyorum', 'uykusuzum', 'uykusuzluk',
    // Sabahlama / uyku düzensizliği — bitkinliğin en yaygın somut nedeni.
    'sabahladım', 'sabahladim', 'sabahlıyorum', 'sabahliyorum',
    'gece boyu çalıştım', 'gece boyu calistim', 'hiç uyumadım', 'hic uyumadim',
    'sabaha kadar', 'gözüme uyku girmiyor', 'gozume uyku girmiyor',
  ];

  // Deneme/net "artmıyor" platosu — tükenmişlikten farklı: enerjisi var,
  // çabalıyor ama sonuç görünmüyor hissi. Bu cümlelerin içinde kısa
  // ünlemler ("aq", "ya") sık geçer ama hakaret değil hayal kırıklığı
  // ifadesidir — bu yüzden _onSend'de hostile kontrolünden ÖNCE
  // değerlendirilir, yoksa gerçek içerik görmezden gelinip kullanıcı
  // azarlanmış gibi hissediyor (kullanıcı geri bildirimi: "afallaması").
  static const List<String> _plateauPhrases = [
    'artmıyor',
    'artmiyor',
    'artmıyo',
    'artmiyo',
    'ilerlemiyor',
    'ilerlemiyo',
    'yükselmiyor',
    'yukselmiyor',
    'yükselmiyo',
    'yukselmiyo',
    'değişmiyor',
    'degismiyor',
    'değişmiyo',
    'degismiyo',
    'sonuç alamıyorum',
    'sonuc alamiyorum',
    'boşuna çalışıyorum',
    'bosuna calisiyorum',
    'boşuna uğraşıyorum',
    'bosuna ugrasiyorum',
    'hiç fark etmiyor',
    'hic fark etmiyor',
    'aynı yerde sayıyorum',
    'ayni yerde sayiyorum',
    'net artmıyor',
    'net artmiyor',
    'netlerim artmıyor',
    'netlerim artmiyor',
    'çabalıyorum ama olmuyor',
    'cabaliyorum ama olmuyor',
    'ne yapsam olmuyor',
    'ne yapsam olmuyo',
    'bir türlü artmıyor',
    'bir turlu artmiyor',
  ];

  // Burnout sorusuna ("hangi derse çalışalım?") olumsuz cevap — kullanıcı
  // hiçbirine çalışmak istemiyor, dinlenmek istiyor. Bunu plan önerisiyle
  // karşılamak yanlış (kullanıcı geri bildirimi) — izin vermek doğru.
  static const List<String> _restNeededPhrases = [
    'hiçbirine',
    'hicbirine',
    'hiçbiri',
    'hicbiri',
    'hiç birine',
    'hic birine',
    'hiçbir derse',
    'hicbir derse',
    'hiçbir şeye çalışmak istemiyorum',
    'hicbir seye calismak istemiyorum',
    'hiçbir şey yapmak istemiyorum',
    'hicbir sey yapmak istemiyorum',
    'çalışmak istemiyorum',
    'calismak istemiyorum',
    'istemiyorum çalışmak',
    'istemiyorum calismak',
    'dinlenmek istiyorum',
    'dinlenmek istiyom',
    'mola vermek istiyorum',
    'mola vereyim',
    'ara vermek istiyorum',
    'ara vereyim',
    'bugün çalışmayacağım',
    'bugun calismayacagim',
    'yok çalışmayacağım',
    'yok calismayacagim',
    'boş vereyim bugünü',
    'bos vereyim bugunu',
  ];

  // Kök hâlde tutuluyor (ör. "salak" → "salaksın"/"salak mısın"/"salak"
  // hepsini substring ile yakalar) — çekim eki listesi elle bakımlı
  // tutulmaz.
  static const List<String> _hostilePhrases = [
    'amk',
    'aq',
    'mk',
    'siktir',
    'sikeyim',
    'orospu',
    'piç',
    'pic',
    'gerizekalı',
    'gerizekali',
    'gerzek',
    'şerefsiz',
    'serefsiz',
    'dallama',
    'aptal',
    'salak',
    'ahmak',
    'embesil',
    'geri zekalı',
    'geri zekali',
    'öküz',
    'okuz',
    'mal mısın',
    'mal misin',
    'yavşak',
    'yavsak',
    'ibne',
    'pezevenk',
    'sürtük',
    'surtuk',
    'kaltak',
    'it oğlu',
    'it oglu',
    'namussuz',
    'haysiyetsiz',
    'şıllık',
    'sillik',
    'boktan',
    'sik kafalı',
    'sik kafali',
    'yarrak',
    'yarrağı',
    'yarragi',
    'kevaşe',
    'kevase',
    'ezik',
    'zibidi',
    'ergen',
    'çocuk musun',
    'cocuk musun',
    'sen ne anlarsın',
    'sen ne anlarsin',
    'işe yaramaz',
    'ise yaramaz',
    'saçmalıyorsun',
    'sacmaliyorsun',
    'zırvalıyorsun',
    'zirvaliyorsun',
    'boş konuşuyorsun',
    'bos konusuyorsun',
    'kapa çeneni',
    'kapa ceneni',
    'sus artık',
    'sus artik',
    'defol',
  ];

  // Konu anlatımı / soru çözme talebi — kesin kapsam sınırı (CLAUDE.md):
  // "Canlı ders/koçluk", "Video konu anlatımı", "Soru bankası" asla.
  // Bunlar olmadan bu tür bir cümle PlanParser'a düşerse anlamsız bir
  // "görev" gibi ayrıştırılırdı ("Türevi anlatır mısın" → başlık).
  // Bunun yerine sınırı net ama sıcak bir dille söyleyip plana geri
  // çeker.
  static const List<String> _contentRequestPhrases = [
    'anlat',
    'açıkla',
    'acikla',
    'nasıl çözül',
    'nasil cozul',
    'nasıl yapılır',
    'nasil yapilir',
    'çöz',
    'coz',
    'video öner',
    'video oner',
    'video izle',
    'anlamıyorum',
    'anlamiyorum',
    'anlamadım',
    'anlamadim',
    'çıkmış soru',
    'cikmis soru',
    'ders anlat',
    'konu anlat',
    'bana öğret',
    'bana ogret',
    'öğretir misin',
    'ogretir misin',
    'anlatır mısın',
    'anlatir misin',
    'açıklar mısın',
    'aciklar misin',
    'izah et',
    'izah eder misin',
    'formülü söyle',
    'formulu soyle',
    'formül nedir',
    'formul nedir',
    'formülünü ver',
    'formulunu ver',
    'tarif et',
    'tarif eder misin',
    'örnek çöz',
    'ornek coz',
    'örnek ver',
    'ornek ver',
    'soru sor',
    'soru çöz',
    'soru coz',
    'bu soruyu çöz',
    'bu soruyu coz',
    'bu soruyu yapar mısın',
    'bu soruyu yapar misin',
    'cevabı ver',
    'cevabi ver',
    'sonucu bul',
    'sonucu söyle',
    'sonucu soyle',
    'yardım et bu soruda',
    'yardim et bu soruda',
    'bilmiyorum nasıl yapılır',
    'bilmiyorum nasil yapilir',
    'anlatım videosu',
    'anlatim videosu',
    'ders videosu',
    'video at',
    'link at',
    'kaynak öner',
    'kaynak oner',
    'pdf at',
    'özet çıkar',
    'ozet cikar',
    'özetle',
    'ozetle',
    'tekrar anlat',
    'bir daha anlat',
    'nasıl hesaplanır',
    'nasil hesaplanir',
    'nasıl bulunur',
    'nasil bulunur',
    'kuralını söyle',
    'kuralini soyle',
  ];

  // Sınav kaygısı — tükenmişlikten farklı: "yapamıyorum" değil "olmayacak/
  // kaybedeceğim" korkusu. Ayrı bir ton hak ediyor (güven verici,
  // somutlaştırıcı).
  static const List<String> _examFearPhrases = [
    'başarama',
    'basarama',
    'kazanama',
    'elenece',
    'eleniyo',
    'kaybede',
    'korkuyorum',
    'korkuyoum',
    'kaygı',
    'kaygi',
    'panik',
    'yapamayacağım',
    'yapamayacagim',
    'çakacağım',
    'cakacagim',
    'çakarım',
    'cakarim',
    'düşük alacağım',
    'dusuk alacagim',
    'sıfır çekerim',
    'sifir cekerim',
    'boş geçerim',
    'bos gecerim',
    'yeterli değilim',
    'yeterli degilim',
    'başaramayacağım',
    'basaramayacagim',
    'elenirim',
    'elenmek',
    'geçemeyeceğim',
    'gecemeyecegim',
    'kazanamayacağım',
    'kazanamayacagim',
    'netlerim düşük',
    'netlerim dusuk',
    'netim düşecek',
    'netim dusecek',
    'hedefe ulaşamam',
    'hedefe ulasamam',
    'hayalim suya düşecek',
    'hayalim suya dusecek',
    'çok geriden geliyorum',
    'cok geriden geliyorum',
    'yetişemiyorum',
    'yetisemiyorum',
    'vakit yetmiyor',
    'zaman yetmiyor',
    'çok az vaktim kaldı',
    'cok az vaktim kaldi',
    'sınava az kaldı korkuyorum',
    'sinava az kaldi korkuyorum',
    'stres yapıyorum sınavdan',
    'stres yapiyorum sinavdan',
    'sınav stresim',
    'sinav stresim',
    'içim rahat değil sınav için',
    'icim rahat degil sinav icin',
    'beynim durdu',
    'panikliyorum',
    'panik atak',
    'panik oluyorum',
    'tir tir titriyorum',
    'elim ayağım titriyor',
    'elim ayagim titriyor',
    'midem bulanıyor sınav',
    'midem bulaniyor sinav',
    'sınav kaygısı',
    'sinav kaygisi',
    'içim içimi yiyor',
    'icim icimi yiyor',
  ];

  // Başkasıyla kıyaslama — YKS öğrencilerinde çok yaygın bir kaygı kaynağı.
  static const List<String> _comparisonPhrases = [
    'benden daha',
    'benden iyi',
    'herkes benden',
    'arkadaşım benden',
    'arkadasim benden',
    'sınıfta herkes',
    'sinifta herkes',
    'ondan geride',
    'geride kal',
    'geri kalıyorum',
    'geri kaliyorum',
    'komşunun çocuğu',
    'komsunun cocugu',
    'arkadaşlarım çok önde',
    'arkadaslarim cok onde',
    'herkes bitirmiş',
    'herkes bitirmis',
    'herkes yaptı bile',
    'herkes yapti bile',
    'ben geride kaldım',
    'ben geride kaldim',
    'başkaları daha hızlı',
    'baskalari daha hizli',
    'çevremdeki herkes',
    'cevremdeki herkes',
    'sınıf birincisi',
    'sinif birincisi',
    'o kadar iyi değilim',
    'o kadar iyi degilim',
    'ondan kötüyüm',
    'ondan kotuyum',
    'onunla kıyaslanınca',
    'onunla kiyaslaninca',
    'herkes benden ileride',
    'rakiplerim benden iyi',
    'diğerleri benden iyi',
    'digerleri benden iyi',
    'arkadaşım kazanacak',
    'arkadasim kazanacak',
    'ben kazanamayacağım',
    'ben kazanamayacagim',
    'başkalarıyla kıyaslıyorum',
    'baskalariyla kiyasliyorum',
    'kendimi başkalarıyla',
    'kendimi baskalariyla',
  ];

  // Ders hakkında olumsuz duygu ("nefret ediyorum", "zor geliyor") —
  // [_detectSubjectMention] ile birlikte kullanılır, ders adı bulunursa
  // cevaba işlenir.
  static const List<String> _negativeSubjectSentiment = [
    'nefret ediyorum',
    'sevmiyorum',
    'sevmedim',
    'zor geliyor',
    'zor geliyo',
    'çok zor',
    'cok zor',
    'anlayamıyorum',
    'anlayamiyorum',
    'kötüyüm',
    'kotuyum',
    'başarısızım',
    'basarisizim',
    'iğreniyorum',
    'igreniyorum',
    'tiksiniyorum',
    'çok sıkıcı',
    'cok sikici',
    'sıkıcı geliyor',
    'sikici geliyor',
    'anlam veremiyorum',
    'kafama girmiyor',
    'hiç girmiyor kafama',
    'hic girmiyor kafama',
    'beynim almıyor',
    'beynim almiyor',
    'saçma geliyor',
    'sacma geliyor',
    'mantıksız geliyor',
    'mantiksiz geliyor',
    'yapamıyorum bu dersi',
    'yapamiyorum bu dersi',
    'beceremiyorum',
    'çuvallıyorum',
    'cuvalliyorum',
    'sıfır çekiyorum bu dersten',
    'sifir cekiyorum bu dersten',
    'en kötü dersim',
    'en kotu dersim',
    'en zayıf olduğum ders',
    'en zayif oldugum ders',
    'asla anlamayacağım',
    'asla anlamayacagim',
    'kafam basmıyor',
    'kafam basmiyor',
    'beynim yanıyor',
    'beynim yaniyor',
    'bu ders beni bitiriyor',
    'bu ders yıpratıyor',
    'bu ders yipratiyor',
    'korkuyorum bu dersten',
    'bu dersten nefret',
    'bu derse alerjim var',
    'içim kaldırmıyor',
    'icim kaldirmiyor',
    'kabus gibi',
    'çile gibi',
    'cile gibi',
  ];

  // Ders hakkında olumlu duygu — [_detectSubjectMention] ile birlikte.
  static const List<String> _positiveSubjectSentiment = [
    'seviyorum',
    'bayılıyorum',
    'bayiliyorum',
    'en sevdiğim',
    'en sevdigim',
    'kolay geliyor',
    'çok iyiyim',
    'çok seviyorum',
    'cok seviyorum',
    'en güçlü dersim',
    'en guclu dersim',
    'en iyi olduğum ders',
    'en iyi oldugum ders',
    'keyif alıyorum',
    'keyif aliyorum',
    'zevk alıyorum',
    'zevk aliyorum',
    'eğlenceli geliyor',
    'eglenceli geliyor',
    'çok yatkınım',
    'cok yatkinim',
    'doğal yeteneğim var',
    'dogal yetenegim var',
    'rahat anlıyorum',
    'rahat anliyorum',
    'hemen kavrıyorum',
    'hemen kavriyorum',
    'çabuk öğreniyorum',
    'cabuk ogreniyorum',
    'favori dersim',
    'gözde dersim',
    'gozde dersim',
    'harika gidiyorum',
    'süper gidiyorum',
    'super gidiyorum',
    'yüksek net alıyorum',
    'yuksek net aliyorum',
    'çok başarılıyım',
    'cok basariliyim',
    'gayet iyiyim bu derste',
  ];

  // Doğal sohbet — sadece giriş selamında değil, sohbet ortasında da
  // gelebilir. Üç alt kategoriye ayrılıyor çünkü her biri farklı bir
  // cevap hak ediyor (selam ≠ "sen kimsin" ≠ "ne yapıyorsun").
  static const List<String> _greetingPhrases = [
    'naber',
    'ne haber',
    'nabersin',
    'selam',
    'merhaba',
    'hey',
    'günaydın',
    'gunaydin',
    'iyi akşamlar',
    'iyi aksamlar',
    'iyi geceler',
    'iyi günler',
    'iyi gunler',
    'selamlar',
    'merhabalar',
    'mrb',
    'slm',
    'hello',
    'hey sana',
    'günaydınlar',
    'gunaydinlar',
    'tünaydın',
    'tunaydin',
    'iyi sabahlar',
    'hayırlı günler',
    'hayirli gunler',
    'hoş geldin',
    'hos geldin',
    'naberr',
    'selam koç',
    'selam koc',
    'selamün aleyküm',
    'selamun aleykum',
    'selamünaleyküm',
    'selamunaleykum',
    'aleyküm selam',
    'aleykum selam',
    'eyvallah',
    'eyw',
    'merhabaa',
    'merhabaaa',
    'selammm',
    'heyyy',
    'hayırlı sabahlar',
    'hayirli sabahlar',
    'günaydın koç',
    'gunaydin koc',
    'heya',
    'selam dostum',
    'selam koçum',
    'selam kocum',
  ];

  static const List<String> _wellbeingCheckPhrases = [
    'nasılsın',
    'nasilsin',
    'iyi misin',
    'nasıl gidiyor',
    'nasil gidiyor',
    'keyifler nasıl',
    'keyifler nasil',
    'ne var ne yok',
    'naber ne var ne yok',
    'iyi misiniz',
    'moralin nasıl',
    'moralin nasil',
    'moral nasıl',
    'moral nasil',
    'durumun nasıl',
    'durumun nasil',
    'bugün nasılsın',
    'bugun nasilsin',
    'iyi hissediyor musun',
    'keyfin nasıl',
    'keyfin nasil',
    'naber nasılsın',
    'naber nasilsin',
    'keyifler ne alemde',
    'ne alemdesin',
    'napıyosun nasılsın',
    'napiyosun nasilsin',
    'iyi misin bakalım',
    'iyi misin bakalim',
    'bugün iyi misin',
    'bugun iyi misin',
    'moralin yerinde mi',
    'her şey yolunda mı',
    'her sey yolunda mi',
    'iyi gidiyor mu',
    'nasıl hissediyorsun',
    'nasil hissediyorsun',
    'keyifler yerinde mi',
  ];

  static const List<String> _botIdentityPhrases = [
    'sen kimsin',
    'kimsin',
    'adın ne',
    'adin ne',
    'ismin ne',
    'yapay zeka mısın',
    'yapay zeka misin',
    'bot musun',
    'robot musun',
    'gerçek misin',
    'gercek misin',
    'insan mısın',
    'insan misin',
    'chatgpt misin',
    'chat gpt misin',
    'gpt misin',
    'claude misin',
    'openai mısın',
    'openai misin',
    'bir program mısın',
    'bir program misin',
    'kod musun',
    'algoritma mısın',
    'algoritma misin',
    'gerçek insan mısın',
    'gercek insan misin',
    'arkanda kim var',
    'seni kim yaptı',
    'seni kim yapti',
    'seni kim yazdı',
    'seni kim yazdi',
    'hangi şirket yaptı seni',
    'hangi sirket yapti seni',
    'yaşın kaç',
    'yasin kac',
    'kaç yaşındasın',
    'kac yasindasin',
    'nerelisin',
    'neredesin sen',
    'yapay zekamısın',
    'yapayzeka mısın',
    'yapayzeka misin',
    'botmusun',
    'robotsun değil mi',
    'robotsun degil mi',
    'gerçek biri değilsin',
    'gercek biri degilsin',
    'chatgptmisin',
    'chat gpt mısın',
    'chat gpt misin',
    'openai ürünü müsün',
    'openai urunu musun',
    'claude ai mısın',
    'claude ai misin',
    'seni kim geliştirdi',
    'seni kim gelistirdi',
    'seni hangi firma yaptı',
    'seni hangi firma yapti',
    'seni hangi şirket kodladı',
    'seni hangi sirket kodladi',
    'karşımdaki bot mu',
    'karsimdaki bot mu',
  ];

  static const List<String> _casualCheckInPhrases = [
    'ne yapıyorsun',
    'ne yapiyorsun',
    'napıyorsun',
    'napiyorsun',
    'ne yapıyon',
    'ne yapiyon',
    'ne yapıyorsun şu an',
    'ne yapiyorsun su an',
    'boş musun',
    'bos musun',
    'meşgul müsün',
    'mesgul musun',
    'müsait misin',
    'musait misin',
    'ne haldesin',
    'şu an neredesin',
    'su an neredesin',
    'ne işle uğraşıyorsun',
    'ne isle ugrasiyorsun',
    'ne yapıyorsun orada',
    'ne yapiyorsun orada',
    'ne yapıyorsun orda',
    'ne yapiyorsun orda',
    'boş musun şu an',
    'bos musun su an',
    'müsait misin şimdi',
    'musait misin simdi',
    'ne alemdesin sen',
    'ne haldesin bakalım',
    'ne haldesin bakalim',
    'napıyoz',
    'napiyoz',
    'ne iş çeviriyorsun',
    'ne is ceviriyorsun',
  ];

  static const List<String> _jokePhrases = [
    'espri yap',
    'şaka yap',
    'saka yap',
    'fıkra anlat',
    'fikra anlat',
    'beni güldür',
    'beni guldur',
    'komik bir şey söyle',
    'komik bir sey soyle',
    'matematik esprisi',
    'matematik espirisi',
    'bilmece sor',
    'bilmece',
    'fıkra',
    'fikra',
    'komik konuş',
    'komik konus',
    'eğlenceli bir şey',
    'eglenceli bir sey',
    'güldür beni',
    'guldur beni',
    'matematik fıkrası anlat',
    'matematik fikrasi anlat',
    'komik bir laf söyle',
    'komik bir laf soyle',
    'espri patlat',
    'bir şaka anlat',
    'bir saka anlat',
  ];

  // Uygulamayı nasıl kullanacağını bilmeyen kullanıcı — kısa kullanım
  // hatırlatması.
  static const List<String> _usageConfusionPhrases = [
    'nasıl kullanılıyor',
    'nasil kullaniliyor',
    'nasıl çalışıyor bu',
    'nasil calisiyor bu',
    'ne yapmam lazım burada',
    'ne yapmam lazim burada',
    'ne yazmam gerekiyor',
    'nasıl yazacağım',
    'nasil yazacagim',
    'bu uygulama ne işe yarıyor',
    'bu uygulama ne ise yariyor',
    'nasıl görev eklerim',
    'nasil gorev eklerim',
    'nasıl plan yaparım',
    'nasil plan yaparim',
    'ne yazacağımı bilmiyorum',
    'ne yazacagimi bilmiyorum',
    'buraya ne yazmalıyım',
    'buraya ne yazmaliyim',
    'kullanmayı bilmiyorum',
    'kullanmayi bilmiyorum',
    'ilk defa kullanıyorum',
    'ilk defa kullaniyorum',
    'yeni kullanıcıyım',
    'yeni kullaniciyim',
    'komut nedir',
    'hangi kelimeleri yazmalıyım',
    'hangi kelimeleri yazmaliyim',
    'elimden bir şey gelmiyor burada',
    'elimden bir sey gelmiyor burada',
    'burada ne yapacağımı bilmiyorum',
    'burada ne yapacagimi bilmiyorum',
    'ilk kez giriyorum buraya',
    'yeni indirdim uygulamayı',
    'yeni indirdim uygulamayi',
    'nasıl mesaj yazacağım',
    'nasil mesaj yazacagim',
  ];

  bool _matchesAny(String low, List<String> phrases) =>
      phrases.any((p) => low.contains(p));

  /// [raw] içinde kullanıcının kendi ders listesindeki bir dersin adı ya da
  /// (yoksa) [SubjectAI] tahmini geçiyorsa adını döndürür — ders duygusu
  /// tespitinde ("matematikten nefret ediyorum") kullanılır.
  String? _detectSubjectMention(String raw) {
    final low = raw.toLowerCase().replaceAll('̇', '');
    for (final s in ref.read(subjectProvider)) {
      if (low.contains(s.name.toLowerCase())) return s.name;
    }
    return SubjectAI.predict(raw);
  }

  void _onSend() {
    final raw = _input.text.trim();
    if (raw.isEmpty) return;
    _input.clear();
    FocusScope.of(context).unfocus();
    _say(raw, coach: false);

    final low = raw.toLowerCase().replaceAll('̇', '');

    if (_matchesAny(low, _burnoutPhrases)) {
      _say(_pick([
        'Bu hissi herkes yaşıyor, çok normal. Ama pes etmek yok — 15 '
            'dakikalık ufak bir şeyle başlayalım. Hangi ders, kaç dakika?',
        'Yorgunluk birikir, sonra patlar — şimdilik büyük hedefleri unut. '
            'Bana bir ders adı ve 15-20 dakika söyle, oradan başlarız.',
        'Normal bu, moralini bozma. Masadan tamamen kalkma — küçük bir '
            'adım yeter. Hangi derse 15 dakika ayırabilirsin?',
        'Deneme netleri bir gecede artmıyor, sabırla birikiyor — bu gece '
            'erken yat. Şimdilik sadece 15 dakika, hangi ders?',
        'Tükenmek bitmek değil, mola sinyali. Bugün büyük hedef yok — '
            'ufak bir blok yeter. Hangi derse 15 dakika ayırırsın?',
      ]));
      return;
    }

    // Burnout sorusuna ("hangi derse?") olumsuz yanıt — plan önermek yerine
    // dinlenmeye izin ver.
    if (_matchesAny(low, _restNeededPhrases)) {
      _say(_pick([
        'Tamam, o zaman bugün kendine izin ver — dinlenmek de planın bir '
            'parçası. Hazır olduğunda buradayım.',
        'Sorun değil, zorlamıyorum. Bugünü dinlenmeye ayır, yarın devam '
            'ederiz.',
        'Anladım, bugün mola. Kafan dinlenince hangi derse bakacağız, o '
            'zaman konuşuruz.',
      ]));
      return;
    }

    if (_matchesAny(low, _plateauPhrases)) {
      _say(_pick([
        'Net birikimi yavaş görünür ama birikir — bugün attığın her adım '
            'sayılıyor, hemen görünmese de. Hangi derse 15-20 dakika '
            'ayıralım?',
        'Bu çok normal, ilerleme bazen görünmez ama arka planda birikir. '
            'Küçük bir blokla devam edelim — hangi ders?',
        'Sonuç görünmemesi çabanın boşa gittiği anlamına gelmez, netler '
            'genelde birikip birden sıçrar. Bugün hangi derse odaklanalım?',
      ]));
      return;
    }

    if (_matchesAny(low, _contentRequestPhrases)) {
      _say(_pick([
        'Ben konu anlatmıyorum ya da soru çözmüyorum — o iş kitabında/'
            'öğretmeninde. Ama planını kurmakta ve takibinde tam '
            'yanındayım. Bu konuya çalışma bloğu ayarlayalım mı?',
        'Bunu sana ben anlatamam, kapsamım dışında. Onun yerine bu konuyu '
            'ne zaman çalışacağını planlayalım — kaç dakika ayırırsın?',
        'Anlatım/çözüm benim işim değil, plan kurmak benim işim. '
            'İstersen bu konuyu bugüne bir görev olarak ekleyeyim.',
      ]));
      return;
    }

    if (_matchesAny(low, _examFearPhrases)) {
      _say(_pick([
        "Bu korkuyu YKS'ye hazırlanan herkes hissediyor, yalnız değilsin. "
            'Kaygı düşünmekle değil, küçük somut adımlarla azalır. Bugün '
            'ne çalışalım?',
        'Sonuç şu an belli değil, ama bugün ne yaptığın belli olacak. '
            'Bir ders seç, küçük bir blok çalışalım — geri kalanı '
            'zamanla gelir.',
        'Bu his geçici, geride bıraktığın her gün seni ileri taşıyor. '
            'Hadi bugüne odaklanalım — hangi ders?',
        'Bir paragrafı kaçırman ya da bir denemenin kötü geçmesi dünyanın '
            'sonu değil — asıl mesele bugün masaya oturman. Hangi ders?',
      ]));
      return;
    }

    if (_matchesAny(low, _comparisonPhrases)) {
      _say(_pick([
        'Başkasının hızı seni bağlamaz — tek kıyaslaman gereken dünkü '
            'hâlin. Bugün neyi ilerletmek istersin?',
        'Herkesin kendi temposu var, yarış onunla değil kendinle. Bugün '
            'hangi derse odaklanalım?',
        'Bu kıyas seni yormaktan başka bir şey yapmaz. Enerjini kendi '
            'planına harcayalım — ne çalışıyorsun?',
        'Arkadaşının netleri seni ilgilendirmez, senin dünkü netlerin '
            'ilgilendirir. Bugün hangi dersi kasıyoruz?',
      ]));
      return;
    }

    final subjectMention = _detectSubjectMention(raw);
    if (subjectMention != null && _matchesAny(low, _negativeSubjectSentiment)) {
      _say(_pick([
        '$subjectMention pek çok kişinin zorlandığı bir ders — yalnız '
            'değilsin. Küçük adımlarla başlarsak korkusu azalır, 15 '
            'dakika dener misin?',
        '$subjectMention için bu his normal. Sevmesen de birazcık '
            'çalışmak fark yaratır — kaç dakika ayırabilirsin?',
        'Zor gelmesi sevmediğin anlamına gelmez, alışkın olmadığın '
            'anlamına gelir. $subjectMention\'a küçük bir blokla '
            'başlayalım mı?',
        '$subjectMention kasmak can sıkıcı olabilir ama küçük dozlarda '
            'başlarsan kafan o kadar yorulmaz. 15 dakika dener misin?',
      ]));
      return;
    }
    if (subjectMention != null && _matchesAny(low, _positiveSubjectSentiment)) {
      _say(_pick([
        'Güzel, $subjectMention seni motive ediyor. O zaman bugün ona '
            'biraz zaman ayıralım — kaç dakika?',
        '$subjectMention senin güçlü yanın gibi duruyor, bu enerjiyi '
            'kullanalım. Ne kadar çalışacaksın?',
        'Sevdiğin bir derste ilerlemek daha kolay — hadi $subjectMention '
            'için bir blok ayarlayalım.',
      ]));
      return;
    }

    // Küfür/sınır testi — hostile kontrolü bilinçli olarak burada, tükenmişlik/
    // net-platosu/sınav kaygısı gibi içerik kategorilerinden SONRA çalışıyor.
    // "Denemelerim artmıyo aq" gibi cümlelerde "aq" hakaret değil hayal
    // kırıklığı ünlemi — önce içerik yakalanmalı, yoksa kullanıcı asıl
    // derdi görmezden gelinip azarlanmış gibi hissediyor.
    if (_matchesAny(low, _hostilePhrases)) {
      _say(_pick([
        'Bu kelimeler netlerini artırmayacak. Enerjini masadaki kitaba '
            'harcayalım — hangi derse çalışıyorsun?',
        'Küfürle net gelmiyor. Onun yerine bir ders adı ve süre ver, '
            'işe koyulalım.',
        'Bunu bir kenara bırakalım. Şu an hangi dersle uğraşıyorsun?',
        'Bu enerjiyle bir konu bile bitirebilirdik aslında. Hadi o '
            'gazı derse ver — hangisi?',
        'Küfür yerine matematik kas, daha çok işine yarar. Hangi '
            'derse geçiyoruz?',
      ]));
      return;
    }

    if (_matchesAny(low, _usageConfusionPhrases)) {
      _say('Basit: bana bir ders + süre söyle ("yarın 2 saat matematik" '
          'gibi), planına eklerim. İstersen "sen ayarla" de, günü ben '
          'kurayım.');
      return;
    }

    if (_matchesAny(low, _botIdentityPhrases)) {
      _say('Ben Pusula\'nın Çalışma Koçu\'yum — karmaşık bir yapay zeka '
          'değilim, basit ama işe yarar bir planlama yardımcısıyım. '
          'Ne çalışalım?');
      return;
    }

    if (_matchesAny(low, _wellbeingCheckPhrases)) {
      _say(_pick([
        'İyiyim, sağ ol. Sıra sende — bugün ne çalışıyoruz?',
        'Gayet iyi. Sen nasılsın, bugün çalışmaya hazır mısın?',
        'Keyifler yerinde. Hadi başlayalım — ne çalışmak istersin?',
      ]));
      return;
    }

    if (_matchesAny(low, _casualCheckInPhrases)) {
      _say(_pick([
        'Seni bekliyordum aslında. Ne çalışmak istersin?',
        'Planlar kuruyorum, tam senlik bir iş — hangi derse bakalım?',
      ]));
      return;
    }

    if (_matchesAny(low, _jokePhrases)) {
      _say(_pick([
        'Şakada pek iyi değilim ama planlamada eşim yok. Hadi bir ders '
            'seçelim.',
        'Espri konusunda zayıfım, plan konusunda güçlüyüm. Ne '
            'çalışıyoruz?',
      ]));
      return;
    }

    if (_matchesAny(low, _greetingPhrases)) {
      _say(_pick([
        'Selam. Bugün ne çalışmak istersin?',
        'Merhaba, hazırsan başlayalım — hangi ders?',
        'Selam sana da. Ne kadar vaktin var bugün?',
      ]));
      return;
    }

    if (_pending != null && _confirm.hasMatch(low)) {
      _commit();
      return;
    }
    // "Farklı yap / değiştir" — deterministik PlanBuilder aynı girdiyle aynı
    // sonucu verdiğinden (kullanıcı geri bildirimi: "aynısını söylüyor"),
    // gün/hafta planında ders sırasını döndürüp gerçekten farklı bir öneri
    // üretiyoruz. Tek görevde döndürecek bir şey yok — ne değiştireceğini
    // sorarız.
    if (_pending != null && _regenerateRe.hasMatch(low)) {
      if (_pendingIsDay) {
        _regenerateOffset++;
        if (_pendingWeek != null) {
          _proposeWeek();
        } else {
          _proposeDay();
        }
      } else {
        _say(_pick([
          'Neyi değiştireyim — süreyi, günü ya da dersi mi? Söylersen '
              'güncelleyeyim.',
          'Peki, hangisini değiştireyim: süre, gün ya da ders?',
        ]));
      }
      return;
    }
    if (_restart.hasMatch(low)) {
      _draft.reset();
      _pending = null;
      _pendingWeek = null;
      _delegate = false;
      _wantsWeek = null;
      _askedRecurrence = false;
      _regenerateOffset = 0;
      _say(_pick([
        'Tamam, temizledim. Baştan anlat bakalım.',
        'Sildim gitti. Yeniden başlayalım — ne çalışacaksın?',
      ]));
      return;
    }
    if (_pending == null && _draft.isEmpty && _finish.hasMatch(low)) {
      _say(_pick(['Kolay gelsin.', 'İyi çalışmalar.', 'Hadi kolay gelsin.']));
      return;
    }

    if (_delegateRe.hasMatch(low)) _delegate = true;

    if (_delegate) {
      if (_weekIntentRe.hasMatch(low)) {
        _wantsWeek = true;
      } else if (_todayIntentRe.hasMatch(low)) {
        _wantsWeek = false;
      } else if (_draft.minutes != null && _wantsWeek == null) {
        // "bugün mü / bu hafta mı" sorusuna serbest cevap.
        if (low.contains('hafta')) {
          _wantsWeek = true;
        } else if (low.contains('bugün') ||
            low.contains('bugun') ||
            low.contains('gün') ||
            low.contains('gun')) {
          _wantsWeek = false;
        }
      }
    }

    // Yeni/değişen alanları fark edip geri yansıtabilmek için birleştirme
    // öncesi taslağın fotoğrafını al — "senaryo robotu" hissini bu kırıyor.
    final snap = (
      subject: _draft.subjectName,
      topic: _draft.topic,
      minutes: _draft.minutes,
      day: _draft.day,
      hour: _draft.hour,
      rec: _draft.recurrence,
    );

    final parsed = PlanParser.parse(raw, subjects: ref.read(subjectProvider));
    _merge(parsed, raw);

    final ack = _ackLine(snap);
    if (ack.isNotEmpty) _say(ack);

    // Onay beklerken gelen serbest metin = düzenleme; yeni bilgiyi al, planı
    // tazele.
    _pending = null;
    _advance();
  }

  /// Kullanıcının son mesajında yakalanan (ya da değiştirilen) alanları kısaca
  /// geri yansıtır — "Not aldım — Matematik: türev · 2 saat." Boşsa hiçbir şey.
  String _ackLine(
      ({
        String? subject,
        String? topic,
        int? minutes,
        DateTime? day,
        int? hour,
        String rec
      }) before) {
    final bits = <String>[];

    final subjectChanged = _draft.hasSubject &&
        (before.subject != _draft.subjectName || before.topic != _draft.topic);
    if (subjectChanged) bits.add(_composeTitle());

    if (_draft.minutes != null && before.minutes != _draft.minutes) {
      bits.add(_fmtMinutes(_draft.minutes!));
    }
    if (_draft.day != null && before.day != _draft.day) {
      bits.add(_dayLabel(_draft.day!));
    }
    if (_draft.hour != null && before.hour != _draft.hour) {
      bits.add(_hhmm(_draft.hour!, _draft.minute ?? 0));
    }
    if (_draft.recurrence != 'none' && before.rec != _draft.recurrence) {
      bits.add(_recLabel(_draft.recurrence).replaceFirst(' · ', ''));
    }

    if (bits.isEmpty) return '';
    return '${_pick(['Tamam', 'Not aldım', 'Anladım', 'Peki'])} — '
        '${bits.join(' · ')}.';
  }

  String _fmtMinutes(int m) {
    if (m <= 0) return '';
    if (m % 60 == 0) return '${m ~/ 60} saat';
    if (m < 60) return '$m dk';
    return '${m ~/ 60} sa ${m % 60} dk';
  }

  void _merge(ParsedPlan p, String raw) {
    if (p.date != null) _draft.day = p.date;
    if (p.durationMinutes != null) _draft.minutes = p.durationMinutes;
    if (p.recurrence != 'none') _draft.recurrence = p.recurrence;
    if (p.hasTime) {
      _draft.hour = p.hour;
      _draft.minute = p.minute ?? 0;
    }
    if (p.subjectId != null) {
      _draft.subjectId = p.subjectId;
      _draft.subjectName = p.subjectName;
    } else if (p.subjectName != null) {
      _draft.subjectName = p.subjectName;
    }

    final t = p.title.trim();
    final sameAsSubject =
        t.toLowerCase() == (p.subjectName ?? '').toLowerCase();
    final rawLow = raw.toLowerCase().replaceAll('̇', '');
    // "plan yap" / "farklı yap" gibi komut cümleleri — sinyalsiz olduğu için
    // aşağıdaki fallback'e düşüp yanlışlıkla konu adı sanılabilirdi (bkz.
    // _delegateRe, _regenerateRe). Bunlar zaten kendi kontrollerinde ele
    // alınıyor, konu olarak taslağa yazılmamalı.
    final isMetaCommand =
        _delegateRe.hasMatch(rawLow) || _regenerateRe.hasMatch(rawLow);
    if (t.isNotEmpty && p.hasSignal && !sameAsSubject) {
      _draft.topic = t;
    } else if (!_draft.hasSubject &&
        !p.hasSignal &&
        t.isNotEmpty &&
        !isMetaCommand) {
      // Sinyalsiz düz cevap ("deneme analizi") → konu olarak kabul et.
      _draft.topic = raw.trim();
    }
  }

  // --- Akış kararı ---------------------------------------------

  int _q = 0;
  String _pick(List<String> options) => options[_q++ % options.length];

  /// [_regenerateOffset] kadar döndürülmüş liste — "farklı yap" dendiğinde
  /// PlanBuilder'a farklı bir öncelik sırası vererek görünür bir fark
  /// üretmek için (bkz. _proposeDay/_proposeWeek/_regenerateRe).
  List<SubjectModel> _rotated(List<SubjectModel> list) {
    if (list.isEmpty || _regenerateOffset == 0) return list;
    final shift = _regenerateOffset % list.length;
    if (shift == 0) return list;
    return [...list.skip(shift), ...list.take(shift)];
  }

  void _advance() {
    final subjects = ref.read(subjectProvider);
    if (subjects.isEmpty) {
      _say('Önce en az bir ders eklemen lazım. Profil → Derslerim\'den '
          'ekleyip geri gelebilirsin.');
      return;
    }

    if (_delegate) {
      if (_draft.minutes == null) {
        _say(_pick([
          'Tamam, ben kurayım. Günde ortalama ne kadar vaktin var?',
          'Olur, devralıyorum. Günde kaç saat çalışabilirsin?',
          'Peki. Bir günde kabaca ne kadar zaman ayırabiliyorsun?',
        ]));
        return;
      }
      if (_wantsWeek == null) {
        _say(_pick([
          'Sadece bugüne mi bakalım, yoksa "bu hafta" deyip 7 güne mi yayayım?',
          'Bugünlük mü olsun, haftalık bir program mı istersin? '
              '("bugün" / "bu hafta")',
        ]));
        return;
      }
      if (_wantsWeek!) {
        _proposeWeek();
      } else {
        _proposeDay();
      }
      return;
    }

    if (!_draft.hasSubject) {
      _say(_pick([
        'Ne çalışmak istiyorsun?',
        'Hangi derse ya da konuya bakalım?',
        'Bugün aklında ne var — hangi ders?',
      ]));
      return;
    }
    if (_draft.minutes == null) {
      _say(_pick([
        'Buna ne kadar zaman ayıralım?',
        'Kaç dakika ya da saat düşünüyorsun?',
        'Ne kadarlık bir çalışma olsun?',
      ]));
      return;
    }
    if (_draft.day == null) {
      _say(_pick([
        'Ne zaman? "Bugün", "yarın" ya da bir gün söyle.',
        'Hangi gün olsun — bugün mü, yarın mı, başka bir gün mü?',
        'Ne günü koyalım bunu?',
      ]));
      return;
    }
    if (_draft.recurrence == 'none' && !_askedRecurrence) {
      _askedRecurrence = true;
      _say(_pick([
        'Tek seferlik mi, yoksa tekrar mı etsin? '
            '(ör. "her gün", "her pazartesi", ya da "tek sefer")',
        'Bir kez mi olsun, düzenli mi? "her gün" / "her salı" / "tek sefer".',
      ]));
      return;
    }

    _proposeSingle();
  }

  // --- Öneri ---------------------------------------------------

  static const _months = [
    'Oca',
    'Şub',
    'Mar',
    'Nis',
    'May',
    'Haz',
    'Tem',
    'Ağu',
    'Eyl',
    'Eki',
    'Kas',
    'Ara',
  ];

  static const _weekdayShort = [
    'Pzt',
    'Sal',
    'Çar',
    'Per',
    'Cum',
    'Cmt',
    'Paz',
  ];

  String _dayLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = DateTime(d.year, d.month, d.day).difference(today).inDays;
    if (diff == 0) return 'Bugün';
    if (diff == 1) return 'Yarın';
    return '${d.day} ${_months[d.month - 1]}';
  }

  String _weekdayLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = DateTime(d.year, d.month, d.day).difference(today).inDays;
    if (diff == 0) return 'Bugün';
    if (diff == 1) return 'Yarın';
    return '${_weekdayShort[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}';
  }

  String _hhmm(int h, int m) =>
      '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

  String _recLabel(String r) => switch (r) {
        'daily' => ' · her gün',
        'weekly' => ' · her hafta',
        _ => '',
      };

  String _composeTitle() {
    final s = _draft.subjectName;
    final t = _draft.topic;
    if (s != null && t != null && t.toLowerCase() != s.toLowerCase()) {
      return '$s: $t';
    }
    return t ?? s ?? 'Çalışma';
  }

  /// Kullanıcının yazdığı serbest konu metni ("türev"), o derste Konu
  /// Takip'te zaten kayıtlı bir konuyla (ad, büyük/küçük harf duyarsız)
  /// birebir eşleşiyorsa id'sini döndürür — görev tamamlanınca o konu
  /// otomatik işaretlensin diye. Eşleşme yoksa null (davranış değişmez).
  String? _matchTopicId(String? subjectId, String? topicText) {
    if (subjectId == null) return null;
    final needle = topicText?.trim().toLowerCase();
    if (needle == null || needle.isEmpty) return null;
    for (final t in ref.read(topicProvider)) {
      if (t.subjectId == subjectId && t.name.toLowerCase() == needle) {
        return t.id;
      }
    }
    return null;
  }

  void _proposeSingle() {
    final now = DateTime.now();
    final day = _draft.day ?? DateTime(now.year, now.month, now.day);
    final minutes = _draft.minutes ?? 45;

    _pending = [
      PlanBlock(
        title: _composeTitle(),
        subjectId: _draft.subjectId ?? '',
        minutes: minutes,
        order: 0,
        priority: TaskPriority.medium,
        topicId: _matchTopicId(_draft.subjectId, _draft.topic),
      ),
    ];
    _pendingRecurrence = _draft.recurrence;
    _pendingIsDay = false;

    final timePart = _draft.hour != null
        ? ' · ${_hhmm(_draft.hour!, _draft.minute ?? 0)}'
        : '';
    _say('${_pick([
          'Şöyle olsun mu?',
          'Bunu mu ekleyeyim?',
          'Şu haliyle uyar mı?'
        ])}'
        '\n\n'
        '${_dayLabel(day)}$timePart${_recLabel(_draft.recurrence)}\n'
        '${_composeTitle()} · ${_fmtMinutes(minutes)}\n\n'
        'Uygunsa "ekle" yaz, değilse neyi değiştireceğini söyle.');
  }

  void _proposeDay() {
    final subjects = ref.read(subjectProvider);
    final allTasks = ref.read(taskProvider);
    final examDate = ref.read(statsProvider).examDate;
    final examDays = examDate == null ? null : daysUntilExam(examDate);

    // Konu Takip verisi: kapsama oranları + ders başına boş konular.
    final coverage = ref.read(coverageBySubjectProvider);
    final coveragePercent = <String, double>{
      for (final e in coverage.entries)
        if (e.value.hasTopics) e.key: e.value.ratio,
    };
    final uncovered = <String, List<UncoveredTopic>>{};
    for (final t in ref.read(topicProvider)) {
      if (t.status != TopicStatus.reviewed && t.status != TopicStatus.studied) {
        uncovered
            .putIfAbsent(t.subjectId, () => [])
            .add((name: t.name, id: t.id));
      }
    }

    final advisorIds = StudyAdvisor.suggest(
      subjects: subjects,
      tasks: allTasks,
      examDate: examDate,
      limit: subjects.length,
      coveragePercent: coveragePercent,
      weakestDenemeSubjectId: ref.read(weakestDenemeSubjectIdProvider),
      focusMinutesBySubject: ref.read(focusMinutesBySubjectProvider),
    ).map((s) => s.subjectId).toList();

    final ordered = _rotated(<SubjectModel>[
      for (final id in advisorIds) subjects.firstWhere((s) => s.id == id),
      for (final s in subjects)
        if (!advisorIds.contains(s.id)) s,
    ]);

    final hours = (_draft.minutes! / 60).round().clamp(1, 12);
    final result = PlanBuilder.build(
      orderedSubjects: ordered,
      hoursAvailable: hours,
      energy: 'orta',
      examDays: examDays,
      uncoveredTopics: uncovered,
      fillToCapacity: uncovered.isNotEmpty,
    );

    if (result.isEmpty) {
      _say('Bu kadar vakitle bir blok bile çıkmadı. Biraz daha vakit yazar '
          'mısın?');
      _draft.minutes = null;
      return;
    }

    _pending = result.blocks;
    _pendingRecurrence = 'none';
    _pendingIsDay = true;

    final lines =
        result.blocks.map((b) => '•  ${b.title} · ${b.minutes} dk').join('\n');
    _say('${result.reason}\n\n$lines\n\n'
        'Toplam ${_fmtMinutes(result.plannedMinutes)} · '
        '${result.blocks.length} görev.\n\n'
        'Uygunsa "ekle" de, dokunmak istediğin bir şey varsa söyle.');
  }

  void _proposeWeek() {
    final subjects = ref.read(subjectProvider);
    final allTasks = ref.read(taskProvider);
    final examDate = ref.read(statsProvider).examDate;
    final examDays = examDate == null ? null : daysUntilExam(examDate);

    // Konu Takip: kapsama oranları + ders başına işaretlenmemiş konular.
    final coverage = ref.read(coverageBySubjectProvider);
    final coveragePercent = <String, double>{
      for (final e in coverage.entries)
        if (e.value.hasTopics) e.key: e.value.ratio,
    };
    final uncovered = <String, List<UncoveredTopic>>{};
    for (final t in ref.read(topicProvider)) {
      if (t.status != TopicStatus.reviewed && t.status != TopicStatus.studied) {
        uncovered
            .putIfAbsent(t.subjectId, () => [])
            .add((name: t.name, id: t.id));
      }
    }

    final advisorIds = StudyAdvisor.suggest(
      subjects: subjects,
      tasks: allTasks,
      examDate: examDate,
      limit: subjects.length,
      coveragePercent: coveragePercent,
      weakestDenemeSubjectId: ref.read(weakestDenemeSubjectIdProvider),
      focusMinutesBySubject: ref.read(focusMinutesBySubjectProvider),
    ).map((s) => s.subjectId).toList();

    final ordered = _rotated(<SubjectModel>[
      for (final id in advisorIds) subjects.firstWhere((s) => s.id == id),
      for (final s in subjects)
        if (!advisorIds.contains(s.id)) s,
    ]);

    final n0 = DateTime.now();
    final today = DateTime(n0.year, n0.month, n0.day);
    final hoursPerDay = (_draft.minutes! / 60).round().clamp(1, 8);

    final week = PlanBuilder.buildWeek(
      orderedSubjects: ordered,
      uncoveredTopics: uncovered,
      hoursPerDay: hoursPerDay,
      startDate: today,
      examDays: examDays,
    );

    if (week.isEmpty) {
      _say('Program çıkmadı — günde biraz daha vakit yazar mısın?');
      _draft.minutes = null;
      return;
    }

    _pendingWeek = week;
    _pending = week.allBlocks;
    _pendingIsDay = true;
    _pendingRecurrence = 'none';

    final buf = StringBuffer()
      ..writeln(week.reason)
      ..writeln();
    for (final d in week.days) {
      buf.writeln('${_weekdayLabel(d.date)} · '
          '${d.blocks.map((b) => b.title).join(', ')}');
    }
    buf
      ..writeln()
      ..write('Toplam ${week.totalBlocks} görev, ${week.days.length} güne '
          'yayılı.\n\nUygunsa "ekle" de, değiştirmek istediğin gün varsa söyle.');
    _say(buf.toString());
  }

  void _commit() {
    final isFirstTaskEver = !ref.read(statsProvider).hasAddedFirstTask;

    // Haftalık program: her bloğu kendi gününün dueDate'iyle yaz.
    final week = _pendingWeek;
    if (week != null) {
      final notifier = ref.read(taskProvider.notifier);
      var count = 0;
      for (final day in week.days) {
        for (final b in day.blocks) {
          notifier.addTask(
            title: b.title,
            subjectId: b.subjectId.isEmpty ? null : b.subjectId,
            dueDate: day.date,
            priority: b.priority,
            estimatedMinutes: b.minutes,
            difficulty: TopicDifficulty.medium,
            topicId: b.topicId,
          );
          count++;
        }
      }
      _pendingWeek = null;
      _pending = null;
      _draft.reset();
      _delegate = false;
      _wantsWeek = null;
      _askedRecurrence = false;
      _regenerateOffset = 0;
      if (isFirstTaskEver) {
        ref.read(statsProvider.notifier).markFirstTaskAdded();
        _say('İlk görevlerini ekledin. $count görev ${week.days.length} '
            'güne yayıldı. Başka bir şey var mı?');
      } else {
        _say(_pick([
          '$count görev ${week.days.length} güne yayıldı. Başka bir şey var mı?',
          'Hepsi eklendi — $count görev, ${week.days.length} gün. '
              'Devam edelim mi?',
        ]));
      }
      return;
    }

    final blocks = _pending;
    if (blocks == null) return;
    final notifier = ref.read(taskProvider.notifier);
    final n0 = DateTime.now();
    final today = DateTime(n0.year, n0.month, n0.day);

    // Saat YALNIZCA kullanıcı açıkça söylediyse ("saat 3", "akşam 8").
    final timeOfDay = _draft.hour != null
        ? TimeOfDay(hour: _draft.hour!, minute: _draft.minute ?? 0)
        : null;

    if (!_pendingIsDay && _pendingRecurrence != 'none') {
      final b = blocks.first;
      notifier.addRecurringTask(
        title: b.title,
        subjectId: b.subjectId.isEmpty ? null : b.subjectId,
        startDate: _draft.day ?? today,
        recurrenceRule: _pendingRecurrence,
        estimatedMinutes: b.minutes,
        scheduledTimeOfDay: timeOfDay,
        topicId: b.topicId,
      );
    } else {
      for (final b in blocks) {
        final due = _pendingIsDay ? today : (_draft.day ?? today);
        // Gün planı: saatsiz gün-kapsamlı görevler. Tek görev: yalnız
        // kullanıcı saat verdiyse zamanlı.
        final scheduled = (!_pendingIsDay && timeOfDay != null)
            ? DateTime(
                due.year, due.month, due.day, timeOfDay.hour, timeOfDay.minute)
            : null;
        notifier.addTask(
          title: b.title,
          subjectId: b.subjectId.isEmpty ? null : b.subjectId,
          dueDate: due,
          priority: b.priority,
          scheduledTime: scheduled,
          estimatedMinutes: b.minutes,
          difficulty: TopicDifficulty.medium,
          topicId: b.topicId,
        );
      }
    }

    final n = blocks.length;
    _pending = null;
    _draft.reset();
    _delegate = false;
    _wantsWeek = null;
    _askedRecurrence = false;
    _regenerateOffset = 0;
    if (isFirstTaskEver) {
      ref.read(statsProvider.notifier).markFirstTaskAdded();
      _say(n == 1
          ? 'İlk görevini ekledin. Başka bir şey planlayalım mı?'
          : 'İlk görevlerini ekledin. $n görev listene eklendi. '
              'Başka bir şey var mı?');
    } else {
      _say(n == 1
          ? _pick([
              'Eklendi. Başka bir şey planlayalım mı?',
              'Tamamdır, listene ekledim. Devam edelim mi?',
            ])
          : _pick([
              '$n görev eklendi. Başka bir şey var mı?',
              '$n görevi listene koydum. Başka?',
            ]));
    }
  }

  // --- Hızlı aksiyonlar -----------------------------------------------
  // Sohbet daha başlamamışken (yalnız karşılama mesajı varken) ekranın
  // büyük kısmı boş kalıyordu — kullanıcı ne yazacağını bilemiyordu.
  // Bu pil satırı en sık istenen üç şeyi tek dokunuşa indiriyor; gerçek
  // bir sohbet başlayınca (ilk kullanıcı mesajından sonra) kaybolur.

  void _sendQuick(String text) {
    _input.text = text;
    _onSend();
  }

  @override
  Widget build(BuildContext context) {
    // Koç'un yazarken tarih/saat/süre/dersi canlı renklendirebilmesi için
    // güncel ders listesini denetleyiciye taşı (bkz. _HighlightingController).
    _input.subjects = ref.watch(subjectProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Çalışma Koçu', style: AppTextStyles.heading2),
      ),
      body: Column(
        children: [
          // Bug: _intro() her zaman TAM 2 mesaj gönderiyor (selam + yönlendirme),
          // <= 1 koşulu bu yüzden hiçbir zaman doğru olmuyor, pil satırı hiç
          // görünmüyordu. Doğru eşik 2 — sohbet gerçekten başlayınca (ilk
          // kullanıcı mesajıyla en az 3'e çıkınca) kaybolur.
          if (_turns.length <= 2)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _QuickActionPill(
                    icon: Icons.timer_outlined,
                    label: '25 dk Pomodoro Başlat',
                    tint: AppColors.vibrantViolet,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const FocusScreen(
                          initialTargetMin: 25,
                          initialPomodoro: true,
                        ),
                      ),
                    ),
                  ),
                  _QuickActionPill(
                    icon: Icons.auto_awesome_outlined,
                    label: 'Eksik konularımı sen planla',
                    tint: AppColors.vibrantViolet,
                    onTap: () => _sendQuick(
                        'sen ayarla, bugün için eksik konularımdan planla'),
                  ),
                  _QuickActionPill(
                    icon: Icons.add_task_outlined,
                    label: 'Hızlı görev ekle',
                    tint: AppColors.vibrantViolet,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AddTaskScreen()),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              itemCount: _turns.length,
              itemBuilder: (_, i) => _Bubble(turn: _turns[i]),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_pending != null) ...[
                    PrimaryButton(
                      label: 'Ekle',
                      icon: Icons.check,
                      onPressed: _commit,
                    ),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: AppColors.surfaceVariant, width: 1),
                          ),
                          child: TextField(
                            controller: _input,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _onSend(),
                            minLines: 1,
                            maxLines: 4,
                            style: AppTextStyles.body
                                .copyWith(color: AppColors.textPrimary),
                            decoration: const InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              hintText: 'Yaz…',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TapScale(
                        onTap: _hasInput ? _onSend : null,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 48,
                          height: 48,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient:
                                _hasInput ? AppColors.primaryGradient : null,
                            color: _hasInput ? null : AppColors.surfaceVariant,
                            shape: BoxShape.circle,
                            boxShadow: _hasInput
                                ? [AppColors.glow(AppColors.primary)]
                                : null,
                          ),
                          child: Icon(
                            Icons.arrow_upward_rounded,
                            size: 18,
                            color:
                                _hasInput ? AppColors.ink : AppColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Koç'un yazarken tanıdığı tarih/saat/süre/tekrar/ders ifadelerini metnin
/// içinde canlı renklendirir — Todoist'in "yarın 4pm" vurgusuyla aynı fikir
/// (docs/rakip_analizi_ve_yon_2026-09.md araştırması), kullanıcı yazdığının
/// gerçekten anlaşıldığını göndermeden önce görsün diye. Her tuş vuruşunda
/// [PlanParser.parse] zaten çağrılıyor olurdu (onSend'de de öyle) — kısa
/// cümle üzerinde regex taraması, ek maliyeti yok.
class _HighlightingController extends TextEditingController {
  List<SubjectModel> subjects = const [];

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final t = text;
    if (t.isEmpty) return TextSpan(style: style, text: t);

    final spans = PlanParser.parse(t, subjects: subjects).spans;
    if (spans.isEmpty) return TextSpan(style: style, text: t);

    // Tek renk (marka altını) — tarih/saat/süre/ders için ayrı renkler
    // denendi ("anlamsız/tutarsız" geri bildirimi) + arka plan dolgusu
    // ("çirkin/kaba" geri bildirimi, TextSpan.backgroundColor köşeli
    // dikdörtgen çiziyor, yuvarlatılamıyor). Artık tek soru: "anlaşıldı mı,
    // anlaşılmadı mı" — kalın + altın metin, kutu yok.
    final highlight = TextStyle(
      color: AppColors.primary,
      fontWeight: FontWeight.w700,
    );

    final children = <InlineSpan>[];
    var cursor = 0;
    for (final s in spans) {
      if (s.start > cursor) {
        children
            .add(TextSpan(text: t.substring(cursor, s.start), style: style));
      }
      children.add(TextSpan(
        text: t.substring(s.start, s.end),
        style: style?.merge(highlight) ?? highlight,
      ));
      cursor = s.end;
    }
    if (cursor < t.length) {
      children.add(TextSpan(text: t.substring(cursor), style: style));
    }
    return TextSpan(style: style, children: children);
  }
}

/// Değişebilir plan taslağı — sohbet ilerledikçe dolar.
class _Draft {
  DateTime? day;
  int? minutes;
  int? hour;
  int? minute;
  String recurrence = 'none';
  String? subjectId;
  String? subjectName;
  String? topic;

  bool get hasSubject =>
      subjectId != null ||
      (subjectName != null && subjectName!.isNotEmpty) ||
      (topic != null && topic!.isNotEmpty);

  bool get isEmpty =>
      day == null &&
      minutes == null &&
      hour == null &&
      recurrence == 'none' &&
      subjectId == null &&
      subjectName == null &&
      topic == null;

  void reset() {
    day = null;
    minutes = null;
    hour = null;
    minute = null;
    recurrence = 'none';
    subjectId = null;
    subjectName = null;
    topic = null;
  }
}

class _Turn {
  final bool coach;
  final String text;
  const _Turn({required this.coach, required this.text});
}

class _Bubble extends StatelessWidget {
  final _Turn turn;
  const _Bubble({required this.turn});

  @override
  Widget build(BuildContext context) {
    final coach = turn.coach;
    return Align(
      alignment: coach ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        decoration: BoxDecoration(
          color: coach ? AppColors.surface : AppColors.tonal(AppColors.primary),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(coach ? 4 : 18),
            bottomRight: Radius.circular(coach ? 18 : 4),
          ),
          boxShadow: coach ? AppColors.softShadow : null,
        ),
        child: Text(
          turn.text,
          style: AppTextStyles.body
              .copyWith(color: AppColors.textPrimary, height: 1.35),
        ),
      ),
    );
  }
}

/// Koç sohbetinin hâlâ boş olduğu anda gösterilen hızlı aksiyon pili.
class _QuickActionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color tint;
  final VoidCallback onTap;

  const _QuickActionPill({
    required this.icon,
    required this.label,
    required this.tint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: tint.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: tint.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: tint),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: tint,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
