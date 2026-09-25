import 'nlu_models.dart';
import 'nlu_phrase_matcher.dart';
import 'nlu_slots.dart';

/// Kural katmanı: kalıp sözlüğünün yakalayamadığı KISA/eksiltili cümleler
/// ("yorgunum", "zorlanıyorum", "yetişmiyor") ve çekim/olumsuzluk ayrımları
/// ("çalışıyorum" ≠ "çalışamadım") için sinyal grupları. Her kural bir niyet
/// için 0..1 ağırlık verir; ders/konu/süre slot'larıyla birlikte de çalışabilir.
class NluRuleContext {
  final NluPrepared p;
  final NluSlots slots;
  final int? timeMinutes;
  const NluRuleContext(this.p, this.slots, this.timeMinutes);

  String get f => p.folded;
  bool get hasSubject => slots.subject != null || slots.topic != null;
  bool get hasTopic => slots.topic != null;
  bool has(RegExp re) => re.hasMatch(f);
}

class NluRule {
  final String name;
  final CoachIntent intent;
  final double weight;
  final bool Function(NluRuleContext c) test;
  const NluRule(this.name, this.intent, this.weight, this.test);
}

RegExp _r(String pattern) => RegExp(pattern);

// --- Yeniden kullanılan kalıplar ------------------------------------------
final _negPlanVerb = _r(
    r'yapamad|yapamiy|yapmad|yapmiy|yapamam|aksad|aksiy|bozul|cokt|sapt|uygulayam|yetistirem');
final _planNoun = _r(r'\b(plan|program|takvim)\w*');
final _planVerb = _r(
    r'\b(yap|yapar|yapsana|yapabilir|kur|kurar|olustur|hazirla|hazirlar|cikar|cikarir|ayarla|planla|ver|lazim|istiyorum|istiyom)\w*');
final _pastWork = _r(r'\bcali(stim|stik|sti)\b');
final _struggle = _r(r'\bzorlan(?!m)\w*');
final _notUnderstand =
    _r(r'\banla(?:m(?:iyor|adi|ayacak)|yam)\w*|\bkavray?am\w*|\bogrenem\w*');
final _whatAsk = _r(
    r'\b(ne|neyi|neye|neyle|hangi\w*)\s+(?:\w+\s+){0,2}(calis|yap|bak|ogren|tekrar|oku|coz)\w*');

