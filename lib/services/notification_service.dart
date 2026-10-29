// notification_service.dart — Handles local push notifications for events/tasks

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'dart:async';
import 'dart:io' show Platform;
import 'dart:typed_data';

/// `Notification.FLAG_INSISTENT`: keeps the alarm sound looping until the
/// notification is dismissed, so an alarm cannot buzz once and vanish.
const int _flagInsistent = 4;

enum ArmStatus {
  /// At least one alert was handed to Android successfully.
  armed,
  /// Every target timestamp is already behind the clock.
  past,
  /// Android refused to accept the alarm; [ArmResult.detail] carries why.
  rejected,
  /// This platform has no local notification support configured.
  unsupported,
}

class ArmResult {
  const ArmResult(this.status, {this.detail});
  final ArmStatus status;
  final String? detail;
  bool get armed => status == ArmStatus.armed;
}

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _isSupported = true;
  bool _permissionsGranted = false;
  String? _initError;
  String? _lastError;

  /// Why the most recent device alert failed, or null when the last one worked.
  String? get lastError => _lastError;

  final StreamController<String> _tapController = StreamController<String>.broadcast();
  String? _pendingTap;

  /// Emits the payload (`task:<id>` / `event:<id>`, with `:alarm` appended for
  /// an actual alarm) of a tapped notification.
  Stream<String> get onNotificationTap => _tapController.stream;

  /// Resolved name of the drawable used as the notification small icon.
  /// Android looks this up with `getIdentifier(..., "drawable", ...)`, so it
  /// must be a bare resource name.
  String get smallIcon => _smallIcon;

  /// Set when `initialize()` threw — alerts cannot be posted until this clears.
  String? get initError => _initError;

  /// Resource names tried in order for the small icon. `ic_notification` ships
  /// in the density buckets; `splash_logo` also exists in plain `drawable/`.
  static const List<String> _iconCandidates = ['ic_notification', 'splash_logo'];
  String _smallIcon = 'ic_notification';

  /// Returns the most recent tap payload and clears it. Needed for cold starts:
  /// the tap arrives during initialize(), before the shell has subscribed.
  String? takePendingTap() {
    final payload = _pendingTap;
    _pendingTap = null;
    return payload;
  }

  Future<void> init({
    DidReceiveBackgroundNotificationResponseCallback? onBackground,
  }) async {
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

      // Must be a bare resource name: the native side resolves it via
      // getIdentifier(), so an '@drawable/' prefix fails and aborts initialize().
      Object? lastError;
      for (final icon in _iconCandidates) {
        try {
          final AndroidInitializationSettings initializationSettingsAndroid =
              AndroidInitializationSettings(icon);

          await _localNotifications.initialize(
            settings: InitializationSettings(android: initializationSettingsAndroid),
            onDidReceiveNotificationResponse: (details) {
              final payload = details.payload;
              debugPrint('Notification tapped: $payload');
              if (payload != null && payload.isNotEmpty) {
                // Only queue when nobody is listening yet (cold start); a live shell
                // handles the tap through the stream and must not see it twice.
                if (!_tapController.hasListener) _pendingTap = payload;
                _tapController.add(payload);
              }
            },
            // REQUIRED for background/killed app: without this top-level entry point
            // the plugin cannot wake a Dart isolate to handle alarm actions when the
            // app is not in the foreground.
            onDidReceiveBackgroundNotificationResponse: onBackground,
          );
          _smallIcon = icon;
          lastError = null;
          break;
        } catch (e) {
          lastError = e;
          debugPrint('Notification initialize() failed with icon "$icon": $e');
        }
      }
      if (lastError != null) throw Exception('plugin initialize failed: $lastError');
      debugPrint('Notification small icon resolved: $_smallIcon');

      // Create notification channel for Android 8.0+
      await _createNotificationChannel();

      // A tap that cold-started the app is reported before the shell can
      // subscribe to the stream, so read the launch response once here.
      final launch = await _localNotifications.getNotificationAppLaunchDetails();
      final launchPayload = launch?.notificationResponse?.payload;
      if (launch?.didNotificationLaunchApp == true &&
          (launchPayload ?? '').isNotEmpty) {
        _pendingTap = launchPayload;
      }

      _initialized = true;
      _initError = null;
      debugPrint('NotificationService initialized successfully');
    } catch (e) {
      _initError = e.toString();
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

      // v3 is a fresh channel because Android freezes channel settings after
      // creation: v2 devices would otherwise keep a channel that was muted or
      // downgraded by an earlier build.
      final AndroidNotificationChannel alarmChannel = AndroidNotificationChannel(
        'quotimate_alarms_v3',
        'QuotiMate Alarms',
        description: 'Full-screen alarms that ring and vibrate until stopped',
        importance: Importance.max,
        enableVibration: true,
        vibrationPattern: Int64List.fromList(<int>[
          0, 900, 500, 900, 500, 900, 500, 900, 500, 900, 500, 900,
        ]),
        enableLights: true,
        playSound: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        showBadge: true,
      );

      await androidImplementation.createNotificationChannel(alarmChannel);
      debugPrint('Notification channel created: quotimate_alarms_v3');

      // Silent channel used for APK download progress bars.
      const AndroidNotificationChannel downloadChannel = AndroidNotificationChannel(
        'quotimate_downloads',
        'QuotiMate Downloads',
        description: 'APK update download progress',
        importance: Importance.low,
        enableVibration: false,
        playSound: false,
      );
      await androidImplementation.createNotificationChannel(downloadChannel);
      debugPrint('Notification channel created: quotimate_downloads');

      // Clean up channels created by earlier builds so they don't linger.
      // Deleting `quotimate_alarms_v2` drops notifications queued against it;
      // the next reschedule re-arms them on v3.
      await androidImplementation.deleteNotificationChannel(channelId: 'quotimate_reminders');
      await androidImplementation.deleteNotificationChannel(channelId: 'quotimate_alarms');
      await androidImplementation.deleteNotificationChannel(channelId: 'quotimate_alarms_v2');
    }
  }

  Future<void> requestPermissions({bool askFullScreen = false}) async {
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

        // Android 14+ revokes full-screen intents for apps that are not alarm
        // or calling apps. Without it an alarm can only post a heads-up card.
        // This opens a settings screen, so only ask when the caller asked us to
        // (the alarm settings section) instead of stacking it onto app launch.
        bool fullScreenOk = true;
        if (askFullScreen) {
          try {
            fullScreenOk = await androidImplementation.requestFullScreenIntentPermission() ?? true;
          } catch (e) {
            debugPrint('Full-screen intent permission request failed: $e');
          }
        }

        _permissionsGranted = granted == true;

        debugPrint('Notification permission granted: $granted');
        debugPrint('Exact alarm permission granted: $exactOk');
        debugPrint('Full-screen alarm permission granted: $fullScreenOk');
        debugPrint('Permissions fully granted: $_permissionsGranted');

        if (!_permissionsGranted) {
          debugPrint('WARNING: Notifications may not work without proper permissions');
        }

        // Auto-request battery optimization exclusion on the same call so the
        // user does not need to manually visit Settings. On most OEMs (Samsung,
        // Huawei, Xiaomi, Oppo) battery optimisation is the primary reason
        // background alarms are dropped silently. We only show the dialog when
        // the app is not already excluded.
        try {
          final bool alreadyExcluded = await isIgnoringBatteryOptimizations();
          if (!alreadyExcluded) {
            debugPrint('Battery optimizations active — requesting exclusion for background alarms');
            await requestIgnoreBatteryOptimizations();
          } else {
            debugPrint('Battery optimizations already disabled for this app');
          }
        } catch (e) {
          debugPrint('Battery optimization check/request failed: $e');
        }
      }
    } catch (e) {
      debugPrint('Failed to request notification permissions: $e');
    }
  }

  /// OS-level switches that stop alerts without the app failing loudly.
  /// Returns null when they cannot be read (non-Android).
  Future<String?> diagnosticSummary() async {
    if (!_initialized) await init();
    if (!_isSupported) return null;

    final android = _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return null;

    final allowed = await android.areNotificationsEnabled() ?? false;
    bool exactAllowed;
    try {
      exactAllowed = await android.canScheduleExactNotifications() ?? false;
    } catch (_) {
      exactAllowed = true; // Pre-Android 12 always permits exact alarms.
    }

    // Battery optimisation status — the #1 silent killer of background alarms
    // on OEM devices (Samsung, Huawei, Xiaomi, Oppo, Vivo).
    bool batteryExcluded = true;
    try {
      batteryExcluded = await isIgnoringBatteryOptimizations();
    } catch (_) {}

    // Counts what Android itself is holding; zero means the app never handed an
    // alarm over, which is a different fault than a blocked channel.
    String armed = 'no alerts queued with Android';
    try {
      final pending = await _localNotifications.pendingNotificationRequests();
      if (pending.isNotEmpty) armed = '${pending.length} alert(s) queued with Android';
    } catch (_) {}

    // A channel the user muted in Android settings keeps accepting posts while
    // silently dropping them, which looks exactly like "alerts only work while
    // the app is open".
    var alarmChannel = 'alarm channel not found';
    try {
      final channels = await android.getNotificationChannels();
      final channel =
          channels?.where((c) => c.id == _alarmChannelId).firstOrNull;
      if (channel != null) {
        alarmChannel = channel.importance == Importance.none
            ? 'BLOCKED: the QuotiMate Alarms channel is muted in Android settings'
            : 'alarm channel active';
      }
    } catch (_) {}

    final plugin = !_initialized ? 'PLUGIN OFFLINE: $_initError · ' : '';
    final batteryStatus = batteryExcluded
        ? 'battery optimization excluded'
        : 'DEGRADED: battery optimization active (background alarms may be delayed or dropped)';
    return '$plugin'
        '${allowed ? 'Notifications allowed' : 'BLOCKED: notifications are switched off for QuotiMate'}'
        ' · ${exactAllowed ? 'exact alarms allowed' : 'DEGRADED: Android denies exact alarms, alerts can be late'}'
        ' · $alarmChannel · $armed · $batteryStatus · icon: $_smallIcon';
  }

  static const String _alarmChannelId = 'quotimate_alarms_v3';

  AndroidNotificationDetails _reminderDetails() => AndroidNotificationDetails(
        'quotimate_reminders_v2',
        'QuotiMate Reminders',
        channelDescription: 'Notifications for scheduled events and tasks',
        importance: Importance.max,
        priority: Priority.max,
        icon: _smallIcon,
        enableVibration: true,
        playSound: true,
      );

  /// An alarm card that stays on screen: `ongoing` blocks swiping it away, the
  /// insistent flag loops the sound, and the "Stop alarm" action cancels it.
  /// [buzz] false degrades it to a loud but ordinary reminder.
  AndroidNotificationDetails _alarmDetails({required bool buzz}) {
    return AndroidNotificationDetails(
      _alarmChannelId,
      'QuotiMate Alarms',
      channelDescription: 'Full-screen alarms that ring and vibrate until stopped',
      importance: Importance.max,
      priority: Priority.max,
      icon: _smallIcon,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      enableVibration: buzz,
      vibrationPattern: buzz
          ? Int64List.fromList(<int>[0, 900, 500, 900, 500, 900, 500, 900])
          : null,
      playSound: true,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      fullScreenIntent: buzz,
      ongoing: buzz,
      autoCancel: !buzz,
      ticker: 'Alarm',
      additionalFlags: buzz ? Int32List.fromList(<int>[_flagInsistent]) : null,
      actions: buzz
          ? const <AndroidNotificationAction>[
              AndroidNotificationAction(
                'dismiss_alarm',
                'Stop alarm',
                cancelNotification: true,
                showsUserInterface: false,
              ),
            ]
          : null,
    );
  }

  /// Fires an alarm immediately so the user can verify on the device that it
  /// rings, vibrates, and cannot be swiped away.
  Future<String> showTestAlarm({bool buzz = true}) async {
    await init();
    if (!_isSupported) return 'This platform has no local notification support.';
    if (!_initialized) return 'Notification plugin failed to start: $_initError';

    try {
      await _localNotifications.show(
        id: _testAlarmId,
        title: buzz ? 'Test alarm' : 'Test notification',
        body: buzz
            ? 'Ringing until you tap Stop alarm — swipe will not dismiss it.'
            : 'Alarm buzz is off, so this is an ordinary notification.',
        notificationDetails: NotificationDetails(android: _alarmDetails(buzz: buzz)),
      );
      _lastError = null;
      return buzz
          ? 'Alarm posted — it rings and vibrates until you tap Stop alarm.'
          : 'Notification posted (alarm buzz is off).';
    } catch (e) {
      _lastError = e.toString();
      return 'Android rejected the alarm: $e';
    }
  }

  static const int _testAlarmId = 900002;

  /// Posts an immediate alert and reports whether Android really displayed it,
  /// so the Settings test button cannot pass while device alerts are broken.
  Future<String> showTestNotification() async {
    await init();
    if (!_isSupported) return 'This platform has no local notification support.';
    if (!_initialized) return 'Notification plugin failed to start: $_initError';

    final access = await diagnosticSummary();
    try {
      await _localNotifications.show(
        id: _testNotificationId,
        title: 'Test Notification',
        body: 'This is a test notification from QuotiMate',
        notificationDetails: NotificationDetails(android: _reminderDetails()),
      );
    } catch (e) {
      _lastError = e.toString();
      return 'Android rejected the alert: $e · $access';
    }

    // The shelf posts asynchronously, so re-read the active list a few times
    // before concluding anything about whether the alert is on screen.
    for (var attempt = 0; attempt < 6; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      try {
        final active = await _localNotifications.getActiveNotifications();
        if (active.any((n) => n.id == _testNotificationId)) {
          _lastError = null;
          return 'Device alert displayed (icon: $_smallIcon) · $access';
        }
      } catch (_) {
        break;
      }
    }
    _lastError = 'show() returned success but the alert is not in the active list';
    return 'Android accepted the alert but did not display it — '
        'open System Settings and check the QuotiMate Reminders channel. · $access'
        '${_initError == null ? '' : ' · init: $_initError'}';
  }

  static const int _testNotificationId = 900001;

  static const MethodChannel _deviceChannel =
      MethodChannel('com.majumaink.quotimate/device_settings');

  /// Returns true if Android allows this app to schedule exact alarms.
  Future<bool> canScheduleExactAlarms() async {
    if (!Platform.isAndroid) return true;
    final android = _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return false;
    try {
      return await android.canScheduleExactNotifications() ?? false;
    } catch (_) {
      return true; // Pre-Android 12
    }
  }

  /// Opens the system "Alarms & Reminders" special access screen for QuotiMate.
  Future<void> openExactAlarmSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _deviceChannel.invokeMethod('openExactAlarmSettings');
    } catch (_) {
      final android = _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestExactAlarmsPermission();
    }
  }

  /// Opens the system notification settings for QuotiMate. Android only shows
  /// the permission dialog once; after a denial this screen is the only way to
  /// re-enable alerts, including scheduled background alarms.
  Future<void> openNotificationSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _deviceChannel.invokeMethod('openNotificationSettings');
    } catch (e) {
      debugPrint('Failed to open notification settings: $e');
    }
  }

  /// Ends the over-lock-screen mode entered by a ringing alarm. If the phone is
  /// still locked, the app returns to the keyguard instead of staying visible.
  Future<void> leaveAlarmLockScreen() async {
    if (!Platform.isAndroid) return;
    try {
      await _deviceChannel.invokeMethod('clearAlarmOverlay');
    } catch (e) {
      debugPrint('Failed to leave alarm lock-screen mode: $e');
    }
  }

  /// Returns true if battery optimization is disabled for this app.
  Future<bool> isIgnoringBatteryOptimizations() async {
    if (!Platform.isAndroid) return true;
    try {
      final bool? result =
          await _deviceChannel.invokeMethod('isIgnoringBatteryOptimizations');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Requests the system dialog or settings to exclude QuotiMate from battery optimizations.
  Future<void> requestIgnoreBatteryOptimizations() async {
    if (!Platform.isAndroid) return;
    try {
      await _deviceChannel.invokeMethod('requestIgnoreBatteryOptimizations');
    } catch (e) {
      debugPrint('Failed to request battery optimization ignore: $e');
    }
  }

  /// Schedules a test alert [seconds] into the future so the user can minimize
  /// or lock the phone to verify out-of-focus / background notification delivery.
  Future<String> scheduleTestNotification({int seconds = 10, bool alarm = false}) async {
    await init();
    if (!_isSupported) return 'This platform has no local notification support.';
    if (!_initialized) return 'Notification plugin failed to start: $_initError';

    // Verify Android exact alarm permission first
    if (Platform.isAndroid) {
      final exact = await canScheduleExactAlarms();
      if (!exact) {
        await openExactAlarmSettings();
        return 'ACTION NEEDED: Android requires "Alarms & Reminders" permission for background delivery. We just opened Settings for you — please toggle it ON, then try again!';
      }
    }

    final targetTime = DateTime.now().add(Duration(seconds: seconds));
    final result = await _scheduleSingleReminder(
      id: 'test_bg',
      suffix: '_probe',
      title: alarm ? '⏰ Background Alarm Test' : '🔔 Background Alert Test',
      body: 'QuotiMate notification successfully delivered while app was out of focus!',
      scheduledTime: targetTime,
      payload: 'test:background',
      alarm: alarm,
      buzz: true,
    );

    if (result.armed) {
      return 'Armed for $seconds seconds! Minimize QuotiMate or lock your screen now to verify.';
    } else {
      return 'Failed to arm alert: ${result.detail ?? result.status.name}';
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
      await _localNotifications.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(android: _reminderDetails()),
      );
    } catch (e) {
      _lastError = e.toString();
      debugPrint('Failed to show instant notification: $e');
    }
  }

  /// Shows or updates a download progress bar notification.
  /// Called frequently during download — uses `onlyAlertOnce: true` so Android
  /// updates the existing bar silently without re-alerting each time.
  Future<void> showDownloadProgress({
    required int id,
    required String filename,
    required int progress,
  }) async {
    if (!_initialized) await init();
    if (!_isSupported) return;

    try {
      final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'quotimate_downloads',
        'QuotiMate Downloads',
        channelDescription: 'APK update download progress',
        importance: Importance.low,
        priority: Priority.low,
        // CRITICAL: must be true so Android updates the existing notification
        // bar in-place instead of posting a new one each call. Without this
        // the system throttles rapid show() calls and the bar appears frozen.
        onlyAlertOnce: true,
        showProgress: true,
        maxProgress: 100,
        progress: progress,
        ongoing: true,
        autoCancel: false,
        icon: _smallIcon,
        enableVibration: false,
        playSound: false,
        // Silence the heads-up on every update — only low importance matters
        // but belt-and-suspenders prevents any sound/vibration.
        enableLights: false,
      );
      await _localNotifications.show(
        id: id,
        title: 'Downloading $filename',
        body: '$progress% complete',
        notificationDetails: NotificationDetails(android: androidDetails),
      );
    } catch (e) {
      debugPrint('Failed to show download progress notification: $e');
    }
  }

  /// Replaces the progress bar with a "Download complete" notification.
  Future<void> showDownloadComplete({
    required int id,
    required String filename,
  }) async {
    if (!_initialized) await init();
    if (!_isSupported) return;

    try {
      final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'quotimate_downloads',
        'QuotiMate Downloads',
        channelDescription: 'APK update download progress',
        importance: Importance.high,
        priority: Priority.high,
        icon: _smallIcon,
        autoCancel: true,
      );
      await _localNotifications.show(
        id: id,
        title: '✅ Download Complete',
        body: '$filename is ready to install',
        notificationDetails: NotificationDetails(android: androidDetails),
      );
    } catch (e) {
      debugPrint('Failed to show download complete notification: $e');
    }
  }

  /// Cancels a notification by its integer ID.
  Future<void> cancelNotification(int id) async {
    if (!_initialized) return;
    try {
      await _localNotifications.cancel(id: id);
    } catch (e) {
      debugPrint('Failed to cancel notification $id: $e');
    }
  }

  int _generateId(String stringId, {String suffix = ''}) {
    // Generate a unique integer ID from a string ID (like 'e1' or 't2').
    // Masked to a positive 32-bit value: Dart hashCode is 64-bit on Android but
    // the native side expects a Java int.
    return '$stringId$suffix'.hashCode & 0x7FFFFFFF;
  }

  /// Schedules a task reminder at its due time, optionally with a quiet
  /// heads-up [leadMinutes] before.
  Future<ArmResult> scheduleTaskReminder({
    required String id,
    required String title,
    required String body,
    required DateTime dueDate,
    int leadMinutes = 0,
    bool alarm = false,
    bool buzz = true,
  }) async {
    await cancelReminder(id);
    final results = <ArmResult>[];

    if (leadMinutes > 0) {
      final leadTime = dueDate.subtract(Duration(minutes: leadMinutes));
      results.add(await _scheduleSingleReminder(
        id: id,
        suffix: '_before',
        title: 'Task due in $leadMinutes minutes',
        body: '$title is due at ${_formatTime(dueDate)}',
        scheduledTime: leadTime,
        payload: 'task:$id',
        // Only the due-time hit rings as an alarm; the lead stays a quiet reminder.
        alarm: false,
        buzz: buzz,
      ));
    }

    results.add(await _scheduleSingleReminder(
      id: id,
      suffix: '_start',
      title: 'Task Due',
      body: body.trim().isEmpty ? title : '$title — ${body.trim()}',
      scheduledTime: dueDate,
      payload: 'task:$id',
      alarm: alarm,
      buzz: buzz,
    ));

    return _combine(results);
  }

  /// A reminder only counts as armed when Android accepted at least one of the
  /// targets; a rejection is more informative than "everything was in the past".
  ArmResult _combine(List<ArmResult> results) {
    final armed = results.where((r) => r.armed).toList();
    if (armed.isNotEmpty) return armed.first;
    final rejected = results.where((r) => r.status == ArmStatus.rejected).toList();
    if (rejected.isNotEmpty) {
      return ArmResult(ArmStatus.rejected, detail: rejected.first.detail);
    }
    if (results.any((r) => r.status == ArmStatus.unsupported)) {
      return const ArmResult(ArmStatus.unsupported);
    }
    return const ArmResult(ArmStatus.past);
  }

  Future<ArmResult> scheduleEventReminders({
    required String id,
    required String title,
    required String description,
    required DateTime startTime,
    int leadMinutes = 15,
    bool alarm = false,
    bool buzz = true,
  }) async {
    if (!_initialized) await init();
    if (!_isSupported) return const ArmResult(ArmStatus.unsupported);

    // Re-arming with a shorter lead must not leave the previous 'before' alarm.
    await cancelReminder(id);

    final results = <ArmResult>[];
    final now = DateTime.now();

    // 1. Notification when the day has come (at midnight on the day of the event)
    final dayStart = DateTime(startTime.year, startTime.month, startTime.day, 0, 0);
    if (dayStart.isAfter(now)) {
      results.add(await _scheduleSingleReminder(
        id: id,
        suffix: '_day',
        title: 'Upcoming Event Today',
        body: '$title is scheduled for today at ${_formatTime(startTime)}',
        scheduledTime: dayStart,
        payload: 'event:$id',
      ));
    }

    // 2. Notification when the event is about to start (X minutes before)
    final beforeStart = startTime.subtract(Duration(minutes: leadMinutes));
    if (beforeStart.isAfter(now)) {
      results.add(await _scheduleSingleReminder(
        id: id,
        suffix: '_before',
        title: 'Event Starting Soon',
        body: '$title starts in $leadMinutes minutes',
        scheduledTime: beforeStart,
        payload: 'event:$id',
      ));
    }

    // 3. Notification when the event starts — this is the alarm itself.
    results.add(await _scheduleSingleReminder(
      id: id,
      suffix: '_start',
      title: 'Event Starting Now',
      body: '$title is starting now',
      scheduledTime: startTime,
      payload: 'event:$id',
      alarm: alarm,
      buzz: buzz,
    ));

    return _combine(results);
  }

  Future<ArmResult> _scheduleSingleReminder({
    required String id,
    required String suffix,
    required String title,
    required String body,
    required DateTime scheduledTime,
    required String payload,
    bool alarm = false,
    bool buzz = true,
  }) async {
    if (!_initialized) await init();
    if (!_isSupported) return const ArmResult(ArmStatus.unsupported);
    // A failed init leaves `_initialized` false; scheduling anyway throws a
    // platform exception for every item, which used to look like "no alarms".
    if (!_initialized) {
      return ArmResult(ArmStatus.rejected,
          detail: _initError ?? 'notification plugin did not initialize');
    }

    if (scheduledTime.isBefore(DateTime.now())) {
      debugPrint('Skipping notification for $id$suffix - scheduled time is in the past');
      return const ArmResult(ArmStatus.past);
    }

    final tzDateTime = tz.TZDateTime.from(scheduledTime, tz.local);
    debugPrint('Scheduling notification for $id$suffix at $scheduledTime (local: $tzDateTime, alarm: $alarm, buzz: $buzz)');

    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        alarm && buzz ? _alarmDetails(buzz: true) : _reminderDetails();
    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    final int notificationId = _generateId(id, suffix: suffix);
    // The alarm suffix tells the shell to open the ringing screen; ordinary
    // reminders and lead-time heads-ups keep the plain payload.
    final resolvedPayload = alarm && buzz ? '$payload:alarm' : payload;

    // alarmClock is exempt from Doze and is the only mode that reliably fires
    // on OEM devices (Samsung, Xiaomi, Huawei) while the screen is off.
    // exactAllowWhileIdle is the fallback for devices where alarmClock is
    // unavailable. inexactAllowWhileIdle is NOT used — on OEM battery savers
    // it fires only when the screen turns on, which is indistinguishable from
    // "notification fired when app came to focus", which is the exact bug we
    // are fixing. Better to reject loudly and ask the user to grant the
    // permission than to silently schedule something that won't work.
    if (Platform.isAndroid) {
      final exact = await canScheduleExactAlarms();
      if (!exact) {
        // The permission is missing. Open the system settings screen and
        // return a clear rejection so the caller can surface it to the user.
        // Do NOT fall through to zonedSchedule — scheduling without exact
        // alarm permission produces an inexact alarm that only fires when the
        // screen wakes up, making it appear to work only when the app is open.
        debugPrint('Exact alarm permission denied for $id$suffix — rejecting schedule');
        try {
          await _localNotifications
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.requestExactAlarmsPermission();
        } catch (e) {
          debugPrint('requestExactAlarmsPermission failed: $e');
        }
        _lastError = 'SCHEDULE_EXACT_ALARM permission denied';
        return const ArmResult(
          ArmStatus.rejected,
          detail: 'ACTION NEEDED: open Settings → Special app access → '
              'Alarms & reminders and enable QuotiMate.',
        );
      }
    }

    // Only try exact modes. Inexact is intentionally excluded — see comment above.
    final modes = <AndroidScheduleMode>[
      AndroidScheduleMode.alarmClock,          // Doze-exempt, shows clock icon
      AndroidScheduleMode.exactAllowWhileIdle, // Exact even in Doze, no clock icon
    ];

    Object? lastFailure;
    for (final mode in modes) {
      try {
        await _localNotifications.zonedSchedule(
          id: notificationId,
          title: title,
          body: body,
          scheduledDate: tzDateTime,
          notificationDetails: platformChannelSpecifics,
          androidScheduleMode: mode,
          payload: resolvedPayload,
        );
        _lastError = null;
        debugPrint('Scheduled $id (suffix: $suffix) with $mode');
        return ArmResult(
          ArmStatus.armed,
          detail: mode == AndroidScheduleMode.inexactAllowWhileIdle
              ? 'inexact'
              : null,
        );
      } catch (e) {
        lastFailure = e;
        debugPrint('Scheduling $id with $mode failed: $e');
      }
    }

    _lastError = '$lastFailure';
    return ArmResult(
      ArmStatus.rejected,
      detail: lastFailure == null
          ? 'Android denied the alarm. Enable "Alarms & reminders" for QuotiMate in Settings.'
          : '$lastFailure',
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> cancelReminder(String id) async {
    if (!_initialized || !_isSupported) return;
    // Never let a cancel failure abort the re-arm that follows it.
    for (final suffix in const ['_day', '_before', '_start']) {
      try {
        await _localNotifications.cancel(id: _generateId(id, suffix: suffix));
      } catch (e) {
        debugPrint('cancel($id$suffix) failed: $e');
      }
    }
  }

  Future<void> cancelAllReminders() async {
    if (!_initialized || !_isSupported) return;
    try {
      await _localNotifications.cancelAll();
    } catch (e) {
      debugPrint('cancelAll failed: $e');
    }
  }
}
