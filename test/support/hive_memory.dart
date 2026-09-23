import 'dart:io';
import 'dart:typed_data';

import 'package:hive/hive.dart';
import 'package:study_planner/daily_closeout_model.dart';
import 'package:study_planner/deneme_model.dart';
import 'package:study_planner/focus_session_model.dart';
import 'package:study_planner/hive_boxes.dart';
import 'package:study_planner/subject_model.dart';
import 'package:study_planner/task_model.dart';
import 'package:study_planner/topic_model.dart';
import 'package:study_planner/user_stats_model.dart';

/// Testler için BELLEK tabanlı Hive kutuları. Dosya G/Ç'si `testWidgets`'in
/// FakeAsync bölgesinde hiç tamamlanmaz (kutu silme/kapatma sonsuza asılır);
/// bellek arka ucu yazmaları mikro-görev olarak bitirir, `pump` ile ilerler —
/// hem widget hem saf provider testlerinde aynı yardımcı kullanılır.
bool _initialized = false;

void registerHiveAdaptersOnce() {
  if (_initialized) return;
  _initialized = true;
  Hive.init(Directory.systemTemp.createTempSync('pusula_mem').path);
  Hive
    ..registerAdapter(SubjectModelAdapter())
    ..registerAdapter(TaskPriorityAdapter())
    ..registerAdapter(TopicDifficultyAdapter())
    ..registerAdapter(TaskModelAdapter())
    ..registerAdapter(UserStatsModelAdapter())
    ..registerAdapter(TopicStatusAdapter())
    ..registerAdapter(TopicModelAdapter())
    ..registerAdapter(FocusSessionAdapter())
    ..registerAdapter(DailyCloseoutAdapter())
    ..registerAdapter(DenemeSectionScoreAdapter())
    ..registerAdapter(DenemeEntryAdapter());
}

/// Uygulamanın tüm kutularını boş, bellek tabanlı açar.
Future<void> openMemoryBoxes() async {
  registerHiveAdaptersOnce();
  final empty = Uint8List(0);
  await Hive.openBox<SubjectModel>(HiveBoxes.subjectsBoxName, bytes: empty);
  await Hive.openBox<TaskModel>(HiveBoxes.tasksBoxName, bytes: empty);
  await Hive.openBox<UserStatsModel>(HiveBoxes.statsBoxName, bytes: empty);
  await Hive.openBox<TopicModel>(HiveBoxes.topicsBoxName, bytes: empty);
  await Hive.openBox<FocusSession>(HiveBoxes.focusSessionsBoxName,
      bytes: empty);
  await Hive.openBox<DailyCloseout>(HiveBoxes.dailyCloseoutsBoxName,
      bytes: empty);
  await Hive.openBox<DenemeEntry>(HiveBoxes.denemelerBoxName, bytes: empty);
  await Hive.openBox(HiveBoxes.focusAnchorBoxName, bytes: empty);
}

Future<void> closeMemoryBoxes() async {
  // Bellek kutuları kapatılınca içerik de gider; her test boş başlar.
  Future<void> close<T>(String name) async {
    if (Hive.isBoxOpen(name)) await Hive.box<T>(name).close();
  }

  await close<SubjectModel>(HiveBoxes.subjectsBoxName);
  await close<TaskModel>(HiveBoxes.tasksBoxName);
  await close<UserStatsModel>(HiveBoxes.statsBoxName);
  await close<TopicModel>(HiveBoxes.topicsBoxName);
  await close<FocusSession>(HiveBoxes.focusSessionsBoxName);
  await close<DailyCloseout>(HiveBoxes.dailyCloseoutsBoxName);
  await close<DenemeEntry>(HiveBoxes.denemelerBoxName);
  await close<dynamic>(HiveBoxes.focusAnchorBoxName);
}
