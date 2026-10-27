// Overflow guards for price-bearing cards (narrow phone + large text scale).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quotimate/app_state.dart';
import 'package:quotimate/models.dart';
import 'package:quotimate/pages/dashboard_page.dart';
import 'package:quotimate/widgets/money_text.dart';
import 'package:quotimate/widgets/project_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppState state;
  setUp(() async {
    await runZonedGuarded(() async {
      state = AppState();
      // Let the constructor's fire-and-forget _init fail harmlessly.
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }, (_, __) {});
  });

  testWidgets('MoneyText shrinks instead of overflowing its row', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 120,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Flexible(child: Text('Net Profit Realized', maxLines: 1)),
                SizedBox(width: 10),
                MoneyText('KES 12,345,678.00', maxWidth: 100),
              ],
            ),
          ),
        ),
      ),
    ));
    expect(tester.takeException(), isNull);
  });

  testWidgets('ProjectCard fits 320dp at 1.3x text scale', (tester) async {
    final project = Project(
      id: 'PRJ-1755000000',
      number: 7,
      name: 'Riverside Apartments Fit-Out Phase Two',
      clientId: 'c1',
      clientName: 'Kamau & Wanjiru Properties Limited',
      startDate: DateTime(2026),
      budget: 12345678,
      location: 'Kiambu Road, Nairobi',
    );
    state.addTask(AppTask(
      id: 't1',
      title: 'Prime walls',
      dueDate: DateTime(2026, 11, 1),
      projectId: project.id,
    ));
    state.addTask(AppTask(
      id: 't2',
      title: 'Install ceiling',
      dueDate: DateTime(2026, 11, 2),
      projectId: project.id,
      status: TaskStatus.done,
    ));

    tester.view.physicalSize = const Size(320 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MediaQuery(
          data: const MediaQueryData(textScaleFactor: 1.3),
          child: ListView(
            children: [
              ProjectCard(project: project, state: state),
              ProjectCard(project: project, state: state, margin: EdgeInsets.zero),
            ],
          ),
        ),
      ),
    ));

    expect(tester.takeException(), isNull);
    // The card fills the available width on both home and projects pages.
    expect(tester.getSize(find.byType(ProjectCard).first).width, 320);
    // The number badge is the real stored number, not digits of the timestamp id.
    expect(find.text('PRJ-007'), findsNWidgets(2));
    expect(find.text('1 to do · 1 completed'), findsNWidgets(2));
  });

  testWidgets('Dashboard at 360dp keeps KPI tiles equal and groups amounts', (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 1600 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    state.addQuote(Quote(
      id: 'Q-1042',
      clientId: 'c1',
      clientName: 'Kamau & Wanjiru Properties Limited',
      date: DateTime(2026, 10, 1),
      expiryDate: DateTime(2026, 10, 31),
      categories: [
        QuoteCategory(
          id: 'cat1',
          name: 'Flooring',
          items: [
            QuoteItem(
              productId: 'p1',
              name: 'Oak Laminate 12mm',
              description: 'Code: LAM-12 / Grade A',
              qty: 3,
              unitPrice: 6172839,
            ),
          ],
        ),
      ],
    ));

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AppStateProvider(state: state, child: const DashboardPage()),
      ),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);

    Rect tile(String label) => tester.getRect(
          find.ancestor(of: find.text(label), matching: find.byType(Container)).last,
        );

    // Both tiles in the first KPI row must be the same size; an unwrapped label
    // used to make 'QUOTATIONS THIS MONTH' taller than its neighbour.
    expect(tile('QUOTATIONS THIS MONTH').height, tile('TOTAL APPROVED').height);
    expect(tile('PENDING APPROVALS').height, tile('CONVERSION RATE').height);

    // Amounts must read as grouped digits, never 'KES18518517'.
    expect(find.textContaining(RegExp(r'\d{1,3}(,\d{3})+')), findsWidgets);
  });
}
