import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'daily_closeout_model.dart';
import 'deneme_model.dart';
import 'focus_session_model.dart';
import 'hive_boxes.dart';
import 'subject_model.dart';
import 'task_model.dart';
import 'topic_model.dart';
import 'user_stats_model.dart';

/// Yerel veri güvenliği (docs/rakip_analizi §6 A1). Pusula'nın tüm verisi
/// cihazda; kaybolursa telafisi yok. Bu servis:
///
///  1. Tüm Hive kutularını tek bir JSON'a **dışa aktarır** (kullanıcı paylaşım
///     sayfasıyla Drive/Dosyalar'a kaydeder).
///  2. Bir JSON yedeğinden **geri yükler** (önce hepsini parse eder, ancak
///     hepsi geçerliyse kutulara yazar — yarıda patlarsa mevcut veri sağlam
///     kalır).
///  3. Açılışta günde bir kez cihaza **sessiz yerel yedek** (`writeDailySnapshot`)
///     yazar; son [_keepSnapshots] tanesi saklanır. Kutu bozulursa buradan
///     dönülebilir.
///
/// Hiçbir provider/repository/model dosyasına dokunmaz — kutuları
/// repository'lerle aynı şekilde doğrudan okur/yazar.
class BackupService {
  BackupService._();

  static const String _magic = 'pusula-backup';
  static const int schemaVersion = 1;
  static const int _keepSnapshots = 7;

  // ------------------------------------------------------------------ EXPORT

  static Map<String, dynamic> exportToMap() {
    final stats = HiveBoxes.stats.get('main');
    return {
      'format': _magic,
      'schemaVersion': schemaVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'subjects': HiveBoxes.subjects.values.map(_subjectToMap).toList(),
      'tasks': HiveBoxes.tasks.values.map(_taskToMap).toList(),
      'topics': HiveBoxes.topics.values.map(_topicToMap).toList(),
      'focusSessions': HiveBoxes.focusSessions.values.map(_focusToMap).toList(),
      'dailyCloseouts':
          HiveBoxes.dailyCloseouts.values.map(_closeoutToMap).toList(),
      'denemeler': HiveBoxes.denemeler.values.map(_denemeToMap).toList(),
      'stats': stats == null ? null : _statsToMap(stats),
    };
  }

  static String exportToJsonString() =>
      const JsonEncoder.withIndent('  ').convert(exportToMap());

  // ------------------------------------------------------------------ IMPORT

