import 'dart:io' show Platform;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

enum NotificationCategory {
  taskReminder,
  examReminder,
  dailyGoal,
  streakWarning,
  aiSuggestion,
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  bool get _isSupportedPlatform => Platform.isAndroid;

  Future<void> initialize() async {
    if (!_isSupportedPlatform) return;
    if (_initialized) return;

    tz_data.initializeTimeZones();

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings =
        InitializationSettings(android: androidSettings);

    await _plugin.initialize(initSettings);

    _initialized = true;
  }

  int _notificationIdFor(String entityId, NotificationCategory category) {
    final int base = entityId.hashCode & 0x0FFFFFF;
    final int categoryOffset = category.index * 1000000;
    return categoryOffset + base;
  }

  Future<void> showTestNotificationNow() async {
    if (!_isSupportedPlatform) return;
    if (!_initialized) return;

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'task_reminder_channel',
      'Görev Hatırlatmaları',
      importance: Importance.high,
      priority: Priority.high,
    );

    const NotificationDetails details =
        NotificationDetails(android: androidDetails);

    await _plugin.show(999999, 'Test Bildirimi', 'Bu anlık bir test', details);
  }

  Future<void> scheduleNotification({
    required String id,
    required NotificationCategory category,
    required String title,
    required String body,
    required DateTime dateTime,
  }) async {
    if (!_isSupportedPlatform) return;
    if (!_initialized) return;
    if (dateTime.isBefore(DateTime.now())) return;

    final int notificationId = _notificationIdFor(id, category);

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      _channelIdFor(category),
      _channelNameFor(category),
      importance: Importance.high,
      priority: Priority.high,
    );

    final NotificationDetails details =
        NotificationDetails(android: androidDetails);

    await _plugin.zonedSchedule(
      notificationId,
      title,
      body,
      tz.TZDateTime.from(dateTime.toUtc(), tz.UTC),
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelNotification(
    String id,
    NotificationCategory category,
  ) async {
    if (!_isSupportedPlatform) return;
    await _plugin.cancel(_notificationIdFor(id, category));
  }

  String _channelIdFor(NotificationCategory category) {
    switch (category) {
      case NotificationCategory.taskReminder:
        return 'task_reminder_channel';
      case NotificationCategory.examReminder:
        return 'exam_reminder_channel';
      case NotificationCategory.dailyGoal:
        return 'daily_goal_channel';
      case NotificationCategory.streakWarning:
        return 'streak_warning_channel';
      case NotificationCategory.aiSuggestion:
        return 'ai_suggestion_channel';
    }
  }

  String _channelNameFor(NotificationCategory category) {
    switch (category) {
      case NotificationCategory.taskReminder:
        return 'Görev Hatırlatmaları';
      case NotificationCategory.examReminder:
        return 'Sınav Hatırlatmaları';
      case NotificationCategory.dailyGoal:
        return 'Günlük Hedef';
      case NotificationCategory.streakWarning:
        return 'Streak Uyarıları';
      case NotificationCategory.aiSuggestion:
        return 'AI Önerileri';
    }
  }
}