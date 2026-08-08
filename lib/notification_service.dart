import 'dart:io' show Platform;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
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

  bool get _isSupportedPlatform => Platform.isAndroid || Platform.isIOS;

  Future<void> initialize() async {
    if (!_isSupportedPlatform) return;
    if (_initialized) return;

    tz_data.initializeTimeZones();

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(initSettings);

    _initialized = true;
  }

  // Sistem izin popup'ı artık burada otomatik tetiklenmiyor — kullanıcıya
  // önce neden izin istendiğini açıklayan bir ekran/dialog gösterildikten
  // sonra bu metod açıkça çağrılmalı (bkz. HomeScreen).
  Future<void> requestPermissions() async {
    if (!_isSupportedPlatform || !_initialized) return;

    if (Platform.isIOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } else if (Platform.isAndroid) {
      // Android 13 (API 33) ve üzeri: POST_NOTIFICATIONS runtime izni
      // istenmezse zamanlanan bildirimler sessizce gösterilmez.
      // Eski sürümlerde bu çağrı no-op'tur.
      await Permission.notification.request();
    }
  }

  int _notificationIdFor(String entityId, NotificationCategory category) {
    final int base = entityId.hashCode & 0x0FFFFFF;
    final int categoryOffset = category.index * 1000000;
    return categoryOffset + base;
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

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

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