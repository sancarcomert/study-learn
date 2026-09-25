import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'day_rollover.dart';

import 'task_model.dart';
import 'task_repository.dart';
import 'stats_provider.dart';
import 'notification_service.dart';
import 'rank_system.dart';
import 'focus_session_provider.dart';
import 'topic_progress.dart';
import 'topic_provider.dart';

const _uuidTask = Uuid();

/// `updateTask`'ın `topicId` parametresi için sentinel — "geçilmedi" (mevcut
/// bağı koru) ile "açıkça null geçildi" (bağı kaldır) arasını ayırt eder.
const Object _unset = Object();

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepository();
});

final taskCompletionEventProvider = StateProvider<int>((ref) => 0);
final goalReachedEventProvider = StateProvider<int>((ref) => 0);

// taskCompletionEventProvider yalnız "bir şey tamamlandı" sinyali — hangi
// görev olduğunu taşımıyor. Tamamlanma bildirimi bunun ÖTESİNDE anlamlı
// olsun (hangi ders, bu hafta kaçıncı oturum, sırada ne var) diye asıl
// görevi de ayrıca tutuyoruz. Yalnız tamamlanmada set edilir, geri
// alınmada dokunulmaz (bildirim zaten sadece tamamlanmada gösteriliyor).
final lastCompletedTaskProvider = StateProvider<TaskModel?>((ref) => null);


class TaskNotifier extends StateNotifier<List<TaskModel>> {
  final TaskRepository _repository;
  final Ref _ref;

  TaskNotifier(this._repository, this._ref)
      : super(_repository.getAllTasks());


  Future<void> _scheduleReminder(TaskModel task) async {
    if (task.scheduledTime == null || task.isCompleted) return;

    // Sadece görevin kendi verisiyle (süre) — ek provider bağımlılığı
    // eklemeden kuru "Görev zamanı geldi" yerine biraz daha somut bir metin.
    final minutes = task.estimatedMinutes;
    final body = (minutes != null && minutes > 0)
        ? '$minutes dakikalık vaktin geldi. Hazır mısın?'
        : 'Vaktin geldi. Hazır mısın?';

    // Hatırlatma "en iyi çaba": zamanlayıcı hata verirse görev yine kaydedilmiş
    // kalır ve hata yakalanmamış bir asenkron istisnaya dönüşmez.
    try {
      await NotificationService.instance.scheduleNotification(
        id: task.id,
        category: NotificationCategory.taskReminder,
        title: task.title,
        body: body,
        dateTime: task.scheduledTime!,
      );
    } catch (_) {}
  }

  Future<void> _cancelReminder(String taskId) async {
    try {
      await NotificationService.instance.cancelNotification(
        taskId,
        NotificationCategory.taskReminder,
      );
    } catch (_) {}
  }


  // Dönüş değeri: eklenen görev — koç ekranının "Şimdi başla" gibi
  // akışlarının, az önce hangi görevin eklendiğini (id'siyle) bilmesi
  // gerekiyor (Odak seansını o göreve bağlamak için). Önceden void'di,
  // çağıran taraf ismi/tarihiyle tekrar arama yapmak zorunda kalıyordu.
  TaskModel addTask({
    required String title,
    String? subjectId,
    required DateTime dueDate,
    TaskPriority priority = TaskPriority.medium,
    TopicDifficulty difficulty = TopicDifficulty.medium,
    DateTime? scheduledTime,
    int? estimatedMinutes,
    String? topicId,
    String? sourceReason,
  }) {
    final newTask = TaskModel(
      id: _uuidTask.v4(),
      title: title,
      subjectId: subjectId,
      dueDate: dueDate,
      priority: priority,
      difficulty: difficulty,
      createdAt: DateTime.now(),
      scheduledTime: scheduledTime,
      estimatedMinutes: estimatedMinutes,
      topicId: topicId,
      sourceReason: sourceReason,
    );

    _repository.addTask(newTask);
    state = [..._repository.getAllTasks()];

    _scheduleReminder(newTask);
    return newTask;
  }


