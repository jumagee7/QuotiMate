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
}
