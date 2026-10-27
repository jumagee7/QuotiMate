// services/signer_capture_service.dart — Collects signer device evidence.
// Gathers the signing device's identity, app build and (best-effort) location so
// a signed document carries verifiable proof of who/what approved it.

import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../models.dart';

class SignerCaptureService {
  static final SignerCaptureService _instance = SignerCaptureService._();
  factory SignerCaptureService() => _instance;
  SignerCaptureService._();

  /// Best-effort collection. Never throws and never blocks signing for long:
  /// every probe is individually guarded and location has a short time limit.
  Future<SignatureMetadata> collect({
    String? signerName,
    String? signerPhone,
  }) async {
    String device = '';
    String appVersion = '';
    String location = '';

    try {
      final info = DeviceInfoPlugin();
      if (kIsWeb) {
        final w = await info.webBrowserInfo;
        device = 'Web ${w.browserName.name}';
      } else if (Platform.isAndroid) {
        final a = await info.androidInfo;
        device = 'Android ${a.version.release} - ${a.manufacturer} ${a.model}';
      } else if (Platform.isIOS) {
        final i = await info.iosInfo;
        device = 'iOS ${i.systemVersion} - ${i.name}';
      } else if (Platform.isWindows) {
        final w = await info.windowsInfo;
        device = 'Windows - ${w.computerName}';
      } else if (Platform.isMacOS) {
        final m = await info.macOsInfo;
        device = 'macOS ${m.osRelease} - ${m.model}';
      } else if (Platform.isLinux) {
        final l = await info.linuxInfo;
        device = 'Linux - ${l.name}';
      }
    } catch (e) {
      debugPrint('Signer device capture skipped: $e');
    }

    try {
      final p = await PackageInfo.fromPlatform();
      appVersion = 'QuotiMate ${p.version}+${p.buildNumber}';
    } catch (e) {
      debugPrint('Signer app version capture skipped: $e');
    }

    location = await _bestEffortLocation();

    return SignatureMetadata(
      signerName: signerName,
      signerPhone: signerPhone,
      device: device.isEmpty ? null : device,
      appVersion: appVersion.isEmpty ? null : appVersion,
      location: location,
    );
  }

  Future<String> _bestEffortLocation() async {
    try {
      if (kIsWeb || Platform.isWindows || Platform.isLinux) return 'Not shared';
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return 'Not shared';

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        return 'Not shared';
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 5),
        ),
      );
      return '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
    } catch (e) {
      debugPrint('Signer location capture skipped: $e');
      return 'Not shared';
    }
  }
}