  // Tekrarlayan görev — V1: sadece "daily" ve "weekly" destekleniyor.
  // Her tekrar, bağımsız bir TaskModel kaydı olarak üretilir (sanal
  // genişletme değil) — bu sayede tamamlama, düzenleme, silme, bildirim
  // gibi mevcut hiçbir mekanizma değişmeden çalışmaya devam eder.
  // Seri düzenleme/silme V1 kapsamı dışıdır; recurringGroupId sadece
  // ileride bu amaçla kullanılmak üzere kaydediliyor.
  void addRecurringTask({
    required String title,
    String? subjectId,
    required DateTime startDate,
    required String recurrenceRule, // "daily" veya "weekly"
    TaskPriority priority = TaskPriority.medium,
    TopicDifficulty difficulty = TopicDifficulty.medium,
    TimeOfDay? scheduledTimeOfDay,
    int? estimatedMinutes,
    String? topicId,
    String? sourceReason,
  }) {
    final groupId = _uuidTask.v4();

    final int occurrenceCount;
    final int stepDays;

    if (recurrenceRule == 'weekly') {
      occurrenceCount = 12;
      stepDays = 7;
    } else {
      // "daily"
      occurrenceCount = 30;
      stepDays = 1;
    }

    final newTasks = <TaskModel>[];

    for (int i = 0; i < occurrenceCount; i++) {
      final occurrenceDate = startDate.add(Duration(days: stepDays * i));

      final scheduledTime = scheduledTimeOfDay == null
          ? null
          : DateTime(
              occurrenceDate.year,
              occurrenceDate.month,
              occurrenceDate.day,
              scheduledTimeOfDay.hour,
              scheduledTimeOfDay.minute,
            );

      newTasks.add(
        TaskModel(
          id: _uuidTask.v4(),
          title: title,
          subjectId: subjectId,
          dueDate: occurrenceDate,
          priority: priority,
          difficulty: difficulty,
          createdAt: DateTime.now(),
          scheduledTime: scheduledTime,
          estimatedMinutes: estimatedMinutes,
          recurringGroupId: groupId,
          recurrenceRule: recurrenceRule,
          topicId: topicId,
          sourceReason: sourceReason,
        ),
      );
    }

    for (final task in newTasks) {
      _repository.addTask(task);
    }

    state = [..._repository.getAllTasks()];

    for (final task in newTasks) {
      _scheduleReminder(task);
    }
  }


  bool _isToday(DateTime date) {
    final now = DateTime.now();

    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }


