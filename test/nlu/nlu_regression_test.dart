import 'package:flutter_test/flutter_test.dart';
import 'package:study_planner/nlu/nlu_engine.dart';

/// Kalıp sözlüğünden BAĞIMSIZ yazılmış (held-out) gerçekçi öğrenci cümleleri.
/// Değer: kabul edilen niyetler `|` ile. `unknown` kabul listesindeyse cümlenin
/// güvenle (orta/yüksek) bir niyete BAĞLANMAMASI da doğru sayılır.
const heldOut = <String, String>{
  'abi ben ne çalışacağım bugün': 'needRecommendation|whatToDoNow',
  'bugün hangi konuya bakayım': 'needRecommendation|whatToDoNow|topicGuidance',
  'hocam bugün neye odaklanayım': 'whatToDoNow|needRecommendation',
  'çalışmaya nerden başlamam gerek': 'needStartPoint',
  'sıfırdan başlıyorum nasıl bir yol izleyeyim':
      'needStartPoint|needRecommendation',
  'bana haftalık çalışma programı yapar mısın': 'needPlan',
  'yarına plan çıkar': 'needPlan',
  'matematik çalışıcam ne çalışayım': 'subjectGuidance|needRecommendation',
  'fizikte nereden başlasam': 'needStartPoint|subjectGuidance',
  'kimyada zorlanıyorum ne yapmalıyım': 'strugglingSubject',
  'biyolojiyi hiç anlamıyorum': 'strugglingSubject',
  'türkçe paragraflarda çok zorlanıyorum':
      'strugglingTopic|questionPerformanceProblem|strugglingSubject',
  'geometri çok zor abi': 'strugglingSubject',
  'tarih ezberleyemiyorum': 'strugglingSubject',
  'polinomlar hiç girmiyor kafama': 'strugglingTopic|strugglingSubject',
  'trigonometride yanlış yapıyorum sürekli':
      'questionPerformanceProblem|strugglingTopic',
  'soruları yetiştiremiyorum süre bitiyor': 'questionPerformanceProblem',
  'denemede netlerim çok düşük geldi': 'mockExamProblem',
  'deneme sonuçlarım hiç iyi değil': 'mockExamProblem',
  'denemelerde matematik yapamıyorum': 'mockExamProblem',
  'yarın matematik yazılım var': 'examUrgency',
  'yarın sınavım var hiç hazırlanmadım': 'examUrgency',
  'deneme sınavı bu hafta sonu': 'examUrgency',
  'sınava 10 gün kaldı': 'examUrgency',
  'çalışma programımın çok gerisindeyim': 'behindSchedule',
  'hiç yetişemiyorum artık': 'behindSchedule',
  'geçen haftaki konuları bitiremedim': 'behindSchedule|tooMuchWork',
  'ders çok fazla nasıl yetişeceğim': 'tooMuchWork|behindSchedule',
  'çok yoğunum hiç vaktim yok': 'tooMuchWork|timeConstraint',
  'bugün hiç çalışmadım': 'lowProgress',
  'dünden beri hiçbir şey yapmadım': 'lowProgress',
  'bugün zar zor 10 dk çalıştım': 'lowProgress|positiveProgress|unknown',
  'çalışmak istemiyorum bugün': 'lowMotivation',
  'çok yorgunum bugün çalışamayacağım': 'lowMotivation|lowProgress',
  'kendimi hiç motive edemiyorum': 'lowMotivation',
  'moralim çok bozuk': 'lowMotivation',
  'hevesim kalmadı': 'lowMotivation',
  'ne kadar çalışsam da netlerim artmıyor': 'progressConcern|mockExamProblem',
  'gelişme göremiyorum': 'progressConcern',
  'hedefime ulaşabilir miyim': 'progressConcern',
  'harika bir gün geçirdim çok çalıştım': 'positiveProgress',
  'sonunda türevi anladım': 'positiveProgress',
  'çok teşekkür ederim': 'thanks',
  'sağolun': 'thanks',
  'peki': 'confirmation',
  '20 dakikam var': 'timeConstraint',
  'iki saatim var bugün': 'timeConstraint',
  // Plan beyanı (kısıt değil): eski PlanParser akışı devralır.
  'yarım saat çalışacağım': 'unknown',
  'çok az vaktim kaldı': 'timeConstraint',
  'bugün sadece 1 saat çalışabilirim ne yapayım':
      'timeConstraint|needRecommendation|whatToDoNow',
  'odak modunu başlat': 'studySessionRequest',
  'şimdi çalışmaya başlıyorum': 'studySessionRequest',
  'zorlanıyorum ama devam edeceğim': 'strugglingSubject',
  'matematik iyi gidiyor': 'positiveProgress',
  'çok kötüyüm': 'generalProblem',
  'bir sorunum var': 'generalProblem',
  'yardım et': 'generalProblem|unknown',
  'ne yapacağımı bilmiyorum': 'whatToDoNow',
  'bugün ne var': 'whatToDoNow',
  'ders çalışmak zor geliyor': 'strugglingSubject|lowMotivation',
  'çalışırken telefona bakıyorum odaklanamıyorum': 'lowProgress',
  'bunaldım artık': 'tooMuchWork|lowMotivation',
  'çok stresliyim': 'unknown|generalProblem|lowMotivation',
  'nasılsın': 'unknown',
  'merhaba': 'unknown',
  'ben kimim': 'unknown',
  'hava çok güzel': 'unknown',
  'pizza yemek istiyorum': 'unknown',
  'napıyon': 'unknown',
  'sen kimsin': 'unknown',
  'planım yok': 'unknown|needPlan',
  'planımı yapamadım': 'behindSchedule',
  'matematiğe çalıştım': 'positiveProgress|unknown',
  'ders çalışmayı sevmiyorum': 'lowMotivation',
  'çalışmaya başlayamıyorum': 'lowProgress|lowMotivation|studySessionRequest',
  'hiçbir şey öğrenemiyorum': 'strugglingSubject|lowProgress|progressConcern',
};

void main() {
  test('held-out Türkçe öğrenci cümleleri doğru niyete düşer', () {
    final bad = <String>[];
    heldOut.forEach((text, ok) {
      final r = CoachNlu.analyze(text);
      final allowed = ok.split('|');
      final confidentIntent = r.isConfident && !r.intent.isLegacyOwned;
      final okUnknown = allowed.contains('unknown') && !confidentIntent;
      if (!allowed.contains(r.intent.name) && !okUnknown) {
        bad.add('"$text" → ${r.intent.name} ${r.confidence.name} '
            '${r.score.toStringAsFixed(2)} ${r.candidates.take(3)} (beklenen $ok)');
      }
    });
    expect(bad, isEmpty, reason: bad.join(String.fromCharCode(10)));
  });

  test('held-out cümlelerin çoğu yüksek güvenle sınıflanır', () {
    var high = 0;
    for (final text in heldOut.keys) {
      if (CoachNlu.analyze(text).confidence.name == 'high') high++;
    }
    expect(high, greaterThan(heldOut.length ~/ 2));
  });
}
