// Alarm/reminder data model round-trips: time-of-day, lead time, in-app feed.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quotimate/models.dart';
import 'package:quotimate/services/notification_service.dart';

void main() {
  test('AppTask keeps a time of day and a lead, defaulting to no lead', () {
    final task = AppTask(
      id: 'T-1',
      title: 'Site visit',
      dueDate: DateTime(2026, 11, 2, 9, 30),
      alarmEnabled: true,
      reminderLeadMinutes: 15,
    );

    final restored = AppTask.fromJson(task.toJson());
    expect(restored.dueDate, DateTime(2026, 11, 2, 9, 30));
    expect(restored.alarmEnabled, isTrue);
    expect(restored.reminderLeadMinutes, 15);
    expect(restored.alarmAt, DateTime(2026, 11, 2, 9, 15));
  });

  test('legacy task JSON without the new fields still parses', () {
    final restored = AppTask.fromJson(const {
      'id': 'T-2',
      'title': 'Old task',
      'dueDate': '2026-10-30T00:00:00.000',
    });
    expect(restored.alarmEnabled, isFalse);
    expect(restored.reminderLeadMinutes, 0);
    expect(restored.dueDate.hour, 0);
  });

  test('AppEvent lead time survives a round trip', () {
    final event = AppEvent(
      id: 'EV-1',
      title: 'Client meeting',
      startTime: DateTime(2026, 11, 3, 14, 0),
      endTime: DateTime(2026, 11, 3, 15, 30),
      alarmEnabled: true,
      reminderLeadMinutes: 30,
    );

    final restored = AppEvent.fromJson(event.toJson());
    expect(restored.startTime, DateTime(2026, 11, 3, 14, 0));
    expect(restored.reminderLeadMinutes, 30);

    final legacy = AppEvent.fromJson(const {
      'id': 'EV-2',
      'title': 'Old event',
      'startTime': '2026-11-04T09:00:00.000',
      'endTime': '2026-11-04T10:00:00.000',
    });
    expect(legacy.reminderLeadMinutes, 15);
  });

  test('in-app notification persists its icon as a key and restores it', () {
    final notification = AppNotification(
      id: 'n_task_arm_T-1',
      title: 'Alarm set',
      body: 'Site visit — tomorrow at 9:15 AM',
      timestamp: DateTime(2026, 11, 1, 8),
      icon: kNotificationIcons['alarm_on']!,
      color: const Color(0xFFFFC107),
    );

    final json = notification.toJson();
    expect(json['icon'], 'alarm_on');

    final restored = AppNotification.fromJson(json);
    expect(restored.icon, kNotificationIcons['alarm_on']);
    expect(restored.color, const Color(0xFFFFC107));
    expect(restored.isRead, isFalse);
  });

  test('test-alert report never claims a device alert it could not post', () async {
    // The suite runs on desktop, where no notification plugin is attached. The
    // Settings button used to print "Test alert sent" regardless; it must now
    // report the platform limitation instead of a displayed alert.
    final result = await NotificationService().showTestNotification();
    expect(result, contains('no local notification support'));
    expect(result.startsWith('Device alert displayed'), isFalse);
    expect(await NotificationService().diagnosticSummary(), isNull);
  });
}
