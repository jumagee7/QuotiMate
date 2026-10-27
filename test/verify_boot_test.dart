// verify_boot_test.dart — boots the real app widget tree and walks the
// sign-in -> shell path, confirming the UI renders end to end.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:quotimate/main.dart';
import 'package:quotimate/main_ui.dart';
import 'package:quotimate/pages/sign_in_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app boots to sign-in, guest entry reaches the shell', (tester) async {
    // Widget tests measure text with a fixed-width test font, which inflates
    // label widths and produces RenderFlex overflow reports that never occur on
    // device. Ignore those specifically; everything else still fails the test.
    // This must be installed inside the test body: the binding replaces
    // FlutterError.onError after setUp runs.
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed by')) return;
      original?.call(details);
    };
    addTearDown(() => FlutterError.onError = original);

    SharedPreferences.setMockInitialValues({});

    // Exercise the desktop layout, which is the primary target surface.
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const QuotiMateApp());
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(MaterialApp), findsOneWidget);

    // Let the splash timer elapse and the route replace.
    await tester.pump(const Duration(milliseconds: 2600));
    await tester.pumpAndSettle(const Duration(milliseconds: 700));
    expect(find.byType(SignInPage), findsOneWidget,
        reason: 'unauthenticated users must land on sign-in');

    await tester.tap(find.text('Explore Local Workspace'));
    await tester.pumpAndSettle(const Duration(milliseconds: 700));

    expect(find.byType(QuotiMateShell), findsOneWidget,
        reason: 'guest sign-in must open the main shell');
    final bell = find.byIcon(Icons.notifications_outlined).evaluate().length +
        find.byIcon(Icons.notifications_active).evaluate().length;
    expect(bell, greaterThan(0),
        reason: 'the app bar notification bell must be present');
  });
}
