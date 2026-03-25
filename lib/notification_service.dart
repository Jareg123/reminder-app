import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:home_widget/home_widget.dart';
import 'database.dart';

/// Обработчик действий из уведомления когда приложение убито
@pragma('vm:entry-point')
Future<void> onNotificationBackground(NotificationResponse details) async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.handleAction(details.id, details.actionId);
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  /// Вызывается после обработки действия — чтобы обновить список в UI
  static void Function()? onTaskUpdated;

  static const Color accentGreen = Color(0xFF10B981);

  static void _log(String msg) {
    if (kDebugMode) debugPrint('[Notify] $msg');
  }

  static Future<void> init() async {
    if (_initialized) return;

    // Шаг 1: timezone
    try {
      tz.initializeTimeZones();
      _log('Timezones loaded');
    } catch (e) {
      _log('TZ init error: $e');
    }

    // Шаг 2: локальная зона
    try {
      final offset = DateTime.now().timeZoneOffset;
      for (final loc in tz.timeZoneDatabase.locations.values) {
        try {
          if (tz.TZDateTime.now(loc).timeZoneOffset == offset) {
            tz.setLocalLocation(loc);
            _log('Local timezone: ${loc.name}');
            break;
          }
        } catch (_) {}
      }
    } catch (e) {
      _log('TZ local error: $e');
    }

    // Шаг 3: плагин
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    try {
      await _plugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (details) {
          _log('Notification tapped: ${details.id}, action: ${details.actionId}');
          if (details.actionId != null) {
            handleAction(details.id, details.actionId);
          }
        },
        onDidReceiveBackgroundNotificationResponse: onNotificationBackground,
      );
      _log('Plugin initialized');
    } catch (e) {
      _log('Plugin init FAILED: $e');
      return;
    }

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    // Шаг 4: разрешения
    try {
      final granted = await android?.requestNotificationsPermission();
      _log('Notification permission: $granted');
    } catch (e) {
      _log('Notification permission error: $e');
    }

    try {
      final granted = await android?.requestExactAlarmsPermission();
      _log('Exact alarm permission: $granted');
    } catch (e) {
      _log('Exact alarm permission error: $e');
    }

    _initialized = true;
    _log('Init complete');
  }

  static Future<void> handleAction(int? id, String? actionId) async {
    if (id == null || actionId == null) return;
    _log('Action: $actionId for #$id');

    if (actionId == 'action_done') {
      await DB.markDoneById(id);
      await DB.recordTaskCompleted();
      await safeCancel(id);
    } else if (actionId == 'action_snooze' || actionId == 'action_snooze_day') {
      final event = await DB.getById(id);
      if (event == null) return;
      final delta = actionId == 'action_snooze_day'
          ? const Duration(days: 1)
          : const Duration(hours: 1);
      final newTime = DateTime.now().add(delta);
      await DB.updateReminderAt(id, DateFormat('yyyy-MM-dd HH:mm').format(newTime));
      await safeCancel(id);
      await safeSchedule(
        id: id,
        title: 'Напоминание',
        body: event.content,
        scheduledTime: newTime,
      );
    }

    await refreshHomeWidget();
    onTaskUpdated?.call();
  }

  /// Обновляет home widget актуальными данными из БД
  static Future<void> refreshHomeWidget() async {
    try {
      final events = await DB.getAll();
      final now = DateTime.now();
      final withTime = events
          .where((e) => e.isDone == 0 && e.reminderAt != null)
          .toList()
        ..sort((a, b) => a.reminderAt!.compareTo(b.reminderAt!));
      final withoutTime = events
          .where((e) => e.isDone == 0 && e.reminderAt == null)
          .toList();
      final upcoming = [...withTime, ...withoutTime];
      final count = upcoming.length > 5 ? 5 : upcoming.length;
      final doneCount = events.where((e) => e.isDone == 1).length;
      await HomeWidget.saveWidgetData<int>('task_count', count);
      await HomeWidget.saveWidgetData<int>('done_count', doneCount);
      await HomeWidget.saveWidgetData<int>('total_count', events.length);
      for (int i = 0; i < 5; i++) {
        if (i < count) {
          final e = upcoming[i];
          await HomeWidget.saveWidgetData<int>('task_id_$i', e.id ?? 0);
          await HomeWidget.saveWidgetData<String>('task_title_$i', e.content);
          await HomeWidget.saveWidgetData<String>('task_time_$i', e.reminderAt ?? '');
          String color = '1D1D1F';
          if (e.reminderAt != null) {
            try {
              final dt = DateFormat('yyyy-MM-dd HH:mm').parse(e.reminderAt!);
              if (dt.isBefore(now)) color = 'FF6B35';
            } catch (_) {}
          }
          if (color == '1D1D1F' && e.labelColor != null) color = e.labelColor!;
          await HomeWidget.saveWidgetData<String>('task_color_$i', color);
        } else {
          await HomeWidget.saveWidgetData<int>('task_id_$i', 0);
          await HomeWidget.saveWidgetData<String>('task_title_$i', '');
          await HomeWidget.saveWidgetData<String>('task_time_$i', '');
          await HomeWidget.saveWidgetData<String>('task_color_$i', '');
        }
      }
      await HomeWidget.updateWidget(
          qualifiedAndroidName: 'com.example.reminder_app.HomeWidgetProvider');
    } catch (e) {
      debugPrint('[Widget] refresh error: $e');
    }
  }

  // ── Планирование ───────────────────────────────────────────
  static Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    await init();
    if (!_initialized) {
      _log('SKIP schedule #$id — not initialized');
      return;
    }

    if (scheduledTime.isBefore(DateTime.now())) {
      _log('SKIP schedule #$id — time in past: $scheduledTime');
      return;
    }

    tz.TZDateTime tzScheduled;
    try {
      tzScheduled = tz.TZDateTime.from(scheduledTime, tz.local);
    } catch (e) {
      _log('TZ convert error: $e, trying UTC');
      try {
        tzScheduled = tz.TZDateTime.from(scheduledTime, tz.UTC);
      } catch (e2) {
        _log('TZ UTC also failed: $e2');
        return;
      }
    }

    _log('Scheduling #$id at $tzScheduled (local: $scheduledTime)');

    const androidDetails = AndroidNotificationDetails(
      'reminders_channel',
      'Напоминания',
      channelDescription: 'Уведомления о запланированных событиях',
      importance: Importance.max,
      priority: Priority.max,
      icon: '@mipmap/ic_launcher',
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      color: accentGreen,
      colorized: true,
      playSound: true,
      enableVibration: true,
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.alarm,
      groupAlertBehavior: GroupAlertBehavior.all,
      autoCancel: true,
      actions: <AndroidNotificationAction>[
        const AndroidNotificationAction(
          'action_done',
          '✓ Выполнено',
          cancelNotification: true,
          showsUserInterface: false,
        ),
        const AndroidNotificationAction(
          'action_snooze',
          '💤 +1 час',
          cancelNotification: false,
          showsUserInterface: false,
        ),
        const AndroidNotificationAction(
          'action_snooze_day',
          '📅 +1 день',
          cancelNotification: false,
          showsUserInterface: false,
        ),
      ],
    );

    const details = NotificationDetails(android: androidDetails);

    try {
      await _plugin.zonedSchedule(
        id, title, body, tzScheduled, details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      _log('Scheduled #$id OK (exact)');
    } catch (e) {
      _log('Exact schedule failed: $e, trying inexact');
      try {
        await _plugin.zonedSchedule(
          id, title, body, tzScheduled, details,
          androidScheduleMode: AndroidScheduleMode.inexact,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
        _log('Scheduled #$id OK (inexact)');
      } catch (e2) {
        _log('BOTH schedule modes FAILED: $e2');
      }
    }
  }

  // ── Перепланировать все ────────────────────────────────────
  static Future<void> rescheduleAll(List<dynamic> events) async {
    await init();
    if (!_initialized) return;
    final now = DateTime.now();
    int count = 0;
    for (final event in events) {
      try {
        if (event.reminderAt == null || event.isDone == 1) continue;
        final dt = DateFormat('yyyy-MM-dd HH:mm').parse(event.reminderAt!);
        if (dt.isAfter(now)) {
          await safeSchedule(
            id: event.id!,
            title: 'Напоминание',
            body: event.content,
            scheduledTime: dt,
          );
          count++;
        }
      } catch (e) {
        _log('rescheduleAll error: $e');
      }
    }
    _log('Rescheduled $count events');
  }

  // ── Безопасные обёртки ────────────────────────────────────
  static Future<void> safeSchedule({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    try {
      await scheduleNotification(
          id: id, title: title, body: body, scheduledTime: scheduledTime);
    } catch (e) {
      _log('safeSchedule error: $e');
    }
  }

  static Future<void> safeCancel(int id) async {
    try {
      await cancelNotification(id);
    } catch (e) {
      _log('safeCancel error: $e');
    }
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
      priority: Priority.max,
      icon: '@mipmap/ic_launcher',
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      color: accentGreen,
      colorized: true,
      playSound: true,
      enableVibration: true,
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.alarm,
    );

    const details = NotificationDetails(android: androidDetails);
    try {
      await _plugin.show(id, title, body, details);
      _log('Instant #$id shown');
    } catch (e) {
      _log('Instant FAILED: $e');
    }
  }

  static Future<void> cancelNotification(int id) async {
    await init();
    if (!_initialized) return;
    await _plugin.cancel(id);
    _log('Cancelled #$id');
  }
}
