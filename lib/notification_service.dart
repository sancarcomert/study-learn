import 'dart:io' show Platform;

import 'package:flutter/services.dart' show PlatformException;
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
  focusSession,
  // Sona eklendi: enum index kanal/bildirim id hesaplamasında kullanılıyor
  // (bkz. _notificationIdFor) — araya eklemek mevcut kategorilerin id'sini
  // kaydırırdı.
  focusOngoing,
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

  // Android 12+ (S) itibarıyla SCHEDULE_EXACT_ALARM ayrı bir "özel erişim"
  // izni — POST_NOTIFICATIONS'ın aksine normal bir izin popup'ı yok,
  // isteği doğrudan sistem Ayarlar ekranına yönlendirir. Android 13+'ta
  // (Play Store'a yeni yüklenen normal uygulamalarda) varsayılan olarak
  // VERİLMEZ; istenmeden `scheduleNotification(exact: true)` çağrısı
  // sessizce (unhandled ama çökmeyen) başarısız olur — bkz. cihaz testi.
  //
  // `permission_handler`'ın Permission.scheduleExactAlarm.isGranted'i
  // cihazda YANLIŞ POZİTİF verdi (izin kapalıyken "açık" dedi, gerçek neden
  // buydu: kullanıcıya soru hiç çıkmadı çünkü kod zaten "izin var" sanıyordu).
  // flutter_local_notifications'ın Android'e özel, AlarmManager'ı doğrudan
  // sorgulayan metodları kullanılıyor — bu paket zaten bağımlılığımız,
  // gerçek/güvenilir sonuç veriyor.
  Future<bool> hasExactAlarmPermission() async {
    if (!Platform.isAndroid) return true;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await android?.canScheduleExactNotifications() ?? false;
  }

  Future<void> requestExactAlarmPermission() async {
    if (!Platform.isAndroid) return;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestExactAlarmsPermission();
  }

  // Ana ekrandaki/odak ekranındaki izin sorusu kullanıcı başına yalnızca BİR
  // KEZ çıkıyor (bkz. hasSeenNotificationPrompt/hasSeenExactAlarmPrompt) —
  // "Şimdi Değil" denirse ya da sistem popup'ı reddedilirse bir daha asla
  // sorulmuyordu, bildirimler kalıcı ve sessizce kapalı kalıyordu. Profil
  // ekranındaki canlı durum satırı bu ikisini okuyup gerektiğinde tekrar
  // istemek/Ayarlar'a yönlendirmek için kullanır.
  Future<bool> hasNotificationPermission() async {
    if (!_isSupportedPlatform) return true;
    if (Platform.isIOS) return true; // iOS kendi ayar akışını yönetir.
    return Permission.notification.isGranted;
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
    bool exact = false,
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

    final tz.TZDateTime scheduled =
        tz.TZDateTime.from(dateTime.toUtc(), tz.UTC);

    try {
      await _plugin.zonedSchedule(
        notificationId,
        title,
        body,
        scheduled,
        details,
        androidScheduleMode: exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } on PlatformException catch (e) {
      // SCHEDULE_EXACT_ALARM verilmemişse (Android 13+ varsayılanı) exact
      // mod bu koduyla başarısız olur — bildirim hiç gitmemek yerine
      // inexact moda düşsün (birkaç dakika sapabilir ama en azından gelir).
      if (exact && e.code == 'exact_alarms_not_permitted') {
        await _plugin.zonedSchedule(
          notificationId,
          title,
          body,
          scheduled,
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } else {
        rethrow;
      }
    }
  }

  Future<void> cancelNotification(
    String id,
    NotificationCategory category,
  ) async {
    if (!_isSupportedPlatform) return;
    await _plugin.cancel(_notificationIdFor(id, category));
  }

  static const String _ongoingFocusId = 'focus_ongoing';

  /// Odak seansı arka plandayken gösterilen, sessiz ve kalıcı ("ongoing")
  /// bildirim — Android'in native chronometer'ı kullanır (`when`'den itibaren
  /// kendi kendine saniyede bir günceller, bizim tarafımızdan periyodik
  /// güncelleme gerekmez). Rakiplerin en çok övülen özelliği ("uygulama
  /// kapalıyken de sayıyor") görsel karşılığı — önceden yalnızca hedef anında
  /// TEK SEFERLİK bir bildirim vardı, arada uygulama arka plandayken hiçbir
  /// ambient gösterge yoktu. Yalnızca Android'e özel: iOS'ta bu API'nin
  /// (ongoing + chronometer) karşılığı yok.
  ///
  /// [countDown] false ise (Serbest mod) [when] geçmişte bir an — sayaç o
  /// andan bu yana geçen süreyi YUKARI sayar. true ise (Pomodoro fazı)
  /// [when] gelecekte bir an — sayaç o ana kadar kalan süreyi AŞAĞI sayar.
  Future<void> showOngoingFocus({
    required String title,
    required String body,
    required DateTime when,
    required bool countDown,
  }) async {
    if (!Platform.isAndroid || !_initialized) return;
    final androidDetails = AndroidNotificationDetails(
      _channelIdFor(NotificationCategory.focusOngoing),
      _channelNameFor(NotificationCategory.focusOngoing),
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      onlyAlertOnce: true,
      playSound: false,
      enableVibration: false,
      showWhen: true,
      usesChronometer: true,
      chronometerCountDown: countDown,
      when: when.millisecondsSinceEpoch,
    );
    await _plugin.show(
      _notificationIdFor(_ongoingFocusId, NotificationCategory.focusOngoing),
      title,
      body,
      NotificationDetails(android: androidDetails),
    );
  }

  Future<void> cancelOngoingFocus() async {
    if (!Platform.isAndroid) return;
    await _plugin.cancel(
      _notificationIdFor(_ongoingFocusId, NotificationCategory.focusOngoing),
    );
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
      case NotificationCategory.focusSession:
        return 'focus_session_channel';
      case NotificationCategory.focusOngoing:
        return 'focus_ongoing_channel';
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
        return 'Seri Uyarıları';
      case NotificationCategory.aiSuggestion:
        return 'Öneriler';
      case NotificationCategory.focusSession:
        return 'Odak Seansı';
      case NotificationCategory.focusOngoing:
        return 'Odak Durumu';
    }
  }
}
