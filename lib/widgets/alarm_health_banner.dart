// widgets/alarm_health_banner.dart — names the Android switch blocking alerts

import 'package:flutter/material.dart';
import '../app_state.dart';
import '../services/notification_service.dart';

const Color _gold = Color(0xFFFFC107);
const Color _card = Color(0xFF131B2F);

/// Banner shown above the schedule when Android is holding alerts back.
/// Hidden as soon as every switch is in the right position.
class AlarmHealthBanner extends StatelessWidget {
  const AlarmHealthBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateProvider.of(context);
    final health = state.alarmHealth;
    if (health == null || health.healthy) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: _gold.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _gold.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.alarm_off_rounded, size: 18, color: _gold),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Background alerts are blocked',
                  style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  health.blockers.join(' · '),
                  style: const TextStyle(color: Colors.white60, fontSize: 11, height: 1.3),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => showAlarmFixSheet(context, state),
            style: TextButton.styleFrom(foregroundColor: _gold, padding: const EdgeInsets.symmetric(horizontal: 10)),
            child: const Text('Fix', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

/// Three tappable status pills for the Settings notification card.
class AlarmHealthStatus extends StatelessWidget {
  const AlarmHealthStatus({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateProvider.of(context);
    final health = state.alarmHealth;
    if (health == null) return const SizedBox.shrink();
    final service = NotificationService();
    final channelsOk = health.notificationsAllowed && health.alarmChannelActive && health.reminderChannelActive;

    Future<void> fix(Future<void> Function() action) async {
      await action();
      await state.refreshScheduledNotifications();
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _pill(
          label: 'Notifications',
          ok: channelsOk,
          icon: channelsOk ? Icons.check_circle : Icons.error_outline,
          onTap: channelsOk ? null : () => fix(service.openNotificationSettings),
        ),
        _pill(
          label: 'Exact alarms',
          ok: health.exactAllowed,
          icon: health.exactAllowed ? Icons.check_circle : Icons.error_outline,
          onTap: health.exactAllowed ? null : () => fix(service.openExactAlarmSettings),
        ),
        _pill(
          label: 'Battery unrestricted',
          ok: health.batteryExcluded,
          icon: health.batteryExcluded ? Icons.check_circle : Icons.error_outline,
          onTap: health.batteryExcluded ? null : () => fix(service.requestIgnoreBatteryOptimizations),
        ),
      ],
    );
  }

  Widget _pill({
    required String label,
    required bool ok,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    final color = ok ? const Color(0xFF10B981) : Colors.redAccent;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet that walks through every blocker with a button for each.
Future<void> showAlarmFixSheet(BuildContext context, AppState state) async {
  final service = NotificationService();
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: _card,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      final health = state.alarmHealth;
      if (health == null) return const SizedBox.shrink();
      final rows = <Widget>[];

      Future<void> run(Future<void> Function() action) async {
        Navigator.of(sheetContext).pop();
        await action();
        await state.refreshScheduledNotifications();
      }

      if (!health.pluginReady) {
        rows.add(const _FixRow(
          title: 'Restart QuotiMate',
          detail: 'The notification plugin failed to start, so nothing can be queued.',
          action: 'OK',
        ));
      }
      if (!health.notificationsAllowed) {
        rows.add(_FixRow(
          title: 'Turn notifications on',
          detail: 'Android is not allowed to show QuotiMate notifications.',
          action: 'Open',
          onTap: () => run(service.openNotificationSettings),
        ));
      }
      if (!health.alarmChannelActive || !health.reminderChannelActive) {
        rows.add(_FixRow(
          title: 'Unmute the QuotiMate channels',
          detail: 'A muted channel accepts alerts and silently drops them.',
          action: 'Open',
          onTap: () => run(service.openNotificationSettings),
        ));
      }
      if (!health.exactAllowed) {
        rows.add(_FixRow(
          title: 'Allow exact alarms',
          detail: 'Without this, Android only queues late alarms that can wait '
              'for the next maintenance window.',
          action: 'Open',
          onTap: () => run(service.openExactAlarmSettings),
        ));
      }
      if (!health.batteryExcluded) {
        rows.add(_FixRow(
          title: 'Set battery usage to Unrestricted',
          detail: 'Battery optimisation freezes the app in the background and '
              'can hold its alarms until the app is opened.',
          action: 'Open',
          onTap: () => run(service.requestIgnoreBatteryOptimizations),
        ));
      }

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Make alarms fire in the background',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Android has switched off one or more of these. Each one can hold '
                'an alarm until you next open QuotiMate.',
                style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.35),
              ),
              const SizedBox(height: 14),
              ...rows,
              const SizedBox(height: 10),
              const Text(
                'On Tecno, Infinix, Xiaomi, Oppo or Vivo also allow QuotiMate under '
                'Auto-start / Background app management in the phone settings.',
                style: TextStyle(color: Colors.white38, fontSize: 11, height: 1.35),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        Navigator.of(sheetContext).pop();
                        await state.refreshScheduledNotifications();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _gold,
                        side: const BorderSide(color: Color(0xFF2A3045)),
                      ),
                      child: const Text('Re-check'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      style: FilledButton.styleFrom(
                        backgroundColor: _gold,
                        foregroundColor: Colors.black,
                      ),
                      child: const Text('Done'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _FixRow extends StatelessWidget {
  const _FixRow({
    required this.title,
    required this.detail,
    required this.action,
    this.onTap,
  });

  final String title;
  final String detail;
  final String action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.error_outline, size: 16, color: Colors.redAccent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(detail, style: const TextStyle(color: Colors.white54, fontSize: 11.5, height: 1.3)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onTap ?? () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(foregroundColor: _gold, padding: const EdgeInsets.symmetric(horizontal: 8)),
            child: Text(action, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
