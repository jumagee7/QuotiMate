// widgets/project_extras.dart — Project photos, notes and task tracking

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../models.dart';

const _surface = Color(0xFF161B26);
const _panel   = Color(0xFF0F162C);
const _border  = Color(0xFF2A3045);
const _gold    = Color(0xFFFFC107);
const _white38 = Color(0xFF616C88);
const _white70 = Color(0xFFB0B8D0);
const _green   = Color(0xFF10B981);
const _red     = Color(0xFFEF4444);

final _dateTimeFmt = DateFormat('dd MMM yyyy, HH:mm');

/// Picks a photo, downscaled and compressed so it can be stored with the project.
Future<String?> pickProjectImage(BuildContext context) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: _surface,
    builder: (ctx) => SafeArea(
      child: Wrap(children: [
        ListTile(
          leading: const Icon(Icons.photo_camera_outlined, color: _gold),
          title: const Text('Take photo', style: TextStyle(color: Colors.white)),
          onTap: () => Navigator.pop(ctx, ImageSource.camera),
        ),
        ListTile(
          leading: const Icon(Icons.photo_library_outlined, color: _gold),
          title: const Text('Choose from gallery', style: TextStyle(color: Colors.white)),
          onTap: () => Navigator.pop(ctx, ImageSource.gallery),
        ),
      ]),
    ),
  );
  if (source == null) return null;
  try {
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 60,
    );
    if (file == null) return null;
    return base64Encode(await file.readAsBytes());
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load image: $e'), backgroundColor: _red),
      );
    }
    return null;
  }
}

Uint8List? _decode(String b64) {
  try {
    return base64Decode(b64);
  } catch (_) {
    return null;
  }
}

void _openImage(BuildContext context, String b64) {
  final bytes = _decode(b64);
  if (bytes == null) return;
  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(12),
      child: Stack(children: [
        InteractiveViewer(child: Image.memory(bytes, fit: BoxFit.contain)),
        Positioned(
          right: 4, top: 4,
          child: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(ctx),
          ),
        ),
      ]),
    ),
  );
}

class _Thumb extends StatelessWidget {
  final String data;
  final double size;
  final VoidCallback? onDelete;
  const _Thumb({required this.data, this.size = 84, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final bytes = _decode(data);
    return Stack(children: [
      GestureDetector(
        onTap: () => _openImage(context, data),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: size, height: size, color: _panel,
            child: bytes == null
                ? const Icon(Icons.broken_image_outlined, color: _white38)
                : Image.memory(bytes, fit: BoxFit.cover),
          ),
        ),
      ),
      if (onDelete != null)
        Positioned(
          right: 2, top: 2,
          child: InkWell(
            onTap: onDelete,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
    ]);
  }
}

// ── Summary photos ───────────────────────────────────────────────────────────

class ProjectSummaryImages extends StatelessWidget {
  final AppState appState;
  final Project project;
  const ProjectSummaryImages({super.key, required this.appState, required this.project});

  Future<void> _add(BuildContext context) async {
    final img = await pickProjectImage(context);
    if (img == null) return;
    appState.setProjectSummaryImages(project.id, [...project.summaryImages, img]);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.photo_library_outlined, color: _gold, size: 18),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('PROJECT PHOTOS',
                style: TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 1.1, fontWeight: FontWeight.bold)),
          ),
          TextButton.icon(
            onPressed: () => _add(context),
            icon: const Icon(Icons.add_a_photo_outlined, size: 16, color: _gold),
            label: const Text('Add', style: TextStyle(color: _gold)),
          ),
        ]),
        if (project.description.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(project.description, style: const TextStyle(color: _white70, fontSize: 13)),
        ],
        const SizedBox(height: 10),
        if (project.summaryImages.isEmpty)
          const Text('No photos yet — add site photos, colour samples or progress shots.',
              style: TextStyle(color: _white38, fontSize: 12))
        else
          SizedBox(
            height: 84,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: project.summaryImages.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) => _Thumb(
                data: project.summaryImages[i],
                onDelete: () {
                  final list = [...project.summaryImages]..removeAt(i);
                  appState.setProjectSummaryImages(project.id, list);
                },
              ),
            ),
          ),
      ]),
    );
  }
}

