import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter/material.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static const Color accentGreen = Color(0xFF10B981);

  // ── Инициализация ──────────────────────────────────────────
  static Future<void> init() async {
    if (_initialized) return;

    try {
      tz.initializeTimeZones();
    } catch (_) {}

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    try {
      await _plugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (details) {},
      );
    } catch (_) {
      return; // не крашим приложение если плагин недоступен
    }

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    // Запрашиваем разрешения (молча — в релизе могут быть недоступны)
    try { await android?.requestNotificationsPermission(); } catch (_) {}
    try { await android?.requestExactAlarmsPermission(); } catch (_) {}
    try { await android?.requestFullScreenIntentPermission(); } catch (_) {}

    _initialized = true;
  }

  // ── Планирование уведомления ───────────────────────────────
  static Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    await init();
    if (!_initialized) return;
    if (scheduledTime.isBefore(DateTime.now())) return;

    tz.TZDateTime tzScheduled;
    try {
      tzScheduled = tz.TZDateTime.from(scheduledTime, tz.local);
    } catch (_) {
      // Фолбэк на UTC если local timezone недоступен
      try {
        tzScheduled = tz.TZDateTime.from(scheduledTime, tz.UTC);
      } catch (_) {
        return;
      }
    }

    const androidDetails = AndroidNotificationDetails(
      'reminders_channel',
      'Напоминания',
      channelDescription: 'Уведомления о запланированных событиях',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      color: accentGreen,
      colorized: true,
      playSound: true,
      enableVibration: true,
      fullScreenIntent: true,
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.alarm,
      groupAlertBehavior: GroupAlertBehavior.all,
      autoCancel: true,
    );

    const details = NotificationDetails(android: androidDetails);

    // Пробуем exactAllowWhileIdle, при отказе — inexact (без точного будильника)
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tzScheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {
      try {
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          tzScheduled,
          details,
          androidScheduleMode: AndroidScheduleMode.inexact,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } catch (_) {
        // Уведомления недоступны — не крашим приложение
      }
    }
  }

  // ── Безопасная обёртка для вызова из _save / _toggleDone ──
  static Future<void> safeSchedule({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    try {
      await scheduleNotification(
          id: id, title: title, body: body, scheduledTime: scheduledTime);
    } catch (_) {}
  }

  // ── Безопасная отмена ─────────────────────────────────────
  static Future<void> safeCancel(int id) async {
    try {
      await cancelNotification(id);
    } catch (_) {}
  }

  /// Мгновенное уведомление (для тестов)
  static Future<void> showInstant({
    required int id,
    required String title,
    required String body,
  }) async {
    await init();
    if (!_initialized) return;

    const androidDetails = AndroidNotificationDetails(
      'reminders_channel',
      'Напоминания',
      channelDescription: 'Уведомления о запланированных событиях',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      color: accentGreen,
      colorized: true,
      playSound: true,
      enableVibration: true,
      fullScreenIntent: true,
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.alarm,
    );

    const details = NotificationDetails(android: androidDetails);
    try {
      await _plugin.show(id, title, body, details);
    } catch (_) {}
  }

  static Future<void> cancelNotification(int id) async {
    await init();
    if (!_initialized) return;
    await _plugin.cancel(id);
  }
}
