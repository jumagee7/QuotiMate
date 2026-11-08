import 'package:flutter_test/flutter_test.dart';
import 'package:quotimate/services/update_service.dart';

void main() {
  group('Version comparison', () {
    test('detects newer releases across major/minor/patch', () {
      expect(UpdateService.compareVersions('v1.2.0', '1.1.9'), greaterThan(0));
      expect(UpdateService.compareVersions('1.10.0', '1.9.9'), greaterThan(0));
      expect(UpdateService.compareVersions('v2.0.0', '1.99.99'), greaterThan(0));
      expect(UpdateService.compareVersions('1.0.0', '1.0.1'), lessThan(0));
    });

    test('ignores tag prefix, build number and pre-release suffix', () {
      expect(UpdateService.compareVersions('v1.0.0', '1.0.0+2002'), 0);
      expect(UpdateService.compareVersions('1.0.0+3', 'v1.0.0'), 0);
      expect(UpdateService.compareVersions('v1.1.0-beta', '1.0.9'), greaterThan(0));
    });

    test('isNewerThan only fires for a higher version', () {
      final release = AppRelease.fromGitHub({
        'tag_name': 'v1.3.0',
        'name': 'QuotiMate v1.3.0',
        'body': 'notes',
        'html_url': 'https://github.com/jumagee7/QuotiMate/releases/tag/v1.3.0',
        'assets': <dynamic>[],
      });
      expect(release.isNewerThan('1.2.9+8'), isTrue);
      expect(release.isNewerThan('1.3.0+9'), isFalse);
      expect(release.isNewerThan('1.4.0'), isFalse);
    });

    test('never offers an older release than the installed build', () {
      final stale = AppRelease.fromGitHub({
        'tag_name': 'v1.0.0',
        'assets': <dynamic>[],
      });
      expect(stale.isNewerThan('1.0.1+2002'), isFalse);
    });
  });

  group('Release asset selection', () {
    Map<String, dynamic> asset(String name, int size) => {
          'name': name,
          'size': size,
          'browser_download_url': 'https://example.com/$name',
        };

    test('prefers the arm64 split APK', () {
      final release = AppRelease.fromGitHub({
        'tag_name': 'v1.1.0',
        'assets': [
          asset('app-armeabi-v7a-release.apk', 100),
          asset('app-arm64-v8a-release.apk', 200),
          asset('app-x86_64-release.apk', 300),
        ],
      });
      expect(release.apkName, 'app-arm64-v8a-release.apk');
      expect(release.apkBytes, 200);
      expect(release.apkUrl, 'https://example.com/app-arm64-v8a-release.apk');
    });

    test('falls back to any APK and ignores non-APK assets', () {
      final release = AppRelease.fromGitHub({
        'tag_name': 'v1.1.0',
        'assets': [
          asset('checksums.txt', 10),
          asset('app-release.apk', 400),
        ],
      });
      expect(release.apkName, 'app-release.apk');
      expect(release.apkBytes, 400);
    });

    test('release without APKs leaves download unavailable', () {
      final release = AppRelease.fromGitHub({'tag_name': 'v1.1.0', 'assets': <dynamic>[]});
      expect(release.apkUrl, isNull);
    });
  });

  group('Atom feed fallback (API rate-limited)', () {
    const feed = '''
<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns="http://www.w3.org/2005/Atom" xml:lang="en-US">
  <entry>
    <id>tag:github.com,2008:Repository/1/v1.0.8</id>
    <link rel="alternate" type="text/html" href="https://github.com/jumagee7/QuotiMate/releases/tag/v1.0.8"/>
    <title>QuotiMate v1.0.8</title>
    <content type="html">&lt;h2&gt;Background alerts&lt;/h2&gt;
&lt;p&gt;Alarms now name the blocker &amp; offer a fix.&lt;/p&gt;
&lt;ul&gt;
&lt;li&gt;Health pills&lt;/li&gt;
&lt;/ul&gt;</content>
  </entry>
  <entry>
    <id>tag:github.com,2008:Repository/1/v1.0.7</id>
    <link rel="alternate" type="text/html" href="https://github.com/jumagee7/QuotiMate/releases/tag/v1.0.7"/>
    <title>QuotiMate v1.0.7</title>
    <content type="html">older</content>
  </entry>
</feed>
''';

    test('reads the newest tag, notes and download URL', () {
      final release = UpdateService.parseReleaseFeed(feed);
      expect(release, isNotNull);
      expect(release!.tagName, 'v1.0.8');
      expect(release.name, 'QuotiMate v1.0.8');
      expect(release.htmlUrl, endsWith('/releases/tag/v1.0.8'));
      expect(release.apkName, 'QuotiMate-v1.0.8-arm64-v8a.apk');
      expect(
        release.apkUrl,
        'https://github.com/jumagee7/QuotiMate/releases/latest/download/QuotiMate-v1.0.8-arm64-v8a.apk',
      );
      expect(release.notes, contains('Background alerts'));
      expect(release.notes, contains('Health pills'));
      expect(release.notes, contains('blocker & offer a fix'));
      expect(release.notes, isNot(contains('<')));
      expect(release.isNewerThan('1.0.7+2008'), isTrue);
      expect(release.isNewerThan('1.0.8+2009'), isFalse);
    });

    test('an empty or unrelated feed yields no release', () {
      expect(UpdateService.parseReleaseFeed(''), isNull);
      expect(UpdateService.parseReleaseFeed('<feed></feed>'), isNull);
      expect(
        UpdateService.parseReleaseFeed('<entry><title>x</title></entry>'),
        isNull,
      );
    });
  });
}
