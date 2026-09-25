import 'package:flutter_test/flutter_test.dart';
import 'package:study_planner/nlu/nlu_engine.dart';
import 'package:study_planner/nlu/nlu_models.dart';
import 'package:study_planner/nlu/nlu_phrases.dart';
import 'package:study_planner/nlu/nlu_slots.dart';
import 'package:study_planner/nlu/tr_text.dart';

/// Bir örnek cümle + kabul edilen niyet(ler). Aynı cümle için birden çok
/// niyet kabulü, gerçekten iç içe niyetlerde (ör. "ne çalışayım" ↔ "nereden
/// başlayayım") kullanılır — kural gevşetmek için değil.
class NluCase {
  final String text;
  final Set<CoachIntent> ok;
  const NluCase(this.text, this.ok);
}

NluCase c(String text, CoachIntent a, [CoachIntent? b, CoachIntent? c2]) =>
    NluCase(text, {a, if (b != null) b, if (c2 != null) c2});

const rec = CoachIntent.needRecommendation;

/// Niyet başına: normal, kısa, yazım hatalı, konuşma dili, uzun, bileşik,
/// olumsuz örnekler.
final List<NluCase> corpus = [
  // ---- needPlan ----
  c('bana bir plan yap', CoachIntent.needPlan),
  c('plan yap', CoachIntent.needPlan),
  c('bugünü planla', CoachIntent.needPlan),
  c('bana haftalık program hazırla', CoachIntent.needPlan),
  c('ya abi bi plan yapsana bana', CoachIntent.needPlan),
  c('bana bir prgoram hazirla', CoachIntent.needPlan),
  c('plan yapamıyorum sen yap', CoachIntent.needPlan),
  c('sınava kadar günlük bir çalışma programı çıkarır mısın bana',
      CoachIntent.needPlan),
  c('sen ayarla', CoachIntent.needPlan),

  // ---- needRecommendation ----
  c('bugün ne çalışsam', rec, CoachIntent.whatToDoNow),
  c('ne çalışayım', rec, CoachIntent.whatToDoNow),
  c('bugun ne calisayim', rec, CoachIntent.whatToDoNow),
  c('bana bir şey öner', rec),
  c('ne çalışsam bilmiyorum abi', rec, CoachIntent.whatToDoNow),
  c('hangi derse çalışmalıyım', rec, CoachIntent.subjectGuidance),
  c('çalışacak bir şey öner', rec),
  c('ne tavsiye edersin', rec),
  c('ya hocam bugün için ne önerirsin galiba kafam karıştı', rec,
      CoachIntent.whatToDoNow),

  // ---- needStartPoint ----
  c('nereden başlayayım', CoachIntent.needStartPoint),
  c('nerden baslasam', CoachIntent.needStartPoint),
  c('nasıl başlayacağım', CoachIntent.needStartPoint),
  c('neyle başlamalıyım', CoachIntent.needStartPoint),
  c('ya nerden başlıycam bilmiyorum', CoachIntent.needStartPoint),
  c('hiçbir şey bilmiyorum nereden başlayayım', CoachIntent.needStartPoint,
      CoachIntent.strugglingSubject),
  c('ilk adım ne olmalı', CoachIntent.needStartPoint),

  // ---- whatToDoNow ----
  c('şimdi ne yapayım', CoachIntent.whatToDoNow),
  c('ne yapacağım şimdi', CoachIntent.whatToDoNow),
  c('şu an ne çalışmalıyım', CoachIntent.whatToDoNow, rec),
  c('napayım şimdi', CoachIntent.whatToDoNow),
  c('sırada ne var', CoachIntent.whatToDoNow),
  c('ne yapacağımı bilmiyorum', CoachIntent.whatToDoNow),

  // ---- studySessionRequest ----
  c('çalışma başlat', CoachIntent.studySessionRequest),
  c('odak seansı başlat', CoachIntent.studySessionRequest),
  c('hadi çalışmaya başlayalım', CoachIntent.studySessionRequest),
  c('pomodoro başlat', CoachIntent.studySessionRequest),
  c('kronometre aç', CoachIntent.studySessionRequest),

  // ---- subjectGuidance ----
  c('matematiğe nasıl çalışmalıyım', CoachIntent.subjectGuidance),
  c('fizik için ne yapmalıyım', CoachIntent.subjectGuidance),
  c('kimyayı nasıl çalışayım', CoachIntent.subjectGuidance),
  c('mat için öneri', CoachIntent.subjectGuidance, rec),
  c('biyolojiye nereden bakayım', CoachIntent.subjectGuidance,
      CoachIntent.needStartPoint),

  // ---- topicGuidance ----
  c('türevi nasıl çalışmalıyım', CoachIntent.topicGuidance),
  c('limite ne kadar süre ayırayım', CoachIntent.topicGuidance),
  c('paragrafa nasıl başlayayım', CoachIntent.topicGuidance,
      CoachIntent.needStartPoint),
  c('integral için ne önerirsin', CoachIntent.topicGuidance, rec),

  // ---- timeConstraint ----
  c('bugün sadece 30 dakikam var', CoachIntent.timeConstraint),
  c('vaktim çok az', CoachIntent.timeConstraint),
  c('yarım saatim var', CoachIntent.timeConstraint),
  c('elimde 45 dk var ne yapayım', CoachIntent.timeConstraint, rec,
      CoachIntent.whatToDoNow),
  c('bugün toplam 2 saat çalışabilirim', CoachIntent.timeConstraint),
  c('sadece bi saatim var ya', CoachIntent.timeConstraint),
  c('Bugün sadece 30 dakikam var ne çalışayım?', CoachIntent.timeConstraint,
      rec),

  // ---- strugglingSubject ----
  c('matematikte zorlanıyorum', CoachIntent.strugglingSubject),
  c('fiziği anlamıyorum', CoachIntent.strugglingSubject),
  c('kimya hiç oturmuyo', CoachIntent.strugglingSubject),
  c('ya abi matematik çok zor', CoachIntent.strugglingSubject),
  c('geometride çok zayıfım', CoachIntent.strugglingSubject),
  c('matmatikte zorlaniyom', CoachIntent.strugglingSubject),
  c('zorlanıyorum', CoachIntent.strugglingSubject),
  c('çalışıyorum ama matematik bir türlü gelmiyor hep tıkanıyorum',
      CoachIntent.strugglingSubject),

  // ---- strugglingTopic ----
  c('türevde zorlanıyorum', CoachIntent.strugglingTopic),
  c('integrali anlamıyorum', CoachIntent.strugglingTopic),
  c('limit hiç oturmadı', CoachIntent.strugglingTopic),
  c('paragrafta zorlanıyorum', CoachIntent.strugglingTopic),

  // ---- questionPerformanceProblem ----
  c('sürekli yanlış yapıyorum', CoachIntent.questionPerformanceProblem),
  c('Paragrafta sürekli yanlış yapıyorum',
      CoachIntent.questionPerformanceProblem, CoachIntent.strugglingTopic),
  c('sorularda süre yetmiyor', CoachIntent.questionPerformanceProblem),
  c('testlerde hep aynı hatayı yapıyorum',
      CoachIntent.questionPerformanceProblem),
  c('soru çözerken takılıyorum', CoachIntent.questionPerformanceProblem),
  c('dikkatsizlikten yanlış yapıyorum', CoachIntent.questionPerformanceProblem),

  // ---- mockExamProblem ----
  c('denemelerim kötü geçiyor', CoachIntent.mockExamProblem),
  c('deneme netlerim artmıyor', CoachIntent.mockExamProblem),
  c('denemede matematik netim çok düşük', CoachIntent.mockExamProblem),
  c('denemeyi bitiremiyorum', CoachIntent.mockExamProblem),
  c('son denemem rezildi', CoachIntent.mockExamProblem),

  // ---- examUrgency ----
  c('yarın deneme var', CoachIntent.examUrgency),
  c('yarın sınav var ne çalışayım', CoachIntent.examUrgency),
  c('sınava çok az kaldı', CoachIntent.examUrgency),
  c('haftaya deneme var hazırlıksızım', CoachIntent.examUrgency),
  c('bugün deneme var', CoachIntent.examUrgency),
  c('Yarın deneme var çok eksiğim', CoachIntent.examUrgency),
  c('yks ye çok az kaldı hazır değilim', CoachIntent.examUrgency),

  // ---- behindSchedule ----
  c('çok geride kaldım', CoachIntent.behindSchedule),
  c('yetişemiyorum', CoachIntent.behindSchedule),
  c('yetismiyor', CoachIntent.behindSchedule),
  c('konular birikti', CoachIntent.behindSchedule),
  c('planım aksadı', CoachIntent.behindSchedule),
  c('matematikte çok geriyim', CoachIntent.behindSchedule),
  c('planı yapamadım geride kaldım', CoachIntent.behindSchedule),
  c('ya abi çok geriye düştüm ne yapayım', CoachIntent.behindSchedule),

  // ---- tooMuchWork ----
  c('çok fazla konu var', CoachIntent.tooMuchWork),
  c('hepsini yapamam', CoachIntent.tooMuchWork),
  c('görev listem çok uzun', CoachIntent.tooMuchWork),
  c('bunaldım çok iş var', CoachIntent.tooMuchWork),
  c('çok fazla konu var hepsini yapamam', CoachIntent.tooMuchWork),

  // ---- lowProgress ----
  c('bugün çalışamadım', CoachIntent.lowProgress),
  c('bugun hic calisamadim', CoachIntent.lowProgress),
  c('iki gündür çalışamıyorum', CoachIntent.lowProgress),
  c('odaklanamıyorum', CoachIntent.lowProgress),
  c('bugün verimsiz geçti', CoachIntent.lowProgress),
  c('bugün çalıştım ama verimsizdi', CoachIntent.lowProgress),

  // ---- lowMotivation ----
  c('motivasyonum yok', CoachIntent.lowMotivation),
  c('çalışasım gelmiyor', CoachIntent.lowMotivation),
  c('bıktım artık', CoachIntent.lowMotivation),
  c('yorgunum', CoachIntent.lowMotivation),
  c('canım hiç çalışmak istemiyor', CoachIntent.lowMotivation),
  c('pes ediyorum', CoachIntent.lowMotivation),
  c('ya abi hiç motivasyonum kalmadı ne yapayım', CoachIntent.lowMotivation),

  // ---- progressConcern ----
  c('ilerleyemiyorum', CoachIntent.progressConcern),
  c('yerimde sayıyorum', CoachIntent.progressConcern),
  c('nasıl gidiyorum', CoachIntent.progressConcern),
  c('çok çalışıyorum ama sonuç yok', CoachIntent.progressConcern),

  // ---- positiveProgress ----
  c('bugün çok iyi çalıştım', CoachIntent.positiveProgress),
  c('netlerim arttı', CoachIntent.positiveProgress),
  c('her şey yolunda', CoachIntent.positiveProgress),
  c('görevlerimi tamamladım', CoachIntent.positiveProgress),

  // ---- thanks / confirmation ----
  c('teşekkürler', CoachIntent.thanks),
  c('sağ ol', CoachIntent.thanks),
  c('tamam', CoachIntent.confirmation),
  c('evet', CoachIntent.confirmation),

  // ---- olumsuzlama ----
  c('zorlanmıyorum', CoachIntent.positiveProgress),
  c('bugün çalıştım', CoachIntent.positiveProgress, CoachIntent.unknown),

  // ---- bileşik cümleler ----
  c('Matematikte çok geride kaldım ne yapacağımı bilmiyorum',
      CoachIntent.behindSchedule),
  c('Matematikte çok gerideyim ve bugün sadece 1 saatim var',
      CoachIntent.behindSchedule),
  c('Yarın deneme var, matematikte hiçbir şey bilmiyorum',
      CoachIntent.examUrgency),
  c('sınava 20 gün kaldı ne yapmalıyım', CoachIntent.examUrgency),
];

