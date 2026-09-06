// notification_service.dart — Handles local push notifications for events/tasks

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'dart:io' show Platform;

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _isSupported = true;
  bool _permissionsGranted = false;

  Future<void> init() async {
    if (_initialized) return;

    if (kIsWeb || Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      _isSupported = false;
      _initialized = true;
      debugPrint('Local notifications not supported on desktop/web natively without extra config. Skipping.');
      return;
    }

    try {
      tz.initializeTimeZones();
      
      try {
        final tzInfo = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
        debugPrint('Timezone set to: ${tzInfo.identifier}');
      } catch (e) {
        debugPrint('Could not set local timezone: $e');
        tz.setLocalLocation(tz.UTC); // Fallback
      }

      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
      );

      await _localNotifications.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: (details) {
          debugPrint('Notification tapped: ${details.payload}');
          // Handle notification tap if needed
        },
      );

      // Create notification channel for Android 8.0+
      await _createNotificationChannel();

      _initialized = true;
      debugPrint('NotificationService initialized successfully');
    } catch (e) {
      debugPrint('NotificationService init failed: $e');
      _initialized = false;
    }
  }

  Future<void> _createNotificationChannel() async {
    if (!Platform.isAndroid) return;
    
    final androidImplementation =
        _localNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidImplementation != null) {
      // NOTE: Android freezes channel settings (importance, sound) once created.
      // These _v2 IDs guarantee fresh settings on devices where earlier builds
      // created the old channels with lower importance / no alarm sound.
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'quotimate_reminders_v2',
        'QuotiMate Reminders',
        description: 'Notifications for scheduled events and tasks',
        importance: Importance.max,
        enableVibration: true,
        enableLights: true,
        playSound: true,
      );

      await androidImplementation.createNotificationChannel(channel);
      debugPrint('Notification channel created: quotimate_reminders_v2');

      const AndroidNotificationChannel alarmChannel = AndroidNotificationChannel(
        'quotimate_alarms_v2',
        'QuotiMate Alarms',
        description: 'Alarm alerts for events and tasks marked with an alarm',
        importance: Importance.max,
        enableVibration: true,
        enableLights: true,
        playSound: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
      );

      await androidImplementation.createNotificationChannel(alarmChannel);
      debugPrint('Notification channel created: quotimate_alarms_v2');

      // Clean up channels created by earlier builds so they don't linger.
      await androidImplementation.deleteNotificationChannel(channelId: 'quotimate_reminders');
      await androidImplementation.deleteNotificationChannel(channelId: 'quotimate_alarms');
    }
  }

  Future<void> requestPermissions() async {
    if (!_initialized) await init();
    if (!_isSupported) return;

    try {
      final androidImplementation =
          _localNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        // Only show the runtime dialog if notifications are currently disabled.
        final alreadyEnabled = await androidImplementation.areNotificationsEnabled() == true;
        final granted = alreadyEnabled
            ? true
            : await androidImplementation.requestNotificationsPermission();

        // Exact alarms: only open the system "Alarms & reminders" screen when
        // the special permission is actually missing, otherwise skip.
        bool exactOk = false;
        try {
          exactOk = await androidImplementation.canScheduleExactNotifications() == true;
        } catch (_) {
          exactOk = true; // Pre-Android 12: always allowed
        }
        if (!exactOk) {
          await androidImplementation.requestExactAlarmsPermission();
          try {
            exactOk = await androidImplementation.canScheduleExactNotifications() == true;
          } catch (_) {}
        }

        _permissionsGranted = granted == true;

        debugPrint('Notification permission granted: $granted');
        debugPrint('Exact alarm permission granted: $exactOk');
        debugPrint('Permissions fully granted: $_permissionsGranted');

        if (!_permissionsGranted) {
          debugPrint('WARNING: Notifications may not work without proper permissions');
        }
      }
    } catch (e) {
      debugPrint('Failed to request notification permissions: $e');
    }
  }

  Future<void> showTestNotification() async {
    if (!_initialized) await init();
    if (!_isSupported) return;
    
    try {
      const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
        'quotimate_reminders_v2',
        'QuotiMate Reminders',
        channelDescription: 'Notifications for scheduled events and tasks',
        importance: Importance.max,
        priority: Priority.max,
        icon: 'ic_notification',
      );
      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
      );

      await _localNotifications.show(
        id: 0,
        title: 'Test Notification',
        body: 'This is a test notification from QuotiMate',
        notificationDetails: platformChannelSpecifics,
      );
      debugPrint('Test notification shown');
    } catch (e) {
      debugPrint('Failed to show test notification: $e');
    }
  }

  Future<void> showInstantNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_initialized) await init();
    if (!_isSupported) return;

    try {
      const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
        'quotimate_reminders_v2',
        'QuotiMate Reminders',
        channelDescription: 'Notifications for scheduled events and tasks',
        importance: Importance.max,
        priority: Priority.max,
        icon: 'ic_notification',
      );
      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
      );

      await _localNotifications.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: platformChannelSpecifics,
      );
    } catch (e) {
      debugPrint('Failed to show instant notification: $e');
    }
  }

  int _generateId(String stringId, {String suffix = ''}) {
    // Generate a unique integer ID from a string ID (like 'e1' or 't2')
    return '${stringId}$suffix'.hashCode;
  }

  Future<void> scheduleEventReminder({
    required String id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    bool alarm = false,
  }) async {
    // Schedule notification at exact time (when session starts)
    await _scheduleSingleReminder(
      id: id,
      suffix: '_start',
      title: title,
      body: body,
      scheduledTime: scheduledTime,
      alarm: alarm,
    );
  }

  Future<void> scheduleEventReminders({
    required String id,
    required String title,
    required String description,
    required DateTime startTime,
    int minutesBefore = 15,
    bool alarm = false,
  }) async {
    if (!_initialized) await init();
    if (!_isSupported) return;

    // 1. Notification when the day has come (at midnight on the day of the event)
    final dayStart = DateTime(startTime.year, startTime.month, startTime.day, 0, 0);
    if (dayStart.isAfter(DateTime.now())) {
      await _scheduleSingleReminder(
        id: id,
        suffix: '_day',
        title: 'Upcoming Event Today',
        body: '$title is scheduled for today at ${_formatTime(startTime)}',
        scheduledTime: dayStart,
        alarm: alarm,
      );
    }

    // 2. Notification when the event is about to start (X minutes before)
    final beforeStart = startTime.subtract(Duration(minutes: minutesBefore));
    if (beforeStart.isAfter(DateTime.now())) {
      await _scheduleSingleReminder(
        id: id,
        suffix: '_before',
        title: 'Event Starting Soon',
        body: '$title starts in $minutesBefore minutes',
        scheduledTime: beforeStart,
        alarm: alarm,
      );
    }

    // 3. Notification when the event starts
    await _scheduleSingleReminder(
      id: id,
      suffix: '_start',
      title: 'Event Starting Now',
      body: '$title is starting now',
      scheduledTime: startTime,
      alarm: alarm,
    );
  }

  Future<void> _scheduleSingleReminder({
    required String id,
    required String suffix,
    required String title,
    required String body,
    required DateTime scheduledTime,
    bool alarm = false,
  }) async {
    if (!_initialized) await init();
    if (!_isSupported) return;

    if (scheduledTime.isBefore(DateTime.now())) {
      debugPrint('Skipping notification for $id - scheduled time is in the past');
      return; // Do not schedule in the past
    }

    final tzDateTime = tz.TZDateTime.from(scheduledTime, tz.local);
    debugPrint('Scheduling notification for $id at $scheduledTime (local: $tzDateTime, alarm: $alarm)');

    final AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      alarm ? 'quotimate_alarms_v2' : 'quotimate_reminders_v2',
      alarm ? 'QuotiMate Alarms' : 'QuotiMate Reminders',
      channelDescription: alarm
          ? 'Alarm alerts for events and tasks marked with an alarm'
          : 'Notifications for scheduled events and tasks',
      importance: Importance.max,
      priority: Priority.max,
      icon: 'ic_notification',
      enableVibration: true,
      enableLights: true,
      playSound: true,
      category: alarm ? AndroidNotificationCategory.alarm : AndroidNotificationCategory.reminder,
      fullScreenIntent: alarm,
      audioAttributesUsage: alarm ? AudioAttributesUsage.alarm : AudioAttributesUsage.notification,
    );
    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    final int notificationId = _generateId(id, suffix: suffix);

    try {
      await _localNotifications.zonedSchedule(
        id: notificationId,
        title: title,
        body: body,
        scheduledDate: tzDateTime,
        notificationDetails: platformChannelSpecifics,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: null, // one-off alarm
      );
      debugPrint('Successfully scheduled notification for $id (suffix: $suffix)');
    } catch (e) {
      // Exact alarms can fail when the "Alarms & reminders" special permission
      // is denied. Fall back to inexact so the reminder still fires.
      debugPrint('Exact scheduling failed for $id, falling back to inexact: $e');
      try {
        await _localNotifications.zonedSchedule(
          id: notificationId,
          title: title,
          body: body,
          scheduledDate: tzDateTime,
          notificationDetails: platformChannelSpecifics,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: null,
        );
        debugPrint('Scheduled inexact notification for $id (suffix: $suffix)');
      } catch (e2) {
        debugPrint('Failed to schedule notification for $id: $e2');
      }
    }
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> cancelReminder(String id) async {
    if (!_initialized) return;
    if (!_isSupported) return;
    // Cancel all reminders for this ID (day, before, start)
    await _localNotifications.cancel(id: _generateId(id, suffix: '_day'));
    await _localNotifications.cancel(id: _generateId(id, suffix: '_before'));
    await _localNotifications.cancel(id: _generateId(id, suffix: '_start'));
  }

  Future<void> cancelAllReminders() async {
    if (!_initialized) return;
    if (!_isSupported) return;
    await _localNotifications.cancelAll();
  }
}
