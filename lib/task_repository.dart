import 'hive_boxes.dart';
import 'task_model.dart';

class TaskRepository {
  List<TaskModel> getAllTasks() {
    return HiveBoxes.tasks.values.toList();
  }

  Future<void> addTask(TaskModel task) async {
    await HiveBoxes.tasks.put(task.id, task);
  }

  Future<void> deleteTask(String id) async {
    await HiveBoxes.tasks.delete(id);
  }

  Future<void> updateTask(TaskModel task) async {
    await task.save();
  }

  Future<void> toggleTaskCompletion(String id) async {
    final task = HiveBoxes.tasks.get(id);
    if (task == null) return;

    task.isCompleted = !task.isCompleted;
    task.completedAt = task.isCompleted ? DateTime.now() : null;

    await task.save();
  }
}