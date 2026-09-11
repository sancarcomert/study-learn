import 'package:hive_flutter/hive_flutter.dart';

import 'daily_closeout_model.dart';
import 'deneme_model.dart';
import 'focus_session_model.dart';
import 'subject_model.dart';
import 'task_model.dart';
import 'topic_model.dart';
import 'user_stats_model.dart';

class HiveBoxes {
  static const String subjectsBoxName = 'subjects';
  static const String tasksBoxName = 'tasks';
  static const String statsBoxName = 'stats';
  static const String topicsBoxName = 'topics';
  static const String focusSessionsBoxName = 'focus_sessions';
  static const String dailyCloseoutsBoxName = 'daily_closeouts';
  static const String denemelerBoxName = 'denemeler';

  static Future<void> init() async {
    await Hive.initFlutter();

    if (!Hive.isAdapterRegistered(SubjectModelAdapter().typeId)) {
      Hive.registerAdapter(SubjectModelAdapter());
    }

    if (!Hive.isAdapterRegistered(TaskPriorityAdapter().typeId)) {
      Hive.registerAdapter(TaskPriorityAdapter());
    }

    if (!Hive.isAdapterRegistered(TopicDifficultyAdapter().typeId)) {
      Hive.registerAdapter(TopicDifficultyAdapter());
    }

    if (!Hive.isAdapterRegistered(TaskModelAdapter().typeId)) {
      Hive.registerAdapter(TaskModelAdapter());
    }

    if (!Hive.isAdapterRegistered(UserStatsModelAdapter().typeId)) {
      Hive.registerAdapter(UserStatsModelAdapter());
    }

    if (!Hive.isAdapterRegistered(TopicStatusAdapter().typeId)) {
      Hive.registerAdapter(TopicStatusAdapter());
    }

    if (!Hive.isAdapterRegistered(TopicModelAdapter().typeId)) {
      Hive.registerAdapter(TopicModelAdapter());
    }

    if (!Hive.isAdapterRegistered(FocusSessionAdapter().typeId)) {
      Hive.registerAdapter(FocusSessionAdapter());
    }

    if (!Hive.isAdapterRegistered(DailyCloseoutAdapter().typeId)) {
      Hive.registerAdapter(DailyCloseoutAdapter());
    }

    if (!Hive.isAdapterRegistered(DenemeSectionScoreAdapter().typeId)) {
      Hive.registerAdapter(DenemeSectionScoreAdapter());
    }

    if (!Hive.isAdapterRegistered(DenemeEntryAdapter().typeId)) {
      Hive.registerAdapter(DenemeEntryAdapter());
    }

    await Hive.openBox<SubjectModel>(subjectsBoxName);
    await Hive.openBox<TaskModel>(tasksBoxName);
    await Hive.openBox<UserStatsModel>(statsBoxName);
    await Hive.openBox<TopicModel>(topicsBoxName);
    await Hive.openBox<FocusSession>(focusSessionsBoxName);
    await Hive.openBox<DailyCloseout>(dailyCloseoutsBoxName);
    await Hive.openBox<DenemeEntry>(denemelerBoxName);
  }

  static Box<SubjectModel> get subjects =>
      Hive.box<SubjectModel>(subjectsBoxName);

  static Box<TaskModel> get tasks =>
      Hive.box<TaskModel>(tasksBoxName);

  static Box<UserStatsModel> get stats =>
      Hive.box<UserStatsModel>(statsBoxName);

  static Box<TopicModel> get topics =>
      Hive.box<TopicModel>(topicsBoxName);

  static Box<FocusSession> get focusSessions =>
      Hive.box<FocusSession>(focusSessionsBoxName);

  static Box<DailyCloseout> get dailyCloseouts =>
      Hive.box<DailyCloseout>(dailyCloseoutsBoxName);

  static Box<DenemeEntry> get denemeler =>
      Hive.box<DenemeEntry>(denemelerBoxName);
}