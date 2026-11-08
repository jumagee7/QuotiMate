// pages/alarm_ringing_page.dart — Shown when an alarm fires and launches the
// app. The device notification keeps sounding until the user stops it here (or
// from the notification's own "Stop alarm" action).

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../services/notification_service.dart';

const _bg = Color(0xFF0B0E17);
const _surface = Color(0xFF161B26);
const _border = Color(0xFF2A3045);
const _gold = Color(0xFFFFC107);
const _red = Color(0xFFFF5252);
const _muted = Color(0xFFB0B8D0);

class AlarmRingingPage extends StatefulWidget {
  /// Either `task` or `event`.
  final String kind;
  final String itemId;
  final AppState appState;

  const AlarmRingingPage({
    super.key,
    required this.kind,
    required this.itemId,
    required this.appState,
  });

  @override
  State<AlarmRingingPage> createState() => _AlarmRingingPageState();
}

class _AlarmRingingPageState extends State<AlarmRingingPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  bool _stopped = false;

  @override
  void dispose() {
    // Leaving the ringing screen is an acknowledgement. Cancelling here also
    // covers the system dismissing the route (back gesture, task removal).
    _stop(leaveScreen: false);
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _stop({required bool leaveScreen}) async {
    if (_stopped) return;
    _stopped = true;
    await NotificationService().cancelReminder(widget.itemId);
    if (leaveScreen) {
      await NotificationService().leaveAlarmLockScreen();
    }
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
                scale: Tween<double>(begin: 0.94, end: 1.06).animate(
                  CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
                ),
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _red.withValues(alpha: 0.14),
                    border: Border.all(color: _red, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: _red.withValues(alpha: 0.34),
                        blurRadius: 42,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.alarm_on_rounded,
                      color: _red, size: 80),
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'ALARM RINGING',
                style: TextStyle(
                  color: _red,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'The alarm keeps sounding until you stop it.',
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
                  onPressed: () async {
                    await _stop(leaveScreen: true);
                    if (mounted) Navigator.of(context).pop();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: _red,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.alarm_off_rounded, size: 22),
                  label: const Text(
                    'Stop alarm',
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