  /// Görevi tamamla/geri al (aç-kapa). Tamamlama bir GERÇEK-DÜNYA OLAYIDIR:
  /// hedef/seri/XP güncellenir ve göreve bağlı konuya bir çalışma olayı
  /// kaydedilir — aşağıdaki kurala göre.
  ///
  /// Konu ilerlemesi (bkz. [TopicProgress]): görev tamamlama, konu için bir
  /// "çalışıldığı beyanı"dır. AMA o görevin çalışması Focus'ta zaten ÖLÇÜLDÜYSE
  /// (bu göreve ve bu konuya bağlı bir Focus seansı varsa) o çalışma olayı
  /// Focus tarafında ZATEN sayılmıştır — ikinci kez sayılmaz. Karar veriden
  /// (FocusSession.taskId) çıkar, arayüzden gelen bir bayraktan değil. Ayrıca
  /// olay anahtarı ("task:id") sayesinde aç-kapa yapılan bir görev konuyu
  /// tekrar tekrar ilerletmez.
  ///
  /// Harcanan süre ([TaskModel.actualMinutes]) de aynı yerden: bu göreve bağlı
  /// Focus seanslarının toplamı (tek doğruluk kaynağı FocusSession'dır); hiç
  /// Focus yoksa null kalır.
  Future<void> toggleTaskCompletion(String id) async {
    // Hızlı art arda dokunuşta görev arada silinmiş olabilir — çökmek yerine yok say.
    final taskBefore = state.where((task) => task.id == id).firstOrNull;
    if (taskBefore == null) return;

    final wasCompleted = taskBefore.isCompleted;

    await _repository.toggleTaskCompletion(id);

    state = [..._repository.getAllTasks()];

    final taskAfter = state.where((task) => task.id == id).firstOrNull;
    if (taskAfter == null) return;

    if (!wasCompleted && taskAfter.isCompleted) {
      final linkedSessions = _ref
          .read(focusSessionProvider)
          .where((s) => s.taskId == id)
          .toList();
      final measured = linkedSessions.fold<int>(0, (sum, s) => sum + s.minutes);
      if (measured > 0) {
        taskAfter.actualMinutes = measured;
        await _repository.updateTask(taskAfter);
      }

      await _cancelReminder(id);

      _ref.read(lastCompletedTaskProvider.notifier).state = taskAfter;
      _ref.read(taskCompletionEventProvider.notifier).state++;

      _ref
          .read(statsProvider.notifier)
          .adjustStudyMinutes(taskAfter.estimatedMinutes ?? 0);

      // XP'nin sabit "+10" olması, önceliğin/direncin hiçbir anlam
      // taşımaması eleştirisine karşılık: bekleyen yüksek öncelikli bir
      // görevi ya da kronik ertelenmiş (2+) bir görevi bitirmek düz
      // görevden daha fazla XP kazandırır — bkz. RankSystem.xpBonus*.
      _ref
          .read(statsProvider.notifier)
          .addBonusXp(_completionXpBonus(taskAfter));

      final linkedTopicId = taskAfter.topicId;
      if (linkedTopicId != null) {
        final alreadyMeasured =
            linkedSessions.any((s) => s.topicId == linkedTopicId);
        if (!alreadyMeasured) {
          _ref
              .read(topicProvider.notifier)
              .recordStudyActivity(linkedTopicId, TopicProgress.taskKey(id));
        }
      }

      // completedAt'e göre — dueDate'e göre sayarsak, geciken (dueDate
      // dünkü/daha eski) bir görevi bugün tamamlamak bugünkü hedefe hiç
      // yansımaz (bkz. taskCompletionDay, tasksCompletedByDayProvider'da
      // zaten aynı mantıkla kullanılıyor).
      final completedToday = state
          .where((task) =>
              task.isCompleted && _isToday(taskCompletionDay(task)))
          .length;

      final dailyGoal = _ref.read(statsProvider).dailyGoal;

      if (completedToday >= dailyGoal) {
        _ref.read(statsProvider.notifier).markGoalCompletedToday();

        _ref.read(goalReachedEventProvider.notifier).state++;
      }
    } else if (wasCompleted && !taskAfter.isCompleted) {
      _ref
          .read(statsProvider.notifier)
          .adjustStudyMinutes(-(taskAfter.estimatedMinutes ?? 0));

      _ref
          .read(statsProvider.notifier)
          .addBonusXp(-_completionXpBonus(taskAfter));

      if (taskAfter.actualMinutes != null) {
        taskAfter.actualMinutes = null;
        await _repository.updateTask(taskAfter);
      }

      await _scheduleReminder(taskAfter);
    }
  }

  /// Görev henüz tamamlanmadıysa tamamlar; zaten tamamsa hiçbir şey yapmaz
  /// (aç-kapa DEĞİL). Focus bitişi gibi "bu iş bitti" olayları için.
  Future<void> completeTask(String id) async {
    final task = state.where((t) => t.id == id).firstOrNull;
    if (task == null || task.isCompleted) return;
    await toggleTaskCompletion(id);
  }

