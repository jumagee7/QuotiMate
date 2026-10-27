// widgets/update_banner.dart — home-screen update card

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../pages/update_prompt.dart';
import '../services/update_service.dart';

const _gold = Color(0xFFFFC107);
const _surface = Color(0xFF161B26);
const _border = Color(0xFF2A3045);

/// Sits at the top of the dashboard and only renders when GitHub has a release
/// that is actually newer than the installed build.
class UpdateBanner extends StatefulWidget {
  const UpdateBanner({super.key});

  @override
  State<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends State<UpdateBanner> with WidgetsBindingObserver {
  AppRelease? _release;
  String _installed = '';
  bool _hidden = false;
  bool _checking = false;
  DateTime _lastCheck = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Returning from the installer is the moment the version can have changed.
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check({bool force = false}) async {
    if (_checking) return;
    if (!force && DateTime.now().difference(_lastCheck) < const Duration(seconds: 60)) {
      return;
    }
    _checking = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool(UpdateService.kAutoCheckKey) ?? true)) {
        if (mounted) setState(() => _release = null);
        return;
      }

      final service = UpdateService();
      final release = await service.fetchLatest();
      final installed = await service.currentVersionWithBuild();
      if (!mounted) return;
      setState(() {
        _installed = installed;
        _release = (release != null && release.isNewerThan(installed)) ? release : null;
      });
    } catch (e) {
      debugPrint('Update check failed: $e');
    } finally {
      _lastCheck = DateTime.now();
      _checking = false;
    }
  }

  Future<void> _openPrompt() async {
    final release = _release;
    if (release == null) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => UpdatePromptDialog(
        release: release,
        installedVersion: _installed,
      ),
    );
    if (mounted) _check(force: true);
  }

  @override
  Widget build(BuildContext context) {
    final release = _release;
    if (release == null || _hidden) return const SizedBox.shrink();

    final size = release.apkBytes > 0
        ? ' · ${(release.apkBytes / (1024 * 1024)).toStringAsFixed(1)} MB'
        : '';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _gold.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: _gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.system_update_alt_rounded, color: _gold, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Update available',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'QuotiMate ${release.tagName}$size  ·  you have $_installed',
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _hidden = true),
                icon: const Icon(Icons.close_rounded, color: Colors.white38, size: 18),
                tooltip: 'Hide until next launch',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _openPrompt,
                  icon: const Icon(Icons.download_rounded, size: 17),
                  label: const Text('Update now', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: FilledButton.styleFrom(
                    backgroundColor: _gold,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: () => setState(() => _hidden = true),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: _border),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Later'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
