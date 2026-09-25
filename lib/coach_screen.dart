import 'study_recommendation.dart';
import 'study_intent.dart';
import 'topic_evidence.dart';
import 'topic_evidence_provider.dart';
import 'package:collection/collection.dart';
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
import 'stats_insight_engine.dart';
import 'deneme_provider.dart';
import 'goal_gap_provider.dart';
import 'focus_session_provider.dart';
import 'subject_ai.dart';
import 'subject_topics_screen.dart';
import 'nlu/nlu_context.dart';
import 'nlu/nlu_engine.dart';
import 'nlu/nlu_entities.dart';
import 'nlu/nlu_models.dart';
import 'nlu/nlu_modifier.dart';
import 'nlu/tr_text.dart';
import 'nlu/nlu_responder.dart';
import 'rank_provider.dart';
import 'profile_screen.dart';
import 'rank_ladder_screen.dart';
import 'tap_scale.dart';
import 'widgets/app_buttons.dart';
import 'widgets/app_header.dart';
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

  // Offline NLU: son cümlede geçen ders/konu — "bu konu" gibi işaretlere bağlam.
  NluSlots? _lastNluSlots;
  NluEntityIndex? _nluIndex;

  // Düzeltme ("biraz ağır yap", "artır", "1 saat daha ekle") için OTURUM İÇİ
  // bağlam: son anlamlı Coach sonucu neydi? Kalıcı değil, yalnız bu ekran açıkken.
  _CoachRef _ref = _CoachRef.none;
  // Bağlam TAZELİĞİ: [_ref] verisi durur ama yalnız [_refActive] iken kısa
  // düzeltmeler ("artır") ona bağlanır. Yeni bir ana konuya geçilince pasifleşir;
  // açık referans ("az önceki planı artır") yeniden kullanabilir.
  bool _refActive = false;
  int _turn = 0; // kullanıcı mesajı sayacı
  int _refTurn = 0; // bağlamın son tazelendiği mesaj
  String _committedEnergy = 'orta';
  bool _committedWeek = false;
  bool _committedDay = false;
  NluResult? _lastNlu;
  int? _lastNluMinutes;
  int? _committedMinutes;

  // Plan yoğunluğu = PlanBuilder'ın mevcut "energy" ayarı (düşük/orta/yüksek).
  String _energy = 'orta';

  @override
  void initState() {
    super.initState();
    _input.addListener(() {
      final has = _input.text.trim().isNotEmpty;
      if (has != _hasInput) setState(() => _hasInput = has);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _intro());
    // Offline NLU sözlüğünü ilk mesajdan ÖNCE hazırla (ilk cümlede takılma yok).
    Future<void>.delayed(const Duration(milliseconds: 400), CoachNlu.warmUp);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _input.dispose();
    super.dispose();
  }

  // --- Konuşma ------------------------------------------------------

  void _say(
    String text, {
    bool coach = true,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    setState(() => _turns.add(_Turn(
          coach: coach,
          text: text,
          actionLabel: actionLabel,
          onAction: onAction,
        )));
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

    // Şablonlu "ne çalışmak istiyorsun" sorusu yerine, varsa GERÇEK bir
    // gözlemle aç (OBSERVATION → REASON → RECOMMENDATION) — koçun her
    // oturumda görülen İLK gerçek sorusu artık genel değil, dünkü/bugünkü
    // davranışa bakıyor. StudyAdvisor'ın Home'da zaten kullandığı aynı
    // motor. Önceden yalnız "ertelendi" (kaçınma) sinyali açılışı ele
    // geçiriyordu — diğer somut sinyaller (gerileme, tekrar zamanı, konu
    // boşluğu, zor konu, kendi-bildirim) sessizce yok sayılıp jenerik
    // soruya düşülüyordu. Artık StudyAdvisor'ın ürettiği HERHANGİ bir somut
    // (jenerik olmayan) gözlem açılışı belirliyor.
    final top = _topSuggestion();
    if (top != null && top.reason != StudyAdvisor.genericReason) {
      _say('${top.subjectName}: ${top.reason}$examLine '
          'İstersen başka bir şey de söyleyebilirsin.');
      return;
    }

    _say('Ne çalışmak istediğini ve ne kadar vaktin olduğunu tek cümleyle '
        'yaz.$examLine İstemiyorsan "sen ayarla" de, ben kurayım.');

    // _say() her mesajda otomatik en alta kaydırıyor (normal sohbet akışı
    // için doğru davranış) — ama İLK açılışta bu, Figma'nın "Birlikte
    // çözelim" karşılama bloğunu (başlık + hızlı aksiyonlar + Konu seç +
    // Sık sorulanlar) ekran açılır açılmaz görünmez kılıyordu. Yalnız bu
    // ilk yükleme anında, iki karşılama mesajı gönderildikten SONRA en üste
    // geri sarılıyor — sonraki gerçek mesajlarda _say()'in en-alta-kaydırma
    // davranışı hiç değişmiyor.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(0);
    });
  }

  /// StudyAdvisor'ın tüm sinyallerle (kapsama, deneme neti/trendi, odak,
  /// tekrar zamanı, zor konu, kendi-bildirim) beslenen tek çağrısı — açılış
  /// gözlemi (_intro) ve "nasıl gidiyorum" sorusu (_progressSummary) AYNI
  /// motoru kullanır, ikinci bir "akıllılık" icat edilmez.
  StudySuggestion? _topSuggestion() {
    return runStudyAdvisor(ref.read, limit: 1).firstOrNull;
  }

  /// "Nasıl gidiyorum" tarzı sorulara GERÇEK veriyle cevap — istatistik
  /// ekranındaki aynı iki motoru (StatsInsightEngine + StudyAdvisor) sohbete
  /// taşır. Önceden bu tür sorular yanlışlıkla `_wellbeingCheckPhrases`e
  /// düşüp ("nasıl gidiyorum" ⊃ "nasıl gidiyor" alt dizesi) koçun KENDİ
  /// haline dair jenerik bir cevap veriyordu — kullanıcının asıl sorduğu
  /// (kendi ilerlemesi) hiç yanıtlanmıyordu.
  String _progressSummary() {
    final stats = ref.read(statsProvider);
    final subjects = ref.read(subjectProvider);
    final allTasks = ref.read(taskProvider);

    final insights = StatsInsightEngine.build(
      tasksThisWeek: ref.read(tasksCompletedThisWeekProvider),
      tasksLastWeek: ref.read(tasksCompletedLastWeekProvider),
      focusMinutesThisWeek: ref.read(focusThisWeekMinutesProvider),
      focusMinutesLastWeek: ref.read(focusLastWeekMinutesProvider),
      completionRateBySubject: StudyAdvisor.completionRateBySubject(
        subjects: subjects,
        tasks: allTasks,
      ),
      subjectNamesById: {for (final s in subjects) s.id: s.name},
      examWeakTopicsBySubject: ref.read(examWeakTopicNamesBySubjectProvider),
      // GOAL → GAP → RE-EVALUATION (Faz 6/7/9) — Stats'ın "Neden" katmanıyla
      // AYNI motor, ikinci bir hesap icat edilmiyor.
      goalGap: ref.read(primaryGoalGapProvider),
      weakestSubjectName: ref.read(weakestDenemeSubjectNameProvider),
      resolvedWeakTopicsBySubject:
          ref.read(resolvedWeakTopicsBySubjectProvider),
    );

    final parts = <String>[];
    if (stats.currentStreak > 0) {
      parts.add('${stats.currentStreak} günlük serin var.');
    }
    if (insights.isNotEmpty) {
      parts.add(insights.first.body);
    } else {
      parts.add('Bu hafta geçen haftayla kıyaslayacak yeterli verin yok '
          'henüz — birkaç gün daha kullan, o zaman gerçek bir kıyas '
          'çıkarabilirim.');
    }

    final top = _topSuggestion();
    if (top != null && top.reason != StudyAdvisor.genericReason) {
      parts.add('Sırada: ${top.subjectName} — ${top.reason}');
    }

    return parts.join(' ');
  }

  /// "Hedefime ne kadar kaldı" / "neden bunu çalışıyorum" gibi sorular için
  /// GOAL → GAP cümlesi — [StatsInsightEngine._goalGapInsight] ile AYNI
  /// hesabın (primaryGoalGapProvider) konuşma diline çevrilmiş hâli. İKİNCİ
  /// bir hedef/gap mantığı İCAT EDİLMEZ (bkz. PHASE 7 notu).
  String? _goalGapSentence() {
    final gap = ref.read(primaryGoalGapProvider);
    if (gap == null || !gap.hasTarget) return null;
    final type = gap.examType;
    final target = gap.target!;

    if (!gap.hasResult) {
      return '$type hedefin ${_fmtNet(target)} net — henüz deneme '
          'eklemedin, ilk sonucunu girince mesafeni söyleyebilirim.';
    }

    final current = gap.currentNet!;
    final diff = gap.gap!;
    if (diff <= 0) {
      return '$type hedefin ${_fmtNet(target)} net, son sonucun '
          '${_fmtNet(current)} net — hedefini geçtin.';
    }

    final buffer = StringBuffer('$type hedefin ${_fmtNet(target)} net, son '
        'sonucun ${_fmtNet(current)} net — aradaki fark '
        '${_fmtNet(diff)} net.');
    final change = gap.gapChange;
    if (change != null && change.abs() >= 0.5) {
      buffer.write(change > 0
          ? ' Geçen denemene göre fark ${_fmtNet(change)} net kapandı.'
          : ' Geçen denemene göre fark ${_fmtNet(-change)} net açıldı.');
    }
    return buffer.toString();
  }

  static String _fmtNet(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);

  // --- Girdi işleme ----------------------------------------------

  // tmm/evt/ok/aynen/tabii(tabi) — öğrencilerin gerçek yazışmada kullandığı
  // kısaltmalar/kısa onaylar; önceden yalnız tam kelimeler ("tamam", "evet")
  // tanınıyordu, kısaltma yazan biri hep "anlaşılamadı" hissediyordu.
  static final _confirm = RegExp(
      r'^(ekle|tamam|tmm|evet|evt|olur|kaydet|ekleyebilirsin|onayla|kabul|ok|aynen|tabii|tabi)\b');
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

  // Kullanıcının KENDİ ilerlemesini sorması ("nasıl gidiyorum") —
  // _wellbeingCheckPhrases'teki "nasıl gidiyor" (koça yönelik "sen nasılsın")
  // alt dizesiyle çakışabildiği için (örn. "nasıl gidiyorum" ⊃ "nasıl
  // gidiyor") bu banka _onSend'de ONDAN ÖNCE kontrol edilir — aksi halde
  // kullanıcının asıl sorduğu (kendi verisi) hiç yanıtlanmadan jenerik bir
  // "İyiyim, sağ ol" cevabı alıyordu.
  static const List<String> _progressCheckPhrases = [
    'nasıl gidiyorum',
    'nasil gidiyorum',
    'ilerlemem nasıl',
    'ilerlemem nasil',
    'durumum ne',
    'durumum nasıl',
    'durumum nasil',
    'ne durumdayım',
    'ne durumdayim',
    'iyi gidiyor muyum',
    'performansım nasıl',
    'performansim nasil',
    'nasıl ilerliyorum',
    'nasil ilerliyorum',
    'başarılı mıyım',
    'basarili miyim',
    'iyi mi gidiyorum',
    'gelişme kaydediyor muyum',
    'gelisme kaydediyor muyum',
  ];

  // GOAL → GAP sorularının bankası (Faz 7) — "nasıl gidiyorum" genel bir
  // ilerleme özeti isterken bunlar spesifik olarak hedef net farkını sorar.
  // Alt dize çakışması yok, bu yüzden sıra _progressCheckPhrases'ten önce ya
  // da sonra olabilir.
  static const List<String> _goalDistancePhrases = [
    'hedefime ne kadar kaldı',
    'hedefime ne kadar kaldi',
    'hedefe ne kadar kaldı',
    'hedefe ne kadar kaldi',
    'hedefime ne kadar var',
    'hedefe ne kadar var',
    'hedefimden ne kadar uzağım',
    'hedefimden ne kadar uzagim',
    'hedefime yetişir miyim',
    'hedefime yetisir miyim',
    'hedefe yetişir miyim',
    'hedefe yetisir miyim',
    'hedefime ulaşır mıyım',
    'hedefime ulasir miyim',
    'kaç net kaldı',
    'kac net kaldi',
    'hedef netim ne durumda',
  ];

  static const List<String> _reasonWhyPhrases = [
    'neden bunu çalışıyorum',
    'neden bunu calisiyorum',
    'neden bu dersi çalışıyorum',
    'neden bu dersi calisiyorum',
    'neden bu konuyu çalışıyorum',
    'neden bu konuyu calisiyorum',
    'niye bunu çalışıyorum',
    'niye bunu calisiyorum',
    'bunu neden öneriyorsun',
    'bunu neden oneriyorsun',
  ];

  static const List<String> _whatToStudyPhrases = [
    'şu an neye çalışmalıyım',
    'su an neye calismaliyim',
    'ne çalışmalıyım',
    'ne calismaliyim',
    'neye çalışmalıyım',
    'neye calismaliyim',
    'bugün ne çalışsam',
    'bugun ne calissam',
    'ne çalışsam iyi olur',
    'ne calissam iyi olur',
    'hangi derse çalışmalıyım',
    'hangi derse calismaliyim',
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

  // --- Offline NLU entegrasyonu -----------------------------------------

  /// NLU'nun eski zincire BIRAKTIĞI cümleler (katlanmış metinde aranır): rica
  /// edilen anlatım/video, "hiçbirine" gibi burnout sorusuna cevaplar, açık
  /// dinlenme talebi ("mola vereyim", "bugün çalışmayacağım"), baştan/iptal.
  static final _nluSkipRe = RegExp(
      r'\b(anlat|acikla|video)\w*|nasil cozul|hic ?bir(ine|i|\s?derse)\b|'
      r'dinlen\w*|\bmola\b|\bara ver\w*|calismayacag|bos ver');

  NluResult _analyzeNlu(String raw) {
    final index = NluEntityIndex.build(
      subjects: ref.read(subjectProvider),
      topics: ref.read(topicProvider),
    );
    _nluIndex = index;
    final r = CoachNlu.analyze(raw, index: index, previous: _lastNluSlots);
    if (r.slots.subject != null || r.slots.topic != null) {
      _lastNluSlots = r.slots;
    }
    return r;
  }

  bool get _midFlow => _pending != null || _delegate || !_draft.isEmpty;

  /// Güvenli (orta/yüksek) ve NLU'nun sahip olduğu bir niyetse cevabı verir.
  bool _tryNlu(NluResult r, String low) {
    if (!r.isConfident || r.intent.isLegacyOwned) return false;
    if (_pending != null && _confirm.hasMatch(low)) return false;
    if (_restart.hasMatch(low) || _nluSkipRe.hasMatch(r.normalized)) {
      return false;
    }
    // Plan akışının ortasındayken (koç bir şey sormuşken) yalnız açık bir
    // SORUN cümlesi akışı böler; "2 saat" gibi cevaplar akışta kalır.
    // Onay bekleyen bir plan varken AÇIK yeni bir plan isteği ("yarın için plan
    // yap") eskisinin yerini alır (bağlam da yeni plana geçer).
    final newPlanOverPending = _pending != null &&
        r.intent == CoachIntent.needPlan &&
        r.confidence == NluConfidence.high;
    if (_midFlow &&
        !newPlanOverPending &&
        !(r.confidence == NluConfidence.high && r.intent.isProblem)) {
      return false;
    }

    final ctx = NluContext.fromReader(
      ref.read,
      goalGapSentence: _goalGapSentence(),
      progressSummary:
          r.intent == CoachIntent.progressConcern ? _progressSummary() : null,
    );
    final reply = NluResponder.reply(r, ctx);
    if (reply == null) return false;
    _applyNluReply(reply);
    _rememberNluReply(r, reply);
    return true;
  }

  // --- Düzeltme (refinement) ----------------------------------------------

  void _rememberNluReply(NluResult r, NluReply reply) {
    final action = reply.action;
    if (action != null && action.kind == NluActionKind.startFocus) {
      final minutes = r.slots.timeMinutes ?? action.intent?.targetMinutes;
      if (minutes != null) {
        _activate(_CoachRef.nluReply);
        _lastNlu = r;
        _lastNluMinutes = minutes;
        return;
      }
    }
  }

  /// "Biraz ağır yap", "artır", "1 saat daha ekle", "2 saat yerine 3 saat yap":
  /// önceki plana/öneriye referans veren kısa düzeltmeler. Neyi değiştireceği
  /// belli değilse UYDURMAZ, açıklama ister.
  bool _tryRefine(String raw, String low) {
    if (_pending != null && _confirm.hasMatch(low)) return false;
    if (_restart.hasMatch(low)) return false;
    final mod = NluModifierParser.parse(raw, index: _nluIndex);
    if (mod == null) return false;
    // "X yerine Y" (sayısız) → eski değiştirme akışı.
    if (mod.type == NluModifierType.replace && !mod.absolute) return false;

    // Bağlam kullanılabilir mi: taze (aktif) ya da açıkça anılmış ("az önceki
    // planı artır"). Veri hâlâ duruyor mu (plan bekliyor / öneri / eklenmiş plan)?
    final usable = _refActive || mod.explicitReference;
    final hasProposal = _ref == _CoachRef.proposal && _pending != null;
    final hasNlu = _ref == _CoachRef.nluReply && _lastNlu != null;
    final hasCommitted = _ref == _CoachRef.committed;

    if (usable && hasProposal) {
      _refineProposal(mod);
      return true;
    }
    // Koç bir soru sormuşken ("günde kaç saat?") "3 saat yap" o sorunun
    // cevabıdır — düzeltme değil.
    if (_pending == null && (_delegate || !_draft.isEmpty)) {
      // Eski ayrıştırıcı "yap"ı konu sanmasın diye süreyi doğrudan taslağa yaz.
      if (mod.absolute && mod.minutes != null) {
        _draft.minutes = mod.minutes;
        _say('Not aldım — ${_fmtMinutes(mod.minutes!)}.');
        _advance();
        return true;
      }
      return false;
    }
    if (usable && hasNlu) {
      _refineNluReply(mod);
      return true;
    }
    if (usable && hasCommitted) {
      _refineCommitted(mod);
      return true;
    }

    // Referans yok / bayat: UYDURMA, sor.
    final stale = hasProposal || hasNlu || hasCommitted;
    _say(stale
        ? _pick([
            'Neyi değiştirmemi istersin? Az önceki planı/öneriyi kastediyorsan '
                '"az önceki planı biraz artır" de; yeni bir şey için "bugün için '
                'plan yap" diyebilirsin.',
            'Buna hangi plan için uygulayayım? Az önceki planı kastediyorsan '
                '"o planı biraz hafiflet" gibi söyle.',
          ])
        : _pick([
            'Neyi değiştirmemi istersin? Önce bir plan ya da öneri isteyelim '
                '(ör. "bugün için 1 saatlik plan yap"), sonra "biraz artır" ya da '
                '"hafiflet" dersen ona uygularım.',
            'Şu an değiştirecek bir plan/öneri görmüyorum. Önce "bugün için plan '
                'yap" de, sonra "biraz ağır yap" ya da "azalt" diyebilirsin.',
          ]));
    return true;
  }

  // --- Bağlam tazeliği ---------------------------------------------------

  /// Bir plan/öneri sunuldu ya da düzeltildi: bağlam taze ve aktif.
  void _activate(_CoachRef kind) {
    _ref = kind;
    _refActive = true;
    _refTurn = _turn;
  }

  /// Kısa onay / teşekkür kelimeleri: yeni konu DEĞİL, akışın devamı.
  static const _continuationWords = {
    'tamam',
    'tmm',
    'olur',
    'evet',
    'evt',
    'hadi',
    'peki',
    'basla',
    'aynen',
    'tabii',
    'tabi',
    'ok',
    'okey',
    'olsun',
    'anladim',
    'sag',
    'ol',
    'saol',
    'tesekkurler',
    'tesekkur',
    'ederim',
    'eyvallah',
  };

  /// Sürekli "tamam" diyerek bile bağlamın sonsuza dek yaşamaması için güvenli
  /// üst sınır (mesaj sayısı) — asıl kural alaka/konu değişimidir.
  static const _refMaxIdleTurns = 6;

  bool _isContinuation(NluResult nlu, String low) {
    if (nlu.intent == CoachIntent.thanks ||
        nlu.intent == CoachIntent.confirmation) {
      return true;
    }
    final t = nlu.normalized.split(' ').where((w) => w.isNotEmpty).toList();
    return t.isNotEmpty &&
        t.length <= 3 &&
        t.every(_continuationWords.contains);
  }

  /// Bu mesaj düzeltme değilse: yeni bir ana konuya mı geçti? Öyleyse eski
  /// düzeltme bağlamını PASİFLEŞTİR (veri durur; yalnız açık referansla dönülür).
  /// Kısa onaylar ve planın kendisi hakkındaki "neden" soruları akışın devamıdır.
  void _expireRefinement(NluResult nlu, String low) {
    if (!_refActive) return;
    final related =
        _isContinuation(nlu, low) || _matchesAny(low, _reasonWhyPhrases);
    if (related && _turn - _refTurn < _refMaxIdleTurns) return;
    _refActive = false;
  }

  /// Plan ZATEN eklenmişken ("tamam"dan sonra) "biraz ağır yap": eklenen plana
  /// dokunma; aynı ayarlarla, düzeltmeyi uygulayan YENİ bir öneri hazırla.
  void _refineCommitted(NluModifier mod) {
    final minutes = _committedMinutes;
    if (minutes == null ||
        !_committedDay ||
        mod.type == NluModifierType.remove) {
      _say('Az önce eklediğim plan listende duruyor; onu bu sohbetten '
          'değiştirmiyorum — Görevler ekranından düzenleyebilirsin. Yeni bir '
          'plan için "bugün için plan yap" de.');
      return;
    }
    _draft.minutes = minutes;
    _energy = _committedEnergy;
    _delegate = true;
    _wantsWeek = _committedWeek;
    _pendingWeek = null;
    _pendingIsDay = true;
    _say('Az önce eklediğim plan listende duruyor; aynı ayarlarla yeni bir '
        'öneri hazırlıyorum — onaylarsan ona eklenir (öncekini Görevler '
        'ekranından silebilirsin).');
    _refineProposal(mod, fromCommitted: true);
  }

  static const _energyLevels = ['düşük', 'orta', 'yüksek'];

  void _refineProposal(NluModifier mod, {bool fromCommitted = false}) {
    if (mod.type == NluModifierType.remove) {
      _removeFromProposal(mod);
      return;
    }
    final isWeek = fromCommitted ? _committedWeek : _pendingWeek != null;
    final dir = mod.direction;
    final intensity = mod.type == NluModifierType.intensityUp ||
        mod.type == NluModifierType.intensityDown ||
        mod.type == NluModifierType.harder ||
        mod.type == NluModifierType.easier;

    var note = '';
    // Yoğunluk = planlayıcının mevcut "energy" ayarı (blok uzunluğu + öncelik).
    if (intensity && !isWeek && _pendingIsDay) {
      final i = _energyLevels.indexOf(_energy);
      final steps = mod.amount == NluAmount.large ? 2 : 1;
      final j = (i + dir * steps).clamp(0, 2);
      if (j != i) {
        final old = _energy;
        _energy = _energyLevels[j];
        _say('Yoğunluğu $old → $_energy yaptım (blok '
            '${PlanBuilder.durationFor(old)} → '
            '${PlanBuilder.durationFor(_energy)} dk).');
        _proposeDay();
        return;
      }
      note = dir > 0
          ? ' Yoğunluk zaten en yüksekte, o yüzden süreyi büyüttüm.'
          : ' Yoğunluk zaten en düşükte, o yüzden süreyi kıstım.';
    } else if (intensity && isWeek) {
      note = ' Haftalık programda ayrı bir yoğunluk ayarı yok; günlük süreyi '
          'değiştirdim.';
    }

    final cur = _draft.minutes ??
        (_pending ?? const <PlanBlock>[]).fold<int>(0, (s, b) => s + b.minutes);
    final maxMinutes = isWeek ? 8 * 60 : 12 * 60;
    final target = (mod.apply(cur) ?? cur).clamp(15, maxMinutes);
    if (target == cur) {
      _say(dir > 0
          ? 'Süre zaten ${_fmtMinutes(cur)} — bunun üstüne çıkmayacağım.'
          : 'Süre zaten ${_fmtMinutes(cur)} — bunun altına inmeyeceğim.');
      return;
    }
    _draft.minutes = target;
    _say('${isWeek ? 'Günlük süreyi' : 'Süreyi'} ${_fmtMinutes(cur)} → '
        '${_fmtMinutes(target)} yaptım.$note');

    // Yeni öneri çıkmazsa (süre en küçük bloğa bile yetmiyorsa) eski öneri
    // geçerli kalır; çıktı aynıysa bunu SÖYLERİZ (sessizce "yaptım" demeyiz).
    final before = _pending;
    final beforeSig = _planSignature(before);
    final beforeWeek = _pendingWeek;
    _pending = null;
    if (isWeek) {
      _proposeWeek();
    } else if (_pendingIsDay) {
      _proposeDay();
    } else {
      _proposeSingle();
    }
    if (_pending == null) {
      _pending = before;
      _pendingWeek = beforeWeek;
      _draft.minutes = cur;
      _activate(_CoachRef.proposal);
      _say('Önceki öneri geçerli — "ekle" dersen onu eklerim.');
    } else if (_planSignature(_pending) == beforeSig) {
      _say('Plan blokları aynı kaldı: bu süre için planlayıcı aynı görevleri '
          'üretiyor. Blokları büyütmek ya da küçültmek için "biraz ağır yap" / '
          '"hafiflet" de.');
    }
  }

  String _planSignature(List<PlanBlock>? blocks) =>
      (blocks ?? const <PlanBlock>[])
          .map((b) => '${b.title}|${b.minutes}')
          .join(',');

  bool _blockIsSubject(PlanBlock b, NluModifier mod) {
    if (mod.targetSubjectId != null && b.subjectId == mod.targetSubjectId) {
      return true;
    }
    final name = mod.targetSubjectName;
    if (name == null) return false;
    return TrText.fold(b.title).contains(TrText.fold(name));
  }

  /// "Fizik çıkar" / "şunu çıkar" — onay bekleyen GÜN planından bir görev.
  void _removeFromProposal(NluModifier mod) {
    final blocks = _pending!;
    if (_pendingWeek != null) {
      _say('Haftalık programdan tek görev çıkarmayı burada yapmıyorum — '
          'ekledikten sonra Görevler ekranından silebilir ya da "günlük süreyi '
          'azalt" diyebilirsin.');
      return;
    }
    if (mod.targetSubjectName == null) {
      final names = blocks.map((b) => b.title).take(4).join(', ');
      _say(
          'Hangisini çıkarayım? ($names) — ders adını yaz, ör. "fizik çıkar".');
      return;
    }
    final keep = blocks.where((b) => !_blockIsSubject(b, mod)).toList();
    if (keep.length == blocks.length) {
      _say('${mod.targetSubjectName} bu önerinin içinde görünmüyor.');
      return;
    }
    if (keep.isEmpty) {
      _pending = null;
      _ref = _CoachRef.none;
      _refActive = false;
      _say('Hepsini çıkarınca plan kalmadı. Baştan kuralım mı — kaç dakika?');
      return;
    }
    _pending = keep;
    final lines = keep.map((b) => '•  ${b.title} · ${b.minutes} dk').join('\n');
    final total = keep.fold<int>(0, (sum, b) => sum + b.minutes);
    _say('${mod.targetSubjectName} çıktı.\n\n$lines\n\n'
        'Toplam ${_fmtMinutes(total)} · ${keep.length} görev.\n\n'
        'Uygunsa "ekle" de.');
  }

  /// Bir öneri cevabından sonra ("30 dk'ya göre daralttım") süreyi değiştir:
  /// aynı NLU sonucunu yeni süreyle mevcut veriye yeniden sor.
  void _refineNluReply(NluModifier mod) {
    final last = _lastNlu!;
    if (mod.type == NluModifierType.remove) {
      _say('Bu öneriden çıkarılacak ayrı bir parça yok; bir plan istersen '
          '"plan yap" de, ondan çıkarabiliriz.');
      return;
    }
    final cur = _lastNluMinutes ?? kDefaultFocusMinutes;
    final target = (mod.apply(cur) ?? cur).clamp(5, 240);
    if (target == cur) {
      _say(mod.direction > 0
          ? 'Süre zaten ${_fmtMinutes(cur)} — bunun üstüne çıkmayacağım.'
          : 'Süre zaten ${_fmtMinutes(cur)} — bunun altına inmeyeceğim.');
      return;
    }
    final intent = (last.intent.isRecommendationFamily || last.intent.isProblem)
        ? last.intent
        : CoachIntent.needRecommendation;
    final r2 = last.copyWith(
      intent: intent,
      slots: last.slots.copyWith(timeMinutes: target, timeIsTarget: true),
    );
    final ctx = NluContext.fromReader(
      ref.read,
      goalGapSentence: _goalGapSentence(),
    );
    final reply = NluResponder.reply(r2, ctx);
    if (reply == null) return;
    _say('Süreyi ${_fmtMinutes(cur)} → ${_fmtMinutes(target)} yaptım.');
    _applyNluReply(reply);
    _rememberNluReply(r2, reply);
  }

  void _applyNluReply(NluReply reply) {
    final action = reply.action;
    if (action?.kind == NluActionKind.planDay) {
      // Koç'un mevcut plan akışını (PlanBuilder) devral — süre/bugün-hafta
      // NLU'dan hazır gelir, eksik olanı koç sorar.
      _draft.reset();
      _pending = null;
      _pendingWeek = null;
      _delegate = true;
      _askedRecurrence = false;
      _regenerateOffset = 0;
      _energy = 'orta';
      _wantsWeek =
          action!.week ? true : (action.minutes != null ? false : null);
      if (action.minutes != null) _draft.minutes = action.minutes;
      _advance();
      return;
    }

    VoidCallback? onAction;
    if (action != null && action.kind == NluActionKind.startFocus) {
      final intent = action.intent!;
      onAction = () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FocusScreen(
                intent: intent,
                autoStart: true, // "Başla" açık bir başlatma jesti
              ),
            ),
          );
    } else if (action != null && action.kind == NluActionKind.openTopics) {
      onAction = () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SubjectTopicsScreen(
                subjectId: action.subjectId!,
                subjectName: action.subjectName!,
              ),
            ),
          );
    }
    _say(reply.text,
        actionLabel: onAction == null ? null : action!.label,
        onAction: onAction);
  }

  static final _dismissRe =
      RegExp(r'\b(bosver|neyse|vazgectim|farketmez|bos ver|onemli degil)\b');

  /// Klavye rastgeleliği ("asdfgh", "kjhgf", "asdasd") — Türkçede ≥4 ardışık
  /// ünsüz ya da yarı yarıya tekrar eden sözcük olmaz.
  bool _looksLikeGibberish(String folded) {
    for (final t in folded.split(' ')) {
      if (t.length < 4) continue;
      if (RegExp(r'[^aeiou0-9_]{4,}').hasMatch(t)) return true;
      if (t.length >= 6 &&
          t.length.isEven &&
          t.substring(0, t.length ~/ 2) == t.substring(t.length ~/ 2)) {
        return true;
      }
      if (t.length >= 6 && !RegExp(r'[aeiou]').hasMatch(t)) return true;
    }
    return false;
  }

  /// Eski zincir bir şey yakalamadıysa VE bir plan akışının ortasında
  /// değilsek: anlamsız/geçiştirme cümlelerini konu sanıp plana çevirmek yerine
  /// nazikçe yönlendir; düşük güvenli bir SORUN cümlesinde kesin konuşmadan
  /// açıklama iste.
  bool _nluFallback(NluResult r, String raw) {
    if (_midFlow) return false;
    final hasPlanSignal =
        PlanParser.parse(raw, subjects: ref.read(subjectProvider)).hasSignal;
    if (hasPlanSignal) return false;

    final unknownish = r.isUnknown || r.confidence == NluConfidence.none;
    // Çalışma sözlüğünden HİÇBİR şey tanımayan, ders/konu içermeyen tam bir cümle
    // ("telefonu bırakamıyorum") konu adı DEĞİLdir: eskiden konu sanılıp "Buna ne
    // kadar zaman ayıralım?" diye soruluyordu. Kısa/konu benzeri girdiler
    // ("deneme analizi") eski akışta kalır.
    final sentenceWithoutVocabulary = unknownish &&
        r.slots.subject == null &&
        r.slots.topic == null &&
        r.knownTokenRatio < 0.5 &&
        (r.normalized.split(' ').length >= 3 ||
            // İki sözcükse: çekimli fiille bitiyorsa cümledir ("telefonu
            // bırakamıyorum"), isim tamlaması ("deneme analizi") konudur.
            RegExp(r'(yorum|yor|dim|dum|tim|tum|acagim|ecegim|irim|urum)$')
                .hasMatch(r.normalized));
    if (unknownish &&
        (sentenceWithoutVocabulary ||
            _looksLikeGibberish(r.normalized) ||
            _dismissRe.hasMatch(r.normalized))) {
      _say(_pick([
        'Tam anlayamadım. "matematikte zorlanıyorum", "bugün 30 dakikam '
            'var ne çalışayım" ya da "plan yap" gibi yazabilirsin.',
        'Bunu çıkaramadım. Ders, süre ya da derdini yaz — örneğin '
            '"paragrafta yanlış yapıyorum" ya da "nereden başlayayım".',
      ]));
      return true;
    }
    if (r.confidence == NluConfidence.low && r.intent.isProblem) {
      _say(NluResponder.clarify(r));
      return true;
    }
    return false;
  }

  void _onSend() {
    final raw = _input.text.trim();
    if (raw.isEmpty) return;
    _input.clear();
    FocusScope.of(context).unfocus();
    _say(raw, coach: false);
    _turn++;

    final low = raw.toLowerCase().replaceAll('̇', '');

    // Offline doğal dil anlama (bkz. lib/nlu): cümleyi niyet + slot'lara
    // çözer; yüksek/orta güvenli ve NLU'nun sahip olduğu niyetlerde MEVCUT
    // Dodom verisiyle (plan, konu kanıtı, StudyAdvisor) cevap verir. Düşük
    // güvende eski zincir aynen çalışır.
    final nlu = _analyzeNlu(raw);
    if (_tryRefine(raw, low)) return;
    _expireRefinement(nlu, low);
    if (_tryNlu(nlu, low)) return;

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

    // GOAL → GAP soruları (Faz 7) — "hedefime ne kadar kaldı" tarzı, genel
    // ilerleme özetinden (_progressCheckPhrases) daha spesifik, bu yüzden
    // önce kontrol edilir.
    if (_matchesAny(low, _goalDistancePhrases)) {
      _say(_goalGapSentence() ??
          'Henüz bir hedef net belirlemedin — Deneme Takip ekranından '
              'TYT/AYT için hedefini girebilirsin.');
      return;
    }

    if (_matchesAny(low, _reasonWhyPhrases)) {
      final top = _topSuggestion();
      final gapSentence = _goalGapSentence();
      if (top != null && top.reason != StudyAdvisor.genericReason) {
        final suffix = gapSentence != null ? ' $gapSentence' : '';
        _say('${top.subjectName}: ${top.reason}.$suffix');
      } else if (gapSentence != null) {
        _say(gapSentence);
      } else {
        _say('Şu an elimde somut bir gerekçe yok — dengeli ilerlemek için '
            'öneriyorum. Deneme eklersen ya da bir hedef net belirlersen '
            'daha somut bir gerekçe verebilirim.');
      }
      return;
    }

    if (_matchesAny(low, _whatToStudyPhrases)) {
      final top = _topSuggestion();
      if (top != null) {
        final reasonText = top.reason == StudyAdvisor.genericReason
            ? top.reason
            : '${top.reason}.';
        _say('${top.subjectName} — $reasonText İstersen bunu planına '
            'ekleyeyim, ya da başka bir ders söyle.');
      } else {
        _say('Henüz önerecek somut bir şey yok — önce bir ders eklemen '
            'gerekiyor.');
      }
      return;
    }

    if (_matchesAny(low, _progressCheckPhrases)) {
      _say(_progressSummary());
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
      _ref = _CoachRef.none;
      _refActive = false;
      _draft.reset();
      _pending = null;
      _pendingWeek = null;
      _delegate = false;
      _wantsWeek = null;
      _askedRecurrence = false;
      _regenerateOffset = 0;
      _energy = 'orta';
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

    if (_nluFallback(nlu, raw)) return;

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
        } else if (_confirm.hasMatch(low)) {
          // Düz "evet/tamam/olur" — iki seçenekli sorunun ilk (daha basit)
          // seçeneğini onayladığı varsayılır. Bu olmadan _wantsWeek hep null
          // kalıp aynı soru sonsuza dek tekrarlanıyordu, çünkü "evet" ne
          // hafta ne gün kelimesini içeriyor.
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

    // Çıplak sayı ("2") — PlanParser bunu bilinçli olarak süre saymıyor
    // (genel amaçlı ayrıştırıcıda "2" tek başına belirsiz: tarih mi, sayı
    // mı?). Ama koç TAM OLARAK süre sorduğu anda (_draft.minutes hâlâ boş,
    // delegate modunda hep önce süre sorulur / normal modda konu zaten
    // biliniyorsa süre sorulur) kullanıcının "2 saat" yerine sadece "2"
    // yazması çok yaygın — önceden bu hiç anlaşılmayıp aynı soru tekrar
    // soruluyordu. Burada, YALNIZCA bu dar bağlamda, saat kabul ediyoruz.
    if ((_delegate || _draft.hasSubject) &&
        _draft.minutes == null &&
        parsed.durationMinutes == null) {
      final bareNumber = RegExp(r'^\d+([.,]\d+)?$').firstMatch(raw.trim());
      if (bareNumber != null) {
        final hours =
            double.tryParse(bareNumber.group(0)!.replaceAll(',', '.'));
        if (hours != null && hours > 0) {
          _draft.minutes = (hours * 60).round();
        }
      }
    }

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
    _activate(_CoachRef.proposal);

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

  /// Plana girecek DOĞRULANMIŞ zorlanma konuları (art arda zorlanma / gerçek süre
  /// aşımı — tek bir "zorlandım" plan değiştirmez). Deneme kanıtıyla zaten
  /// "tekrar" olanlar çıkarılır (aynı konu iki kez planlanmasın). Her birinin
  /// gerekçesi öğrencinin kendi kanıtına dayanır.
  Map<String, List<ReviewTopic>> _struggledPlanTopics() {
    final examWeakIds = ref.read(currentWeakTopicIdSetProvider);
    final repeated = ref.read(repeatedStruggleTopicsBySubjectProvider);
    return {
      for (final e in repeated.entries)
        e.key: [
          for (final t in e.value)
            if (!examWeakIds.contains(t.id))
              (
                name: t.name,
                id: t.id,
                reason:
                    '${TopicEvidenceEngine.difficultyReason(t.name, DifficultySignal.repeated)}.',
              ),
        ],
    }..removeWhere((_, v) => v.isEmpty);
  }

  void _proposeDay() {
    final subjects = ref.read(subjectProvider);
    final allTasks = ref.read(taskProvider);
    final examDate = ref.read(statsProvider).examDate;
    final examDays = examDate == null ? null : daysUntilExam(examDate);

    // Konu Takip verisi: kapsama oranları + ders başına boş konular.
    final uncovered = <String, List<UncoveredTopic>>{};
    for (final t in ref.read(topicProvider)) {
      if (t.status != TopicStatus.reviewed && t.status != TopicStatus.studied) {
        uncovered
            .putIfAbsent(t.subjectId, () => [])
            .add((name: t.name, id: t.id));
      }
    }

    final advisorResults = runStudyAdvisor(ref.read, limit: subjects.length);
    final advisorIds = advisorResults.map((s) => s.subjectId).toList();
    // "Neden bu görev?" (Faz 6) — StudyAdvisor'ın dersi seçerkenki AYNI
    // gerekçesi PlanBuilder'a taşınır (jenerik olanlar hariç — somut bir
    // sinyal yoksa sahte bir gerekçe üretilmez).
    final subjectReasons = <String, String>{
      for (final s in advisorResults)
        if (s.reason != StudyAdvisor.genericReason) s.subjectId: s.reason,
    };

    final ordered = _rotated(<SubjectModel>[
      for (final id in advisorIds) subjects.firstWhere((s) => s.id == id),
      for (final s in subjects)
        if (!advisorIds.contains(s.id)) s,
    ]);

    // Önceden saate yuvarlanıp geri çarpılıyordu ("20 dakikam var" → 60 dk
    // plan çıkıyordu) — artık kullanıcının verdiği dakika doğrudan kullanılır.
    final capacityMinutes = _draft.minutes!.clamp(15, 12 * 60);
    final result = PlanBuilder.build(
      orderedSubjects: ordered,
      capacityMinutes: capacityMinutes,
      energy: _energy,
      examDays: examDays,
      uncoveredTopics: uncovered,
      fillToCapacity: uncovered.isNotEmpty,
      reducedCapacitySubjectIds: StudyAdvisor.overcommittedSubjectIds(
        subjects: subjects,
        tasks: allTasks,
      ),
      subjectCompletionRates: StudyAdvisor.completionRateBySubject(
        subjects: subjects,
        tasks: allTasks,
      ),
      examWeakTopics: ref.read(examWeakTopicsBySubjectProvider),
      struggledTopics: _struggledPlanTopics(),
      subjectReasons: subjectReasons,
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
    _activate(_CoachRef.proposal);

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
    final uncovered = <String, List<UncoveredTopic>>{};
    for (final t in ref.read(topicProvider)) {
      if (t.status != TopicStatus.reviewed && t.status != TopicStatus.studied) {
        uncovered
            .putIfAbsent(t.subjectId, () => [])
            .add((name: t.name, id: t.id));
      }
    }

    final advisorResults = runStudyAdvisor(ref.read, limit: subjects.length);
    final advisorIds = advisorResults.map((s) => s.subjectId).toList();
    final subjectReasons = <String, String>{
      for (final s in advisorResults)
        if (s.reason != StudyAdvisor.genericReason) s.subjectId: s.reason,
    };

    final ordered = _rotated(<SubjectModel>[
      for (final id in advisorIds) subjects.firstWhere((s) => s.id == id),
      for (final s in subjects)
        if (!advisorIds.contains(s.id)) s,
    ]);

    final n0 = DateTime.now();
    final today = DateTime(n0.year, n0.month, n0.day);
    final minutesPerDay = _draft.minutes!.clamp(15, 8 * 60);

    final week = PlanBuilder.buildWeek(
      orderedSubjects: ordered,
      uncoveredTopics: uncovered,
      minutesPerDay: minutesPerDay,
      startDate: today,
      examDays: examDays,
      reducedCapacitySubjectIds: StudyAdvisor.overcommittedSubjectIds(
        subjects: subjects,
        tasks: allTasks,
      ),
      subjectCompletionRates: StudyAdvisor.completionRateBySubject(
        subjects: subjects,
        tasks: allTasks,
      ),
      examWeakTopics: ref.read(examWeakTopicsBySubjectProvider),
      struggledTopics: _struggledPlanTopics(),
      subjectReasons: subjectReasons,
    );

    if (week.isEmpty) {
      _say('Program çıkmadı — günde biraz daha vakit yazar mısın?');
      _draft.minutes = null;
      return;
    }

    _pendingWeek = week;
    _pending = week.allBlocks;
    _pendingIsDay = true;
    _activate(_CoachRef.proposal);
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
    _committedMinutes = _draft.minutes;
    _committedEnergy = _energy;
    _committedWeek = _pendingWeek != null;
    _committedDay = _pendingIsDay;
    _activate(_CoachRef.committed);
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
            difficulty: b.difficulty,
            topicId: b.topicId,
            sourceReason: b.reason,
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
      _energy = 'orta';
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

    // "Şimdi Başla" eylemi (varsa) if/else dışına buradan taşınır — bkz.
    // aşağıdaki blok, yalnız bugüne eklenen ilk görev için doldurulur.
    VoidCallback? startAction;

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
        sourceReason: b.reason,
      );
    } else {
      TaskModel? firstTask;
      DateTime? firstDue;
      for (final b in blocks) {
        final due = _pendingIsDay ? today : (_draft.day ?? today);
        // Gün planı: saatsiz gün-kapsamlı görevler. Tek görev: yalnız
        // kullanıcı saat verdiyse zamanlı.
        final scheduled = (!_pendingIsDay && timeOfDay != null)
            ? DateTime(
                due.year, due.month, due.day, timeOfDay.hour, timeOfDay.minute)
            : null;
        final created = notifier.addTask(
          title: b.title,
          subjectId: b.subjectId.isEmpty ? null : b.subjectId,
          dueDate: due,
          priority: b.priority,
          scheduledTime: scheduled,
          estimatedMinutes: b.minutes,
          difficulty: b.difficulty,
          topicId: b.topicId,
          sourceReason: b.reason,
        );
        firstTask ??= created;
        firstDue ??= due;
      }

      // "Şimdi Başla" — yalnız BUGÜNE eklenen ilk görev için (yarına/başka
      // güne planlanan bir görev için şimdi kronometre başlatmak anlamsız).
      // Kilitleme/zorlama değil, tek dokunuşla Odak ekranına (ders/konu/
      // süre önceden dolu) geçiş — istemezse hiç dokunmaz, sohbette kalır.
      if (firstTask != null && firstDue == today) {
        final task = firstTask;
        startAction = () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FocusScreen(
                  intent: intentForTask(ref.read, task),
                  autoStart: true, // "Şimdi Başla" açık bir başlatma jesti
                ),
              ),
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
    _energy = 'orta';
    if (isFirstTaskEver) {
      ref.read(statsProvider.notifier).markFirstTaskAdded();
      _say(
        n == 1
            ? 'İlk görevini ekledin. Başka bir şey planlayalım mı?'
            : 'İlk görevlerini ekledin. $n görev listene eklendi. '
                'Başka bir şey var mı?',
        actionLabel: startAction == null ? null : 'Şimdi Başla',
        onAction: startAction,
      );
    } else {
      _say(
        n == 1
            ? _pick([
                'Eklendi. Başka bir şey planlayalım mı?',
                'Tamamdır, listene ekledim. Devam edelim mi?',
              ])
            : _pick([
                '$n görev eklendi. Başka bir şey var mı?',
                '$n görevi listene koydum. Başka?',
              ]),
        actionLabel: startAction == null ? null : 'Şimdi Başla',
        onAction: startAction,
      );
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

  // Önceden "Bu soruyu adım adım açıklar mısın?" vardı — koç bunu her
  // seferinde reddediyordu (kapsam dışı, bkz. _contentRequestPhrases).
  // "Sınava nasıl hazırlanmalıyım?" da aslında hiç cevaplanmıyordu — konu
  // sinyali yok diye sessizce "ne çalışmak istiyorsun" sorusuna düşüyordu.
  // İkisi de koçun GERÇEKTEN yapabildiği şeyleri (plan kurma) örnekliyor.
  static const _faqPrompts = [
    'Bugünümü sen ayarla',
    'Yarın 1 saat matematik çalışacağım',
  ];

  @override
  Widget build(BuildContext context) {
    // Koç'un yazarken tarih/saat/süre/dersi canlı renklendirebilmesi için
    // güncel ders listesini denetleyiciye taşı (bkz. _HighlightingController).
    final subjects = ref.watch(subjectProvider);
    _input.subjects = subjects;

    // Bug: _intro() her zaman TAM 2 mesaj gönderiyor (selam + yönlendirme),
    // <= 1 koşulu bu yüzden hiçbir zaman doğru olmuyor, karşılama bloğu hiç
    // görünmüyordu. Doğru eşik 2 — sohbet gerçekten başlayınca (ilk
    // kullanıcı mesajıyla en az 3'e çıkınca) kaybolur.
    final isFresh = _turns.length <= 2;

    final stats = ref.watch(statsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      // Figma'nın Dodom+avatar üst şeridi Home/Dersler'le aynı — piksel
      // karşılaştırmasında bu ekranda hiç yoktu, eklendi. Koç bir sekme
      // değil push edilen bir ekran olduğu için AppBar geri oku için
      // korunuyor (şeffaf, başlıksız).
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: AppHeader(
              initial: (stats.userName?.trim().isNotEmpty ?? false)
                  ? stats.userName!.trim()[0].toUpperCase()
                  : null,
              rank: ref.watch(rankProvider).rank,
              onProfileTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              ),
              onRankTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RankLadderScreen()),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Figma'daki "Birlikte çözelim" başlığı + hızlı aksiyonlar +
          // Konu seç + Sık sorulanlar bloğu, sohbetin geri kalanıyla AYNI
          // ListView'a ilk öğe olarak konuyor (küçük ekranlarda ayrı sabit
          // bir Column'un taşma riskini önlemek için — hepsi tek bir kaydırma
          // ekseninde).
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              itemCount: _turns.length + (isFresh ? 1 : 0),
              itemBuilder: (_, i) {
                if (isFresh && i == 0) {
                  return _CoachIntroHeader(
                    subjects: subjects,
                    faqPrompts: _faqPrompts,
                    onQuickPomodoro: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const FocusScreen(
                          intent: StudyIntent(
                            source: StudyIntentSource.free,
                            targetMinutes: 25,
                          ),
                          initialPomodoro: true,
                        ),
                      ),
                    ),
                    onQuickAutoPlan: () => _sendQuick(
                        'sen ayarla, bugün için eksik konularımdan planla'),
                    onQuickAddTask: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AddTaskScreen()),
                    ),
                    onSubjectTap: (s) =>
                        _sendQuick('${s.name} konusunda yardımcı olur musun?'),
                    onFaqTap: _sendQuick,
                  );
                }
                final turnIndex = isFresh ? i - 1 : i;
                return _Bubble(turn: _turns[turnIndex]);
              },
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
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(999),
                            border:
                                Border.all(color: AppColors.border, width: 1),
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
                              hintText: 'Sorunu buraya yaz…',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Semantics(
                        button: true,
                        enabled: _hasInput,
                        label: 'Gönder',
                        child: TapScale(
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
                            color: _hasInput
                                ? AppColors.onColor(AppColors.primary)
                                : AppColors.textMuted,
                          ),
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
  // Plan onaylandıktan sonra "Şimdi Başla" gibi tek seferlik bir eylem
  // sunmak için — kilitleme/zorlama değil, tek dokunuşla Odak ekranına
  // (seçilen ders/konu/süre önceden dolu) geçiş kolaylığı.
  final String? actionLabel;
  final VoidCallback? onAction;
  const _Turn({
    required this.coach,
    required this.text,
    this.actionLabel,
    this.onAction,
  });
}

/// Figma'daki "Birlikte çözelim" karşılama bloğu — başlık + hızlı
/// aksiyonlar + Konu seç + Sık sorulanlar. Sohbet henüz başlamamışken
/// (yalnız karşılama mesajı varken) sohbet listesinin İLK öğesi olarak
/// gösterilir, ilk kullanıcı mesajından sonra kaybolur.
class _CoachIntroHeader extends StatelessWidget {
  final List<SubjectModel> subjects;
  final List<String> faqPrompts;
  final VoidCallback onQuickPomodoro;
  final VoidCallback onQuickAutoPlan;
  final VoidCallback onQuickAddTask;
  final ValueChanged<SubjectModel> onSubjectTap;
  final ValueChanged<String> onFaqTap;

  const _CoachIntroHeader({
    required this.subjects,
    required this.faqPrompts,
    required this.onQuickPomodoro,
    required this.onQuickAutoPlan,
    required this.onQuickAddTask,
    required this.onSubjectTap,
    required this.onFaqTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ÖNEMLİ: Bu ekran konu anlatmıyor/soru çözmüyor (bkz.
          // _contentRequestPhrases — "açıklar mısın" gibi istekleri açıkça
          // reddediyor, CLAUDE.md kapsam sınırı). Önceki metin ("Yapay Zeka
          // Öğretmenin" + "adım adım açıklayarak yardımcı olayım") tam
          // olarak reddettiği şeyi vaat ediyordu — kullanıcı "Bu soruyu
          // adım adım açıklar mısın?" hızlı sorusuna basınca "kapsamım
          // dışında" cevabı alıyordu. Metin artık gerçekte yaptığı şeyle
          // (plan kurma) tutarlı.
          const AppTitleBlock(
            eyebrow: 'ÇALIŞMA KOÇUN',
            title: 'Bugünü kuralım',
            subtitle: 'Ne çalışmak istediğini yaz, planını birlikte '
                'kurayım. İstersen "sen ayarla" de, ben hallederim.',
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _QuickActionPill(
                icon: Icons.timer_outlined,
                label: '25 dk Pomodoro Başlat',
                tint: AppColors.vibrantViolet,
                onTap: onQuickPomodoro,
              ),
              _QuickActionPill(
                icon: Icons.auto_awesome_outlined,
                label: 'Eksik konularımı sen planla',
                tint: AppColors.vibrantViolet,
                onTap: onQuickAutoPlan,
              ),
              _QuickActionPill(
                icon: Icons.add_task_outlined,
                label: 'Hızlı görev ekle',
                tint: AppColors.vibrantViolet,
                onTap: onQuickAddTask,
              ),
            ],
          ),
          if (subjects.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Konu seç', style: AppTextStyles.heading3),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: subjects.map((s) {
                final tint = Color(s.colorValue);
                return TapScale(
                  onTap: () => onSubjectTap(s),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.tonal(tint),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      s.name,
                      style: AppTextStyles.caption.copyWith(
                        color: tint,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 20),
          Text('Örnek istekler', style: AppTextStyles.heading3),
          const SizedBox(height: 10),
          ...faqPrompts.map((q) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _FaqRow(question: q, onTap: () => onFaqTap(q)),
              )),
        ],
      ),
    );
  }
}

