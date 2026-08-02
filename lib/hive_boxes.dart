import 'package:hive_flutter/hive_flutter.dart';

import 'subject_model.dart';
import 'task_model.dart';
import 'user_stats_model.dart';
import 'user_progress.dart';

class HiveBoxes {
  static const String subjectsBoxName = 'subjects';
  static const String tasksBoxName = 'tasks';
  static const String statsBoxName = 'stats';
  static const String progressBoxName = 'progress';

  static Future<void> init() async {
    await Hive.initFlutter();

    // Subject
    if (!Hive.isAdapterRegistered(SubjectModelAdapter().typeId)) {
      Hive.registerAdapter(SubjectModelAdapter());
    }

    // Task enumları
    if (!Hive.isAdapterRegistered(TaskPriorityAdapter().typeId)) {
      Hive.registerAdapter(TaskPriorityAdapter());
    }

 if (!Hive.isAdapterRegistered(TaskModelAdapter().typeId)) {
      Hive.registerAdapter(TaskModelAdapter());
    }


    if (!Hive.isAdapterRegistered(TopicDifficultyAdapter().typeId)) {
      Hive.registerAdapter(TopicDifficultyAdapter());
    }

    // Task
    if (!Hive.isAdapterRegistered(TaskModelAdapter().typeId)) {
      Hive.registerAdapter(TaskModelAdapter());
    }

    // Stats
    if (!Hive.isAdapterRegistered(UserStatsModelAdapter().typeId)) {
      Hive.registerAdapter(UserStatsModelAdapter());
    }

    // Progress
    if (!Hive.isAdapterRegistered(UserProgressAdapter().typeId)) {
      Hive.registerAdapter(UserProgressAdapter());
    }


    await Hive.openBox<SubjectModel>(subjectsBoxName);
    await Hive.openBox<TaskModel>(tasksBoxName);
    await Hive.openBox<UserStatsModel>(statsBoxName);
    await Hive.openBox<UserProgress>(progressBoxName);
  }


  static Box<SubjectModel> get subjects =>
      Hive.box<SubjectModel>(subjectsBoxName);

  static Box<TaskModel> get tasks =>
      Hive.box<TaskModel>(tasksBoxName);

  static Box<UserStatsModel> get stats =>
      Hive.box<UserStatsModel>(statsBoxName);

  static Box<UserProgress> get progress =>
      Hive.box<UserProgress>(progressBoxName);
}