  static Future<ImportSummary> importFromJsonString(String raw) {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      throw const BackupException('Dosya okunamadı — geçerli bir yedek değil.');
    }
    if (decoded is! Map) {
      throw const BackupException('Dosya geçerli bir yedek gibi görünmüyor.');
    }
    return importFromMap(decoded.cast<String, dynamic>());
  }

  static Future<ImportSummary> importFromMap(Map<String, dynamic> data) async {
    if (data['format'] != _magic) {
      throw const BackupException('Bu dosya geçerli bir yedek değil.');
    }
    final v = data['schemaVersion'];
    if (v is! int || v > schemaVersion) {
      throw const BackupException(
          'Yedek, uygulamanın bu sürümünden yeni. Önce uygulamayı güncelle.');
    }

    // Önce HER ŞEYİ parse et — biri patlarsa mevcut kutulara hiç dokunma.
    final List<SubjectModel> subjects;
    final List<TaskModel> tasks;
    final List<TopicModel> topics;
    final List<FocusSession> focus;
    final List<DailyCloseout> closeouts;
    final List<DenemeEntry> denemeler;
    final UserStatsModel? stats;
    try {
      subjects = _mapList(data['subjects']).map(_subjectFromMap).toList();
      tasks = _mapList(data['tasks']).map(_taskFromMap).toList();
      topics = _mapList(data['topics']).map(_topicFromMap).toList();
      focus = _mapList(data['focusSessions']).map(_focusFromMap).toList();
      closeouts =
          _mapList(data['dailyCloseouts']).map(_closeoutFromMap).toList();
      denemeler = _mapList(data['denemeler']).map(_denemeFromMap).toList();
      final s = data['stats'];
      stats = s is Map ? _statsFromMap(s.cast<String, dynamic>()) : null;
    } catch (_) {
      throw const BackupException('Yedek dosyası bozuk — geri yüklenemedi.');
    }

    // Parse tamam — artık kutuları değiştirebiliriz.
    await HiveBoxes.subjects.clear();
    for (final s in subjects) {
      await HiveBoxes.subjects.put(s.id, s);
    }
    await HiveBoxes.tasks.clear();
    for (final t in tasks) {
      await HiveBoxes.tasks.put(t.id, t);
    }
    await HiveBoxes.topics.clear();
    for (final t in topics) {
      await HiveBoxes.topics.put(t.id, t);
    }
    await HiveBoxes.focusSessions.clear();
    for (final f in focus) {
      await HiveBoxes.focusSessions.put(f.id, f);
    }
    await HiveBoxes.dailyCloseouts.clear();
    for (final c in closeouts) {
      await HiveBoxes.dailyCloseouts.put(c.id, c);
    }
    await HiveBoxes.denemeler.clear();
    for (final d in denemeler) {
      await HiveBoxes.denemeler.put(d.id, d);
    }
    if (stats != null) {
      await HiveBoxes.stats.put('main', stats);
    }

    return ImportSummary(
      subjects: subjects.length,
      tasks: tasks.length,
      topics: topics.length,
      focusSessions: focus.length,
      denemeler: denemeler.length,
    );
  }

  // -------------------------------------------------------- LOCAL SNAPSHOTS

  static Future<Directory> _snapshotDir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/backups');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Günde bir kez, sessizce cihaza yerel yedek yazar. Hata olursa hiçbir şey
  /// yapmaz — açılışı asla bloke etmez.
  static Future<void> writeDailySnapshot() async {
    try {
      final dir = await _snapshotDir();
      final now = DateTime.now();
      final stamp = '${now.year}-${_pad2(now.month)}-${_pad2(now.day)}';
      final file = File('${dir.path}/pusula-$stamp.json');
      if (await file.exists()) return; // bugün zaten alınmış
      await file.writeAsString(exportToJsonString());
      await _pruneSnapshots(dir);
    } catch (_) {
      // best-effort
    }
  }

  static Future<void> _pruneSnapshots(Directory dir) async {
    final files = _snapshotFiles(dir);
    for (final f in files.skip(_keepSnapshots)) {
      try {
        await f.delete();
      } catch (_) {}
    }
  }

  static List<File> _snapshotFiles(Directory dir) => dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList()
    // Dosya adı `pusula-YYYY-MM-DD.json` → alfabetik sıralama = tarih sırası.
    ..sort((a, b) => b.path.compareTo(a.path)); // en yeni önce

  /// Cihazdaki otomatik yedeklerin listesi (en yeni önce).
  static Future<List<SnapshotInfo>> listSnapshots() async {
    try {
      final dir = await _snapshotDir();
      return _snapshotFiles(dir).map((f) {
        DateTime? taken;
        var items = 0;
        try {
          final decoded = jsonDecode(f.readAsStringSync());
          if (decoded is Map) {
            taken = DateTime.tryParse(decoded['exportedAt']?.toString() ?? '');
            items = _mapList(decoded['subjects']).length +
                _mapList(decoded['tasks']).length +
                _mapList(decoded['topics']).length +
                _mapList(decoded['focusSessions']).length +
                _mapList(decoded['dailyCloseouts']).length +
                _mapList(decoded['denemeler']).length;
          }
        } catch (_) {}
        return SnapshotInfo(path: f.path, takenAt: taken, itemCount: items);
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  // ------------------------------------------------------------------ MAPPERS

  static Map<String, dynamic> _subjectToMap(SubjectModel s) => {
        'id': s.id,
        'name': s.name,
        'colorValue': s.colorValue,
        'createdAt': s.createdAt.toIso8601String(),
      };

  static SubjectModel _subjectFromMap(Map<String, dynamic> m) => SubjectModel(
        id: m['id'] as String,
        name: (m['name'] as String?) ?? '',
        colorValue: (m['colorValue'] as num?)?.toInt() ?? 0xFF7FB3AC,
        createdAt: _date(m['createdAt']) ?? DateTime.now(),
      );

  static Map<String, dynamic> _taskToMap(TaskModel t) => {
        'id': t.id,
        'title': t.title,
        'subjectId': t.subjectId,
        'dueDate': t.dueDate.toIso8601String(),
        'isCompleted': t.isCompleted,
        'priority': t.priority.name,
        'createdAt': t.createdAt.toIso8601String(),
        'completedAt': t.completedAt?.toIso8601String(),
        'scheduledTime': t.scheduledTime?.toIso8601String(),
        'estimatedMinutes': t.estimatedMinutes,
        'difficulty': t.difficulty.name,
        'recurringGroupId': t.recurringGroupId,
        'recurrenceRule': t.recurrenceRule,
      };

  static TaskModel _taskFromMap(Map<String, dynamic> m) => TaskModel(
        id: m['id'] as String,
        title: (m['title'] as String?) ?? '',
        subjectId: m['subjectId'] as String?,
        dueDate: _date(m['dueDate']) ?? DateTime.now(),
        isCompleted: (m['isCompleted'] as bool?) ?? false,
        priority:
            _enumByName(TaskPriority.values, m['priority'], TaskPriority.medium),
        createdAt: _date(m['createdAt']) ?? DateTime.now(),
        completedAt: _date(m['completedAt']),
        scheduledTime: _date(m['scheduledTime']),
        estimatedMinutes: (m['estimatedMinutes'] as num?)?.toInt(),
        difficulty: _enumByName(
            TopicDifficulty.values, m['difficulty'], TopicDifficulty.medium),
        recurringGroupId: m['recurringGroupId'] as String?,
        recurrenceRule: m['recurrenceRule'] as String?,
      );

  static Map<String, dynamic> _topicToMap(TopicModel t) => {
        'id': t.id,
        'subjectId': t.subjectId,
        'name': t.name,
        'status': t.status.name,
        'createdAt': t.createdAt.toIso8601String(),
        'updatedAt': t.updatedAt?.toIso8601String(),
      };

  static TopicModel _topicFromMap(Map<String, dynamic> m) => TopicModel(
        id: m['id'] as String,
        subjectId: (m['subjectId'] as String?) ?? '',
        name: (m['name'] as String?) ?? '',
        status: _enumByName(
            TopicStatus.values, m['status'], TopicStatus.notStarted),
        createdAt: _date(m['createdAt']) ?? DateTime.now(),
        updatedAt: _date(m['updatedAt']),
      );

  static Map<String, dynamic> _focusToMap(FocusSession f) => {
        'id': f.id,
        'endedAt': f.endedAt.toIso8601String(),
        'minutes': f.minutes,
        'mode': f.mode,
      };

  static FocusSession _focusFromMap(Map<String, dynamic> m) => FocusSession(
        id: m['id'] as String,
        endedAt: _date(m['endedAt']) ?? DateTime.now(),
        minutes: (m['minutes'] as num?)?.toInt() ?? 0,
        mode: (m['mode'] as String?) ?? 'serbest',
      );

  static Map<String, dynamic> _closeoutToMap(DailyCloseout c) => {
        'id': c.id,
        'date': c.date.toIso8601String(),
        'intent': c.intent,
        'completedTasks': c.completedTasks,
        'focusMinutes': c.focusMinutes,
        'closedAt': c.closedAt.toIso8601String(),
      };

  static DailyCloseout _closeoutFromMap(Map<String, dynamic> m) => DailyCloseout(
        id: m['id'] as String,
        date: _date(m['date']) ?? DateTime.now(),
        intent: (m['intent'] as String?) ?? '',
        completedTasks: (m['completedTasks'] as num?)?.toInt() ?? 0,
        focusMinutes: (m['focusMinutes'] as num?)?.toInt() ?? 0,
        closedAt: _date(m['closedAt']) ?? DateTime.now(),
      );

  static Map<String, dynamic> _denemeSectionToMap(DenemeSectionScore s) => {
        'subject': s.subject,
        'correct': s.correct,
        'wrong': s.wrong,
        'blank': s.blank,
      };

  static DenemeSectionScore _denemeSectionFromMap(Map<String, dynamic> m) =>
      DenemeSectionScore(
        subject: (m['subject'] as String?) ?? '',
        correct: (m['correct'] as num?)?.toInt() ?? 0,
        wrong: (m['wrong'] as num?)?.toInt() ?? 0,
        blank: (m['blank'] as num?)?.toInt() ?? 0,
      );

  static Map<String, dynamic> _denemeToMap(DenemeEntry e) => {
        'id': e.id,
        'examType': e.examType,
        'name': e.name,
        'date': e.date.toIso8601String(),
        'sections': e.sections.map(_denemeSectionToMap).toList(),
      };

  static DenemeEntry _denemeFromMap(Map<String, dynamic> m) => DenemeEntry(
        id: m['id'] as String,
        examType: (m['examType'] as String?) ?? 'TYT',
        name: m['name'] as String?,
        date: _date(m['date']) ?? DateTime.now(),
        sections: _mapList(m['sections']).map(_denemeSectionFromMap).toList(),
      );

  static Map<String, dynamic> _statsToMap(UserStatsModel s) => {
        'currentStreak': s.currentStreak,
        'longestStreak': s.longestStreak,
        'lastCompletedDate': s.lastCompletedDate?.toIso8601String(),
        'dailyGoal': s.dailyGoal,
        'freezesAvailable': s.freezesAvailable,
        'totalCompletedTasks': s.totalCompletedTasks,
        'totalStudyMinutes': s.totalStudyMinutes,
        'hasCompletedOnboarding': s.hasCompletedOnboarding,
        'userName': s.userName,
        'hasSeenNotificationPrompt': s.hasSeenNotificationPrompt,
        'examDate': s.examDate?.toIso8601String(),
        'focusMinutes': s.focusMinutes,
        'hasSeenTaskHints': s.hasSeenTaskHints,
        'gradeLevel': s.gradeLevel,
      };

  static UserStatsModel _statsFromMap(Map<String, dynamic> m) => UserStatsModel(
        currentStreak: (m['currentStreak'] as num?)?.toInt() ?? 0,
        longestStreak: (m['longestStreak'] as num?)?.toInt() ?? 0,
        lastCompletedDate: _date(m['lastCompletedDate']),
        dailyGoal: (m['dailyGoal'] as num?)?.toInt() ?? 1,
        freezesAvailable: (m['freezesAvailable'] as num?)?.toInt() ?? 1,
        totalCompletedTasks: (m['totalCompletedTasks'] as num?)?.toInt() ?? 0,
        totalStudyMinutes: (m['totalStudyMinutes'] as num?)?.toInt() ?? 0,
        // Yedek geri yükleyen biri uygulamayı zaten kullanmış — onboarding'e
        // düşmesin.
        hasCompletedOnboarding: (m['hasCompletedOnboarding'] as bool?) ?? true,
        userName: m['userName'] as String?,
        hasSeenNotificationPrompt:
            (m['hasSeenNotificationPrompt'] as bool?) ?? true,
        examDate: _date(m['examDate']),
        focusMinutes: (m['focusMinutes'] as num?)?.toInt() ?? 0,
        hasSeenTaskHints: (m['hasSeenTaskHints'] as bool?) ?? false,
        gradeLevel: (m['gradeLevel'] as num?)?.toInt(),
      );

  // ------------------------------------------------------------------ UTIL

  static List<Map<String, dynamic>> _mapList(Object? v) => v is List
      ? v.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList()
      : const [];

  static DateTime? _date(Object? v) =>
      v == null ? null : DateTime.tryParse(v.toString());

  static T _enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    return fallback;
  }

  static String _pad2(int n) => n.toString().padLeft(2, '0');
}

/// Geri yükleme sırasında kullanıcıya gösterilebilir hata.
class BackupException implements Exception {
  final String message;
  const BackupException(this.message);
  @override
  String toString() => message;
}

class ImportSummary {
  final int subjects;
  final int tasks;
  final int topics;
  final int focusSessions;
  final int denemeler;

  const ImportSummary({
    required this.subjects,
    required this.tasks,
    required this.topics,
    required this.focusSessions,
    this.denemeler = 0,
  });
}

class SnapshotInfo {
  final String path;
  final DateTime? takenAt;
  final int itemCount;

  const SnapshotInfo({
    required this.path,
    required this.takenAt,
    required this.itemCount,
  });
}
