import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quotimate/pages/update_prompt.dart';
import 'package:quotimate/services/update_service.dart';

AppRelease _release() => AppRelease.fromGitHub({
      'tag_name': 'v1.1.0',
      'name': 'QuotiMate v1.1.0',
      'body': 'Faster syncing and new project notes.',
      'html_url': 'https://github.com/jumagee7/QuotiMate/releases/tag/v1.1.0',
      'assets': [
        {
          'name': 'app-arm64-v8a-release.apk',
          'size': 39302139,
          'browser_download_url': 'https://example.com/app-arm64-v8a-release.apk',
        },
      ],
    });

Widget _host(Widget child) => MaterialApp(
      theme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('prompt shows version, notes and update/later actions', (tester) async {
    await tester.pumpWidget(_host(UpdatePromptDialog(
      release: _release(),
      installedVersion: '1.0.1+2',
    )));

    expect(find.text('Update available'), findsOneWidget);
    expect(find.textContaining('v1.1.0'), findsOneWidget);
    expect(find.textContaining('you have 1.0.1+2'), findsOneWidget);
    expect(find.text('Faster syncing and new project notes.'), findsOneWidget);
    expect(find.text('Update now'), findsOneWidget);
    expect(find.text('Later'), findsOneWidget);
  });

  testWidgets('clean install path warns about local data before saving', (tester) async {
    await tester.pumpWidget(_host(UpdatePromptDialog(
      release: _release(),
      installedVersion: '1.0.1+2',
    )));

    await tester.tap(find.text('Update fails? Uninstall previous version first'));
    await tester.pumpAndSettle();

    expect(find.text('This erases local data on this phone'), findsOneWidget);
    expect(find.text('Save APK & continue'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Update now'), findsOneWidget);
  });

  testWidgets('release without an APK cannot start a download', (tester) async {
    final release = AppRelease.fromGitHub({'tag_name': 'v1.1.0', 'assets': <dynamic>[]});
    await tester.pumpWidget(_host(UpdatePromptDialog(
      release: release,
      installedVersion: '1.0.1+2',
    )));

    final button = tester.widget<FilledButton>(
      find.ancestor(of: find.text('Update now'), matching: find.byType(FilledButton)),
    );
    expect(button.onPressed, isNull);
  });
}