  // Bkz. toggleTaskCompletion — tamamlanınca eklenen, geri alınınca aynen
  // çıkarılan "anlamlı" XP bonusu.
  int _completionXpBonus(TaskModel task) {
    var bonus = 0;
    if (task.priority == TaskPriority.high) {
      bonus += RankSystem.xpBonusHighPriority;
    }
    // "Recovered" ödülü BİLEREK postponeCount + systemRescheduleCount
    // toplamına bakar — bu bir ÖDÜL (ceza değil): kaynağı ne olursa olsun
    // (öğrenci kendi ertelemiş ya da sistem backlog'u yaymış), birkaç kez
    // sıkışmış bir görevi bitirmek hâlâ gerçek bir "toparlama". StudyAdvisor'ın
    // "kaçınma" SİNYALİ (avoidance) buradan AYRI — o SADECE postponeCount'a
    // bakar (bkz. task_model.dart'taki not).
    if ((task.postponeCount + task.systemRescheduleCount) >= 2) {
      bonus += RankSystem.xpBonusRecovered;
    }
    if (task.difficulty == TopicDifficulty.hard) {
      bonus += RankSystem.xpBonusHardTask;
    }
    return bonus;
  }


  // Geri Al akışı için: silmeden önce alanların bağımsız bir kopyasını
  // döndürür (silinen HiveObject'in kendisi kullanılamaz — box'tan
  // silindikten sonra artık geçerli değildir). null dönerse görev zaten
  // yok demektir.
  TaskModel? deleteTask(String id) {
    final index = state.indexWhere((task) => task.id == id);
    if (index == -1) return null;

    final original = state[index];
    final snapshot = TaskModel(
      id: original.id,
      title: original.title,
      subjectId: original.subjectId,
      dueDate: original.dueDate,
      isCompleted: original.isCompleted,
      priority: original.priority,
      createdAt: original.createdAt,
      completedAt: original.completedAt,
      scheduledTime: original.scheduledTime,
      estimatedMinutes: original.estimatedMinutes,
      difficulty: original.difficulty,
      recurringGroupId: original.recurringGroupId,
      recurrenceRule: original.recurrenceRule,
      topicId: original.topicId,
      postponeCount: original.postponeCount,
      actualMinutes: original.actualMinutes,
      systemRescheduleCount: original.systemRescheduleCount,
      sourceReason: original.sourceReason,
    );

    _cancelReminder(id);

    _repository.deleteTask(id);

    state = [..._repository.getAllTasks()];

    return snapshot;
  }

  // "Geri Al" ile deleteTask'ın döndürdüğü kopyayı aynı id ile geri ekler.
  void restoreTask(TaskModel task) {
    _repository.addTask(task);

    state = [..._repository.getAllTasks()];

    _scheduleReminder(task);
  }

  // Görevi bir sonraki güne taşır — TaskTile'da sola kaydırma aksiyonu.
  void postponeTask(String id) {
    final task = state.where((t) => t.id == id).firstOrNull;
    if (task == null) return;
    // updateTask bu alana dokunmuyor, bu yüzden çağrıdan ÖNCE elle
    // artırıyoruz — StudyAdvisor'ın "kronik erteleme" sinyali buradan
    // besleniyor (bkz. study_advisor.dart).
    task.postponeCount += 1;

    final newDueDate = DateTime(
      task.dueDate.year,
      task.dueDate.month,
      task.dueDate.day + 1,
      task.dueDate.hour,
      task.dueDate.minute,
    );

    final newScheduledTime = task.scheduledTime == null
        ? null
        : DateTime(
            task.scheduledTime!.year,
            task.scheduledTime!.month,
            task.scheduledTime!.day + 1,
            task.scheduledTime!.hour,
            task.scheduledTime!.minute,
          );

    updateTask(
      task,
      title: task.title,
      subjectId: task.subjectId,
      dueDate: newDueDate,
      priority: task.priority,
      scheduledTime: newScheduledTime,
      estimatedMinutes: task.estimatedMinutes,
      difficulty: task.difficulty,
    );
  }


  // Bir tekrar serisindeki TÜM örnekleri (geçmiş + gelecek) tek seferde
  // siler. Kullanıcı "her gün" gibi bir seçim yapıp pişman olduğunda,
  // 30 görevi tek tek silmek zorunda kalmasın diye eklendi.
  void deleteRecurringGroup(String groupId) {
    final tasksInGroup =
        state.where((task) => task.recurringGroupId == groupId).toList();

    for (final task in tasksInGroup) {
      _cancelReminder(task.id);
      _repository.deleteTask(task.id);
    }

    state = [..._repository.getAllTasks()];
  }



