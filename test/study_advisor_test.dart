import 'package:flutter_test/flutter_test.dart';
import 'package:study_planner/study_advisor.dart';
import 'package:study_planner/subject_model.dart';
import 'package:study_planner/task_model.dart';

SubjectModel _sub(String name, {DateTime? created}) => SubjectModel(
      id: 'id-$name',
      name: name,
      colorValue: 0,
      createdAt: created ?? DateTime(2026, 1, 1),
    );

TaskModel _task(
  String subjectId, {
  required DateTime due,
  bool completed = false,
  TaskPriority priority = TaskPriority.medium,
  int postponeCount = 0,
}) =>
    TaskModel(
      id: 'task-$subjectId-${due.millisecondsSinceEpoch}-$completed-$postponeCount',
      title: 't',
      subjectId: subjectId,
      dueDate: due,
      isCompleted: completed,
      priority: priority,
      createdAt: DateTime(2026, 1, 1),
      postponeCount: postponeCount,
    );

void main() {
  final now = DateTime(2026, 9, 10, 12);
  final today = DateTime(2026, 9, 10);

  test('ders yoksa boş liste', () {
    expect(
      StudyAdvisor.suggest(subjects: const [], tasks: const [], now: now),
      isEmpty,
    );
  });

  test('bugün zaten görevi olan ders önerilmez', () {
    final subjects = [_sub('Matematik')];
    final tasks = [_task('id-Matematik', due: today)];
    final out = StudyAdvisor.suggest(subjects: subjects, tasks: tasks, now: now);
    expect(out, isEmpty);
  });

  test('uzun süredir dokunulmayan ders üste çıkar', () {
    final subjects = [_sub('Matematik'), _sub('Fizik')];
    final tasks = [
      _task('id-Matematik', due: today.subtract(const Duration(days: 1))),
      _task('id-Fizik', due: today.subtract(const Duration(days: 20))),
    ];
    final out = StudyAdvisor.suggest(subjects: subjects, tasks: tasks, now: now);
    expect(out.first.subjectName, 'Fizik');
    expect(out.first.reason, contains('gündür dokunmadın'));
  });

  test('hiç görevi olmayan ders "henüz hiç görev" gerekçesi alır', () {
    final subjects = [_sub('Kimya', created: today.subtract(const Duration(days: 3)))];
    final out = StudyAdvisor.suggest(subjects: subjects, tasks: const [], now: now);
    expect(out, isNotEmpty);
    expect(out.first.reason, 'Henüz hiç görev eklemedin');
  });

  test('bekleyen yüksek öncelikli görev gerekçesi', () {
    final subjects = [_sub('Fizik')];
    final tasks = [
      _task('id-Fizik',
          due: today.subtract(const Duration(days: 1)),
          priority: TaskPriority.high),
    ];
    final out = StudyAdvisor.suggest(subjects: subjects, tasks: tasks, now: now);
    expect(out.first.reason, 'Bekleyen öncelikli görevin var');
  });

  test('kronik ertelenen görev (2+) "kaçınma" gerekçesiyle öne çıkar', () {
    final subjects = [_sub('Fizik'), _sub('Kimya')];
    final tasks = [
      // Fizik: 3 kez ertelenmiş, hâlâ tamamlanmamış — kaçınma sinyali.
      _task('id-Fizik',
          due: today.subtract(const Duration(days: 1)), postponeCount: 3),
      // Kimya: hiç ertelenmemiş, sadece biraz ihmal edilmiş — kıyas için.
      _task('id-Kimya',
          due: today.subtract(const Duration(days: 1)), postponeCount: 0),
    ];
    final out = StudyAdvisor.suggest(subjects: subjects, tasks: tasks, now: now);
    expect(out.first.subjectName, 'Fizik');
    expect(out.first.reason, '3 kez ertelendi — bugün küçük bir adım atalım mı?');
  });

  test('tek erteleme (postponeCount==1) kaçınma sayılmaz', () {
    final subjects = [_sub('Fizik')];
    final tasks = [
      _task('id-Fizik',
          due: today.subtract(const Duration(days: 1)), postponeCount: 1),
    ];
    final out = StudyAdvisor.suggest(subjects: subjects, tasks: tasks, now: now);
    expect(out.first.reason, isNot(contains('ertelendi')));
  });

  test('düşük konu kapsaması olan ders öne çıkar + gerekçe', () {
    final subjects = [_sub('Matematik'), _sub('Fizik')];
    // İkisi de aynı gün dokunulmuş; fark yalnız kapsama.
    final tasks = [
      _task('id-Matematik', due: today.subtract(const Duration(days: 2))),
      _task('id-Fizik', due: today.subtract(const Duration(days: 2))),
    ];
    final out = StudyAdvisor.suggest(
      subjects: subjects,
      tasks: tasks,
      now: now,
      coveragePercent: {'id-Matematik': 0.9, 'id-Fizik': 0.1},
    );
    expect(out.first.subjectName, 'Fizik');
    expect(out.first.reason, contains('işaretli'));
  });

  test('deneme netinde en zayıf ders öne çıkar + gerekçe', () {
    final subjects = [_sub('Matematik'), _sub('Fizik')];
    final tasks = [
      _task('id-Matematik', due: today.subtract(const Duration(days: 2))),
      _task('id-Fizik', due: today.subtract(const Duration(days: 2))),
    ];
    final out = StudyAdvisor.suggest(
      subjects: subjects,
      tasks: tasks,
      now: now,
      weakestDenemeSubjectId: 'id-Fizik',
    );
    expect(out.first.subjectName, 'Fizik');
    expect(out.first.reason, contains('zayıf'));
  });

  test('hiç odak yapılmamış ders (odak kullanılıyorsa) öne çıkar + gerekçe',
      () {
    final subjects = [_sub('Matematik'), _sub('Fizik')];
    // İkisi de aynı gün dokunulmuş; fark yalnız odak dakikası.
    final tasks = [
      _task('id-Matematik', due: today.subtract(const Duration(days: 2))),
      _task('id-Fizik', due: today.subtract(const Duration(days: 2))),
    ];
    final out = StudyAdvisor.suggest(
      subjects: subjects,
      tasks: tasks,
      now: now,
      focusMinutesBySubject: {'id-Matematik': 120, 'id-Fizik': 0},
    );
    expect(out.first.subjectName, 'Fizik');
    expect(out.first.reason, 'Bu derse hiç odak seansı ayırmadın');
  });

  test('kullanıcı hiç odak seansı kullanmamışsa kimse cezalandırılmaz', () {
    final subjects = [_sub('Matematik'), _sub('Fizik')];
    final tasks = [
      _task('id-Matematik', due: today.subtract(const Duration(days: 2))),
      _task('id-Fizik', due: today.subtract(const Duration(days: 2))),
    ];
    final withoutFocusMap = StudyAdvisor.suggest(
      subjects: subjects,
      tasks: tasks,
      now: now,
    );
    final withEmptyFocusMap = StudyAdvisor.suggest(
      subjects: subjects,
      tasks: tasks,
      now: now,
      focusMinutesBySubject: {'id-Matematik': 0, 'id-Fizik': 0},
    );
    expect(
      withEmptyFocusMap.map((s) => s.score),
      withoutFocusMap.map((s) => s.score),
    );
  });

  test('limit uygulanır', () {
    final subjects = List.generate(
      6,
      (i) => _sub('D$i', created: today.subtract(Duration(days: 10 + i))),
    );
    final out = StudyAdvisor.suggest(
        subjects: subjects, tasks: const [], now: now, limit: 3);
    expect(out.length, 3);
  });

  test('sıralama deterministik (eşit puanda ada göre)', () {
    final subjects = [
      _sub('Zebra', created: today.subtract(const Duration(days: 10))),
      _sub('Adana', created: today.subtract(const Duration(days: 10))),
    ];
    final a = StudyAdvisor.suggest(subjects: subjects, tasks: const [], now: now);
    final b = StudyAdvisor.suggest(
        subjects: subjects.reversed.toList(), tasks: const [], now: now);
    expect(a.map((s) => s.subjectName), b.map((s) => s.subjectName));
    expect(a.first.subjectName, 'Adana');
  });

  test('kendi bildirdiği zayıf ders — hesaplanmış sinyal yokken devreye girer',
      () {
    final subjects = [_sub('Matematik'), _sub('Fizik')];
    final tasks = [
      _task('id-Matematik', due: today.subtract(const Duration(days: 2))),
      _task('id-Fizik', due: today.subtract(const Duration(days: 2))),
    ];
    final out = StudyAdvisor.suggest(
      subjects: subjects,
      tasks: tasks,
      now: now,
      selfReportedWeakSubjectId: 'id-Fizik',
    );
    expect(out.first.subjectName, 'Fizik');
    expect(out.first.reason, 'Kendin de bu derste zorlandığını söylemiştin');
  });

  test('kendi bildirilen zayıflık, hesaplanmış deneme gerilemesini geçemez',
      () {
    final subjects = [_sub('Matematik'), _sub('Fizik')];
    final tasks = [
      _task('id-Matematik', due: today.subtract(const Duration(days: 2))),
      _task('id-Fizik', due: today.subtract(const Duration(days: 2))),
    ];
    final out = StudyAdvisor.suggest(
      subjects: subjects,
      tasks: tasks,
      now: now,
      selfReportedWeakSubjectId: 'id-Matematik',
      worseningDenemeSubjectIds: {'id-Fizik'},
    );
    expect(out.first.subjectName, 'Fizik');
  });

  test('denemede yanlış yapılan konu gerekçede geçer', () {
    final subjects = [_sub('Matematik')];
    final tasks = [
      _task('id-Matematik', due: today.subtract(const Duration(days: 2))),
    ];
    final out = StudyAdvisor.suggest(
      subjects: subjects,
      tasks: tasks,
      now: now,
      examWeakTopicsBySubject: {
        'id-Matematik': ['Türev'],
      },
    );
    expect(out.first.reason, '"Türev" konusunda denemede yanlış yapmıştın');
  });

  test('deneme sonucu (gerçek kanıt), davranışsal zor-konu sinyalinden önce gelir',
      () {
    final subjects = [_sub('Matematik'), _sub('Fizik')];
    final tasks = [
      _task('id-Matematik', due: today.subtract(const Duration(days: 2))),
      _task('id-Fizik', due: today.subtract(const Duration(days: 2))),
    ];
    final out = StudyAdvisor.suggest(
      subjects: subjects,
      tasks: tasks,
      now: now,
      // Fizik: yalnızca davranışsal (süre) sinyali. Matematik: GERÇEK
      // deneme kanıtı. İkisi ayrı sinyal — deneme kanıtı ağır basmalı.
      difficultTopicsBySubject: {
        'id-Fizik': ['Elektrik'],
      },
      examWeakTopicsBySubject: {
        'id-Matematik': ['Türev'],
      },
    );
    expect(out.first.subjectName, 'Matematik');
    expect(out.first.reason, contains('denemede yanlış yapmıştın'));
  });

  test('zor çıkan konu adı gerekçede geçer', () {
    final subjects = [_sub('Matematik')];
    final tasks = [
      _task('id-Matematik', due: today.subtract(const Duration(days: 2))),
    ];
    final out = StudyAdvisor.suggest(
      subjects: subjects,
      tasks: tasks,
      now: now,
      difficultTopicsBySubject: {
        'id-Matematik': ['Türev'],
      },
    );
    expect(out.first.reason, '"Türev" konusu tahmininden çok daha uzun sürdü');
  });

  test('deneme netleri gerileyen ders "en zayıf"ten önce gelir + gerekçe', () {
    final subjects = [_sub('Matematik'), _sub('Fizik')];
    final tasks = [
      _task('id-Matematik', due: today.subtract(const Duration(days: 2))),
      _task('id-Fizik', due: today.subtract(const Duration(days: 2))),
    ];
    final out = StudyAdvisor.suggest(
      subjects: subjects,
      tasks: tasks,
      now: now,
      weakestDenemeSubjectId: 'id-Matematik',
      worseningDenemeSubjectIds: {'id-Fizik'},
    );
    expect(out.first.subjectName, 'Fizik');
    expect(out.first.reason, 'Deneme netlerin bu derste geriliyor');
  });

  test('tekrar zamanı geçmiş konusu olan ders öne çıkar + gerekçe', () {
    final subjects = [_sub('Matematik'), _sub('Fizik')];
    final tasks = [
      _task('id-Matematik', due: today.subtract(const Duration(days: 2))),
      _task('id-Fizik', due: today.subtract(const Duration(days: 2))),
    ];
    final out = StudyAdvisor.suggest(
      subjects: subjects,
      tasks: tasks,
      now: now,
      staleReviewSubjectIds: {'id-Fizik'},
    );
    expect(out.first.subjectName, 'Fizik');
    expect(out.first.reason, contains('Tekrar ettiğin'));
  });

  group('sistem-yeniden-planlama kaçınma sinyalini kirletmez (Faz 8)', () {
    test('yüksek systemRescheduleCount, postponeCount sıfırken kaçınma tetiklemez',
        () {
      final subjects = [_sub('Matematik')];
      final tasks = [
        TaskModel(
          id: 't1',
          title: 't',
          subjectId: 'id-Matematik',
          dueDate: today.subtract(const Duration(days: 1)),
          createdAt: DateTime(2026, 1, 1),
          postponeCount: 0,
          systemRescheduleCount: 5,
        ),
      ];
      final out = StudyAdvisor.suggest(subjects: subjects, tasks: tasks, now: now);
      expect(out, isNotEmpty);
      expect(out.first.reason, isNot(contains('ertelendi')));
    });

    test('gerçek (manuel) postponeCount 2+ ise kaçınma tetiklenir', () {
      final subjects = [_sub('Matematik')];
      final tasks = [
        TaskModel(
          id: 't1',
          title: 't',
          subjectId: 'id-Matematik',
          dueDate: today.subtract(const Duration(days: 1)),
          createdAt: DateTime(2026, 1, 1),
          postponeCount: 2,
          systemRescheduleCount: 0,
        ),
      ];
      final out = StudyAdvisor.suggest(subjects: subjects, tasks: tasks, now: now);
      expect(out.first.reason, contains('ertelendi'));
    });
  });

  group('goalGapAmplifier (Faz 3)', () {
    test(
        'zaten zayıf işaretli ders, hedef aciliyeti eklenince daha da öne çıkar',
        () {
      final subjects = [_sub('Matematik'), _sub('Fizik')];
      final tasks = [
        _task('id-Matematik', due: today.subtract(const Duration(days: 2))),
        _task('id-Fizik', due: today.subtract(const Duration(days: 2))),
      ];
      final withoutGap = StudyAdvisor.suggest(
        subjects: subjects,
        tasks: tasks,
        now: now,
        worseningDenemeSubjectIds: {'id-Matematik'},
      );
      final withGap = StudyAdvisor.suggest(
        subjects: subjects,
        tasks: tasks,
        now: now,
        worseningDenemeSubjectIds: {'id-Matematik'},
        goalGapAmplifier: 1.0,
      );
      final matScoreWithout =
          withoutGap.firstWhere((s) => s.subjectId == 'id-Matematik').score;
      final matScoreWith =
          withGap.firstWhere((s) => s.subjectId == 'id-Matematik').score;
      expect(matScoreWith, greaterThan(matScoreWithout));
    });

    test(
        'gerçek zayıflık kanıtı olmayan (güçlü/nötr) bir ders, yalnızca hedef '
        'farkı yüzünden yapay olarak öne çıkmaz', () {
      final subjects = [_sub('Matematik'), _sub('Fizik')];
      final tasks = [
        _task('id-Matematik', due: today.subtract(const Duration(days: 2))),
        _task('id-Fizik', due: today.subtract(const Duration(days: 2))),
      ];
      final withoutGap = StudyAdvisor.suggest(
        subjects: subjects,
        tasks: tasks,
        now: now,
      );
      final withGap = StudyAdvisor.suggest(
        subjects: subjects,
        tasks: tasks,
        now: now,
        goalGapAmplifier: 1.0,
      );
      // Hiçbirinin gerçek bir zayıflık kanıtı yok — amplifikatör puanları
      // DEĞİŞTİRMEZ.
      expect(
        withGap.map((s) => s.score).toList(),
        withoutGap.map((s) => s.score).toList(),
      );
    });

    test('gerçek deneme-zayıf konusu, jenerik hedef aciliyetini her zaman geçer',
        () {
      final subjects = [_sub('Matematik'), _sub('Fizik')];
      final tasks = [
        _task('id-Matematik', due: today.subtract(const Duration(days: 2))),
        _task('id-Fizik', due: today.subtract(const Duration(days: 2))),
      ];
      final out = StudyAdvisor.suggest(
        subjects: subjects,
        tasks: tasks,
        now: now,
        // Fizik yalnızca hedef-aciliyeti sinyaline sahip olsa da (ki
        // burada hiçbir gerçek kanıtı yok, bu yüzden amplifikatör onu bile
        // etkilemez), Matematik'in GERÇEK deneme kanıtı her zaman kazanır.
        examWeakTopicsBySubject: {
          'id-Matematik': ['Türev'],
        },
        goalGapAmplifier: 1.0,
      );
      expect(out.first.subjectId, 'id-Matematik');
    });
  });

  group('completionRateBySubject', () {
    test('≥minTasks görevi olan dersler için oran döner', () {
      final subjects = [_sub('Fizik')];
      final tasks = [
        _task('id-Fizik', due: today, completed: true),
        _task('id-Fizik', due: today, completed: true),
        _task('id-Fizik', due: today, completed: false),
        _task('id-Fizik', due: today, completed: false),
      ];
      final rates = StudyAdvisor.completionRateBySubject(
          subjects: subjects, tasks: tasks);
      expect(rates['id-Fizik'], 0.5);
    });

    test('minTasks altında dersler haritada yer almaz', () {
      final subjects = [_sub('Fizik')];
      final tasks = [
        _task('id-Fizik', due: today, completed: true),
        _task('id-Fizik', due: today, completed: false),
      ];
      final rates = StudyAdvisor.completionRateBySubject(
          subjects: subjects, tasks: tasks);
      expect(rates.containsKey('id-Fizik'), isFalse);
    });
  });

  group('overcommittedSubjectIds', () {
    test('3+ görev, tamamlama <%50 → işaretlenir', () {
      final subjects = [_sub('Fizik')];
      final tasks = [
        _task('id-Fizik', due: today, completed: true),
        _task('id-Fizik', due: today, completed: false),
        _task('id-Fizik', due: today, completed: false),
        _task('id-Fizik', due: today, completed: false),
      ];
      final ids = StudyAdvisor.overcommittedSubjectIds(
          subjects: subjects, tasks: tasks);
      expect(ids, {'id-Fizik'});
    });

    test('3 görevden az → işaretlenmez (örneklem küçük)', () {
      final subjects = [_sub('Fizik')];
      final tasks = [
        _task('id-Fizik', due: today, completed: false),
        _task('id-Fizik', due: today, completed: false),
      ];
      final ids = StudyAdvisor.overcommittedSubjectIds(
          subjects: subjects, tasks: tasks);
      expect(ids, isEmpty);
    });

    test('tamamlama oranı yeterince yüksekse işaretlenmez', () {
      final subjects = [_sub('Fizik')];
      final tasks = [
        _task('id-Fizik', due: today, completed: true),
        _task('id-Fizik', due: today, completed: true),
        _task('id-Fizik', due: today, completed: false),
      ];
      final ids = StudyAdvisor.overcommittedSubjectIds(
          subjects: subjects, tasks: tasks);
      expect(ids, isEmpty);
    });
  });
}
