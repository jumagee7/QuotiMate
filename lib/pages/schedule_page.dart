// pages/schedule_page.dart â€” QuotiMate Task & Event Scheduler

import 'package:flutter/material.dart';
import '../app_state.dart';
import '../models.dart';
import '../services/notification_service.dart';

String fmtClock(DateTime dt) {
  final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
  return '$h:${dt.minute.toString().padLeft(2, '0')} ${dt.hour >= 12 ? 'PM' : 'AM'}';
}

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});
  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  TaskStatus? _filterStatus;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // â”€â”€ Tab bar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFF131B2F),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: Colors.black,
            unselectedLabelColor: Colors.white54,
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: BoxDecoration(
              color: const Color(0xFFFFC107),
              borderRadius: BorderRadius.circular(10),
            ),
            tabs: const [
              Tab(icon: Icon(Icons.task_alt), text: 'Tasks'),
              Tab(icon: Icon(Icons.calendar_month), text: 'Schedule'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _TasksTab(filterStatus: _filterStatus, onFilterChanged: (s) => setState(() => _filterStatus = s)),
              const _ScheduleTab(),
            ],
          ),
        ),
      ],
    );
  }
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// TASKS TAB
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

class _TasksTab extends StatelessWidget {
  final TaskStatus? filterStatus;
  final ValueChanged<TaskStatus?> onFilterChanged;

  const _TasksTab({required this.filterStatus, required this.onFilterChanged});

