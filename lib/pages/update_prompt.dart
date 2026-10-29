// pages/update_prompt.dart — update prompt with progress, permission & clean install

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../services/update_service.dart';

const _gold = Color(0xFFFFC107);
const _green = Color(0xFF10B981);
const _surface = Color(0xFF161B26);
const _border = Color(0xFF2A3045);
const _void = Color(0xFF0F162C);

enum _Stage {
  prompt,
  needsPermission,
  cleanInstallConfirm,
  working,
  installerOpened,
  error,
  savedForCleanInstall,
}

class UpdatePromptDialog extends StatefulWidget {
  final AppRelease release;
  final String installedVersion;

  const UpdatePromptDialog({
    super.key,
    required this.release,
    required this.installedVersion,
  });

  @override
  State<UpdatePromptDialog> createState() => _UpdatePromptDialogState();
}

class _UpdatePromptDialogState extends State<UpdatePromptDialog> with WidgetsBindingObserver {
  final UpdateService _service = UpdateService();

  _Stage _stage = _Stage.prompt;
  bool _cleanInstall = false;
  double _progress = 0;
  int _received = 0;
  int _total = 0;
  String? _error;
  String? _savedPath;
  DownloadCancelToken? _cancelToken;

  bool get _busy => _stage == _Stage.working;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The user grants "install unknown apps" in system settings; coming back is
    // the moment to see whether the permission was actually turned on.
    if (state == AppLifecycleState.resumed && _stage == _Stage.needsPermission) {
      _resumeAfterPermission();
    }
  }

  Future<void> _resumeAfterPermission() async {
    if (!await _service.canRequestInstalls()) return;
    if (!mounted) return;
    await _startUpdate(cleanInstall: _cleanInstall);
  }

  String get _sizeLabel {
    final bytes = _total > 0 ? _total : widget.release.apkBytes;
    if (bytes <= 0) return '';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _startUpdate({required bool cleanInstall}) async {
    if (_busy) return;

    if (!await _service.canRequestInstalls()) {
      if (!mounted) return;
      setState(() {
        _cleanInstall = cleanInstall;
        _stage = _Stage.needsPermission;
      });
      // Send the user straight to the switch instead of failing after download.
      await _service.openInstallPermissionSettings();
      return;
    }

    setState(() {
      _cleanInstall = cleanInstall;
      _stage = _Stage.working;
      _progress = 0;
      _received = 0;
      _total = widget.release.apkBytes;
      _error = null;
      _savedPath = null;
      _cancelToken = DownloadCancelToken();
    });

    try {
      final file = await _service.downloadApk(
        widget.release,
        cancelToken: _cancelToken,
        onBytes: (received, total) {
          if (!mounted) return;
          setState(() {
            _received = received;
            if (total > 0) _total = total;
            _progress = total > 0 ? (received / total).clamp(0.0, 1.0) : 0;
          });
        },
      );
      if (!mounted) return;

      if (cleanInstall) {
        final saved = await _service.saveApkToDownloads(file);
        if (!mounted) return;
        if (saved == null) {
          // Never uninstall without a copy the user can reopen afterwards.
          setState(() {
            _error = 'Could not save the APK to Downloads, so nothing was uninstalled. '
                'Check storage space and try again.';
            _stage = _Stage.error;
          });
          return;
        }
        setState(() {
          _savedPath = saved;
          _stage = _Stage.savedForCleanInstall;
        });
        return;
      }

      final result = await _service.installApk(file);
      if (!mounted) return;
      if (result.outcome == InstallOutcome.launched) {
        setState(() => _stage = _Stage.installerOpened);
      } else if (result.outcome == InstallOutcome.permissionMissing) {
        setState(() {
          _stage = _Stage.needsPermission;
        });
        await _service.openInstallPermissionSettings();
      } else {
        setState(() {
          _error = result.message ?? 'The installer did not start.';
          _stage = _Stage.error;
        });
      }
    } on UpdateCancelled {
      if (mounted) {
        setState(() {
          _stage = _Stage.prompt;
          _progress = 0;
          _received = 0;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Download failed: $e';
        _stage = _Stage.error;
      });
    }
  }

  Future<void> _uninstallNow() async {
    final launched = await _service.uninstallSelf();
    if (!launched && mounted) {
      rootMessengerKey.currentState?.showSnackBar(
        const SnackBar(content: Text('Open Settings › Apps › QuotiMate to uninstall.')),
      );
    }
  }

  void _close() {
    if (_busy) {
      // Cancel the in-flight download, then let the stage reset close the dialog.
      _cancelToken?.cancel();
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    // While downloading, wrap with a modal barrier so the user cannot tap
    // anything behind the dialog. Outside that stage the dialog is a normal
    // dismissible sheet.
    final dialog = Dialog(
      backgroundColor: _surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: _border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(),
              const SizedBox(height: 16),
              ..._bodyForStage(),
            ],
          ),
        ),
      ),
    );

    return PopScope(
      // Back gesture is always blocked while downloading so the user must
      // explicitly tap "Cancel download" to abort.
      canPop: !_busy,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancelToken?.cancel();
      },
      child: _busy
          // Stack a full-screen absorber behind the dialog so touches on the
          // scrim are eaten and nothing underneath receives them.
          ? Stack(
              children: [
                // Solid barrier — absorbs all taps outside the dialog.
                const Positioned.fill(
                  child: AbsorbPointer(
                    absorbing: true,
                    child: ModalBarrier(
                      dismissible: false,
                      color: Color(0xAA000000),
                    ),
                  ),
                ),
                Center(child: dialog),
              ],
            )
          : dialog,
    );
  }

  Widget _header() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _gold.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.system_update_alt_rounded, color: _gold, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Update available',
                style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                'QuotiMate ${widget.release.tagName}  ·  you have ${widget.installedVersion}',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
        if (!_busy)
          IconButton(
            onPressed: _close,
            icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
            tooltip: 'Later',
          ),
      ],
    );
  }

  List<Widget> _bodyForStage() {
    switch (_stage) {
      case _Stage.prompt:
        return _promptBody();
      case _Stage.needsPermission:
        return _permissionBody();
      case _Stage.cleanInstallConfirm:
        return _cleanInstallBody();
      case _Stage.working:
        return _workingBody();
      case _Stage.installerOpened:
        return _installerOpenedBody();
      case _Stage.error:
        return _errorBody();
      case _Stage.savedForCleanInstall:
        return _savedBody();
    }
  }

  // ── Stages ────────────────────────────────────────────────────────────────

  List<Widget> _promptBody() {
    final release = widget.release;
    final hasNotes = release.notes.trim().isNotEmpty;

    return [
      if (hasNotes)
        Container(
          constraints: const BoxConstraints(maxHeight: 170),
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _void,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _border),
          ),
          child: SingleChildScrollView(
            child: Text(
              release.notes.trim(),
              style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.5),
            ),
          ),
        ),
      if (hasNotes) const SizedBox(height: 12),
      Row(
        children: [
          const Icon(Icons.android_rounded, color: _green, size: 15),
          const SizedBox(width: 6),
          Text(
            _sizeLabel.isEmpty ? 'Android APK' : 'Android APK  ·  $_sizeLabel',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
      const SizedBox(height: 18),
      Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _close,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: const BorderSide(color: _border),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Later'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: release.apkUrl == null ? null : () => _startUpdate(cleanInstall: false),
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Update now', style: TextStyle(fontWeight: FontWeight.bold)),
              style: FilledButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 6),
      Center(
        child: TextButton(
          onPressed: () => setState(() => _stage = _Stage.cleanInstallConfirm),
          style: TextButton.styleFrom(foregroundColor: Colors.white38),
          child: const Text(
            'Update fails? Uninstall previous version first',
            style: TextStyle(fontSize: 12),
          ),
        ),
      ),
    ];
  }

  List<Widget> _permissionBody() {
    return [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _gold.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _gold.withValues(alpha: 0.4)),
        ),
        child: const Row(
          children: [
            Icon(Icons.shield_outlined, color: _gold, size: 18),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Android needs your permission before QuotiMate can install an update.',
                style: TextStyle(color: _gold, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      const Text(
        'Android calls this “Install unknown apps”. Turn it on for QuotiMate, '
        'then come back here — the download continues automatically.',
        style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.5),
      ),
      const SizedBox(height: 18),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: () => _service.openInstallPermissionSettings(),
          icon: const Icon(Icons.settings_rounded, size: 18),
          label: const Text('Allow installs', style: TextStyle(fontWeight: FontWeight.bold)),
          style: FilledButton.styleFrom(
            backgroundColor: _gold,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      const SizedBox(height: 6),
      Center(
        child: TextButton(
          onPressed: _resumeAfterPermission,
          style: TextButton.styleFrom(foregroundColor: _green),
          child: const Text('I’ve allowed it — continue', style: TextStyle(fontSize: 12)),
        ),
      ),
      Center(
        child: TextButton(
          onPressed: _close,
          style: TextButton.styleFrom(foregroundColor: Colors.white38),
          child: const Text('Later', style: TextStyle(fontSize: 12)),
        ),
      ),
    ];
  }

  List<Widget> _cleanInstallBody() {
    return [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'This erases local data on this phone',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'QuotiMate must be uninstalled before the new version can install. '
              'Local quotes, invoices and photos on this phone are deleted. Anything '
              'already synced to your QuotiMate cloud account comes back when you '
              'sign in again.',
              style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.5),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      const Text(
        'The new APK is saved to Downloads first, so you can install it right '
        'after QuotiMate is removed.',
        style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.5),
      ),
      const SizedBox(height: 18),
      Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => setState(() => _stage = _Stage.prompt),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: const BorderSide(color: _border),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: widget.release.apkUrl == null
                  ? null
                  : () => _startUpdate(cleanInstall: true),
              icon: const Icon(Icons.delete_forever_rounded, size: 18),
              label: const Text('Save APK & continue',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _workingBody() {
    final percent = (_progress * 100).round();
    final downloaded = (_received / (1024 * 1024)).toStringAsFixed(1);

    return [
      Text(
        _cleanInstall ? 'Downloading for clean install…' : 'Downloading update…',
        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 14),
      ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: LinearProgressIndicator(
          value: _total > 0 ? _progress : null,
          minHeight: 8,
          backgroundColor: _border,
          valueColor: AlwaysStoppedAnimation<Color>(_cleanInstall ? Colors.redAccent : _green),
        ),
      ),
      const SizedBox(height: 8),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$percent%', style: const TextStyle(color: _green, fontSize: 13, fontWeight: FontWeight.bold)),
          Text(
            _sizeLabel.isEmpty
                ? '$downloaded MB downloaded'
                : '$downloaded / $_sizeLabel',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
      const SizedBox(height: 16),
      Center(
        child: OutlinedButton(
          onPressed: _close,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white70,
            side: const BorderSide(color: _border),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Cancel download'),
        ),
      ),
    ];
  }

  List<Widget> _installerOpenedBody() {
    return [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _green.withValues(alpha: 0.4)),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: _green, size: 18),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Installer opened — confirm the update there.',
                style: TextStyle(color: _green, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      const Text(
        'If Android says “App not installed”, this build was signed with a '
        'different key. Use clean install to remove this version first — synced '
        'data returns after you sign in again.',
        style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.5),
      ),
      const SizedBox(height: 18),
      Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _close,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: const BorderSide(color: _border),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Done'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton.icon(
              onPressed: () => setState(() => _stage = _Stage.cleanInstallConfirm),
              icon: const Icon(Icons.delete_forever_rounded, size: 17),
              label: const Text('Clean install'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _errorBody() {
    return [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.35)),
        ),
        child: Text(
          _error ?? 'Something went wrong while updating.',
          style: const TextStyle(color: Colors.redAccent, fontSize: 12, height: 1.5),
        ),
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _close,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: const BorderSide(color: _border),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Close'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton(
              onPressed: () => _startUpdate(cleanInstall: _cleanInstall),
              style: FilledButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Try again', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      const SizedBox(height: 4),
      Center(
        child: TextButton(
          onPressed: () => setState(() => _stage = _Stage.cleanInstallConfirm),
          style: TextButton.styleFrom(foregroundColor: Colors.white38),
          child: const Text(
            'Uninstall previous version & clean install',
            style: TextStyle(fontSize: 12),
          ),
        ),
      ),
      Center(
        child: TextButton(
          onPressed: () async {
            final uri = Uri.parse(widget.release.htmlUrl);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
          style: TextButton.styleFrom(foregroundColor: Colors.white38),
          child: const Text('Download from GitHub instead', style: TextStyle(fontSize: 12)),
        ),
      ),
    ];
  }

  List<Widget> _savedBody() {
    return [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _green.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: _green, size: 18),
                SizedBox(width: 8),
                Text(
                  'APK saved',
                  style: TextStyle(color: _green, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _savedPath ?? 'Downloads',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      const Text(
        'Tap “Uninstall now”, confirm, then open the Downloads app (or Files) '
        'and tap the saved APK to install the new version.',
        style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.5),
      ),
      const SizedBox(height: 18),
      Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _close,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: const BorderSide(color: _border),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Keep app'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: _uninstallNow,
              icon: const Icon(Icons.delete_forever_rounded, size: 18),
              label: const Text('Uninstall now',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    ];
  }
}
