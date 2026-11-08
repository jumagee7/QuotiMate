// Alarm delivery: a full-screen alarm launch and a notification tap arrive
// through the same intent, so the ring window decides which one it was.

import 'package:flutter_test/flutter_test.dart';
import 'package:quotimate/services/notification_service.dart';

void main() {
  final ringAt = DateTime(2026, 11, 8, 9, 0);

  test('an alarm payload at its ring time is the alarm firing', () {
    expect(
      isWithinAlarmRingWindow(ringAt, now: DateTime(2026, 11, 8, 9, 0, 5)),
      isTrue,
    );
    // A few seconds early still covers clock skew.
    expect(
      isWithinAlarmRingWindow(ringAt, now: DateTime(2026, 11, 8, 8, 59, 55)),
      isTrue,
    );
    expect(
      isWithinAlarmRingWindow(ringAt, now: DateTime(2026, 11, 8, 9, 14)),
      isTrue,
    );
  });

  test('a later tap on an old alarm is an acknowledgement, not a ring', () {
    expect(
      isWithinAlarmRingWindow(ringAt, now: DateTime(2026, 11, 8, 9, 30)),
      isFalse,
    );
    expect(
      isWithinAlarmRingWindow(ringAt, now: DateTime(2026, 11, 8, 8, 0)),
      isFalse,
    );
  });

  AlarmHealth health({
    bool pluginReady = true,
    bool notificationsAllowed = true,
    bool exactAllowed = true,
    bool alarmChannelActive = true,
    bool reminderChannelActive = true,
    bool batteryExcluded = true,
    bool inAppAlertsOn = true,
    bool alarmBuzzOn = true,
    bool fullScreenAllowed = true,
    bool restrictedBucket = false,
    bool doNotDisturbSilent = false,
  }) =>
      AlarmHealth(
        pluginReady: pluginReady,
        notificationsAllowed: notificationsAllowed,
        exactAllowed: exactAllowed,
        alarmChannelActive: alarmChannelActive,
        reminderChannelActive: reminderChannelActive,
        batteryExcluded: batteryExcluded,
        inAppAlertsOn: inAppAlertsOn,
        alarmBuzzOn: alarmBuzzOn,
        fullScreenAllowed: fullScreenAllowed,
        restrictedBucket: restrictedBucket,
        doNotDisturbSilent: doNotDisturbSilent,
        pendingAlerts: 0,
      );

  test('alert health is clean only when every switch is in place', () {
    expect(health().healthy, isTrue);
    expect(health().blockers, isEmpty);
    expect(health(exactAllowed: false).healthy, isFalse);
    expect(health(batteryExcluded: false).healthy, isFalse);
    expect(health(notificationsAllowed: false).healthy, isFalse);
    expect(health(alarmChannelActive: false).healthy, isFalse);
    expect(health(reminderChannelActive: false).healthy, isFalse);
    expect(health(pluginReady: false).healthy, isFalse);
  });

  test('each blocker is named so the UI can offer a fix', () {
    expect(health(exactAllowed: false).blockers.single, contains('exact alarms'));
    expect(health(batteryExcluded: false).blockers.single, contains('Battery optimisation'));
    expect(health(notificationsAllowed: false).blockers.single, contains('Notifications are switched off'));
    expect(health(alarmChannelActive: false).blockers.single, contains('Alarms channel'));
    expect(health(reminderChannelActive: false).blockers.single, contains('Reminders channel'));
  });

  test('app switches cannot stay green while alarms are cancelled or demoted',
      () {
    final disabled = health(inAppAlertsOn: false);
    expect(disabled.healthy, isFalse);
    expect(disabled.blockers.single, contains('cancels every alarm'));

    final buzzOff = health(alarmBuzzOn: false);
    expect(buzzOff.healthy, isFalse);
    expect(buzzOff.blockers.single, contains('notify only'));
  });

  test('Android 14 full-screen access, restricted bucket and total silence block',
      () {
    expect(health(fullScreenAllowed: false).blockers.single, contains('full-screen'));
    final restricted = health(restrictedBucket: true);
    expect(restricted.healthy, isFalse);
    expect(restricted.blockers.single, contains('Restricted'));
    final dnd = health(doNotDisturbSilent: true);
    expect(dnd.healthy, isFalse);
    expect(dnd.blockers.single, contains('Total silence'));
  });
}