/// "Örnek istekler" satırı — sohbet rozeti + örnek metin + chevron.
/// Dokununca metni doğrudan Koç'a gönderir (statik metin değil, gerçek
/// bir hızlı-gönder aksiyonu).
class _FaqRow extends StatelessWidget {
  final String question;
  final VoidCallback onTap;

  const _FaqRow({required this.question, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.tonal(AppColors.eyebrowRose),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.chat_bubble_outline,
                  size: 14, color: AppColors.eyebrowRose),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                question,
                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final _Turn turn;
  const _Bubble({required this.turn});

  @override
  Widget build(BuildContext context) {
    final coach = turn.coach;
    final bubble = Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.7,
      ),
      decoration: BoxDecoration(
        color: coach ? AppColors.surface : AppColors.tonal(AppColors.primary),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: Radius.circular(coach ? 4 : 20),
          bottomRight: Radius.circular(coach ? 20 : 4),
        ),
        border: coach ? Border.all(color: AppColors.border) : null,
        boxShadow: coach ? AppColors.softShadow : null,
      ),
      child: Text(
        turn.text,
        style: AppTextStyles.body
            .copyWith(color: AppColors.textPrimary, height: 1.35),
      ),
    );

    // Figma'da Koç mesajlarının solunda mor daire + sparkle ikonlu bir AI
    // avatarı var — piksel karşılaştırmasında bu tamamen eksikti, eklendi.
    if (!coach) {
      return Align(alignment: Alignment.centerRight, child: bubble);
    }

    final content = turn.onAction == null
        ? bubble
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              bubble,
              const SizedBox(height: 6),
              TapScale(
                onTap: turn.onAction,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [AppColors.glow(AppColors.primary)],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.timer_outlined,
                          size: 16,
                          color: AppColors.onColor(AppColors.primary)),
                      const SizedBox(width: 6),
                      Text(
                        turn.actionLabel!,
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.onColor(AppColors.primary),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 10),
        Flexible(child: content),
      ],
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
            Flexible(
              child: Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: tint,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Düzeltme cümlelerinin ("artır", "biraz ağır yap") neye referans verdiği.
enum _CoachRef { none, proposal, nluReply, committed }
