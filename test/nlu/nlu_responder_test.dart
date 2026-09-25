import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_planner/deneme_model.dart';
import 'package:study_planner/deneme_provider.dart';
import 'package:study_planner/focus_session_model.dart';
import 'package:study_planner/hive_boxes.dart';
import 'package:study_planner/nlu/nlu_context.dart';
import 'package:study_planner/nlu/nlu_engine.dart';
import 'package:study_planner/nlu/nlu_entities.dart';
import 'package:study_planner/nlu/nlu_models.dart';
import 'package:study_planner/nlu/nlu_responder.dart';
import 'package:study_planner/study_intent.dart';
import 'package:study_planner/subject_provider.dart';
import 'package:study_planner/task_model.dart';
import 'package:study_planner/task_provider.dart';
import 'package:study_planner/topic_provider.dart';

import '../support/hive_memory.dart';

/// NLU cevapları GERÇEK Dodom verisinden (bugünkü plan, konu kanıtı, deneme,
/// ölçülmüş çalışma) çıkar; veri yoksa uydurma yerine bunu söyler.
void main() {
  setUp(openMemoryBoxes);
  tearDown(closeMemoryBoxes);

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  ProviderContainer boot() {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    return c;
  }

  String addSubject(ProviderContainer c, String name) {
    c.read(subjectProvider.notifier).addSubject(name, 0xFF6750A4);
    return c.read(subjectProvider).firstWhere((s) => s.name == name).id;
  }

  String addTopic(ProviderContainer c, String subjectId, String name) {
    c.read(topicProvider.notifier).addTopic(subjectId, name);
    return c
        .read(topicProvider)
        .firstWhere((t) => t.subjectId == subjectId && t.name == name)
        .id;
  }

  TaskModel addTask(
    ProviderContainer c,
    String title,
    String subjectId, {
    int minutes = 25,
    DateTime? due,
    String? topicId,
    TaskPriority priority = TaskPriority.medium,
  }) {
    return c.read(taskProvider.notifier).addTask(
          title: title,
          subjectId: subjectId,
          dueDate: due ?? today,
          estimatedMinutes: minutes,
          topicId: topicId,
          priority: priority,
        );
  }

  Future<void> hardRun(
      String id, String subjectId, String topicId, Duration ago) async {
    await HiveBoxes.focusSessions.put(
      id,
      FocusSession(
        id: id,
        endedAt: DateTime.now().subtract(ago),
        minutes: 25,
        mode: 'serbest',
        subjectId: subjectId,
        topicId: topicId,
        runId: 'run-$id',
        feeling: FocusFeeling.hard,
      ),
    );
  }

  /// Kullanıcının GERÇEK ders/konu adlarıyla NLU + cevap.
  ({NluResult nlu, NluReply? reply}) ask(
    ProviderContainer c,
    String text, {
    String? progressSummary,
    String? goalGap,
  }) {
    final index = NluEntityIndex.build(
      subjects: c.read(subjectProvider),
      topics: c.read(topicProvider),
    );
    final r = CoachNlu.analyze(text, index: index);
    final ctx = NluContext.fromReader(
      c.read,
      progressSummary: progressSummary,
      goalGapSentence: goalGap,
    );
    return (nlu: r, reply: NluResponder.reply(r, ctx));
  }

  group('süre kısıtı → bugünkü planı daralt', () {
    test('30 dk: yalnız sığan görev seçilir, kalan yarına bırakılır', () {
      final c = boot();
      final mat = addSubject(c, 'Matematik');
      final fiz = addSubject(c, 'Fizik');
      final kim = addSubject(c, 'Kimya');
      addTask(c, 'Matematik: Türev', mat, minutes: 25);
      addTask(c, 'Fizik: Optik', fiz, minutes: 25);
      addTask(c, 'Kimya: Mol', kim, minutes: 20);

      final a = ask(c, 'Bugün sadece 30 dakikam var ne çalışayım?');
      final reply = a.reply!;
      expect(a.nlu.slots.timeMinutes, 30);
      expect(reply.text, contains('30 dk'));
      expect(reply.text, contains('daralttım'));
      expect(reply.text, contains('Kalan 2 görev'));
      expect(reply.source, 'today');
      expect(reply.action?.kind, NluActionKind.startFocus);
      final intent = reply.action!.intent!;
      expect(intent.source, StudyIntentSource.task);
      expect(intent.taskId, isNotNull);
      expect(intent.targetMinutes, 25);
    });

    test('süre görevden kısaysa Focus süresi verilen süreyle sınırlanır', () {
      final c = boot();
      final mat = addSubject(c, 'Matematik');
      addTask(c, 'Matematik: Türev', mat, minutes: 45);

      final reply = ask(c, 'sadece 20 dakikam var').reply!;
      expect(reply.action!.intent!.targetMinutes, 20);
      expect(reply.text, contains('20 dk'));
    });

    test('bugün plan yoksa: kanıtlı konu, verilen süreyle önerilir', () {
      final c = boot();
      final mat = addSubject(c, 'Matematik');
      final turev = addTopic(c, mat, 'Türev');
      c.read(denemeProvider.notifier).addEntry(
        examType: 'TYT',
        date: DateTime.now().subtract(const Duration(days: 2)),
        sections: [
          DenemeSectionScore(
              subject: 'Matematik',
              correct: 10,
              wrong: 10,
              weakTopicIds: [turev]),
        ],
      );

      final reply = ask(c, 'Bugün sadece 30 dakikam var ne çalışayım?').reply!;
      expect(reply.text, contains('Türev'));
      expect(reply.text, contains('30 dk'));
      expect(reply.source, anyOf('topicEvidence', 'advisor'));
      final intent = reply.action!.intent!;
      expect(intent.topicId, turev);
      expect(intent.targetMinutes, 30);
    });
  });

  group('sorun cümleleri veriye bağlanır', () {
    test('"Matematikte zorlanıyorum": doğrulanmış zorlanma konusu adıyla',
        () async {
      final c = boot();
      final mat = addSubject(c, 'Matematik');
      final bol = addTopic(c, mat, 'Bölünebilme');
      await hardRun('f1', mat, bol, const Duration(days: 3));
      await hardRun('f2', mat, bol, const Duration(days: 1));

      final reply = ask(c, 'Matematikte zorlanıyorum').reply!;
      expect(reply.text, contains('Bölünebilme'));
      expect(reply.text, contains('üst üste zorlandığını söyledin'));
      expect(reply.action!.intent!.topicId, bol);
      expect(reply.action!.label, 'Başla');
    });

    test(
        'kanıt YOKSA zayıflık uydurmaz; dürüstçe söyler ve küçük başlangıç önerir',
        () {
      final c = boot();
      final mat = addSubject(c, 'Matematik');
      addTopic(c, mat, 'Kümeler');

      final reply = ask(c, 'Matematikte zorlanıyorum').reply!;
      expect(reply.text, contains('henüz bir işaret yok'));
      expect(reply.text, isNot(contains('deneme')));
      expect(reply.action!.intent!.topicId, isNotNull);
      expect(reply.source, 'topic');
    });

    test(
        'konu kaydı hiç yoksa katalogdan konu UYDURULMAZ; konu listesine yönlendirir',
        () {
      final c = boot();
      addSubject(c, 'Matematik');

      final a = ask(c, 'Matematikte zorlanıyorum');
      final reply = a.reply!;
      expect(reply.text, contains('henüz konu eklemedin'));
      expect(reply.action!.kind, NluActionKind.openTopics);
      expect(reply.action!.label, 'Konuya git');
      expect(reply.text, isNot(contains('Türev')));
    });

    test('kullanıcıda olmayan ders → uydurma yerine dürüst yönlendirme', () {
      final c = boot();
      addSubject(c, 'Matematik');
      final reply = ask(c, 'kimyada zorlanıyorum').reply!;
      expect(reply.text, contains('Kimya'));
      expect(reply.text, contains('Derslerim'));
      expect(reply.action, isNull);
    });

    test('"türevde zorlanıyorum" kullanıcının kendi konusuna bağlanır (id ile)',
        () async {
      final c = boot();
      final mat = addSubject(c, 'Matematik');
      final turev = addTopic(c, mat, 'Türev');
      await hardRun('f1', mat, turev, const Duration(hours: 5));

      final a = ask(c, 'türevde zorlanıyorum');
      expect(a.nlu.intent, CoachIntent.strugglingTopic);
      expect(a.nlu.slots.topic?.id, turev);
      expect(a.reply!.action!.intent!.topicId, turev);
      expect(a.reply!.text, contains('Türev'));
    });
  });

  group('geride kalma / çok iş', () {
    test(
        'geciken görev varsa sayısıyla ve adıyla söyler, en kritik olana Başla',
        () {
      final c = boot();
      final mat = addSubject(c, 'Matematik');
      final old = today.subtract(const Duration(days: 4));
      final t1 = addTask(c, 'Matematik: Fonksiyonlar', mat,
          due: old, priority: TaskPriority.high);
      addTask(c, 'Matematik: Diziler', mat,
          due: today.subtract(const Duration(days: 2)));

      final a =
          ask(c, 'Matematikte çok geride kaldım ne yapacağımı bilmiyorum');
      expect(a.nlu.intent, CoachIntent.behindSchedule);
      final reply = a.reply!;
      expect(reply.text, contains('2 görevin geride kalmış'));
      expect(reply.text, contains('Fonksiyonlar'));
      expect(reply.source, 'overdue');
      expect(reply.action!.intent!.taskId, t1.id);
    });

    test('gecikmiş görev YOKSA geride olduğunu iddia etmez', () async {
      final c = boot();
      final mat = addSubject(c, 'Matematik');
      final turev = addTopic(c, mat, 'Türev');
      await hardRun('f1', mat, turev, const Duration(hours: 5));

      final reply = ask(c, 'Matematikte çok geride kaldım').reply!;
      expect(reply.text, contains('gecikmiş görevin görünmüyor'));
      expect(reply.action, isNotNull);
    });

    test('geride + süre: süre Focus hedefine taşınır', () {
      final c = boot();
      final mat = addSubject(c, 'Matematik');
      addTask(c, 'Matematik: Limit', mat,
          due: today.subtract(const Duration(days: 1)), minutes: 90);

      final reply =
          ask(c, 'Matematikte çok gerideyim ve bugün sadece 1 saatim var')
              .reply!;
      expect(reply.action!.intent!.targetMinutes, 60);
    });

    test('çok iş: bugünkü görev sayısı/süresi gerçek, tek görev önerilir', () {
      final c = boot();
      final mat = addSubject(c, 'Matematik');
      for (var i = 1; i <= 4; i++) {
        addTask(c, 'Görev $i', mat, minutes: 30);
      }
      final reply = ask(c, 'çok fazla konu var hepsini yapamam').reply!;
      expect(reply.text, contains('Bugün 4 görevin var'));
      expect(reply.text, contains('2 sa'));
      expect(reply.text, contains('yarına kalabilir'));
      expect(reply.action!.kind, NluActionKind.startFocus);
    });

    test('çok iş ama görev yoksa uydurma yük iddia etmez', () {
      final c = boot();
      addSubject(c, 'Matematik');
      final reply = ask(c, 'çok fazla işim var').reply!;
      expect(reply.text, contains('görünmüyor'));
    });
  });

  group('sınav / deneme', () {
    test(
        '"Yarın deneme var, matematikte hiçbir şey bilmiyorum" → deneme '
        'kanıtı olan konular öne çıkar', () {
      final c = boot();
      final mat = addSubject(c, 'Matematik');
      final turev = addTopic(c, mat, 'Türev');
      addTopic(c, mat, 'Limit');
      c.read(denemeProvider.notifier).addEntry(
        examType: 'TYT',
        date: DateTime.now().subtract(const Duration(days: 3)),
        sections: [
          DenemeSectionScore(
              subject: 'Matematik',
              correct: 12,
              wrong: 8,
              weakTopicIds: [turev]),
        ],
      );

      final a = ask(c, 'Yarın deneme var, matematikte hiçbir şey bilmiyorum');
      expect(a.nlu.intent, CoachIntent.examUrgency);
      final reply = a.reply!;
      expect(reply.text, startsWith('Yarın deneme var.'));
      expect(reply.text, contains('Türev'));
      expect(reply.text, contains('Yeni konuya girme'));
      expect(reply.action!.intent!.topicId, turev);
    });

    test('deneme kaydı yoksa deneme sorununda uydurma net söylemez', () {
      final c = boot();
      addSubject(c, 'Matematik');
      final reply = ask(c, 'denemelerim kötü geçiyor').reply!;
      expect(reply.text, contains('Henüz deneme kaydın yok'));
      expect(reply.action, isNull);
    });

    test('deneme sorununda hedef→fark cümlesi Coach\'tan gelen gerçek cümledir',
        () {
      final c = boot();
      final mat = addSubject(c, 'Matematik');
      final fiz = addSubject(c, 'Fizik');
      final turev = addTopic(c, mat, 'Türev');
      c.read(denemeProvider.notifier).addEntry(
        examType: 'TYT',
        date: DateTime.now().subtract(const Duration(days: 3)),
        sections: [
          DenemeSectionScore(
              subject: 'Matematik',
              correct: 5,
              wrong: 15,
              weakTopicIds: [turev]),
          DenemeSectionScore(subject: 'Fizik', correct: 12, wrong: 2),
        ],
      );
      expect(fiz, isNotEmpty);

      final reply = ask(c, 'denemelerim kötü geçiyor',
              goalGap: 'TYT hedefin 100 net, son sonucun 60 net.')
          .reply!;
      expect(reply.text, contains('en çok net kaybettiğin ders Matematik'));
      expect(reply.text, contains('TYT hedefin 100 net'));
      expect(reply.text, contains('Türev'));
    });
  });

  group('bugün çalışamadım / motivasyon', () {
    test('ölçülmüş çalışma yoksa "henüz kaydın yok" der ve küçük adım önerir',
        () {
      final c = boot();
      final mat = addSubject(c, 'Matematik');
      addTask(c, 'Matematik: Türev', mat, minutes: 40);
      final reply = ask(c, 'Bugün çalışamadım').reply!;
      expect(reply.text, contains('henüz çalışma kaydın yok'));
      expect(reply.action!.intent!.targetMinutes, 15);
    });

    test(
        'bugün gerçekten çalışılmışsa bunu söyler (yalan "hiç çalışmadın" yok)',
        () async {
      final c = boot();
      final mat = addSubject(c, 'Matematik');
      addTask(c, 'Matematik: Türev', mat);
      await HiveBoxes.focusSessions.put(
        's1',
        FocusSession(
          id: 's1',
          endedAt: DateTime.now(),
          minutes: 20,
          mode: 'serbest',
          subjectId: mat,
        ),
      );
      final reply = ask(c, 'Bugün çalışamadım').reply!;
      expect(reply.text, contains('20 dk çalışma kaydın var'));
      expect(reply.text, isNot(contains('henüz çalışma kaydın yok')));
    });

    test('yorgunum → hafif, kısa blok', () {
      final c = boot();
      final mat = addSubject(c, 'Matematik');
      addTask(c, 'Matematik: Türev', mat, minutes: 45);
      final reply = ask(c, 'yorgunum').reply!;
      expect(reply.text, contains('zorlamayalım'));
      expect(reply.action!.intent!.targetMinutes, 15);
    });
  });

  group('diğer', () {
    test('plan isteği mevcut plan akışına devredilir (süre taşınır)', () {
      final c = boot();
      addSubject(c, 'Matematik');
      final a = ask(c, 'bana 2 saatlik bir plan yap');
      expect(a.nlu.intent, CoachIntent.needPlan);
      expect(a.reply!.action!.kind, NluActionKind.planDay);
      expect(a.reply!.action!.minutes, 120);
      expect(a.reply!.action!.week, isFalse);
    });

    test('"bu hafta için program yap" → haftalık', () {
      final c = boot();
      addSubject(c, 'Matematik');
      final a = ask(c, 'bu hafta için program yap');
      expect(a.reply!.action!.kind, NluActionKind.planDay);
      expect(a.reply!.action!.week, isTrue);
    });

    test('ders hiç yoksa yönlendirir', () {
      final c = boot();
      final reply = ask(c, 'ne çalışayım').reply!;
      expect(reply.text, contains('en az bir ders eklemen'));
    });

    test('teşekkür/onay/bilinmeyen: NLU cevap üretmez (eski zincir devralır)',
        () {
      final c = boot();
      addSubject(c, 'Matematik');
      expect(ask(c, 'teşekkürler').reply, isNull);
      expect(ask(c, 'tamam').reply, isNull);
      expect(ask(c, 'asdfgh').reply, isNull);
    });

    test('düşük güvenli sorun → kesin konuşmayan açıklama isteği', () {
      final c = boot();
      addSubject(c, 'Matematik');
      final a = ask(c, 'berbat');
      expect(a.nlu.confidence, NluConfidence.low);
      final text = NluResponder.clarify(a.nlu);
      expect(text, contains('oturtamadım'));
      expect(text, isNot(contains('Matematik')));
    });

    test('ilerleme kaygısı Coach\'un gerçek ilerleme özetini kullanır', () {
      final c = boot();
      addSubject(c, 'Matematik');
      final reply =
          ask(c, 'yerimde sayıyorum', progressSummary: '3 günlük serin var.')
              .reply!;
      expect(reply.text, contains('3 günlük serin var.'));
    });

    test('deterministik: aynı veri + aynı cümle → aynı cevap', () {
      final c = boot();
      final mat = addSubject(c, 'Matematik');
      addTask(c, 'Matematik: Türev', mat);
      final a = ask(c, 'ne çalışayım').reply!;
      final b = ask(c, 'ne çalışayım').reply!;
      expect(a.text, b.text);
    });

    test('bağlam sürekliliği: "bu konu" önceki mesajdaki konuya bağlanır', () {
      final c = boot();
      final mat = addSubject(c, 'Matematik');
      final turev = addTopic(c, mat, 'Türev');
      final index = NluEntityIndex.build(
        subjects: c.read(subjectProvider),
        topics: c.read(topicProvider),
      );
      final first = CoachNlu.analyze('türevde zorlanıyorum', index: index);
      final follow = CoachNlu.analyze('bu konuyu nasıl çalışayım',
          index: index, previous: first.slots);
      expect(follow.slots.topic?.id, turev);
      expect(follow.intent, CoachIntent.topicGuidance);

      final noContext =
          CoachNlu.analyze('bu konuyu nasıl çalışayım', index: index);
      expect(noContext.slots.topic, isNull);
    });
  });
}
