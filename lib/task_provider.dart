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

    await NotificationService.instance.scheduleNotification(
      id: task.id,
      category: NotificationCategory.taskReminder,
      title: task.title,
      body: 'Görev zamanı geldi',
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

      await _scheduleReminder(taskAfter);
    }
  }


  void deleteTask(String id) {

    _cancelReminder(id);

    _repository.deleteTask(id);

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