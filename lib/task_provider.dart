import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'task_model.dart';
import 'task_repository.dart';
import 'stats_provider.dart';
import 'notification_service.dart';

const _uuidTask = Uuid();

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepository();
});

final taskCompletionEventProvider = StateProvider<int>((ref) => 0);
final goalReachedEventProvider = StateProvider<int>((ref) => 0);


class TaskNotifier extends StateNotifier<List<TaskModel>> {
  final TaskRepository _repository;

  TaskNotifier(this._repository)
      : super(_repository.getAllTasks());


  Future<void> _scheduleReminder(TaskModel task) async {
    if (task.scheduledTime == null || task.isCompleted) return;

    // Sadece görevin kendi verisiyle (süre) — ek provider bağımlılığı
    // eklemeden kuru "Görev zamanı geldi" yerine biraz daha somut bir metin.
    final minutes = task.estimatedMinutes;
    final body = (minutes != null && minutes > 0)
        ? '$minutes dakikalık vaktin geldi. Hazır mısın?'
        : 'Vaktin geldi. Hazır mısın?';

    await NotificationService.instance.scheduleNotification(
      id: task.id,
      category: NotificationCategory.taskReminder,
      title: task.title,
      body: body,
      dateTime: task.scheduledTime!,
    );
  }

  Future<void> _cancelReminder(String taskId) async {
    await NotificationService.instance.cancelNotification(
      taskId,
      NotificationCategory.taskReminder,
    );
  }


  void addTask({
    required String title,
    String? subjectId,
    required DateTime dueDate,
    TaskPriority priority = TaskPriority.medium,
    TopicDifficulty difficulty = TopicDifficulty.medium,
    DateTime? scheduledTime,
    int? estimatedMinutes,
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
    );

    _repository.addTask(newTask);
    state = [..._repository.getAllTasks()];

    _scheduleReminder(newTask);
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


  Future<void> toggleTaskCompletion(
      String id, WidgetRef ref) async {

    final taskBefore =
        state.firstWhere((task) => task.id == id);

    final wasCompleted = taskBefore.isCompleted;

    await _repository.toggleTaskCompletion(id);

    state = [..._repository.getAllTasks()];

    final taskAfter =
        state.firstWhere((task) => task.id == id);

    if (!wasCompleted && taskAfter.isCompleted) {

      await _cancelReminder(id);

      ref.read(taskCompletionEventProvider.notifier).state++;

      ref
          .read(statsProvider.notifier)
          .adjustStudyMinutes(taskAfter.estimatedMinutes ?? 0);


      final completedToday =
          state.where(
            (task) =>
                task.isCompleted &&
                _isToday(task.dueDate),
          ).length;


      final dailyGoal =
          ref.read(statsProvider).dailyGoal;


      if (completedToday >= dailyGoal) {

        ref
            .read(statsProvider.notifier)
            .markGoalCompletedToday();


        ref
            .read(goalReachedEventProvider.notifier)
            .state++;
      }
    } else if (wasCompleted && !taskAfter.isCompleted) {

      ref
          .read(statsProvider.notifier)
          .adjustStudyMinutes(-(taskAfter.estimatedMinutes ?? 0));

      await _scheduleReminder(taskAfter);
    }
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
    final task = state.firstWhere((t) => t.id == id);

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
  }) {

    task.title = title;
    task.subjectId = subjectId;
    task.dueDate = dueDate;
    task.priority = priority;
    task.scheduledTime = scheduledTime;
    task.estimatedMinutes = estimatedMinutes;
    task.difficulty = difficulty;


    _repository.updateTask(task);

    state = [..._repository.getAllTasks()];

    _cancelReminder(task.id);
    _scheduleReminder(task);
  }
}



final taskProvider =
    StateNotifierProvider<TaskNotifier, List<TaskModel>>((ref) {

  final repository =
      ref.watch(taskRepositoryProvider);

  return TaskNotifier(repository);
});



final todayTasksProvider =
    Provider<List<TaskModel>>((ref) {

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

DateTime _taskCompletionDay(TaskModel t) {
  final d = t.completedAt ?? t.dueDate;
  return DateTime(d.year, d.month, d.day);
}

/// Gün (saat sıfır) → o gün tamamlanan görev sayısı.
final tasksCompletedByDayProvider = Provider<Map<DateTime, int>>((ref) {
  final all = ref.watch(taskProvider);
  final map = <DateTime, int>{};
  for (final t in all) {
    if (!t.isCompleted) continue;
    final d = _taskCompletionDay(t);
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

/// Bu haftanın (Pazartesi–bugün) tamamlanan görev sayısı.
final tasksCompletedThisWeekProvider = Provider<int>((ref) {
  final byDay = ref.watch(tasksCompletedByDayProvider);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final monday = today.subtract(Duration(days: today.weekday - 1));
  final nextMonday = monday.add(const Duration(days: 7));
  return _weekSum(byDay, monday, nextMonday);
});

/// Geçen haftanın (Pazartesi–Pazar) tamamlanan görev sayısı.
final tasksCompletedLastWeekProvider = Provider<int>((ref) {
  final byDay = ref.watch(tasksCompletedByDayProvider);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final monday = today.subtract(Duration(days: today.weekday - 1));
  final lastMonday = monday.subtract(const Duration(days: 7));
  return _weekSum(byDay, lastMonday, monday);
});