  void updateTask(
    TaskModel task, {
    required String title,
    String? subjectId,
    required DateTime dueDate,
    required TaskPriority priority,
    DateTime? scheduledTime,
    int? estimatedMinutes,
    TopicDifficulty difficulty = TopicDifficulty.medium,
    Object? topicId = _unset,
  }) {

    task.title = title;
    task.subjectId = subjectId;
    task.dueDate = dueDate;
    task.priority = priority;
    task.scheduledTime = scheduledTime;
    task.estimatedMinutes = estimatedMinutes;
    task.difficulty = difficulty;
    // Çağıran taraf topicId geçmezse (ör. taşıma/postponeTask) mevcut bağ
    // korunur — sentinel [_unset] ile "değiştirme" ile "null'a çek" ayrılır.
    if (!identical(topicId, _unset)) {
      task.topicId = topicId as String?;
    }


    _repository.updateTask(task);

    state = [..._repository.getAllTasks()];

    _cancelReminder(task.id);
    _scheduleReminder(task);
  }

  // Bir ders silinince, o derse bağlı görevler "öksüz" (var olmayan bir
  // subjectId'ye işaret eden) kalmasın diye çağrılır — konular için zaten
  // yapılan deleteForSubject ile aynı gerekçe (bkz. subjects_screen.dart).
  // Görevin kendisi SİLİNMEZ (kullanıcının yapılacak işi bu yüzden
  // kaybolmamalı) — yalnızca ders/konu bağı temizlenip "Derssiz" olur.
  /// Döndürür: bağı çözülen görevlerin (görev, ders, konu) kayıtları — "Geri
  /// Al" bunları [restoreSubjectLinks] ile geri getirir.
  List<({String taskId, String subjectId, String? topicId})>
      clearSubjectFromTasks(String subjectId) {
    final affected =
        state.where((t) => t.subjectId == subjectId).toList();
    if (affected.isEmpty) return const [];
    final links = [
      for (final t in affected)
        (taskId: t.id, subjectId: subjectId, topicId: t.topicId),
    ];
    for (final task in affected) {
      task.subjectId = null;
      task.topicId = null;
      _repository.updateTask(task);
    }
    state = [..._repository.getAllTasks()];
    return links;
  }

  /// [clearSubjectFromTasks]'ın geri alması: görev hâlâ varsa ve hâlâ dersiz
  /// ise eski ders/konu bağı geri verilir (bu arada elle başka derse
  /// bağlanmış bir göreve dokunulmaz).
  void restoreSubjectLinks(
      List<({String taskId, String subjectId, String? topicId})> links) {
    var changed = false;
    for (final link in links) {
      final task = state.where((t) => t.id == link.taskId).firstOrNull;
      if (task == null || task.subjectId != null) continue;
      task.subjectId = link.subjectId;
      task.topicId = link.topicId;
      _repository.updateTask(task);
      changed = true;
    }
    if (changed) state = [..._repository.getAllTasks()];
  }
}



final taskProvider =
    StateNotifierProvider<TaskNotifier, List<TaskModel>>((ref) {

  final repository =
      ref.watch(taskRepositoryProvider);

  return TaskNotifier(repository, ref);
});



final todayTasksProvider =
    Provider<List<TaskModel>>((ref) {
  ref.watch(dayRolloverProvider);

  final allTasks =
      ref.watch(taskProvider);


  final now =
      DateTime.now();


  return allTasks.where((task) {

    return task.dueDate.year == now.year &&
        task.dueDate.month == now.month &&
        task.dueDate.day == now.day;

  }).toList();

});

DateTime taskCompletionDay(TaskModel t) {
  final d = t.completedAt ?? t.dueDate;
  return DateTime(d.year, d.month, d.day);
}

/// Gün (saat sıfır) → o gün tamamlanan görev sayısı.
final tasksCompletedByDayProvider = Provider<Map<DateTime, int>>((ref) {
  final all = ref.watch(taskProvider);
  final map = <DateTime, int>{};
  for (final t in all) {
    if (!t.isCompleted) continue;
    final d = taskCompletionDay(t);
    map[d] = (map[d] ?? 0) + 1;
  }
  return map;
});

