// services/signer_info_service.dart — Collects signer identity & device evidence

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../models.dart';

class SignerInfoService {
  static const _excludedKeys = {'signatureData', 'signedAt', 'signerInfo', 'status', 'shareToken', 'isPinned'};

  /// SHA-256 fingerprint of the document content (excluding signature fields),
  /// so any later change to the quote/invoice can be detected.
  static String hashDocument(Map<String, dynamic> json) {
    final filtered = Map<String, dynamic>.from(json)..removeWhere((k, _) => _excludedKeys.contains(k));
    return sha256.convert(utf8.encode(jsonEncode(filtered))).toString();
  }

  static Future<SignerInfo> collect({
    required String name,
    required String phone,
    String email = '',
    required String docHash,
    String method = 'In-app',
  }) async {
    var deviceModel = '';
    var platform = defaultTargetPlatform.name;
    var osVersion = '';
    var appVersion = '';
    try {
      final plugin = DeviceInfoPlugin();
      if (kIsWeb) {
        final web = await plugin.webBrowserInfo;
        deviceModel = web.browserName.name;
        platform = web.platform ?? 'web';
        osVersion = web.userAgent ?? '';
      } else {
        switch (defaultTargetPlatform) {
          case TargetPlatform.android:
            final a = await plugin.androidInfo;
            deviceModel = '${a.manufacturer} ${a.model} (${a.id})';
            platform = 'Android';
            osVersion = '${a.version.release} (SDK ${a.version.sdkInt})';
          case TargetPlatform.iOS:
            final i = await plugin.iosInfo;
            deviceModel = '${i.name} ${i.utsname.machine}';
            platform = i.systemName;
            osVersion = i.systemVersion;
          case TargetPlatform.windows:
            final w = await plugin.windowsInfo;
            deviceModel = w.computerName;
            platform = 'Windows';
            osVersion = w.displayVersion;
          case TargetPlatform.macOS:
            final m = await plugin.macOsInfo;
            deviceModel = m.model;
            platform = 'macOS';
            osVersion = m.osRelease;
          case TargetPlatform.linux:
            final l = await plugin.linuxInfo;
            deviceModel = l.prettyName;
            platform = 'Linux';
            osVersion = l.versionId ?? '';
          default:
            break;
        }
      }
    } catch (e) {
      debugPrint('Device info error: $e');
    }
    try {
      final info = await PackageInfo.fromPlatform();
      appVersion = '${info.version}+${info.buildNumber}';
    } catch (_) {}
    return SignerInfo(
      name: name,
      phone: phone,
      email: email,
      method: method,
      deviceModel: deviceModel,
      platform: platform,
      osVersion: osVersion,
      appVersion: appVersion,
      timezone: DateTime.now().timeZoneName,
      docHash: docHash,
    );
  }
}
