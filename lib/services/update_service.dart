// services/update_service.dart — GitHub release checks, APK download & install

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_service.dart';

/// Thrown when the user cancels an in-flight download.
class UpdateCancelled implements Exception {
  const UpdateCancelled();
}

/// Throwaway cancellation flag shared with the download loop.
class DownloadCancelToken {
  bool _cancelled = false;
  void cancel() => _cancelled = true;
  bool get isCancelled => _cancelled;
}

/// A GitHub release with the matching APK asset already picked out.
class AppRelease {
  final String tagName;
  final String name;
  final String notes;
  final String htmlUrl;
  final String? apkUrl;
  final String? apkName;
  final int apkBytes;

  const AppRelease({
    required this.tagName,
    required this.name,
    required this.notes,
    required this.htmlUrl,
    required this.apkUrl,
    required this.apkName,
    required this.apkBytes,
  });

  factory AppRelease.fromGitHub(Map<String, dynamic> json) {
    final assets = (json['assets'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .where((a) => (a['name'] as String? ?? '').toLowerCase().endsWith('.apk'))
        .toList();

    Map<String, dynamic>? pick;
    for (final asset in assets) {
      final name = (asset['name'] as String? ?? '').toLowerCase();
      if (name.contains('v8a') || name.contains('arm64')) {
        pick = asset;
        break;
      }
    }
    pick ??= assets.isEmpty ? null : assets.first;

    return AppRelease(
      tagName: json['tag_name'] as String? ?? '',
      name: json['name'] as String? ?? '',
      notes: json['body'] as String? ?? '',
      htmlUrl: json['html_url'] as String? ?? 'https://github.com/${UpdateService.repo}/releases',
      apkUrl: pick?['browser_download_url'] as String?,
      apkName: pick?['name'] as String?,
      apkBytes: (pick?['size'] as num?)?.toInt() ?? 0,
    );
  }

  String get version => tagName;

  bool isNewerThan(String installedVersion) =>
      UpdateService.compareVersions(tagName, installedVersion) > 0;
}

/// Outcome of handing an APK to the system package installer.
enum InstallOutcome { launched, permissionMissing, failed }

class InstallResult {
  final InstallOutcome outcome;
  final String? message;
  const InstallResult(this.outcome, [this.message]);
}

/// Shared updater used by the settings screen and the launch-time prompt.
class UpdateService {
  UpdateService._();
  static final UpdateService _instance = UpdateService._();
  factory UpdateService() => _instance;

  static const String repo = 'jumagee7/QuotiMate';
  static const String _apiLatest = 'https://api.github.com/repos/$repo/releases/latest';
  // The REST API allows only 60 unauthenticated reads per hour per IP. On a
  // shared/CGNAT mobile network that budget is routinely exhausted, and the
  // updater then fell back to its cache and kept offering the previous
  // version. github.com HTML and the Atom feed are not rate-limited, so they
  // are the fallback source of truth.
  static const String _releasesAtom = 'https://github.com/$repo/releases.atom';
  static const String _latestDownloadBase = 'https://github.com/$repo/releases/latest/download';
  static const String kAutoCheckKey = 'auto_check_updates';
  static const String _kCachedReleaseJson = 'cached_release_json';
  static const int _downloadNotifId = 9901;
  static const MethodChannel _channel =
      MethodChannel('com.majumaink.quotimate/device_settings');

  PackageInfo? _packageInfo;

  /// "1.4.2" — the user-facing version, without the build number.
  Future<String> currentVersion() async {
    _packageInfo ??= await PackageInfo.fromPlatform();
    return _packageInfo!.version;
  }

  /// "1.4.2+17" — shown in settings and the update prompt.
  Future<String> currentVersionWithBuild() async {
    _packageInfo ??= await PackageInfo.fromPlatform();
    return '${_packageInfo!.version}+${_packageInfo!.buildNumber}';
  }

  /// Latest published release. Always asks GitHub first: a cached answer could
  /// name the previous release for an hour after a new one is published, which
  /// made the updater offer an older version than the one installed. The cache
  /// is only an offline fallback now.
  Future<AppRelease?> fetchLatest() async {
    final prefs = await SharedPreferences.getInstance();

    final fromApi = await _fetchFromApi();
    if (fromApi != null) {
      await _cacheRelease(fromApi, prefs);
      return fromApi;
    }

    // Rate-limited or blocked API: the Atom feed carries the same tag and
    // notes without the per-IP budget.
    final fromFeed = await _fetchFromFeed();
    if (fromFeed != null) {
      await _cacheRelease(fromFeed, prefs);
      return fromFeed;
    }

    final cached = prefs.getString(_kCachedReleaseJson);
    return cached == null ? null : _parse(cached);
  }

  Future<AppRelease?> _fetchFromApi() async {
    try {
      final res = await http
          .get(Uri.parse(_apiLatest), headers: {
            'Accept': 'application/vnd.github.v3+json',
            'User-Agent': 'QuotiMate-updater',
          })
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return null;
      final parsed = _parse(res.body);
      if (parsed != null) return parsed;
    } catch (_) {
      // Offline / DNS / timeout / rate limit — try the feed next.
    }
    return null;
  }

  Future<AppRelease?> _fetchFromFeed() async {
    try {
      final res = await http
          .get(Uri.parse(_releasesAtom), headers: {'User-Agent': 'QuotiMate-updater'})
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return null;
      return parseReleaseFeed(res.body);
    } catch (_) {
      return null;
    }
  }

  /// Reads the newest entry of the releases Atom feed. The feed has no asset
  /// list, so the APK URL is rebuilt from the tag using the release naming
  /// convention (`QuotiMate-<tag>-arm64-v8a.apk`).
  static AppRelease? parseReleaseFeed(String xml) {
    final entry = RegExp(r'<entry>([\s\S]*?)</entry>').firstMatch(xml)?.group(1);
    if (entry == null) return null;

    final href = RegExp(r'<link rel="alternate"[^>]*href="([^"]*/releases/tag/[^"]+)"')
        .firstMatch(entry)
        ?.group(1);
    if (href == null) return null;
    final tag = href.split('/releases/tag/').last;
    if (tag.isEmpty) return null;

    final title = RegExp(r'<title>([\s\S]*?)</title>').firstMatch(entry)?.group(1) ??
        'QuotiMate $tag';
    final encodedNotes =
        RegExp(r'<content type="html">([\s\S]*?)</content>').firstMatch(entry)?.group(1) ?? '';
    final apkName = 'QuotiMate-$tag-arm64-v8a.apk';

    return AppRelease(
      tagName: tag,
      name: _decodeEntities(title).trim(),
      notes: _feedNotes(encodedNotes),
      htmlUrl: href,
      apkUrl: '$_latestDownloadBase/$apkName',
      apkName: apkName,
      apkBytes: 0,
    );
  }

  /// The feed escapes its HTML body and stores block elements as tags; the
  /// update dialog shows plain text, so unwrap both.
  static String _feedNotes(String encoded) {
    final html = _decodeEntities(encoded);
    return html
        .replaceAll(RegExp(r'<li>'), '• ')
        .replaceAll(RegExp(r'</(p|li|h1|h2|h3|ul|ol|div)>'), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll(RegExp(r'[ \t]+\n'), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  static String _decodeEntities(String raw) => raw
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&#x27;', "'")
      .replaceAll('&amp;', '&');

  AppRelease? _parse(String raw) {
    try {
      final json = jsonDecode(raw);
      if (json is Map<String, dynamic>) return AppRelease.fromGitHub(json);
    } catch (_) {}
    return null;
  }

  /// Stores the release in the GitHub-shaped cache the offline path reads.
  Future<void> _cacheRelease(AppRelease release, SharedPreferences prefs) async {
    final json = jsonEncode({
      'tag_name': release.tagName,
      'name': release.name,
      'body': release.notes,
      'html_url': release.htmlUrl,
      'assets': release.apkUrl == null
          ? const []
          : [
              {
                'name': release.apkName,
                'browser_download_url': release.apkUrl,
                'size': release.apkBytes,
              }
            ],
    });
    await prefs.setString(_kCachedReleaseJson, json);
  }

  /// Downloads [release]'s APK to the temp directory, reporting progress as a
  /// 0..1 fraction. Posts a progress notification so the user can leave the app.
  Future<File> downloadApk(
    AppRelease release, {
    void Function(double fraction)? onProgress,
    void Function(int receivedBytes, int totalBytes)? onBytes,
    DownloadCancelToken? cancelToken,
  }) async {
    final url = release.apkUrl;
    if (url == null) {
      throw const HttpException('This release has no APK attached.');
    }

    final safeName = (release.apkName ?? 'QuotiMate-${release.version}.apk')
        .replaceAll(RegExp(r'[^\w.\-]'), '_');
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$safeName');
    if (await file.exists()) await file.delete();

    final notifications = NotificationService();
    unawaited(notifications.showDownloadProgress(
      id: _downloadNotifId,
      filename: safeName,
      progress: 0,
    ));

    final client = http.Client();
    IOSink? sink;
    try {
      final response = await client
          .send(http.Request('GET', Uri.parse(url)))
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        throw HttpException('Download failed (HTTP ${response.statusCode})', uri: Uri.parse(url));
      }

      final total = response.contentLength ?? release.apkBytes;
      var received = 0;
      var lastShown = -1;
      var lastNotif = -1;

      sink = file.openWrite();
      await for (final chunk in response.stream) {
        if (cancelToken?.isCancelled ?? false) throw const UpdateCancelled();
        sink.add(chunk);
        received += chunk.length;

        final fraction = total > 0 ? (received / total).clamp(0.0, 1.0) : 0.0;
        onBytes?.call(received, total);
        onProgress?.call(fraction);

        final percent = (fraction * 100).round();
        if (percent != lastShown) {
          lastShown = percent;
          // Update the system notification every 2% to keep it visibly moving.
          // We await here intentionally — firing hundreds of unawaited show()
          // calls floods the channel and Android drops most of them, making the
          // bar look frozen. One awaited call per 2% is cheap and reliable.
          if (percent != lastNotif && percent % 2 == 0) {
            lastNotif = percent;
            await notifications.showDownloadProgress(
              id: _downloadNotifId,
              filename: safeName,
              progress: percent,
            );
          }
        }
      }

      await sink.flush();
      await sink.close();
      sink = null;

      unawaited(notifications.showDownloadComplete(
        id: _downloadNotifId,
        filename: safeName,
      ));
      return file;
    } catch (_) {
      await sink?.close();
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }
      unawaited(notifications.cancelNotification(_downloadNotifId));
      rethrow;
    } finally {
      client.close();
    }
  }

  /// Hands the APK to the system installer. Returns [InstallOutcome] so the UI
  /// can route the user to the "install unknown apps" setting when needed.
  Future<InstallResult> installApk(File apk) async {
    if (!Platform.isAndroid) {
      return const InstallResult(InstallOutcome.failed, 'APK install is Android-only.');
    }
    if (!await canRequestInstalls()) {
      return const InstallResult(
        InstallOutcome.permissionMissing,
        'Android needs permission to install apps from QuotiMate.',
      );
    }
    try {
      final result = await OpenFile.open(apk.path, type: 'application/vnd.android.package-archive');
      if (result.type == ResultType.done) {
        return const InstallResult(InstallOutcome.launched);
      }
      return InstallResult(InstallOutcome.failed, result.message);
    } catch (e) {
      return InstallResult(InstallOutcome.failed, '$e');
    }
  }

  /// Whether the OS allows this app to launch the package installer.
  Future<bool> canRequestInstalls() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('canInstallPackages') ?? true;
    } catch (_) {
      return true;
    }
  }

  Future<void> openInstallPermissionSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('openInstallPermissionSettings');
    } catch (_) {}
  }

  /// Copies the downloaded APK into the public Downloads folder so it survives
  /// the uninstall. Returns the human-readable location, or null on failure.
  Future<String?> saveApkToDownloads(File apk) async {
    if (!Platform.isAndroid) return null;
    try {
      return await _channel.invokeMethod<String>('saveApkToDownloads', {
        'sourcePath': apk.path,
        'fileName': apk.uri.pathSegments.last,
      });
    } catch (_) {
      return null;
    }
  }

  /// Opens the system "uninstall app" confirmation for QuotiMate itself.
  Future<bool> uninstallSelf() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('uninstallSelf') ?? false;
    } catch (_) {
      return false;
    }
  }

  // ── Version helpers ───────────────────────────────────────────────────────

  /// Compares dotted versions ("v1.2.3+9", "1.2.3-beta") numerically.
  /// Returns <0 when [a] is older, 0 when equal, >0 when [a] is newer.
  ///
  /// Build numbers are ignored: on Android `PackageInfo.buildNumber` is the
  /// split-per-ABI versionCode (2002), so it is not comparable with a tag.
  static int compareVersions(String a, String b) {
    final pa = _versionParts(a);
    final pb = _versionParts(b);
    for (var i = 0; i < 3; i++) {
      final diff = pa[i].compareTo(pb[i]);
      if (diff != 0) return diff;
    }
    return 0;
  }

  static List<int> _versionParts(String raw) {
    var value = raw.trim();
    if (value.startsWith('v') || value.startsWith('V')) {
      value = value.substring(1);
    }
    value = value.split('+').first.split('-').first;
    final parts = value.split('.');
    return List<int>.generate(3, (i) {
      if (i >= parts.length) return 0;
      final digits = RegExp(r'\d+').firstMatch(parts[i])?.group(0);
      return digits == null ? 0 : (int.tryParse(digits) ?? 0);
    });
  }
}