int _weekSum(Map<DateTime, int> byDay, DateTime start, DateTime end) {
  var total = 0;
  byDay.forEach((day, count) {
    if (!day.isBefore(start) && day.isBefore(end)) total += count;
  });
  return total;
}

/// Bir konuya bağlı, gerçek süresi ölçülmüş (actualMinutes — bkz.
/// TaskModel.actualMinutes) görevler arasında, gerçek sürenin planlanandan
/// belirgin (%40+) uzun olduğu konular — "bu konu tahmininden zor çıktı"
/// sinyali. Deneme verisi konu granülerliğinde YOK (DenemeSectionScore
/// yalnız ders bazında tutuluyor) — bu, mevcut veriyle ulaşılabilecek en
/// ince zayıflık sinyali. subjectId → o dersin zor çıkan konu adları (en
/// fazla 2, en belirgin olandan başlayarak).
final difficultTopicNamesBySubjectProvider =
    Provider<Map<String, List<String>>>((ref) {
  final topics = ref.watch(topicProvider);
  final topicById = {for (final t in topics) t.id: t};
  final result = <String, List<String>>{};
  for (final topicId in ref.watch(overranTopicIdsProvider)) {
    final topic = topicById[topicId];
    if (topic == null) continue;
    result.putIfAbsent(topic.subjectId, () => []).add(topic.name);
  }
  for (final list in result.values) {
    if (list.length > 2) list.removeRange(2, list.length);
  }
  return result;
});

/// Bir konuya bağlı, gerçek süresi ölçülmüş görevlerde gerçek sürenin
/// planlanandan belirgin (%40+) uzun olduğu konu id'leri. Aynı konuya bağlı
/// birden çok görev varsa ortalama oran kullanılır (tek seferlik bir yavaşlık
/// gürültü sayılmasın). Bu bir DAVRANIŞSAL sinyaldir ("zor çıktı"), tek
/// başına "zayıf" demez; öğrencinin "zorlandım" cevabıyla BİRLEŞİNCE daha
/// güçlü bir sonuç olur (bkz. TopicEvidenceEngine.difficultySignals).
final overranTopicIdsProvider = Provider<Set<String>>((ref) {
  final tasks = ref.watch(taskProvider);
  final ratioSum = <String, double>{};
  final ratioCount = <String, int>{};
  for (final task in tasks) {
    final topicId = task.topicId;
    final actual = task.actualMinutes;
    final estimated = task.estimatedMinutes;
    if (topicId == null ||
        actual == null ||
        estimated == null ||
        estimated <= 0) {
      continue;
    }
    ratioSum[topicId] = (ratioSum[topicId] ?? 0) + actual / estimated;
    ratioCount[topicId] = (ratioCount[topicId] ?? 0) + 1;
  }
  return {
    for (final e in ratioSum.entries)
      if (e.value / ratioCount[e.key]! >= 1.4) e.key,
  };
});

/// Bu haftanın (Pazartesi–bugün) tamamlanan görev sayısı.
final tasksCompletedThisWeekProvider = Provider<int>((ref) {
  ref.watch(dayRolloverProvider);
  final byDay = ref.watch(tasksCompletedByDayProvider);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final monday = today.subtract(Duration(days: today.weekday - 1));
  final nextMonday = monday.add(const Duration(days: 7));
  return _weekSum(byDay, monday, nextMonday);
});

/// Geçen haftanın (Pazartesi–Pazar) tamamlanan görev sayısı.
final tasksCompletedLastWeekProvider = Provider<int>((ref) {
  ref.watch(dayRolloverProvider);
  final byDay = ref.watch(tasksCompletedByDayProvider);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final monday = today.subtract(Duration(days: today.weekday - 1));
  final lastMonday = monday.subtract(const Duration(days: 7));
  return _weekSum(byDay, lastMonday, monday);
});