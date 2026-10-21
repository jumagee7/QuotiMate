// notification_service.dart — Local notifications for alarms, schedules and tasks
//
// Android: two channels (reminders / alarms). Alarms use AlarmClock scheduling
// (exempt from Doze, shown in the status bar), full-screen intent, insistent
// sound and Snooze / Dismiss actions. Reminders use exact-while-idle with an
// inexact fallback when the "Alarms & reminders" permission is denied.
// All pending reminders are re-registered on app start via [rescheduleAll].

import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  static const _remindersChannelId = 'quotimate_reminders_v3';
  static const _remindersChannelName = 'QuotiMate Reminders';
  static const _remindersChannelDesc = 'Scheduled events, task due dates and updates';
  static const _alarmsChannelId = 'quotimate_alarms_v3';
  static const _alarmsChannelName = 'QuotiMate Alarms';
  static const _alarmsChannelDesc = 'Alarm alerts for events and tasks marked with an alarm';
  static const _snoozeActionId = 'snooze_10';
  static const _dismissActionId = 'dismiss';
  static const _snoozeMinutes = 10;

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _isSupported = true;
  bool _exactAllowed = true;
  Future<void>? _initFuture;

  bool get isSupported => _isSupported;

  Future<void> init() => _initFuture ??= _init();

  Future<void> _init() async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) {
      _isSupported = false;
      _initialized = true;
      return;
    }
    try {
      tz.initializeTimeZones();
      try {
        final info = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(info.identifier));
      } catch (e) {
        debugPrint('Could not resolve local timezone, using UTC: $e');
        tz.setLocalLocation(tz.UTC);
      }

      const settings = InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );
      await _plugin.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: _onResponse,
      );
      await _createChannels();
      _initialized = true;
    } catch (e) {
      debugPrint('NotificationService init failed: $e');
      _initFuture = null;
    }
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  Future<void> _createChannels() async {
    final android = _android;
    if (android == null) return;
    await android.createNotificationChannel(const AndroidNotificationChannel(
      _remindersChannelId, _remindersChannelName,
      description: _remindersChannelDesc,
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
    ));
    await android.createNotificationChannel(const AndroidNotificationChannel(
      _alarmsChannelId, _alarmsChannelName,
      description: _alarmsChannelDesc,
      importance: Importance.max,
      enableVibration: true,
      enableLights: true,
      playSound: true,
      audioAttributesUsage: AudioAttributesUsage.alarm,
    ));
    for (final old in ['quotimate_reminders', 'quotimate_alarms', 'quotimate_reminders_v2', 'quotimate_alarms_v2']) {
      await android.deleteNotificationChannel(channelId: old);
    }
  }

  Future<void> requestPermissions() async {
    await init();
    if (!_isSupported || !_initialized) return;
    try {
      final android = _android;
      if (android != null) {
        if (await android.areNotificationsEnabled() != true) {
          await android.requestNotificationsPermission();
        }
        try {
          _exactAllowed = await android.canScheduleExactNotifications() == true;
          if (!_exactAllowed) {
            await android.requestExactAlarmsPermission();
            _exactAllowed = await android.canScheduleExactNotifications() == true;
          }
        } catch (_) {
          _exactAllowed = true; // Pre-Android 12
        }
        try {
          await android.requestFullScreenIntentPermission();
        } catch (_) {}
      }
      final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      await ios?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (e) {
      debugPrint('Notification permission request failed: $e');
    }
  }

  // ── Details ────────────────────────────────────────────────────────────────

  NotificationDetails _details({required bool alarm}) {
    final android = alarm
        ? AndroidNotificationDetails(
            _alarmsChannelId, _alarmsChannelName,
            channelDescription: _alarmsChannelDesc,
            importance: Importance.max,
            priority: Priority.max,
            icon: 'ic_notification',
            category: AndroidNotificationCategory.alarm,
            fullScreenIntent: true,
            ongoing: true,
            autoCancel: false,
            playSound: true,
            enableVibration: true,
            vibrationPattern: Int64List.fromList([0, 800, 400, 800, 400, 800]),
            audioAttributesUsage: AudioAttributesUsage.alarm,
            visibility: NotificationVisibility.public,
            additionalFlags: Int32List.fromList([4]), // FLAG_INSISTENT: repeat sound until handled
            actions: const [
              AndroidNotificationAction(_snoozeActionId, 'Snooze $_snoozeMinutes min',
                  showsUserInterface: true, cancelNotification: true),
              AndroidNotificationAction(_dismissActionId, 'Dismiss', cancelNotification: true),
            ],
          )
        : const AndroidNotificationDetails(
            _remindersChannelId, _remindersChannelName,
            channelDescription: _remindersChannelDesc,
            importance: Importance.high,
            priority: Priority.high,
            icon: 'ic_notification',
            category: AndroidNotificationCategory.reminder,
            visibility: NotificationVisibility.public,
          );
    return NotificationDetails(
      android: android,
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        interruptionLevel: alarm ? InterruptionLevel.timeSensitive : InterruptionLevel.active,
      ),
    );
  }

  /// Stable 31-bit id (FNV-1a) so the same reminder keeps the same id across restarts.
  static int notificationId(String key) {
    var hash = 0x811c9dc5;
    for (final c in key.codeUnits) {
      hash ^= c;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash & 0x7fffffff;
  }

  // ── Immediate ──────────────────────────────────────────────────────────────

  Future<void> showInstantNotification({
    required int id,
    required String title,
    required String body,
    bool alarm = false,
    String? payload,
  }) async {
    await init();
    if (!_isSupported || !_initialized) return;
    try {
      await _plugin.show(
        id: id & 0x7fffffff,
        title: title,
        body: body,
        notificationDetails: _details(alarm: alarm),
        payload: payload,
      );
    } catch (e) {
      debugPrint('Failed to show notification: $e');
    }
  }

  Future<void> showTestNotification() async {
    await showInstantNotification(
      id: notificationId('test'),
      title: 'QuotiMate notifications are working',
      body: 'Reminders and alarms will appear like this.',
    );
    await _schedule(
      key: 'test_alarm',
      title: 'QuotiMate test alarm',
      body: 'This alarm was scheduled 10 seconds ago.',
      when: DateTime.now().add(const Duration(seconds: 10)),
      alarm: true,
    );
  }

  // ── Scheduling ─────────────────────────────────────────────────────────────

  Future<void> _schedule({
    required String key,
    required String title,
    required String body,
    required DateTime when,
    bool alarm = false,
  }) async {
    await init();
    if (!_isSupported || !_initialized) return;
    if (!when.isAfter(DateTime.now())) return;

    final id = notificationId(key);
    final date = tz.TZDateTime.from(when, tz.local);
    final modes = <AndroidScheduleMode>[
      if (alarm) AndroidScheduleMode.alarmClock,
      if (_exactAllowed) AndroidScheduleMode.exactAllowWhileIdle,
      AndroidScheduleMode.inexactAllowWhileIdle,
    ];
    for (final mode in modes) {
      try {
        await _plugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: date,
          notificationDetails: _details(alarm: alarm),
          androidScheduleMode: mode,
          payload: '$key|$title|$body|${alarm ? 1 : 0}',
        );
        return;
      } catch (e) {
        debugPrint('Scheduling $key with $mode failed: $e');
      }
    }
  }

  /// Task / generic reminder: 1 hour before (when there's time) and at the due time.
  Future<void> scheduleEventReminder({
    required String id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    bool alarm = false,
  }) async {
    final before = scheduledTime.subtract(const Duration(hours: 1));
    if (before.isAfter(DateTime.now())) {
      await _schedule(
        key: '${id}_before',
        title: title,
        body: 'Due in 1 hour${body.isNotEmpty ? ' — $body' : ''}',
        when: before,
      );
    }
    await _schedule(key: '${id}_start', title: title, body: body, when: scheduledTime, alarm: alarm);
  }

  /// Calendar event: morning-of summary, N minutes before, and at start.
  Future<void> scheduleEventReminders({
    required String id,
    required String title,
    required String description,
    required DateTime startTime,
    int minutesBefore = 15,
    bool alarm = false,
  }) async {
    await cancelReminder(id);
    final morning = DateTime(startTime.year, startTime.month, startTime.day, 7);
    if (morning.isBefore(startTime.subtract(Duration(minutes: minutesBefore)))) {
      await _schedule(
        key: '${id}_day',
        title: 'Today: $title',
        body: 'Scheduled at ${_formatTime(startTime)}${description.isNotEmpty ? ' — $description' : ''}',
        when: morning,
      );
    }
    await _schedule(
      key: '${id}_before',
      title: 'Starting soon: $title',
      body: 'Starts in $minutesBefore minutes (${_formatTime(startTime)})',
      when: startTime.subtract(Duration(minutes: minutesBefore)),
    );
    await _schedule(
      key: '${id}_start',
      title: title,
      body: description.isNotEmpty ? description : 'Starting now',
      when: startTime,
      alarm: alarm,
    );
  }

  /// Re-registers every future reminder (call after loading data on app start,
  /// e.g. after an update or when permissions were granted later).
  Future<void> rescheduleAll({required List<AppTask> tasks, required List<AppEvent> events}) async {
    await init();
    if (!_isSupported || !_initialized) return;
    final now = DateTime.now();
    for (final t in tasks) {
      if (t.status == TaskStatus.done || t.dueDate.isBefore(now)) continue;
      await scheduleEventReminder(
        id: t.id, title: 'Task Due: ${t.title}', body: t.description,
        scheduledTime: t.dueDate, alarm: t.alarmEnabled,
      );
    }
    for (final e in events) {
      if (e.startTime.isBefore(now)) continue;
      await scheduleEventReminders(
        id: e.id, title: e.title, description: e.description,
        startTime: e.startTime, alarm: e.alarmEnabled,
      );
    }
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  void _onResponse(NotificationResponse response) {
    final parts = (response.payload ?? '').split('|');
    if (response.actionId == _snoozeActionId && parts.length >= 4) {
      _schedule(
        key: '${parts[0]}_snooze',
        title: parts[1],
        body: parts[2],
        when: DateTime.now().add(const Duration(minutes: _snoozeMinutes)),
        alarm: parts[3] == '1',
      );
    }
  }

  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  Future<void> cancelReminder(String id) async {
    if (!_isSupported || !_initialized) return;
    for (final suffix in ['_day', '_before', '_start', '_snooze']) {
      await _plugin.cancel(id: notificationId('$id$suffix'));
    }
  }

  Future<void> cancelAllReminders() async {
    if (!_isSupported || !_initialized) return;
    await _plugin.cancelAll();
  }
}