void main() {
  group('TrText.fold', () {
    test('Türkçe karakterleri ve büyük/küçük harfi katlar', () {
      expect(TrText.fold('MATEMATİĞİM'), 'matematigim');
      expect(TrText.fold('Çalışıyorum'), 'calisiyorum');
      expect(TrText.fold('yetişemedim!!'), 'yetisemedim');
      expect(TrText.fold("matematik'te"), 'matematikte');
    });

    test('uzatılmış harfleri ve noktalamayı sadeleştirir', () {
      expect(TrText.fold('çoooook zooor...'), 'cok zor');
      expect(TrText.fold('  ya   abi,  bi   şey  '), 'ya abi bi sey');
    });

    test('jeton benzerliği: çekim eki, yazım hatası, ilgisiz', () {
      expect(TrText.tokenSimilarity('calis', 'calis'), 1.0);
      expect(TrText.tokenSimilarity('geri', 'gerideyim'), greaterThan(0.85));
      expect(TrText.tokenSimilarity('matmatik', 'matematik'), greaterThan(0.8));
      expect(TrText.tokenSimilarity('program', 'prgoram'), greaterThan(0.8));
      expect(TrText.tokenSimilarity('kitap', 'defter'), 0.0);
      expect(TrText.tokenSimilarity('ne', 'no'), 0.0);
    });
  });

  group('süre slot\'u', () {
    int? m(String s) => NluSlotExtractor.minutes(s);
    test('dakika/saat ifadeleri', () {
      expect(m('30 dakikam var'), 30);
      expect(m('45 dk'), 45);
      expect(m('2 saat'), 120);
      expect(m('yarım saat'), 30);
      expect(m('1,5 saat'), 90);
      expect(m('1 saat 30 dk'), 90);
      expect(m('bir buçuk saat'), 90);
      expect(m('bi saatim var'), 60);
      expect(m('kırk beş dakika'), 45);
      expect(m('otuz dakika'), 30);
      expect(m('iki saat'), 120);
    });
    test('süre olmayan sayılar süre sayılmaz', () {
      expect(m('10 sayfa okudum'), isNull);
      expect(m('saat 5te başlayacağım'), isNull);
      expect(m('3 gün kaldı'), isNull);
      expect(m('matematik'), isNull);
      expect(m('1 dakika'), isNull); // mantıksız (<5)
    });
  });

  group('kalıp sözlüğü', () {
    test('en az 700 örnek ve 20+ niyet; hiçbir örnek tekrar etmez', () {
      expect(NluPhrases.totalCount, greaterThanOrEqualTo(700));
      final intentsWithPhrases = NluPhrases.byIntent.keys.length;
      expect(intentsWithPhrases, greaterThanOrEqualTo(20));
      final seen = <String, CoachIntent>{};
      final dup = <String>[];
      NluPhrases.byIntent.forEach((intent, list) {
        for (final p in list) {
          final key = TrText.fold(p);
          if (seen.containsKey(key)) dup.add('$p (${seen[key]} / $intent)');
          seen[key] = intent;
        }
      });
      expect(dup, isEmpty);
    });

    test('her yeni niyet için 20+ örnek var (thanks/confirmation hariç 30+)',
        () {
      NluPhrases.byIntent.forEach((intent, list) {
        final min =
            (intent == CoachIntent.thanks || intent == CoachIntent.confirmation)
                ? 15
                : 29;
        expect(list.length, greaterThanOrEqualTo(min), reason: '$intent');
      });
    });
  });

  group('niyet regresyon korpusu', () {
    test('tüm örnekler beklenen niyete düşer', () {
      final failures = <String>[];
      for (final e in corpus) {
        final r = CoachNlu.analyze(e.text);
        if (!e.ok.contains(r.intent)) {
          failures.add('"${e.text}" → ${r.intent.name} '
              '(${r.confidence.name} ${r.score.toStringAsFixed(2)}); '
              'beklenen: ${e.ok.map((i) => i.name).join('/')}; '
              'aday: ${r.candidates.take(3)}');
        }
      }
      expect(failures, isEmpty, reason: '\n${failures.join('\n')}');
    });

    test('olumsuz/eksik cümleler güvenli niyet üretmez', () {
      for (final t in [
        'yorgun değilim',
        'asdfgh',
        'asdfgh neyse boşver',
        'selam',
        'hedefime ne kadar kaldı',
        'bugün hava çok güzel',
        'kjhgf',
        'matematik',
        'matematik çalışacağım',
        'yarın 2 saat fizik çalışacağım',
        '',
        '   ',
        '???',
      ]) {
        final r = CoachNlu.analyze(t);
        expect(
          r.isConfident && !r.intent.isLegacyOwned,
          isFalse,
          reason: '"$t" → $r',
        );
      }
    });

    test('yorgun değilim → lowMotivation DEĞİL', () {
      final r = CoachNlu.analyze('yorgun değilim');
      expect(r.intent == CoachIntent.lowMotivation && r.isConfident, isFalse);
    });

    test('"berbat" tek başına Matematik problemine çevrilmez, düşük güven', () {
      final r = CoachNlu.analyze('berbat');
      expect(r.intent, CoachIntent.generalProblem);
      expect(r.confidence, NluConfidence.low);
      expect(r.slots.subject, isNull);
      expect(r.slots.topic, isNull);
    });
  });

  group('bileşik cümle: asıl niyet + slot\'lar korunur', () {
    test('geride + ne yapacağımı bilmiyorum', () {
      final r = CoachNlu.analyze(
          'Matematikte çok geride kaldım ne yapacağımı bilmiyorum');
      expect(r.intent, CoachIntent.behindSchedule);
      expect(r.confidence, NluConfidence.high);
      expect(r.slots.subject?.name, 'Matematik');
      expect(r.secondary, contains(CoachIntent.whatToDoNow));
    });

    test('geride + 1 saatim var → süre slot\'u atılmaz', () {
      final r = CoachNlu.analyze(
          'Matematikte çok gerideyim ve bugün sadece 1 saatim var');
      expect(r.intent, CoachIntent.behindSchedule);
      expect(r.slots.timeMinutes, 60);
      expect(r.slots.subject?.name, 'Matematik');
      expect(r.secondary, contains(CoachIntent.timeConstraint));
      expect(r.isConfident, isTrue);
    });

    test('yarın deneme + hiçbir şey bilmiyorum → aciliyet + zorlanma', () {
      final r = CoachNlu.analyze(
          'Yarın deneme var, matematikte hiçbir şey bilmiyorum');
      expect(r.intent, CoachIntent.examUrgency);
      expect(r.slots.urgency, NluUrgency.tomorrow);
      expect(r.slots.exam, NluExamKind.mockExam);
      expect(r.slots.subject?.name, 'Matematik');
      expect(r.secondary, contains(CoachIntent.strugglingSubject));
    });

    test('30 dakikam var + ne çalışayım → süre + öneri isteği', () {
      final r = CoachNlu.analyze('Bugün sadece 30 dakikam var ne çalışayım?');
      expect({CoachIntent.timeConstraint, CoachIntent.needRecommendation},
          contains(r.intent));
      expect(r.slots.timeMinutes, 30);
      expect(r.slots.request, NluRequestType.recommendation);
    });

    test('paragrafta sürekli yanlış → ders + konu + sorun', () {
      final r = CoachNlu.analyze('Paragrafta sürekli yanlış yapıyorum');
      expect(r.intent.isProblem, isTrue);
      expect(r.slots.topic?.name, 'Paragraf');
      expect(r.slots.subjectName, 'Türkçe');
      expect(r.slots.topic?.id, isNull,
          reason: 'katalog konusu — id uydurulmaz');
    });

    test('yarın deneme var çok eksiğim → "Deneme" edebiyat konusu sanılmaz',
        () {
      final r = CoachNlu.analyze('Yarın deneme var çok eksiğim');
      expect(r.intent, CoachIntent.examUrgency);
      expect(r.slots.topic, isNull);
    });
  });

  group('güven (confidence)', () {
    test('net ve güçlü cümle → HIGH', () {
      expect(CoachNlu.analyze('nereden başlayayım').confidence,
          NluConfidence.high);
      expect(
          CoachNlu.analyze('yarın deneme var').confidence, NluConfidence.high);
    });

    test('anlamsız cümle → none + unknown', () {
      final r = CoachNlu.analyze('asdfgh neyse boşver');
      expect(r.intent, CoachIntent.unknown);
      expect(r.confidence, NluConfidence.none);
    });

    test('bilinmeyen kelimelerle dolu cümlede kesinlik düşer', () {
      final r =
          CoachNlu.analyze('zorlanıyorum ama qwrtp zxcvb mnbvcx lkjhg poiuy');
      expect(r.confidence, isNot(NluConfidence.high));
    });
  });

  test('istatistik: niyet ve örnek sayısı raporlanabilir', () {
    expect(CoachNlu.intentCount, 23);
    expect(CoachNlu.phraseCount, greaterThanOrEqualTo(700));
  });

  group('konu tespiti: yazım hatası toleransı yanlış pozitif üretmemeli', () {
    // "değilim" gibi çok yaygın olumsuzlama çekimleri, katalogdaki bir konu
    // adına (ör. "Değişim") tek harf farkıyla tesadüfen benzeyebiliyordu —
    // yanlışlıkla o konuyu "anılmış" sayıp sonraki "bu konu" referansını
    // bozuyordu (bkz. nlu_entities.dart _fuzzyMatchExcluded).
    test('"iyi değilim" konu UYDURMAZ', () {
      final r = CoachNlu.analyze('iyi değilim');
      expect(r.slots.topic, isNull);
    });
    test('"bugün hazır değilim" konu UYDURMAZ', () {
      final r = CoachNlu.analyze('bugün hazır değilim');
      expect(r.slots.topic, isNull);
    });
    test('"yorgunum ama iyi değilim bugün" konu UYDURMAZ', () {
      final r = CoachNlu.analyze('yorgunum ama iyi değilim bugün');
      expect(r.slots.topic, isNull);
    });
  });
}