// ── Notes tab ────────────────────────────────────────────────────────────────

class ProjectNotesTab extends StatelessWidget {
  final AppState appState;
  final Project project;
  const ProjectNotesTab({super.key, required this.appState, required this.project});

  Future<void> _addNote(BuildContext context) async {
    final textCtrl = TextEditingController();
    final images = <String>[];
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: _surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _border)),
          title: const Text('New Project Note', style: TextStyle(color: Colors.white, fontSize: 16)),
          content: SizedBox(
            width: 420,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextField(
                controller: textCtrl,
                maxLines: 5,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Site observations, client requests, colour choices...',
                  hintStyle: const TextStyle(color: _white38),
                  filled: true,
                  fillColor: _panel,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _border)),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (var i = 0; i < images.length; i++)
                  _Thumb(data: images[i], size: 64, onDelete: () => setDlg(() => images.removeAt(i))),
                InkWell(
                  onTap: () async {
                    final img = await pickProjectImage(ctx);
                    if (img != null) setDlg(() => images.add(img));
                  },
                  child: Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                      color: _panel,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _border),
                    ),
                    child: const Icon(Icons.add_a_photo_outlined, color: _gold),
                  ),
                ),
              ]),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _gold, foregroundColor: Colors.black),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save Note'),
            ),
          ],
        ),
      ),
    );
    if (saved != true) return;
    if (textCtrl.text.trim().isEmpty && images.isEmpty) return;
    appState.addProjectNote(project.id, ProjectNote(
      id: 'note_${DateTime.now().millisecondsSinceEpoch}',
      text: textCtrl.text.trim(),
      images: images,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add_note_${project.id}',
        backgroundColor: _gold,
        foregroundColor: Colors.black,
        onPressed: () => _addNote(context),
        icon: const Icon(Icons.note_add_outlined),
        label: const Text('Add Note'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          ProjectSummaryImages(appState: appState, project: project),
          const SizedBox(height: 16),
          if (project.notes.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text('No notes yet', style: TextStyle(color: _white38)),
              ),
            ),
          for (final note in project.notes)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _border),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.sticky_note_2_outlined, color: _gold, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(_dateTimeFmt.format(note.createdAt),
                        style: const TextStyle(color: _white38, fontSize: 11)),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.delete_outline, color: _red, size: 18),
                    onPressed: () => appState.deleteProjectNote(project.id, note.id),
                  ),
                ]),
                if (note.text.isNotEmpty)
                  Text(note.text, style: const TextStyle(color: Colors.white, fontSize: 14)),
                if (note.images.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final img in note.images) _Thumb(data: img, size: 72),
                  ]),
                ],
              ]),
            ),
        ],
      ),
    );
  }
}

// ── Tasks tab ────────────────────────────────────────────────────────────────

class ProjectTasksTab extends StatelessWidget {
  final AppState appState;
  final Project project;
  const ProjectTasksTab({super.key, required this.appState, required this.project});

  Color _priorityColor(TaskPriority p) => switch (p) {
    TaskPriority.high => _red,
    TaskPriority.medium => _gold,
    TaskPriority.low => _green,
  };

