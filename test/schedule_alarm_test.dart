// Schedule page: alarm lead is shown, configurable, and events report live state.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quotimate/app_state.dart';
import 'package:quotimate/models.dart';
import 'package:quotimate/pages/schedule_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AppState> boot(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final state = AppState();
    // AppState runs a periodic ticker; the harness disposes it with the tree,
    // which flutter_test tears down before checking for pending timers.
    await tester.pumpWidget(MaterialApp(
      home: _Harness(state: state, child: const SchedulePage()),
    ));
    // Let AppState._init()'s async loads settle before interacting.
    await tester.pump(const Duration(milliseconds: 400));
    return state;
  }

  testWidgets('task card shows the alarm lead and the dialog sets it', (tester) async {
    final state = await boot(tester);
    final due = DateTime.now().add(const Duration(hours: 3));
    state.upsertTask(AppTask(
      id: 'T-9',
      title: 'Deliver quotation',
      dueDate: due,
      alarmEnabled: true,
      reminderLeadMinutes: 15,
    ));
    await tester.pump();

    expect(find.textContaining('alarm 15m before'), findsOneWidget);

    await tester.tap(find.text('Add Task'));
    await tester.pumpAndSettle();
    expect(find.text('Add New Task'), findsOneWidget);
    expect(find.text('Remind me'), findsNothing);

    await tester.enterText(find.byType(TextField).first, 'Call client');

    // Turning the alarm on reveals the lead picker and the resolved ring time.
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.text('Remind me'), findsOneWidget);
    expect(find.textContaining('Rings'), findsOneWidget);

    await tester.tap(find.byType(DropdownButton<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1 hour before'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Task').last);
    await tester.pumpAndSettle();

    final created = state.tasks.last;
    expect(created.title, 'Call client');
    expect(created.alarmEnabled, isTrue);
    expect(created.reminderLeadMinutes, 60);
    expect(created.alarmAt, created.dueDate.subtract(const Duration(minutes: 60)));
  });

  testWidgets('a new event defaults to a start time that can still ring', (tester) async {
    final state = await boot(tester);

    await tester.tap(find.text('Schedule'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add Event'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Event Title'), 'Site handover');
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    // The default 15-minute lead no longer fits inside a ~10-minute start, so the
    // dialog must report the alert that can actually ring.
    expect(find.textContaining('heads-up window has already passed'), findsOneWidget);

    await tester.tap(find.text('Add Event').last);
    await tester.pumpAndSettle();

    final created = state.events.last;
    expect(created.startTime.isAfter(DateTime.now()), isTrue,
        reason: 'a new event must not default into the past, or no alarm is armed');
    expect(created.endTime.isAfter(created.startTime), isTrue);
    expect(created.alarmEnabled, isTrue);
  });

  testWidgets('event card reports Live now while it is running', (tester) async {
    final state = await boot(tester);
    final now = DateTime.now();
    state.upsertEvent(AppEvent(
      id: 'EV-9',
      title: 'Site handover',
      startTime: now.subtract(const Duration(hours: 1)),
      endTime: now.add(const Duration(hours: 1)),
      alarmEnabled: true,
    ));
    await tester.pump();

    await tester.tap(find.text('Schedule'));
    await tester.pumpAndSettle();

    expect(find.text('Site handover'), findsOneWidget);
    expect(find.text('Live now'), findsOneWidget);
  });
}

class _Harness extends StatefulWidget {
  const _Harness({required this.state, required this.child});

  final AppState state;
  final Widget child;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  @override
  void dispose() {
    widget.state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: AppStateProvider(state: widget.state, child: widget.child),
      );
}
