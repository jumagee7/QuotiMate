// widgets/project_card.dart — Shared project card used across the app

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../models.dart';
import '../pages/project_quickbook_page.dart';

const _surface = Color(0xFF161B26);
const _panel   = Color(0xFF0F162C);
const _border  = Color(0xFF2A3045);
const _gold    = Color(0xFFFFC107);
const _white38 = Color(0xFF616C88);
const _white70 = Color(0xFFB0B8D0);
const _green   = Color(0xFF10B981);
const _red     = Color(0xFFEF4444);

class ProjectCard extends StatelessWidget {
  final Project project;
  final AppState appState;
  /// Compact layout for horizontal carousels (e.g. dashboard).
  final bool compact;
  final EdgeInsetsGeometry margin;

  const ProjectCard({
    super.key,
    required this.project,
    required this.appState,
    this.compact = false,
    this.margin = const EdgeInsets.only(bottom: 14),
  });

  static final _money = NumberFormat.compactCurrency(symbol: 'KES ', decimalDigits: 1);
  static final _date = DateFormat('dd MMM yyyy');

  @override
  Widget build(BuildContext context) {
    final totalInvoiced = project.totalInvoiced(appState.invoices);
    final totalQuoted = project.totalQuoted(appState.quotes);
    final value = totalInvoiced > 0 ? totalInvoiced : (totalQuoted > 0 ? totalQuoted : project.budget);
    final paid = project.totalPaymentsReceived;
    final profit = project.netProfitRealized();
    final collected = value > 0 ? (paid / value).clamp(0.0, 1.0) : 0.0;
    final tasks = appState.tasksForProject(project.id);
    final doneTasks = tasks.where((t) => t.status == TaskStatus.done).length;
    final taskProgress = tasks.isEmpty ? 0.0 : doneTasks / tasks.length;
    final cover = project.summaryImages.isNotEmpty ? _tryDecode(project.summaryImages.first) : null;
    final overdue = project.deadline != null &&
        project.deadline!.isBefore(DateTime.now()) &&
        project.status != ProjectStatus.completed;

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 12, offset: Offset(0, 4))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => openProjectQuickBookPage(context, projectId: project.id),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header band: cover photo or status gradient
              Container(
                height: compact ? 64 : 84,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [project.status.color.withValues(alpha: 0.45), _panel],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  image: cover == null
                      ? null
                      : DecorationImage(
                          image: MemoryImage(cover),
                          fit: BoxFit.cover,
                          colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.45), BlendMode.darken),
                        ),
                ),
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        project.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: compact ? 15 : 17,
                          fontWeight: FontWeight.bold,
                          shadows: const [Shadow(color: Colors.black54, blurRadius: 4)],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StatusPill(status: project.status),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(children: [
                      const Icon(Icons.person_outline_rounded, color: _gold, size: 14),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(project.clientName,
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: _white70, fontSize: 12.5, fontWeight: FontWeight.w500)),
                      ),
                      if (project.location.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.location_on_outlined, color: _white38, size: 13),
                        Flexible(
                          child: Text(project.location,
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: _white38, fontSize: 12)),
                        ),
                      ],
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      _Stat(label: 'Value', value: _money.format(value), color: Colors.white),
                      _Stat(label: 'Collected', value: _money.format(paid), color: _green),
                      _Stat(label: 'Profit', value: _money.format(profit), color: profit >= 0 ? _green : _red),
                    ]),
                    const SizedBox(height: 12),
                    _ProgressRow(
                      label: 'Payments',
                      value: collected,
                      trailing: '${(collected * 100).toStringAsFixed(0)}%',
                      color: collected >= 1 ? _green : _gold,
                    ),
                    const SizedBox(height: 8),
                    _ProgressRow(
                      label: 'Tasks',
                      value: taskProgress,
                      trailing: '$doneTasks/${tasks.length}',
                      color: const Color(0xFF3B82F6),
                    ),
                    if (!compact) ...[
                      const SizedBox(height: 12),
                      Row(children: [
                        _Chip(icon: Icons.article_outlined, text: '${project.quoteIds.length}'),
                        const SizedBox(width: 6),
                        _Chip(icon: Icons.receipt_long_outlined, text: '${project.invoiceIds.length}'),
                        const SizedBox(width: 6),
                        _Chip(icon: Icons.sticky_note_2_outlined, text: '${project.notes.length}'),
                        const Spacer(),
                        Icon(Icons.event_outlined, size: 13, color: overdue ? _red : _white38),
                        const SizedBox(width: 4),
                        Text(
                          project.deadline != null
                              ? 'Due ${_date.format(project.deadline!)}'
                              : 'Started ${_date.format(project.startDate)}',
                          style: TextStyle(color: overdue ? _red : _white38, fontSize: 11),
                        ),
                      ]),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static MemoryImage? _decodeCache;
  static String? _decodeKey;
  static dynamic _tryDecode(String b64) {
    if (_decodeKey == b64 && _decodeCache != null) return _decodeCache!.bytes;
    try {
      final bytes = base64Decode(b64);
      _decodeKey = b64;
      _decodeCache = MemoryImage(bytes);
      return bytes;
    } catch (_) {
      return null;
    }
  }
}

class _StatusPill extends StatelessWidget {
  final ProjectStatus status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: status.color),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(status.icon, color: status.color, size: 11),
          const SizedBox(width: 4),
          Text(status.label, style: TextStyle(color: status.color, fontSize: 10, fontWeight: FontWeight.bold)),
        ]),
      );
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Stat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: _white38, fontSize: 10.5)),
          const SizedBox(height: 2),
          Text(value,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontSize: 13.5, fontWeight: FontWeight.bold)),
        ]),
      );
}

class _ProgressRow extends StatelessWidget {
  final String label;
  final double value;
  final String trailing;
  final Color color;
  const _ProgressRow({required this.label, required this.value, required this.trailing, required this.color});

  @override
  Widget build(BuildContext context) => Row(children: [
        SizedBox(width: 62, child: Text(label, style: const TextStyle(color: _white38, fontSize: 11))),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value, minHeight: 6, backgroundColor: _panel,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 36,
          child: Text(trailing, textAlign: TextAlign.right,
              style: const TextStyle(color: _white70, fontSize: 11, fontWeight: FontWeight.bold)),
        ),
      ]);
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Chip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: _panel, borderRadius: BorderRadius.circular(6), border: Border.all(color: _border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: _white70, size: 12),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(color: _white70, fontSize: 11)),
        ]),
      );
}