  @override
  Widget build(BuildContext context) {
    final state = AppStateProvider.of(context);
    final tasks = state.tasks.where((t) => filterStatus == null || t.status == filterStatus).toList()
      ..sort((a, b) {
        // Sort: high priority first, then by due date
        final priorityOrder = {TaskPriority.high: 0, TaskPriority.medium: 1, TaskPriority.low: 2};
        final pc = priorityOrder[a.priority]!.compareTo(priorityOrder[b.priority]!);
        return pc != 0 ? pc : a.dueDate.compareTo(b.dueDate);
      });

    // Stats
    final total = state.tasks.length;
    final done = state.tasks.where((t) => t.status == TaskStatus.done).length;
    final inProg = state.tasks.where((t) => t.status == TaskStatus.inProgress).length;
    final todo = state.tasks.where((t) => t.status == TaskStatus.todo).length;

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // â”€â”€ Stats Row â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            // ── Stats Row ──────────────────────────────────────────────────
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _statChip('All', total, null, filterStatus, onFilterChanged),
                  const SizedBox(width: 8),
                  _statChip('To Do', todo, TaskStatus.todo, filterStatus, onFilterChanged),
                  const SizedBox(width: 8),
                  _statChip('In Progress', inProg, TaskStatus.inProgress, filterStatus, onFilterChanged),
                  const SizedBox(width: 8),
                  _statChip('Done', done, TaskStatus.done, filterStatus, onFilterChanged),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // â”€â”€ Task List â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            Expanded(
              child: tasks.isEmpty
                  ? _emptyState('No tasks', 'Add a task using the + button', Icons.task_alt)
                  : ListView.separated(
                      itemCount: tasks.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 8),
                      itemBuilder: (ctx, i) => _TaskCard(
                        task: tasks[i],
                        onEdit: () => _showTaskDialog(ctx, state, existing: tasks[i]),
                      ),
                    ),
            ),
          ],
        ),

        // â”€â”€ FAB â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        Positioned(
          bottom: 24,
          right: 0,
          child: FloatingActionButton.extended(
            heroTag: 'task_fab',
            onPressed: () => _showTaskDialog(context, state),
            backgroundColor: const Color(0xFFFFC107),
            foregroundColor: Colors.black,
            icon: const Icon(Icons.add),
            label: const Text('Add Task', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  Widget _statChip(String label, int count, TaskStatus? status, TaskStatus? current, ValueChanged<TaskStatus?> onChanged) {
    final selected = current == status;
    return GestureDetector(
      onTap: () => onChanged(selected ? null : status),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFFC107) : const Color(0xFF19233E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? const Color(0xFFFFC107) : Colors.white12),
        ),
        child: Text(
          '$label ($count)',
          style: TextStyle(
            color: selected ? Colors.black : Colors.white70,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  void _showTaskDialog(BuildContext context, AppState state, {AppTask? existing}) {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    TaskPriority priority = existing?.priority ?? TaskPriority.medium;
    // A date-only due date meant midnight, so every "alarm" either fired at
    // 00:00 or was dropped for being in the past. New tasks ring at 09:00.
    DateTime dueDate = existing?.dueDate ??
        DateTime.now().add(const Duration(days: 1)).copyWith(hour: 9, minute: 0);
    bool alarm = existing?.alarmEnabled ?? false;
    int lead = existing?.reminderLeadMinutes ?? 0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final alarmAt = dueDate.subtract(Duration(minutes: lead));
          final willRing = dueDate.isAfter(DateTime.now());
          final leadWillRing = alarmAt.isAfter(DateTime.now());
          return AlertDialog(
          backgroundColor: const Color(0xFF19233E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            existing == null ? 'Add New Task' : 'Edit Task',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _dialogField('Task Title', titleCtrl),
                  const SizedBox(height: 12),
                  _dialogField('Description (optional)', descCtrl, maxLines: 2),
                  const SizedBox(height: 16),
                  const Text('Priority', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: TaskPriority.values.map((p) {
                      final sel = priority == p;
                      return GestureDetector(
                        onTap: () => setDialogState(() => priority = p),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: sel ? p.color.withValues(alpha: 0.2) : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: sel ? p.color : Colors.white24),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(p.icon, color: p.color, size: 14),
                              const SizedBox(width: 6),
                              Text(p.label, style: TextStyle(color: p.color, fontSize: 13, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  const Text('Due date & time', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: dueDate,
                              firstDate: DateTime.now().subtract(const Duration(days: 365)),
                              lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                              builder: (c, child) => Theme(
                                data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: Color(0xFFFFC107))),
                                child: child!,
                              ),
                            );
                            if (picked != null) {
                              setDialogState(() => dueDate = DateTime(
                                picked.year, picked.month, picked.day, dueDate.hour, dueDate.minute,
                              ));
                            }
                          },
                          style: TextButton.styleFrom(foregroundColor: const Color(0xFFFFC107)),
                          icon: const Icon(Icons.calendar_today, size: 15),
                          label: Text('${dueDate.day}/${dueDate.month}/${dueDate.year}'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextButton.icon(
                          onPressed: () async {
                            final picked = await showTimePicker(
                              context: ctx,
                              initialTime: TimeOfDay.fromDateTime(dueDate),
                              builder: (c, child) => Theme(
                                data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: Color(0xFFFFC107))),
                                child: child!,
                              ),
                            );
                            if (picked != null) {
                              setDialogState(() => dueDate = dueDate.copyWith(hour: picked.hour, minute: picked.minute));
                            }
                          },
                          style: TextButton.styleFrom(foregroundColor: const Color(0xFFFFC107)),
                          icon: const Icon(Icons.access_time, size: 15),
                          label: Text(fmtClock(dueDate)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Alarm toggle
                  Row(
                    children: [
                      const Icon(Icons.notifications_active_outlined, color: Color(0xFFFFC107), size: 18),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text('Alarm', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      ),
                      Switch(
                        value: alarm,
                        activeThumbColor: const Color(0xFFFFC107),
                        onChanged: (v) {
                          setDialogState(() => alarm = v);
                          // Opting into an alarm is the right moment to ask for
                          // exact-alarm and full-screen access.
                          if (v) NotificationService().requestPermissions(askFullScreen: true);
                        },
                      ),
                    ],
                  ),
                  if (alarm) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const SizedBox(width: 28),
                        const Text('Remind me', style: TextStyle(color: Colors.white70, fontSize: 13)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: kLeadOptions.containsKey(lead) ? lead : 0,
                              isExpanded: true,
                              dropdownColor: const Color(0xFF19233E),
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              items: kLeadOptions.entries.map((e) => DropdownMenuItem(
                                value: e.key,
                                child: Text(e.value),
                              )).toList(),
                              onChanged: (v) => setDialogState(() => lead = v ?? 0),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      !willRing
                          ? 'That time has already passed — the task saves, but no device alert is set.'
                          : leadWillRing
                              ? 'Rings ${AppState.whenPhrase(alarmAt)}'
                              : 'Rings at ${fmtClock(dueDate)} only — the heads-up window has already passed.',
                      style: TextStyle(
                        color: willRing ? Colors.white38 : Colors.redAccent,
                        fontSize: 11.5,
                      ),
                    ),
                  ] else if (!willRing) ...[
                    const SizedBox(height: 2),
                    const Text(
                      'That time has already passed — the task saves, but no device alert is set.',
                      style: TextStyle(color: Colors.redAccent, fontSize: 11.5),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
            FilledButton(
              onPressed: () {
                if (titleCtrl.text.trim().isEmpty) return;
                state.upsertTask(AppTask(
                  id: existing?.id ?? state.nextTaskId,
                  title: titleCtrl.text.trim(),
                  description: descCtrl.text.trim(),
                  priority: priority,
                  status: existing?.status ?? TaskStatus.todo,
                  dueDate: dueDate,
                  linkedQuoteId: existing?.linkedQuoteId,
                  projectId: existing?.projectId,
                  alarmEnabled: alarm,
                  reminderLeadMinutes: alarm ? lead : 0,
                ));
                Navigator.pop(ctx);
              },
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFFC107), foregroundColor: Colors.black),
              child: Text(existing == null ? 'Add Task' : 'Save'),
            ),
          ],
          );
        },
      ),
    );
  }

  Widget _dialogField(String hint, TextEditingController ctrl, {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
        focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFFFC107))),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.04),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final AppTask task;
  final VoidCallback onEdit;
  const _TaskCard({required this.task, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final state = AppStateProvider.of(context);
    final isOverdue = task.dueDate.isBefore(DateTime.now()) && task.status != TaskStatus.done;
    final isDone = task.status == TaskStatus.done;

    return Card(
      color: const Color(0xFF19233E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: isOverdue ? Colors.red.withValues(alpha: 0.4) : Colors.transparent, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // â”€â”€ Checkbox / Done â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            GestureDetector(
              onTap: () {
                task.status = task.status == TaskStatus.done ? TaskStatus.todo : TaskStatus.done;
                state.updateTask(task);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 22,
                height: 22,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDone ? Colors.green : Colors.transparent,
                  border: Border.all(color: isDone ? Colors.green : Colors.white38, width: 2),
                ),
                child: isDone ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
              ),
            ),
            const SizedBox(width: 14),

            // â”€â”€ Content â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          task.title,
                          style: TextStyle(
                            color: isDone ? Colors.white38 : Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            decoration: isDone ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _priorityBadge(task.priority),
                    ],
                  ),
                  if (task.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(task.description, style: const TextStyle(color: Colors.white70, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 12,
                        color: isOverdue ? Colors.red : Colors.white38,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          _scheduleLine(task),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isOverdue ? Colors.red : Colors.white38,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      if (task.alarmEnabled) ...[
                        const SizedBox(width: 6),
                        Icon(
                          isDone ? Icons.notifications_off : Icons.alarm,
                          size: 12,
                          color: isDone ? Colors.white24 : const Color(0xFFFFC107),
                        ),
                      ],
                      const SizedBox(width: 8),
                      _statusChip(task.status),
                    ],
                  ),
                ],
              ),
            ),

            // â”€â”€ Status Toggle â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            IconButton(
              onPressed: onEdit,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              icon: const Icon(Icons.edit_outlined, color: Colors.white38, size: 16),
              tooltip: 'Edit task',
            ),
            PopupMenuButton<TaskStatus>(
              color: const Color(0xFF19233E),
              icon: const Icon(Icons.more_vert, color: Colors.white38, size: 18),
              onSelected: (s) {
                task.status = s;
                state.updateTask(task);
              },
              itemBuilder: (_) => TaskStatus.values.map((s) => PopupMenuItem(
                value: s,
                child: Row(
                  children: [
                    Icon(Icons.circle, color: s.color, size: 10),
                    const SizedBox(width: 8),
                    Text(s.label, style: const TextStyle(color: Colors.white)),
                  ],
                ),
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _priorityBadge(TaskPriority p) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: p.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(p.icon, size: 10, color: p.color),
          const SizedBox(width: 4),
          Text(p.label, style: TextStyle(color: p.color, fontSize: 10, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _statusChip(TaskStatus s) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: s.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
      child: Text(s.label, style: TextStyle(color: s.color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final diff = d.difference(DateTime(now.year, now.month, now.day)).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff == -1) return 'Yesterday';
    if (diff < 0) return 'Overdue by ${-diff}d';
    return '${d.day}/${d.month}/${d.year}';
  }

  String _scheduleLine(AppTask t) {
    final parts = <String>[_formatDate(t.dueDate), fmtClock(t.dueDate)];
    if (t.alarmEnabled && t.reminderLeadMinutes > 0) {
      parts.add('alarm ${t.reminderLeadMinutes}m before');
    }
    return parts.join(' · ');
  }
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// SCHEDULE TAB (Weekly Calendar)
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

class _ScheduleTab extends StatefulWidget {
  const _ScheduleTab();

  @override
  State<_ScheduleTab> createState() => _ScheduleTabState();
}

class _ScheduleTabState extends State<_ScheduleTab> {
  late DateTime _displayMonth; // first day of the currently displayed month
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _displayMonth = DateTime(now.year, now.month, 1);
    _selectedDay = now;
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isToday(DateTime d) => _isSameDay(d, DateTime.now());

  List<DateTime> _buildMonthGrid() {
    // First day of the month's weekday (1=Mon â€¦ 7=Sun)
    final firstWeekday = _displayMonth.weekday; // 1=Mon
    final daysInMonth = DateUtils.getDaysInMonth(_displayMonth.year, _displayMonth.month);

    // Days from previous month to fill leading cells
    final leadingDays = firstWeekday - 1;
    final prevMonth = DateTime(_displayMonth.year, _displayMonth.month - 1, 1);
    final daysInPrevMonth = DateUtils.getDaysInMonth(prevMonth.year, prevMonth.month);

    final List<DateTime> grid = [];

    // Leading cells (prev month)
    for (int i = leadingDays - 1; i >= 0; i--) {
      grid.add(DateTime(prevMonth.year, prevMonth.month, daysInPrevMonth - i));
    }
    // Current month
    for (int d = 1; d <= daysInMonth; d++) {
      grid.add(DateTime(_displayMonth.year, _displayMonth.month, d));
    }
    // Trailing cells (next month) to complete 6-row grid = 42 cells
    int trailing = 42 - grid.length;
    for (int d = 1; d <= trailing; d++) {
      grid.add(DateTime(_displayMonth.year, _displayMonth.month + 1, d));
    }
    return grid;
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateProvider.of(context);
    final monthName = _monthName(_displayMonth.month);
    final grid = _buildMonthGrid();

    final todayEvents = state.events.where((e) =>
        _isSameDay(e.startTime, _selectedDay)).toList();

    const weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.only(bottom: 80),
          children: [
            // â”€â”€ Month Navigator â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            Card(
              color: const Color(0xFF131B2F),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                child: Column(
                  children: [
                    // Header row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left, color: Color(0xFFFFC107)),
                          onPressed: () => setState(() {
                            _displayMonth = DateTime(_displayMonth.year, _displayMonth.month - 1, 1);
                          }),
                        ),
                        Column(
                          children: [
                            Text(
                              '$monthName ${_displayMonth.year}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${DateUtils.getDaysInMonth(_displayMonth.year, _displayMonth.month)} days',
                              style: const TextStyle(color: Colors.white38, fontSize: 11),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right, color: Color(0xFFFFC107)),
                          onPressed: () => setState(() {
                            _displayMonth = DateTime(_displayMonth.year, _displayMonth.month + 1, 1);
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Day-of-week headers
                    Row(
                      children: weekDays.map((d) => Expanded(
                        child: Center(
                          child: Text(d,
                            style: TextStyle(
                              color: (d == 'Sat' || d == 'Sun') ? const Color(0xFFFFC107).withValues(alpha: 0.6) : Colors.white38,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      )).toList(),
                    ),
                    const SizedBox(height: 6),

                    // Month grid â€” 6 rows Ã— 7 cols
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        childAspectRatio: 1.4,
                        crossAxisSpacing: 2,
                        mainAxisSpacing: 2,
                      ),
                      itemCount: 42,
                      itemBuilder: (ctx, idx) {
                        final day = grid[idx];
                        final isCurrentMonth = day.month == _displayMonth.month;
                        final isSelected = _isSameDay(day, _selectedDay);
                        final isToday = _isToday(day);
                        final eventColors = state.events
                            .where((e) => _isSameDay(e.startTime, day))
                            .map((e) => e.color)
                            .take(3)
                            .toList();

                        return GestureDetector(
                          onTap: () => setState(() => _selectedDay = day),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFFFC107)
                                  : isToday
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isToday && !isSelected
                                    ? const Color(0xFFFFC107).withValues(alpha: 0.6)
                                    : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${day.day}',
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.black
                                        : isCurrentMonth
                                            ? isToday ? const Color(0xFFFFC107) : Colors.white
                                            : Colors.white24,
                                    fontSize: 13,
                                    fontWeight: isToday || isSelected ? FontWeight.w800 : FontWeight.w500,
                                  ),
                                ),
                                if (eventColors.isNotEmpty)
                                  const SizedBox(height: 2),
                                if (eventColors.isNotEmpty)
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: eventColors.map((c) => Container(
                                      width: 4,
                                      height: 4,
                                      margin: const EdgeInsets.symmetric(horizontal: 1),
                                      decoration: BoxDecoration(
                                        color: isSelected ? Colors.black54 : c,
                                        shape: BoxShape.circle,
                                      ),
                                    )).toList(),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // â”€â”€ Selected day label â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  Text(
                    _formatSelectedDay(_selectedDay),
                    style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFC107).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${todayEvents.length} event${todayEvents.length == 1 ? '' : 's'}',
                      style: const TextStyle(color: Color(0xFFFFC107), fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // â”€â”€ Events for selected day â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            todayEvents.isEmpty
                ? _emptyState(
                    'No events',
                    'Tap + to add an event for this day',
                    Icons.event_available,
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: todayEvents.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) => _EventCard(
                      event: todayEvents[i],
                      onEdit: () => _showEventDialog(ctx, state, existing: todayEvents[i]),
                    ),
                  ),
          ],
        ),

        // â”€â”€ FAB â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        Positioned(
          bottom: 16,
          right: 0,
          child: FloatingActionButton.extended(
            heroTag: 'event_fab',
            onPressed: () => _showEventDialog(context, state),
            backgroundColor: const Color(0xFFFFC107),
            foregroundColor: Colors.black,
            icon: const Icon(Icons.add),
            label: const Text('Add Event', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  String _monthName(int m) => const [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ][m - 1];

  String _formatSelectedDay(DateTime d) {
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${days[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}';
  }

  void _showEventDialog(BuildContext context, AppState state, {AppEvent? existing}) {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    // _selectedDay is midnight of the browsed day, so a fixed 09:00 start meant
    // most new events were created already in the past and never armed.
    DateTime startDate;
    if (existing != null) {
      startDate = existing.startTime;
    } else {
      final now = DateTime.now();
      final selectedDay = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);
      final today = DateTime(now.year, now.month, now.day);
      startDate = selectedDay.isAfter(today)
          ? DateTime(selectedDay.year, selectedDay.month, selectedDay.day, 9, 0)
          : now.add(const Duration(minutes: 10));
    }
    DateTime eventDate = DateTime(startDate.year, startDate.month, startDate.day);
    TimeOfDay startTime = TimeOfDay.fromDateTime(startDate);
    TimeOfDay endTime = TimeOfDay.fromDateTime(
        existing?.endTime ?? startDate.add(const Duration(hours: 1)));
    Color eventColor = existing?.color ?? const Color(0xFFFFC107);
    bool alarm = existing?.alarmEnabled ?? false;
    int lead = existing?.reminderLeadMinutes ?? 15;

    final colorOptions = [
      const Color(0xFFFFC107),
      Colors.blue,
      Colors.purple,
      Colors.green,
      Colors.red,
      Colors.teal,
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final start = DateTime(eventDate.year, eventDate.month, eventDate.day, startTime.hour, startTime.minute);
          final alarmAt = start.subtract(Duration(minutes: lead));
          final willRing = start.isAfter(DateTime.now());
          final leadWillRing = alarmAt.isAfter(DateTime.now());
          return AlertDialog(
          backgroundColor: const Color(0xFF19233E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            existing == null ? 'Add New Event' : 'Edit Event',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _dialogField('Event Title', titleCtrl),
                  const SizedBox(height: 12),
                  _dialogField('Description (optional)', descCtrl, maxLines: 2),
                  const SizedBox(height: 16),
                  // Date picker
                  Row(
                    children: [
                      const Text('Date:', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      const SizedBox(width: 12),
                      TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: eventDate,
                            firstDate: DateTime.now().subtract(const Duration(days: 365)),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                            builder: (c, child) => Theme(
                              data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: Color(0xFFFFC107))),
                              child: child!,
                            ),
                          );
                          if (picked != null) setDialogState(() => eventDate = picked);
                        },
                        style: TextButton.styleFrom(foregroundColor: const Color(0xFFFFC107)),
                        child: Text('${eventDate.day}/${eventDate.month}/${eventDate.year}'),
                      ),
                    ],
                  ),
                  // Time pickers
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Start', style: TextStyle(color: Colors.white54, fontSize: 12)),
                            TextButton(
                              onPressed: () async {
                                final t = await showTimePicker(context: ctx, initialTime: startTime,
                                  builder: (c, child) => Theme(data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: Color(0xFFFFC107))), child: child!),
                                );
                                if (t != null) setDialogState(() => startTime = t);
                              },
                              style: TextButton.styleFrom(foregroundColor: const Color(0xFFFFC107)),
                              child: Text(startTime.format(ctx)),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward, color: Colors.white38, size: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('End', style: TextStyle(color: Colors.white54, fontSize: 12)),
                            TextButton(
                              onPressed: () async {
                                final t = await showTimePicker(context: ctx, initialTime: endTime,
                                  builder: (c, child) => Theme(data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: Color(0xFFFFC107))), child: child!),
                                );
                                if (t != null) setDialogState(() => endTime = t);
                              },
                              style: TextButton.styleFrom(foregroundColor: const Color(0xFFFFC107)),
                              child: Text(endTime.format(ctx)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Color picker
                  const Text('Color:', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 8),
                  Row(
                    children: colorOptions.map((c) => GestureDetector(
                      onTap: () => setDialogState(() => eventColor = c),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: eventColor == c ? Colors.white : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                      ),
                    )).toList(),
                  ),
                  const SizedBox(height: 8),
                  // Alarm toggle
                  Row(
                    children: [
                      const Icon(Icons.notifications_active_outlined, color: Color(0xFFFFC107), size: 18),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text('Alarm', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      ),
                      Switch(
                        value: alarm,
                        activeThumbColor: const Color(0xFFFFC107),
                        onChanged: (v) {
                          setDialogState(() => alarm = v);
                          // Opting into an alarm is the right moment to ask for
                          // exact-alarm and full-screen access.
                          if (v) NotificationService().requestPermissions(askFullScreen: true);
                        },
                      ),
                    ],
                  ),
                  if (alarm) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const SizedBox(width: 28),
                        const Text('Remind me', style: TextStyle(color: Colors.white70, fontSize: 13)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: kLeadOptions.containsKey(lead) ? lead : 15,
                              isExpanded: true,
                              dropdownColor: const Color(0xFF19233E),
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              items: kLeadOptions.entries.map((e) => DropdownMenuItem(
                                value: e.key,
                                child: Text(e.value),
                              )).toList(),
                              onChanged: (v) => setDialogState(() => lead = v ?? 15),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      !willRing
                          ? 'This event starts in the past — it saves, but no device alert is set.'
                          : leadWillRing
                              ? 'Alerts: ${AppState.whenPhrase(alarmAt)}, then at ${fmtClock(start)}'
                              : 'Alerts at ${fmtClock(start)} only — the heads-up window has already passed.',
                      style: TextStyle(
                        color: willRing ? Colors.white38 : Colors.redAccent,
                        fontSize: 11.5,
                      ),
                    ),
                  ] else if (!willRing) ...[
                    // Quiet reminders are still scheduled per event, so a past
                    // start time matters even with the alarm switch off.
                    const SizedBox(height: 2),
                    const Text(
                      'This event starts in the past — it saves, but no device alert is set.',
                      style: TextStyle(color: Colors.redAccent, fontSize: 11.5),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
            FilledButton(
              onPressed: () {
                if (titleCtrl.text.trim().isEmpty) return;
                final end = DateTime(eventDate.year, eventDate.month, eventDate.day, endTime.hour, endTime.minute);
                state.upsertEvent(AppEvent(
                  id: existing?.id ?? state.nextEventId,
                  title: titleCtrl.text.trim(),
                  description: descCtrl.text.trim(),
                  startTime: start,
                  // An end clock-time earlier than the start means it runs past midnight.
                  endTime: end.isAfter(start) ? end : end.add(const Duration(days: 1)),
                  color: eventColor,
                  alarmEnabled: alarm,
                  reminderLeadMinutes: lead,
                ));
                Navigator.pop(ctx);
              },
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFFC107), foregroundColor: Colors.black),
              child: Text(existing == null ? 'Add Event' : 'Save'),
            ),
          ],
          );
        },
      ),
    );
  }

  Widget _dialogField(String hint, TextEditingController ctrl, {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
        focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFFFC107))),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.04),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final AppEvent event;
  final VoidCallback onEdit;
  const _EventCard({required this.event, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final state = AppStateProvider.of(context);
    final now = DateTime.now();
    final duration = event.endTime.difference(event.startTime);
    final hours = duration.inHours;
    final mins = duration.inMinutes % 60;
    final durationStr = hours > 0 ? '${hours}h${mins > 0 ? ' ${mins}m' : ''}' : '${mins}m';
    final phase = _phase(now);
    final isLive = !now.isBefore(event.startTime) && now.isBefore(event.endTime);
    final isEnded = !now.isBefore(event.endTime);

    return Card(
      color: const Color(0xFF19233E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: event.color,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: event.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.event, color: event.color, size: 18),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  event.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isEnded ? Colors.white38 : Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    decoration: isEnded ? TextDecoration.lineThrough : null,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _phasePill(phase, isLive, isEnded),
                            ],
                          ),
                          if (event.description.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(event.description, style: const TextStyle(color: Colors.white54, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.access_time, size: 12, color: event.color),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  '${_fmtTime(event.startTime)} – ${_fmtTime(event.endTime)} ($durationStr)',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: event.color, fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ),
                              if (event.alarmEnabled) ...[
                                const SizedBox(width: 8),
                                const Icon(Icons.alarm, size: 12, color: Color(0xFFFFC107)),
                                if (event.reminderLeadMinutes > 0) ...[
                                  const SizedBox(width: 3),
                                  Flexible(
                                    child: Text(
                                      '-${event.reminderLeadMinutes}m',
                                      maxLines: 1,
                                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                                    ),
                                  ),
                                ],
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined, color: Colors.white24, size: 18),
                      tooltip: 'Edit event',
                    ),
                    IconButton(
                      onPressed: () => _confirmDelete(context, state),
                      icon: const Icon(Icons.delete_outline, color: Colors.white24, size: 18),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtTime(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }

  String _phase(DateTime now) {
    if (!now.isBefore(event.endTime)) return 'Ended';
    if (!now.isBefore(event.startTime)) return 'Live now';
    final until = event.startTime.difference(now);
    if (until.inDays >= 1) return 'in ${until.inDays}d';
    if (until.inHours >= 1) return 'in ${until.inHours}h ${until.inMinutes % 60}m';
    if (until.inMinutes >= 1) return 'in ${until.inMinutes}m';
    return 'Starting';
  }

  Widget _phasePill(String label, bool isLive, bool isEnded) {
    final color = isLive ? const Color(0xFF22C55E) : isEnded ? Colors.white38 : event.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLive) ...[
            Icon(Icons.circle, size: 6, color: color),
            const SizedBox(width: 4),
          ],
          Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, AppState state) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF19233E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Event?', style: TextStyle(color: Colors.white)),
        content: Text('Remove "${event.title}"?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () { state.deleteEvent(event.id); Navigator.pop(context); },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// â”€â”€ Shared empty state â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

Widget _emptyState(String title, String subtitle, IconData icon) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: Colors.white12, size: 64),
        const SizedBox(height: 16),
        Text(title, style: const TextStyle(color: Colors.white38, fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(subtitle, style: const TextStyle(color: Colors.white24, fontSize: 13)),
      ],
    ),
  );
}