final List<NluRule> nluRules = [
  // --- Plan --------------------------------------------------------------
  NluRule('plan+fiil', CoachIntent.needPlan, 0.88,
      (c) => c.has(_planNoun) && c.has(_planVerb) && !c.has(_negPlanVerb)),
  NluRule('sen ayarla', CoachIntent.needPlan, 0.88,
      (c) => c.has(_r(r'\bsen (ayarla|yap|kur|planla|hallet)\w*'))),
  NluRule(
      'planla',
      CoachIntent.needPlan,
      0.8,
      (c) =>
          c.has(_r(r'\bplanla(?:r misin|beni|bugunu|yin|mami)?\b')) &&
          !c.has(_negPlanVerb)),
  NluRule(
      'program/plan tipi',
      CoachIntent.needPlan,
      0.75,
      (c) =>
          c.has(_r(r'\b(haftalik|gunluk|calisma|ders) (plan|program)\w*')) &&
          !c.has(_negPlanVerb) &&
          !c.has(_r(r'\bnerede\b|\bgoster\w*'))),

  // --- Öneri / ne çalışayım ------------------------------------------------
  NluRule('öner/tavsiye', CoachIntent.needRecommendation, 0.8,
      (c) => c.has(_r(r'\b(oner\w*|tavsiye\w*)\b'))),
  NluRule('ne çalışayım', CoachIntent.needRecommendation, 0.78,
      (c) => c.has(_whatAsk) && !c.has(_r(r'\bnasil\b'))),
  NluRule('çalışacak konu', CoachIntent.needRecommendation, 0.7,
      (c) => c.has(_r(r'\bcalisilacak|\bcalisacak (bir )?(sey|konu|ders)'))),

  // --- Şimdi ne yapayım ----------------------------------------------------
  NluRule(
      'şimdi + ne',
      CoachIntent.whatToDoNow,
      0.86,
      (c) =>
          c.has(_r(
              r'\b(simdi|su an\w*|suan|hemen)\b.*\bne\w*\b.*\b(yap|calis|bak)\w*')) ||
          c.has(_r(
              r'\bne\w*\b.*\b(yap|calis|bak)\w*.*\b(simdi|su an\w*|suan)\b'))),
  NluRule(
      'ne yapacağım',
      CoachIntent.whatToDoNow,
      0.72,
      (c) =>
          c.has(_r(
              r'\bne (yap(?:ayim|malayim|sam|acagim|acagimi|mam lazim|iyim|iyorum|ayim)|napayim|yapim)\b')) ||
          c.has(_r(r'\bna+p(?:ayim|iyim|cam)\b'))),
  NluRule('sıradaki', CoachIntent.whatToDoNow, 0.72,
      (c) => c.has(_r(r'\bsirada\w*|\bsonraki adim|\bbir sonraki'))),

  // --- Nereden başlayayım --------------------------------------------------
  NluRule(
      'nereden başla',
      CoachIntent.needStartPoint,
      0.95,
      (c) =>
          c.has(_r(r'\b(nereden|nerden|neresinden|nereye)\b.*\bbasl\w*')) ||
          c.has(_r(r'\bbasl\w*.*\b(nereden|nerden)\b')) ||
          c.has(_r(r'\bnere(den|sinden) (girsem|tutsam|baslasam)'))),
  NluRule('nasıl başla', CoachIntent.needStartPoint, 0.9,
      (c) => c.has(_r(r'\bnasil basl\w*'))),
  NluRule('neyle başla', CoachIntent.needStartPoint, 0.88,
      (c) => c.has(_r(r'\b(neyle|ne ile|hangi\w* (konu|ders)\w*) basl\w*'))),
  NluRule('ilk adım', CoachIntent.needStartPoint, 0.72,
      (c) => c.has(_r(r'\bilk (adim|once)\w*|\bbaslangic\w*'))),

  // --- Çalışma seansı ------------------------------------------------------
  NluRule(
      'seans+başlat',
      CoachIntent.studySessionRequest,
      0.88,
      (c) =>
          c.has(_r(
              r'\b(oturum|seans\w*|pomodoro|kronometre|sayac|zamanlayici|odak modu|blok\w*)\b')) &&
          c.has(_r(r'\b(baslat\w*|ac|kur|yap|baslayalim|baslasin)\b'))),
  NluRule(
      'çalışmaya başlayalım',
      CoachIntent.studySessionRequest,
      0.82,
      (c) =>
          c.has(_r(r'\b(calisma\w*|hadi|hemen)\b.*\bbaslayalim\b')) ||
          c.has(_r(r'\bhadi calisalim\b')) ||
          c.has(_r(r'^baslat\b|\bbaslat$'))),

  // --- Ders / konu rehberliği ------------------------------------------------
  NluRule(
      'ders + nasıl/ne',
      CoachIntent.subjectGuidance,
      0.78,
      (c) =>
          c.slots.subject != null &&
          c.slots.topic == null &&
          c.has(_r(
              r'\b(nasil|ne yap|ne calis|nereden|oner|strateji|tavsiye|yol|calissam|calisayim)\w*')) &&
          !c.has(_struggle) &&
          !c.has(_notUnderstand)),
  NluRule(
      'konu + nasıl/ne',
      CoachIntent.topicGuidance,
      0.82,
      (c) =>
          c.slots.topic != null &&
          c.has(_r(
              r'\b(nasil|ne yap|ne calis|nereden|oner|strateji|tavsiye|yol|calissam|calisayim|ne kadar)\w*')) &&
          !c.has(_struggle) &&
          !c.has(_notUnderstand)),
  NluRule(
      'bu konu nasıl',
      CoachIntent.topicGuidance,
      0.75,
      (c) =>
          c.has(
              _r(r'\b(bu|su) konu\w*.*\b(nasil|ne yap|nereden|calis\w*)\b')) &&
          !c.has(_struggle) &&
          !c.has(_notUnderstand)),

  // --- Süre kısıtı -----------------------------------------------------------
  NluRule(
      'süre + var/sadece',
      CoachIntent.timeConstraint,
      0.82,
      (c) =>
          c.timeMinutes != null &&
          !c.has(_pastWork) &&
          c.has(_r(
              r'\b(vaktim\w*|zamanim\w*|var|sadece|ancak|en fazla|elimde|ayirabilir\w*|calisabilir\w*|kadar|yok|az)\b'))),
  NluRule(
      'süre yalın',
      CoachIntent.timeConstraint,
      0.62,
      (c) =>
          c.timeMinutes != null &&
          !c.has(_pastWork) &&
          c.has(_r(r'\bcalisabil\w*|\bne\b'))),
  NluRule(
      'vakit az',
      CoachIntent.timeConstraint,
      0.82,
      (c) =>
          c.has(_r(
              r'\b(vaktim|zamanim|vakit|zaman)\w*\s+(cok\s+)?(az|yok|kisitli|daral\w*|kalmadi|kaldi)\b')) &&
          !c.has(_r(r'\bsinav\w*|\bdeneme\w*'))),
  NluRule(
      'az vakit',
      CoachIntent.timeConstraint,
      0.78,
      (c) =>
          c.has(_r(r'\b(az|kisa) (vakit|zaman|sure)\w*|\bcok vaktim yok\b'))),

  // --- Zorlanma ---------------------------------------------------------------
  NluRule('zorlanıyorum', CoachIntent.strugglingSubject, 0.86,
      (c) => c.has(_struggle)),
  NluRule('anlamıyorum', CoachIntent.strugglingSubject, 0.82,
      (c) => c.has(_notUnderstand)),
  NluRule(
      'zayıfım/eksiğim',
      CoachIntent.strugglingSubject,
      0.78,
      (c) =>
          c.hasSubject &&
          c.has(_r(r'\bzayif\w*|\beksik\w*|\bkotu\b|\bkotuyum'))),
  NluRule(
      'hiç bilmiyorum',
      CoachIntent.strugglingSubject,
      0.8,
      (c) =>
          c.has(_r(
              r'\bhic ?bir (sey|konu)\w* (bil|anla)\w*|\bhic bil\w*|\bhicbir sey bilmiyor\w*')) ||
          (c.hasSubject && c.has(_r(r'\bbilmiyor\w*')))),
  NluRule(
      'ağır/zor geliyor',
      CoachIntent.strugglingSubject,
      0.84,
      (c) =>
          c.hasSubject &&
          c.has(_r(r'\b(agir|zor|yorucu|bunaltici)\b')) &&
          c.has(_r(r'\bgel(iyor|iyo|ir|di|mis)\b'))),
  NluRule(
      'yapamıyorum+ders',
      CoachIntent.strugglingSubject,
      0.74,
      (c) =>
          c.hasSubject &&
          c.has(_r(
              r'\byapam(?:iyor|adim)\w*|\bcozem(?:iyor|edim)\w*|\btikan\w*|\bezberleyem\w*|\bgelmiy\w*|\boturmu\w*|\bcok zor\b')) &&
          !c.has(_r(r'\bsoru\w*|\btest\w*'))),

  // --- Soru performansı --------------------------------------------------------
  NluRule(
      'soru+yanlış',
      CoachIntent.questionPerformanceProblem,
      0.86,
      (c) =>
          c.has(_r(r'\b(soru\w*|test\w*|paragraf\w*|problem\w*|sorular)\b')) &&
          c.has(_r(
              r'\byanlis\w*|\byapamiy\w*|\bcozemiy\w*|\btakil\w*|\bhata\w*|\bbitirem\w*|\byetmiy\w*|\byetistirem\w*|\byavas\w*|\bdikkatsiz\w*|\bcozemedim\w*'))),
  NluRule(
      'sürekli yanlış',
      CoachIntent.questionPerformanceProblem,
      0.84,
      (c) => c.has(_r(
          r'\b(surekli|hep|hala|yine|hic) yanlis\b|\byanlis yap\w*|\bdikkatsizlik\w*|\bislem hata\w*'))),

  // --- Deneme --------------------------------------------------------------------
  NluRule(
      'deneme+net/kötü',
      CoachIntent.mockExamProblem,
      0.86,
      (c) =>
          c.slots.exam == NluExamKind.mockExam &&
          c.has(_r(
              r'\bnet\w*|\bpuan\w*|\bkotu\w*|\bdusuk\w*|\bdustu\w*|\bartmiy\w*|\byetmiy\w*|\byapamad\w*|\byapamiy\w*|\bbitirem\w*|\bberbat\w*|\brezil\w*|\byanlis\w*|\bsonuc\w*|\banaliz\w*|\bstres\w*|\bdonup\w*|\bheyecan\w*|\bbos birak\w*|\bmoral\w*'))),
  NluRule(
      'net artmıyor',
      CoachIntent.mockExamProblem,
      0.76,
      (c) => c.has(_r(
          r'\bnet\w*\s+(artmiy|dusuk|dustu|yukselmiy|yerinde say|yok)\w*|\bnet yapam\w*'))),

  // --- Sınav aciliyeti -------------------------------------------------------------
  NluRule(
      'sınav+yakın+var',
      CoachIntent.examUrgency,
      0.92,
      (c) =>
          c.slots.exam != NluExamKind.none &&
          c.slots.urgency != NluUrgency.none &&
          c.has(_r(
              r'\bvar\b|\bkaldi\b|\byaklas\w*|\bhazirlan\w*|\byetis\w*|\byakin\b|\bhazir degil\w*'))),
  NluRule(
      'sınava az kaldı',
      CoachIntent.examUrgency,
      0.88,
      (c) =>
          c.slots.exam != NluExamKind.none &&
          c.has(_r(
              r'\b(cok )?az kaldi\b|\bkac gun\b|\byaklas\w*|\bcok yakin\b|\bgun kaldi\b'))),
  NluRule(
      'sınav + yetişemem',
      CoachIntent.examUrgency,
      0.82,
      (c) =>
          c.slots.exam != NluExamKind.none &&
          c.has(_r(
              r'\b(vakit|zaman) yok\b|\byetisem\w*|\byetismez\w*|\bhazir degil\w*'))),
  NluRule('acil sınav', CoachIntent.examUrgency, 0.82,
      (c) => c.has(_r(r'\bacil\b')) && c.slots.exam != NluExamKind.none),

  // --- Geride kalma ----------------------------------------------------------------
  NluRule(
      'geride',
      CoachIntent.behindSchedule,
      0.9,
      (c) => c.has(_r(
          r'\bgeri(?:de|lerde|yim|dey\w*|sin\w*|mde|ye dus\w*)|\bgeri ?(?:kal|dus)\w*'))),
  NluRule(
      'yetişemiyorum',
      CoachIntent.behindSchedule,
      0.86,
      (c) =>
          c.has(_r(
              r'\byetis(?:em|mi|tirem|ecek mi|meyecek)\w*|\byetiste?m\w*')) &&
          !c.has(_r(r'\bsinav\w*|\bdeneme\w*|\bsoru\w*|\btest\w*'))),
  NluRule('birikti', CoachIntent.behindSchedule, 0.82,
      (c) => c.has(_r(r'\bbirik(?:ti|ik|mis|en)\w*'))),
  NluRule('aksadı', CoachIntent.behindSchedule, 0.82,
      (c) => c.has(_r(r'\baksa(?:di|dim|yor|ma)\w*'))),
  NluRule('geç kaldım', CoachIntent.behindSchedule, 0.78,
      (c) => c.has(_r(r'\bgec kal\w*|\bgecik\w*|\bgeç kal\w*'))),
  NluRule(
      'plan bozuldu',
      CoachIntent.behindSchedule,
      0.86,
      (c) => c.has(_r(
          r'\b(plan|program)\w* (bozul|cokt|sap|aksa|uygulayam|yapamad)\w*'))),
  NluRule(
      'yarım kaldı',
      CoachIntent.behindSchedule,
      0.7,
      (c) => c.has(_r(
          r'\byarim (kal|birak)\w*|\bertelen\w* (cok|hep)\b|\b(cok|hep) ertele\w*'))),

  // --- Çok iş ---------------------------------------------------------------------
  NluRule(
      'çok iş/görev',
      CoachIntent.tooMuchWork,
      0.82,
      (c) =>
          c.has(_r(r'\bcok (fazla )?(is|gorev|konu|ders|yuk|odev|yogun)\w*')) ||
          c.has(
              _r(r'\byapacak cok|\byapilacak\w* cok|\bliste\w* (cok )?uzun'))),
  NluRule(
      'hepsini yapamam',
      CoachIntent.tooMuchWork,
      0.82,
      (c) => c.has(_r(
          r'\b(hepsini|bunca|bu kadar)\b.*\b(yetistirem|bitirem|yapam|nasil)\w*'))),
  NluRule(
      'boğuldum',
      CoachIntent.tooMuchWork,
      0.8,
      (c) => c.has(_r(
          r'\bbogul\w*|\bbunal\w*|\byigil\w*|\bust uste gel\w*|\bagir yuk\b|\byuk\w* (cok |agir |fazla )'))),
  NluRule(
      'azalt',
      CoachIntent.tooMuchWork,
      0.76,
      (c) =>
          c.has(_r(r'\b(azalt|hafiflet|kisalt)\w*')) &&
          c.has(_r(r'\bplan\w*|\bgorev\w*|\bprogram\w*|\byuk\w*'))),

  // --- Bugün çalışamadım -------------------------------------------------------------
  NluRule(
      'bugün çalışamadım',
      CoachIntent.lowProgress,
      0.9,
      (c) =>
          c.has(_r(
              r'\b(bugun|dun|gundur|haftadir|bu hafta|hic)\b.*\b(calisamad|calismad|calisamiy|calismiy|yapamad|yapmad|verimsiz|bosa|ilerleyemed)\w*')) ||
          c.has(_r(r'\bhic (calis(?!mak)|bir sey yap)\w*'))),
  NluRule('çalışamadım', CoachIntent.lowProgress, 0.84,
      (c) => c.has(_r(r'\bcalis(?:amad|amiy|amam|mad|miyor)\w*'))),
  NluRule(
      'verimsiz',
      CoachIntent.lowProgress,
      0.8,
      (c) => c.has(_r(
          r'\bverimsiz\w*|\bverim (alam|yok)\w*|\bbosa (gecti|harca)\w*|\bbos dur\w*|\btembel\w*'))),
  NluRule(
      'odaklanamıyorum',
      CoachIntent.lowProgress,
      0.8,
      (c) =>
          c.has(_r(r'\bodaklanam\w*|\bkonsantre olam\w*|\bdikkatim dagil\w*'))),

  NluRule(
      'kafam almıyor',
      CoachIntent.lowProgress,
      0.82,
      (c) => c.has(_r(
          r'\bkafa(m)? almiyor|\bkafam yerinde degil|\bkafam basimda degil|\baklim (yok|baska yerde)|\bdaginik\w*'))),
  NluRule(
      'bitmiyor',
      CoachIntent.behindSchedule,
      0.78,
      (c) =>
          c.has(_r(r'\bbitmiyo(r)?\b|\bbitmedi\b|\bbitmeyecek\b')) &&
          (c.hasSubject || c.has(_r(r'\b(konu|is|ders|gorev|plan)\w*')))),

  // --- Motivasyon ---------------------------------------------------------------------
  NluRule('motivasyon', CoachIntent.lowMotivation, 0.86,
      (c) => c.has(_r(r'\bmotivasyon\w*|\bmotive (ol|et|ed)\w*'))),
  NluRule(
      'isteksiz',
      CoachIntent.lowMotivation,
      0.86,
      (c) => c.has(_r(
          r'\bisteksiz\w*|\bcalisasim\b|\bcalismak istemiyor\w*|\bicim (gelmiy|cekmiy)\w*|\bcanim (hic )?(istemiyor|cekmiyor)|\bhevesim\b|\bbikti\w*|\busan\w*|\bsikil(?!m)\w*|\bsikici\b'))),
  NluRule(
      'yorgun/tükenmiş',
      CoachIntent.lowMotivation,
      0.8,
      (c) =>
          c.has(_r(
              r'\byorgun\w*|\byorul(?!ma)\w*|\bbitkin\w*|\btukend\w*|\btukenm\w*|\benerjim yok|\bgucum kalmadi')) &&
          !c.has(_r(r'\b(yorgun|bitkin)\w* degil'))),
  NluRule(
      'pes/bırak',
      CoachIntent.lowMotivation,
      0.86,
      (c) => c.has(_r(
          r'\bpes (et|ed)\w*|\bbirakas\w*|\bbirakmak istiyor\w*|\bhicbir sey yapasim yok'))),
  NluRule('moral', CoachIntent.lowMotivation, 0.8,
      (c) => c.has(_r(r'\bmoral\w* (bozuk|kotu|sifir)|\bmoral bozuk\w*'))),
  NluRule(
      'erteliyorum',
      CoachIntent.lowMotivation,
      0.7,
      (c) =>
          c.has(_r(r'\bertele\w*')) &&
          !c.has(_r(r'\bcok ertelemis|\bhep ertele'))),

  // --- İlerleme kaygısı -----------------------------------------------------------------
  NluRule(
      'ilerleyemiyorum',
      CoachIntent.progressConcern,
      0.84,
      (c) =>
          c.has(_r(
              r'\bilerle(?:yem|miyor|me yok|me kaydedem)\w*|\bilerleme kaydedem\w*')) &&
          !c.has(_r(r'\bbugun\b'))),
  NluRule(
      'yerinde sayıyorum',
      CoachIntent.progressConcern,
      0.86,
      (c) => c.has(_r(
          r'\byerimde say\w*|\bayni yerde\w*|\bayni seviye\w*|\bgelisem\w*|\bgelisme (yok|goremiy)\w*|\bgelisiyor muyum'))),
  NluRule(
      'emek karşılık',
      CoachIntent.progressConcern,
      0.84,
      (c) => c.has(_r(
          r'\bemeg\w*|\bkarsilik\w*|\b(cok|ne kadar) calis\w*.*\b(sonuc yok|olmuyor|artmiy\w*|fayda)'))),
  NluRule(
      'nasıl gidiyorum',
      CoachIntent.progressConcern,
      0.88,
      (c) => c.has(_r(
          r'\bnasil (gidiyorum|ilerliyorum)\b|\bne durumdayim\b|\bdurumum (ne|nasil)\b|\biyi gidiyor muyum\b|\byeterli mi\b|\byeterince calis\w*|\bilerlemem nasil\b|\bperformansim nasil\b'))),
  NluRule('hedefe ulaşır mıyım', CoachIntent.progressConcern, 0.76,
      (c) => c.has(_r(r'\bhedef\w*\s+(ulas|yetis|yaklas)\w*'))),

  // --- Genel sorun (bilerek düşük ağırlık) ------------------------------------------------
  NluRule(
      'genel sorun',
      CoachIntent.generalProblem,
      0.6,
      (c) =>
          c.has(_r(
              r'\b(sorun|problem|sikinti|dert)\w*\s+(var|oldu)\b|\bsorun\w*\b|\bsikinti\w*|\bdertli\w*|\bberbat\b|\brezalet\b|\brezil\b|\bcok kotu\b|\bkotu gidiyor\b|\bolmuyor\b|\bcaresiz\w*|\bcikmaz\w*|\bkafam (cok )?karisik\b|\bters gidiyor\b|\byolunda (degil|gitmiyor)\b|\biyi degilim\b|\byardim\b')) &&
          !c.has(_r(r'\b(sorun|problem|sikinti)\w*\s+(yok|degil)\b'))),

  // --- Olumlu ---------------------------------------------------------------------------------
  NluRule(
      'olumlu',
      CoachIntent.positiveProgress,
      0.82,
      (c) =>
          c.has(_r(
              r'\biyi (gidiyor|calistim|gecti|gidiyorum)\b|\bverimliydi\b|\bcok verimli (gecti|calistim)\b|\bbasardim\b|\bbitirdim\b|\btamamladim\b|\bharika\b|\bsuper\b|\bmemnun\w*|\bmutluyum\b|\bnet\w* (artti|yukseldi|iyi)\b|\bhedefimi (tamamladim|astim)\b|\byukseldi\b')) &&
          !c.has(_r(
              r'\b(iyi|verimli) (gitmiyor|degil)\w*|\bverimli (calisam|degil)\w*|\bnasil\b|\bmi\b|\bmu\b'))),
  NluRule(
      'anladım/öğrendim',
      CoachIntent.positiveProgress,
      0.76,
      (c) =>
          c.has(_r(r'\b(anladim|ogrendim|cozdum|kavradim)\b')) &&
          c.f.split(' ').length >= 3),
  NluRule(
      'zorlanmıyorum',
      CoachIntent.positiveProgress,
      0.7,
      (c) =>
          c.has(_r(r'\bzorlanm(?:iyor|adim|am)\w*|\b(sorun|problem) yok\b'))),

  NluRule(
      'çalıştım',
      CoachIntent.positiveProgress,
      0.66,
      (c) =>
          c.has(_r(r'\bcalistim\b')) &&
          !c.has(_r(r'\bverimsiz|\bama\b|\bhic'))),

  // --- Teşekkür / onay -----------------------------------------------------------------------
  NluRule(
      'teşekkür',
      CoachIntent.thanks,
      0.96,
      (c) => c.has(_r(
          r'\btesekkur\w*|\bsag ?ol\w*|\beyvallah\b|\bmersi\b|\btsk\w*|\bsaol\b|\bthanks\b|\belinize saglik'))),
  NluRule(
      'onay',
      CoachIntent.confirmation,
      0.95,
      (c) => c.has(_r(
          r'^(evet|tamam|olur|tmm|tabii|tabi|aynen|ok|peki|kabul|olsun|tamamdir|anladim)( \w+)?$'))),
];

/// Kural puanı: en güçlü kural + her ek kural için +0.04 (en çok +0.08).
({double score, List<String> signals}) evaluateRules(
    CoachIntent intent, NluRuleContext c) {
  final hits = <NluRule>[];
  for (final r in nluRules) {
    if (r.intent != intent) continue;
    if (r.test(c)) hits.add(r);
  }
  if (hits.isEmpty) return (score: 0.0, signals: const []);
  hits.sort((a, b) => b.weight.compareTo(a.weight));
  final bonus = (hits.length - 1) * 0.04;
  return (
    score: (hits.first.weight + (bonus > 0.08 ? 0.08 : bonus)).clamp(0.0, 1.0),
    signals: [for (final h in hits) h.name],
  );
}

/// Ek olarak dışarıya açık: süre slot'unu kurallara taşımak için.
int? extractTime(String raw) => NluSlotExtractor.minutes(raw);
