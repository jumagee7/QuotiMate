// widgets/project_card.dart — Shared project card (home + projects pages).

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import 'money_text.dart';

const _surface = Color(0xFF161B26);
const _panel = Color(0xFF1E2538);
const _border = Color(0xFF2A3045);
const _gold = Color(0xFFFFC107);
const _green = Color(0xFF34D399);
const _muted = Color(0xFF8A92A6);
const _dim = Color(0xFF616C88);

class ProjectCard extends StatelessWidget {
  final Project project;
  final AppState state;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry margin;

  const ProjectCard({
    super.key,
    required this.project,
    required this.state,
    this.onTap,
    this.margin = const EdgeInsets.only(bottom: 14),
  });

  double get _invoiced => project.totalInvoiced(state.invoices);

  List<AppTask> get _tasks => state.tasksForProject(project.id);

  /// Completed milestones: task progress when tasks exist, else how much of
  /// the contract value has been invoiced.
  double get _progress {
    final tasks = _tasks;
    if (tasks.isNotEmpty) {
      return tasks.where((t) => t.status == TaskStatus.done).length / tasks.length;
    }
    final target = project.budget > 0 ? project.budget : _invoiced;
    if (target <= 0) return 0;
    return (_invoiced / target).clamp(0.0, 1.0);
  }

  List<String> get _categories {
    final names = <String>[];
    for (final q in state.quotes) {
      if (q.projectId != project.id && !project.quoteIds.contains(q.id)) continue;
      for (final c in q.categories) {
        if (c.name.trim().isNotEmpty && !names.contains(c.name)) names.add(c.name.trim());
      }
    }
    return names;
  }

  @override
  Widget build(BuildContext context) {
    String money(double value) => formatAmount(value, state.currency);
    final pct = (_progress * 100).round();
    final tasks = _tasks;
    final openTasks = tasks.where((t) => t.status != TaskStatus.done).length;
    final doneTasks = tasks.length - openTasks;
    final quoteCount = state.quotes
        .where((q) => q.projectId == project.id || project.quoteIds.contains(q.id))
        .length;
    final invoiceCount = state.invoices
        .where((i) => i.projectId == project.id || project.invoiceIds.contains(i.id))
        .length;

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 11, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Tooltip(
                      message: 'Project No. ${project.numberLabel}',
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _panel,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: _border),
                        ),
                        child: Text(
                          project.numberLabel,
                          style: const TextStyle(
                            color: _muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: _StatusPill(label: project.status.label, color: project.status.color),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  project.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Text('Client: ',
                        style: TextStyle(color: _muted, fontSize: 13)),
                    Expanded(
                      child: Text(
                        project.clientName.isEmpty ? 'Not assigned' : project.clientName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Expanded(
                      child: Text('Milestone Progress',
                          style: TextStyle(color: _muted, fontSize: 13)),
                    ),
                    Text('$pct%',
                        style: const TextStyle(
                            color: _gold, fontSize: 14, fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: _progress.clamp(0.0, 1.0),
                    minHeight: 8,
                    color: _gold,
                    backgroundColor: Colors.white.withValues(alpha: 0.07),
                  ),
                ),
                if (tasks.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.checklist_rtl_outlined, size: 13, color: _muted),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '$openTasks to do · $doneTasks completed',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: _muted, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: _panel,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _figure(
                          'CONTRACT BUDGET',
                          money(project.budget),
                          Colors.white,
                          TextAlign.left,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _figure(
                          'INVOICED TO DATE',
                          money(_invoiced),
                          _green,
                          TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(color: _green, shape: BoxShape.circle),
                      child: const Icon(Icons.check_rounded, size: 11, color: Colors.black),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$quoteCount Quotes · $invoiceCount Invoices',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: _green, fontSize: 12.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                if (_categories.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final name in _categories.take(3)) _chip(name),
                      if (_categories.length > 3) _chip('+${_categories.length - 3}'),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Label + amount. FittedBox keeps long figures (KES 4,500,000) on one line
  /// instead of overflowing the card at narrow widths or large text scales.
  Widget _figure(String label, String value, Color valueColor, TextAlign align) {
    return Column(
      crossAxisAlignment:
          align == TextAlign.right ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: _dim, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: align == TextAlign.right ? Alignment.centerRight : Alignment.centerLeft,
          child: Text(value,
              maxLines: 1,
              style: TextStyle(color: valueColor, fontSize: 15, fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }

  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Text(label,
          style: const TextStyle(color: _muted, fontSize: 11.5, fontWeight: FontWeight.w600)),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
