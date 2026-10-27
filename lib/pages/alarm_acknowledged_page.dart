// pages/alarm_acknowledged_page.dart — Shown after the user taps an alarm
// notification. The tap itself acknowledges the alarm, so nothing rings here.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../services/notification_service.dart';

const _bg = Color(0xFF0B0E17);
const _surface = Color(0xFF161B26);
const _border = Color(0xFF2A3045);
const _gold = Color(0xFFFFC107);
const _green = Color(0xFF10B981);
const _muted = Color(0xFFB0B8D0);

class AlarmAcknowledgedPage extends StatefulWidget {
  /// Either `task` or `event`.
  final String kind;
  final String itemId;
  final AppState appState;

  const AlarmAcknowledgedPage({
    super.key,
    required this.kind,
    required this.itemId,
    required this.appState,
  });

  @override
  State<AlarmAcknowledgedPage> createState() => _AlarmAcknowledgedPageState();
}

class _AlarmAcknowledgedPageState extends State<AlarmAcknowledgedPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    // Idempotent: the tap handler already canceled the card, this covers the
    // route being opened from anywhere else.
    NotificationService().cancelReminder(widget.itemId);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  String get _title {
    if (widget.kind == 'task') {
      return widget.appState.tasks
              .where((t) => t.id == widget.itemId)
              .firstOrNull
              ?.title ??
          'Task alarm';
    }
    return widget.appState.events
            .where((e) => e.id == widget.itemId)
            .firstOrNull
            ?.title ??
        'Event alarm';
  }

  String get _note {
    if (widget.kind == 'task') {
      return widget.appState.tasks
              .where((t) => t.id == widget.itemId)
              .firstOrNull
              ?.description ??
          '';
    }
    return widget.appState.events
            .where((e) => e.id == widget.itemId)
            .firstOrNull
            ?.description ??
        '';
  }

  String get _timeLabel {
    DateTime? at;
    if (widget.kind == 'task') {
      at = widget.appState.tasks
          .where((t) => t.id == widget.itemId)
          .firstOrNull
          ?.dueDate;
    } else {
      at = widget.appState.events
          .where((e) => e.id == widget.itemId)
          .firstOrNull
          ?.startTime;
    }
    if (at == null) return '';
    return DateFormat('EEE d MMM · h:mm a').format(at);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              ScaleTransition(
                scale: Tween<double>(begin: 0.94, end: 1.04).animate(
                  CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
                ),
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _green.withValues(alpha: 0.12),
                    border: Border.all(color: _green, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: _green.withValues(alpha: 0.28),
                        blurRadius: 36,
                        spreadRadius: 6,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.check_rounded, color: _green, size: 76),
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'ALARM ACKNOWLEDGED',
                style: TextStyle(
                  color: _green,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.4,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Tapping the notification counts as reading it — the ringing and vibration have stopped.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _muted, fontSize: 13),
              ),
              const SizedBox(height: 28),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _border),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.alarm, color: _gold, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.kind == 'task' ? 'Task alarm' : 'Event alarm',
                            style: const TextStyle(
                              color: _muted,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (_timeLabel.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _timeLabel,
                          style: const TextStyle(color: _muted, fontSize: 14),
                        ),
                      ),
                    ],
                    if (_note.trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _note,
                          style: const TextStyle(color: _muted, fontSize: 13),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: _gold,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.done_rounded, size: 22),
                  label: const Text(
                    'Done',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