  Future<void> _editTask(BuildContext context, [AppTask? existing]) async {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    var priority = existing?.priority ?? TaskPriority.medium;
    var due = existing?.dueDate ?? DateTime.now().add(const Duration(days: 1));
    var alarm = existing?.alarmEnabled ?? false;

    InputDecoration dec(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _white38),
      filled: true,
      fillColor: _panel,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _border)),
    );

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: _surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _border)),
          title: Text(existing == null ? 'New Project Task' : 'Edit Task',
              style: const TextStyle(color: Colors.white, fontSize: 16)),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: titleCtrl, autofocus: existing == null,
                    style: const TextStyle(color: Colors.white), decoration: dec('Task title')),
                const SizedBox(height: 10),
                TextField(controller: descCtrl, maxLines: 3,
                    style: const TextStyle(color: Colors.white), decoration: dec('Details (optional)')),
                const SizedBox(height: 10),
                SegmentedButton<TaskPriority>(
                  segments: const [
                    ButtonSegment(value: TaskPriority.low, label: Text('Low')),
                    ButtonSegment(value: TaskPriority.medium, label: Text('Medium')),
                    ButtonSegment(value: TaskPriority.high, label: Text('High')),
                  ],
                  selected: {priority},
                  onSelectionChanged: (s) => setDlg(() => priority = s.first),
                ),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule, color: _gold),
                  title: const Text('Due', style: TextStyle(color: _white70, fontSize: 12)),
                  subtitle: Text(_dateTimeFmt.format(due), style: const TextStyle(color: Colors.white)),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: due,
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                    );
                    if (d == null || !ctx.mounted) return;
                    final t = await showTimePicker(context: ctx, initialTime: TimeOfDay.fromDateTime(due));
                    setDlg(() => due = DateTime(d.year, d.month, d.day, t?.hour ?? due.hour, t?.minute ?? due.minute));
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: _gold,
                  value: alarm,
                  onChanged: (v) => setDlg(() => alarm = v),
                  title: const Text('Alarm reminder', style: TextStyle(color: Colors.white)),
                  subtitle: const Text('Rings like an alarm when due', style: TextStyle(color: _white38, fontSize: 12)),
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _gold, foregroundColor: Colors.black),
              onPressed: () => Navigator.pop(ctx, titleCtrl.text.trim().isNotEmpty),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    if (existing == null) {
      appState.addTask(AppTask(
        id: 'task_${DateTime.now().millisecondsSinceEpoch}',
        title: titleCtrl.text.trim(),
        description: descCtrl.text.trim(),
        priority: priority,
        dueDate: due,
        alarmEnabled: alarm,
        projectId: project.id,
      ));
    } else {
      existing
        ..title = titleCtrl.text.trim()
        ..description = descCtrl.text.trim()
        ..priority = priority
        ..dueDate = due
        ..alarmEnabled = alarm;
      appState.updateTask(existing);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tasks = appState.tasksForProject(project.id)
      ..sort((a, b) {
        final byStatus = (a.status == TaskStatus.done ? 1 : 0) - (b.status == TaskStatus.done ? 1 : 0);
        return byStatus != 0 ? byStatus : a.dueDate.compareTo(b.dueDate);
      });
    final done = tasks.where((t) => t.status == TaskStatus.done).length;
    final progress = tasks.isEmpty ? 0.0 : done / tasks.length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add_task_${project.id}',
        backgroundColor: _gold,
        foregroundColor: Colors.black,
        onPressed: () => _editTask(context),
        icon: const Icon(Icons.add_task),
        label: const Text('Add Task'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('TASK PROGRESS',
                    style: TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 1.1, fontWeight: FontWeight.bold)),
                Text('$done / ${tasks.length} done',
                    style: const TextStyle(color: _gold, fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: _panel,
                  valueColor: AlwaysStoppedAnimation(progress >= 1 ? _green : _gold),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          if (tasks.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: Text('No tasks yet', style: TextStyle(color: _white38))),
            ),
          for (final task in tasks)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(12),
                border: Border(left: BorderSide(color: _priorityColor(task.priority), width: 4)),
              ),
              child: ListTile(
                onTap: () => _editTask(context, task),
                leading: Checkbox(
                  activeColor: _green,
                  value: task.status == TaskStatus.done,
                  onChanged: (v) {
                    task.status = v == true ? TaskStatus.done : TaskStatus.todo;
                    appState.updateTask(task);
                  },
                ),
                title: Text(
                  task.title,
                  style: TextStyle(
                    color: task.status == TaskStatus.done ? _white38 : Colors.white,
                    decoration: task.status == TaskStatus.done ? TextDecoration.lineThrough : null,
                  ),
                ),
                subtitle: Text(
                  [
                    _dateTimeFmt.format(task.dueDate),
                    if (task.description.isNotEmpty) task.description,
                  ].join(' • '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: task.status != TaskStatus.done && task.dueDate.isBefore(DateTime.now()) ? _red : _white38,
                    fontSize: 12,
                  ),
                ),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (task.alarmEnabled) const Icon(Icons.alarm, color: _gold, size: 16),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: _red, size: 18),
                    onPressed: () => appState.deleteTask(task.id),
                  ),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}
