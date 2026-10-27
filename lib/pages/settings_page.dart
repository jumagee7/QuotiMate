// pages/settings_page.dart â€” QuotiMate Settings & Preferences

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_state.dart';
import '../models.dart';
import '../services/auth_service.dart';
import '../services/cloud_sync_service.dart';
import '../services/notification_service.dart';
import '../services/update_service.dart';
import 'sign_in_page.dart';
import 'pdf_viewer_page.dart';
import 'update_prompt.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _formKey = GlobalKey<FormState>();

  bool _checkingUpdate = false;
  AppRelease? _latestRelease;
  String? _updateError;
  String _currentAppVersion = '1.0.0+1';
  bool _hasCheckedUpdate = false;
  bool _autoCheckUpdates = false;

  static const _kAutoCheckUpdates = UpdateService.kAutoCheckKey;

  @override
  void initState() {
    super.initState();
    _loadCurrentVersion();
    _loadAutoCheckPref();
  }

  Future<void> _loadAutoCheckPref() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_kAutoCheckUpdates) ?? true;
    if (mounted) {
      setState(() => _autoCheckUpdates = enabled);
    }
    if (enabled) {
      _checkForUpdate();
    }
  }

  Future<void> _saveAutoCheckPref(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAutoCheckUpdates, value);
  }

  Future<void> _loadCurrentVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _currentAppVersion = '${info.version}+${info.buildNumber}';
        });
      }
    } catch (_) {}
  }

  Future<void> _checkForUpdate() async {
    setState(() {
      _checkingUpdate = true;
      _updateError = null;
      _hasCheckedUpdate = true;
    });

    final service = UpdateService();
    final release = await service.fetchLatest();
    final installed = await service.currentVersionWithBuild();
    if (!mounted) return;

    setState(() {
      _currentAppVersion = installed;
      _checkingUpdate = false;
      if (release == null) {
        _latestRelease = null;
        _updateError = 'Could not reach GitHub. Check your connection and try again.';
      } else if (!release.isNewerThan(installed)) {
        // Never offer an older (or identical) build, even from an offline cache.
        _latestRelease = null;
      } else {
        _latestRelease = release;
      }
    });
  }

  /// Opens the shared update prompt so Settings and the home banner behave the
  /// same way (progress, install permission, clean-install fallback).
  Future<void> _openUpdatePrompt(AppRelease release) async {
    final installed = await UpdateService().currentVersionWithBuild();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => UpdatePromptDialog(
        release: release,
        installedVersion: installed,
      ),
    );
    if (mounted) _checkForUpdate();
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateProvider.of(context);

    return ListView(
      children: [
        // â”€â”€ Header â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFC107).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.settings, color: Color(0xFFFFC107), size: 22),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Settings & Preferences', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                Text('Manage your app configuration', style: TextStyle(color: Colors.white54, fontSize: 13)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),

        // ── Google Account & Cloud Sync ──────────────────────────────────────
        _buildAccountSection(context, appState),
        const SizedBox(height: 16),

        // ── Company Details ──────────────────────────────────────────────────
        _sectionCard(
          icon: Icons.business,
          title: 'Company Details',
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTextField('Company Name', appState.companyName, (val) => appState.updateSettings(companyName: val)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildTextField('Email', appState.companyEmail, (val) => appState.updateSettings(companyEmail: val))),
                    const SizedBox(width: 12),
                    Expanded(child: _buildTextField('Phone', appState.companyPhone, (val) => appState.updateSettings(companyPhone: val))),
                  ],
                ),
                const SizedBox(height: 12),
                _buildTextField('Address', appState.companyAddress, (val) => appState.updateSettings(companyAddress: val)),
                const SizedBox(height: 12),
                _buildTextField('KRA PIN (for taxation)', appState.companyKraPin, (val) => appState.updateSettings(companyKraPin: val)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildTextField('Currency', appState.currency, (val) => appState.updateSettings(currency: val))),
                    const SizedBox(width: 12),
                    Expanded(child: _buildTextField('Prepared By', appState.preparedBy, (val) => appState.updateSettings(preparedBy: val))),
                  ],
                ),
                const SizedBox(height: 12),
                _buildTextField('Default Expiry (Days)', appState.defaultExpiryDays.toString(), (val) => appState.updateSettings(defaultExpiryDays: int.tryParse(val) ?? 30)),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        _formKey.currentState!.save();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Settings saved'),
                            backgroundColor: Color(0xFF19233E),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.save),
                    label: const Text('Save Settings'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFC107), foregroundColor: Colors.black),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // â”€â”€ Document Templates â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        _sectionCard(
          icon: Icons.description_outlined,
          title: 'Document Templates',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                initialValue: appState.pdfTemplate,
                dropdownColor: const Color(0xFF161B26),
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Select PDF Template'),
                items: const [
                  DropdownMenuItem(value: 'modern_edge', child: Text('Modern Edge (Default)')),
                  DropdownMenuItem(value: 'minimalist', child: Text('Modern Minimalist')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    appState.updateSettings(pdfTemplate: val);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Template updated'), backgroundColor: Color(0xFF161B26)),
                    );
                  }
                },
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  final dummyQuote = Quote(
                    id: 'PREVIEW',
                    clientId: 'dummy',
                    clientName: 'Preview Client',
                    date: DateTime.now(),
                    expiryDate: DateTime.now().add(Duration(days: appState.defaultExpiryDays)),
                    categories: [
                      QuoteCategory(
                        id: 'preview',
                        name: 'Preview Category',
                        items: [
                          QuoteItem(productId: 'p1', name: 'Sample Item 1', qty: 2, unitPrice: 1500),
                          QuoteItem(productId: 'p2', name: 'Sample Item 2', qty: 1, unitPrice: 5000),
                        ],
                      ),
                    ],
                  );
                  PdfViewerPage.openQuotePdf(context, dummyQuote, appState);
                },
                icon: const Icon(Icons.preview),
                label: const Text('Preview Template'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFC107), foregroundColor: Colors.black),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // â”€â”€ Quotation Defaults â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        _sectionCard(
          icon: Icons.receipt_outlined,
          title: 'Quotation Defaults',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTextField(
                'Next Quotation Number (e.g. 1001)',
                appState.nextQuoteNumber.toString(),
                (val) => appState.updateSettings(nextQuoteNumber: int.tryParse(val) ?? appState.nextQuoteNumber),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                'Default VAT %',
                appState.defaultVatPercent.toString(),
                (val) => appState.updateSettings(defaultVatPercent: double.tryParse(val) ?? 16.0),
              ),
              const SizedBox(height: 12),
              _buildTextField(
                'Default Payment Terms',
                appState.defaultPaymentTerms,
                (val) => appState.updateSettings(defaultPaymentTerms: val),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                'Default Notes / Footer',
                appState.defaultNotes,
                (val) => appState.updateSettings(defaultNotes: val),
                maxLines: 3,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // â”€â”€ Notifications â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        _sectionCard(
          icon: Icons.notifications_outlined,
          title: 'Notifications',
          child: Column(
            children: [
              _switchTile(
                'Enable In-App Notifications',
                'Show notification badges and alerts. Switching this off cancels every scheduled alarm.',
                appState.notificationsEnabled,
                (val) => appState.updateSettings(notificationsEnabled: val),
                Icons.notifications_active_outlined,
              ),
              const SizedBox(height: 12),
              _switchTile(
                'Ring & Buzz Alarms',
                'Alarms take over the screen and keep vibrating until you tap Stop. Off turns them into ordinary notifications.',
                appState.alarmBuzzEnabled,
                (val) => appState.updateSettings(alarmBuzzEnabled: val),
                Icons.vibration,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () async {
                  final service = NotificationService();
                  await service.requestPermissions();
                  final result = await service.showTestNotification();
                  final delivered = result.startsWith('Device alert displayed');
                  appState.pushNotification(
                    key: 'n_test_${DateTime.now().millisecondsSinceEpoch}',
                    title: delivered ? 'Device alert confirmed' : 'Device alert failed',
                    body: result,
                    icon: delivered
                        ? kNotificationIcons['bell']!
                        : kNotificationIcons['bell_off']!,
                    color: delivered ? const Color(0xFF10B981) : Colors.redAccent,
                  );
                  showToast(delivered ? '🔔 Alert on your shade' : '⚠️ ${result.split(' · ').first}');
                },
                icon: const Icon(Icons.play_arrow, size: 16),
                label: const Text('Test Notification'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFFC107),
                  foregroundColor: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  final service = NotificationService();
                  // Full-screen access lives behind its own settings screen, so
                  // ask for it here where the user expects to tune alarms.
                  await service.requestPermissions(askFullScreen: true);
                  final result = await service.showTestAlarm(buzz: appState.alarmBuzzEnabled);
                  appState.pushNotification(
                    key: 'n_alarm_test_${DateTime.now().millisecondsSinceEpoch}',
                    title: 'Alarm test',
                    body: result,
                    icon: result.startsWith('Alarm posted')
                        ? kNotificationIcons['bell']!
                        : kNotificationIcons['bell_off']!,
                    color: result.startsWith('Alarm posted')
                        ? const Color(0xFF10B981)
                        : Colors.redAccent,
                  );
                  showToast(result);
                },
                icon: const Icon(Icons.alarm, size: 16),
                label: const Text('Test Alarm'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFFC107),
                  side: const BorderSide(color: Color(0xFF2A3045)),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  final service = NotificationService();
                  await service.requestPermissions();
                  final result = await service.scheduleTestNotification(seconds: 10);
                  final isArmed = result.startsWith('Armed for');
                  appState.pushNotification(
                    key: 'n_bg_test_${DateTime.now().millisecondsSinceEpoch}',
                    title: isArmed ? 'Background test armed' : 'Background alert notice',
                    body: result,
                    icon: isArmed ? kNotificationIcons['bell']! : kNotificationIcons['bell_off']!,
                    color: isArmed ? const Color(0xFF10B981) : Colors.amber,
                  );
                  showToast(isArmed ? '⏳ $result' : '⚠️ $result');
                },
                icon: const Icon(Icons.timer_outlined, size: 16),
                label: const Text('Test Background Alert (in 10s)'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF60A5FA),
                  side: const BorderSide(color: Color(0xFF2A3045)),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final service = NotificationService();
                        await service.openExactAlarmSettings();
                        showToast('Turn ON "Allow setting alarms & reminders"');
                      },
                      icon: const Icon(Icons.alarm_on, size: 15),
                      label: const Text('Alarms & Reminders', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF34D399),
                        side: const BorderSide(color: Color(0xFF2A3045)),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final service = NotificationService();
                        await service.requestIgnoreBatteryOptimizations();
                        showToast('Exclude QuotiMate from battery limits');
                      },
                      icon: const Icon(Icons.battery_charging_full, size: 15),
                      label: const Text('Battery Settings', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFA78BFA),
                        side: const BorderSide(color: Color(0xFF2A3045)),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  final service = NotificationService();
                  await service.requestPermissions();
                  final summary = await service.diagnosticSummary();
                  if (summary == null) return;
                  final troubled = summary.contains('BLOCKED') ||
                      summary.contains('DEGRADED') ||
                      summary.contains('PLUGIN OFFLINE');
                  appState.pushNotification(
                    key: 'n_diag_${DateTime.now().millisecondsSinceEpoch}',
                    title: 'Alert access check',
                    body: summary,
                    icon: troubled
                        ? kNotificationIcons['bell_off']!
                        : kNotificationIcons['bell']!,
                    color: troubled ? Colors.redAccent : const Color(0xFF10B981),
                  );
                  if (summary.contains('BLOCKED: notifications')) {
                    // Android shows the runtime dialog only once. After a denial
                    // the system settings screen is the only way back, so open
                    // it instead of silently re-requesting.
                    await service.openNotificationSettings();
                    showToast('Turn ON notifications for QuotiMate');
                    return;
                  }
                  if (troubled) {
                    await service.requestPermissions();
                  }
                  showToast('🔎 ${summary.split(' · ').first}');
                },
                icon: const Icon(Icons.security_outlined, size: 16),
                label: const Text('Check Alert Access'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFFC107),
                  side: const BorderSide(color: Color(0xFF2A3045)),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tap to test if notifications are working on your device, or check what Android is blocking',
                style: TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Data Management ──────────────────────────────────────────────────
        _sectionCard(
          icon: Icons.storage_outlined,
          title: 'Data Management',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Manage your application data. These actions are permanent and cannot be undone.',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _confirmClearQuotes(context, appState),
                    icon: const Icon(Icons.delete_sweep_outlined, size: 16),
                    label: const Text('Clear All Quotes'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.withValues(alpha: 0.15),
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Export coming soon'), backgroundColor: Color(0xFF161B26)),
                      );
                    },
                    icon: const Icon(Icons.download_outlined, size: 16),
                    label: const Text('Export Data'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF161B26),
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF2A3045)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['json'],
                        );
                        if (result != null && result.files.isNotEmpty) {
                          final file = result.files.first;
                          
                          // Handle both path and bytes for better compatibility
                          String contents;
                          if (file.path != null) {
                            final fileObj = File(file.path!);
                            contents = await fileObj.readAsString();
                            debugPrint('File read from path: ${file.path}');
                          } else if (file.bytes != null) {
                            contents = String.fromCharCodes(file.bytes!);
                            debugPrint('File read from bytes (${file.bytes!.length} bytes)');
                          } else {
                            throw Exception('Unable to read file - no path or bytes available');
                          }
                          
                          debugPrint('File contents length: ${contents.length}');
                          debugPrint('File contents preview: ${contents.length > 100 ? contents.substring(0, 100) : contents}...');
                          
                          // Trim whitespace and check if empty
                          contents = contents.trim();
                          if (contents.isEmpty) {
                            throw Exception('File is empty');
                          }
                          
                          // Verify it's a valid JSON
                          final parsed = jsonDecode(contents);
                          debugPrint('Parsed JSON type: ${parsed.runtimeType}');
                          
                          if (parsed is Map<String, dynamic>) {
                            final dir = await getApplicationDocumentsDirectory();
                            final customFile = File('${dir.path}/custom_itemlist.json');
                            await customFile.writeAsString(contents);
                            
                            if (mounted) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(
                                  content: Text('Custom item list imported successfully! (${parsed.length} items)'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } else if (parsed is List) {
                            final dir = await getApplicationDocumentsDirectory();
                            final customFile = File('${dir.path}/custom_itemlist.json');
                            await customFile.writeAsString(contents);
                            
                            if (mounted) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(
                                  content: Text('Custom item list imported successfully! (${parsed.length} items)'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } else {
                            throw FormatException('File is not a valid JSON object or list. Got: ${parsed.runtimeType}');
                          }
                        }
                      } catch (e) {
                        debugPrint('Import error: $e');
                        if (mounted) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(
                              content: Text('Import failed: $e'),
                              backgroundColor: Colors.red,
                              duration: const Duration(seconds: 4),
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.upload_file_outlined, size: 16),
                    label: const Text('Import Custom itemlist.json'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF161B26),
                      foregroundColor: const Color(0xFFFFC107),
                      side: const BorderSide(color: Color(0xFFFFC107)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      _confirmResetDefaults(context, appState);
                    },
                    icon: const Icon(Icons.restore_outlined, size: 16),
                    label: const Text('Reset Defaults'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.withValues(alpha: 0.15),
                      foregroundColor: Colors.orange,
                      side: const BorderSide(color: Colors.orange),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── App Updates (GitHub) ──────────────────────────────────────────────
        _buildAppUpdateSection(context),
        const SizedBox(height: 16),

        // ── About ─────────────────────────────────────────────────────────────
        _sectionCard(
          icon: Icons.info_outline,
          title: 'About QuotiMate',
          child: Column(
            children: [
              _infoRow('Version', _currentAppVersion),
              _infoRow('Developer', 'QuotiMate Team'),
              _infoRow('Build', 'Production'),
              _infoRow('Platform', 'Flutter'),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  // ── App Update Section ─────────────────────────────────────────────────────
  Widget _buildAppUpdateSection(BuildContext context) {
    final release = _latestRelease;
    final hasRelease = release != null;
    final tagName = release?.tagName ?? '';
    final releaseName = release?.name ?? '';
    final releaseBody = release?.notes ?? '';
    final htmlUrl = release?.htmlUrl ?? 'https://github.com/jumagee7/QuotiMate/releases';
    final apkDownloadUrl = release?.apkUrl;
    final apkLabel = release?.apkName?.toLowerCase().contains('v8a') ?? false
        ? 'Download v8a'
        : 'Download APK';
    final apkSize = (release?.apkBytes ?? 0) > 0
        ? ' · ${(release!.apkBytes / (1024 * 1024)).toStringAsFixed(1)} MB'
        : '';

    return _sectionCard(
      icon: Icons.system_update_alt_rounded,
      title: 'App Updates',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Auto vs Manual toggle ─────────────────────────────────
          _switchTile(
            'Automatic Update Check',
            _autoCheckUpdates
                ? 'QuotiMate checks GitHub for updates on every launch'
                : 'Tap "Check GitHub" manually to look for updates',
            _autoCheckUpdates,
            (val) {
              setState(() => _autoCheckUpdates = val);
              _saveAutoCheckPref(val);
            },
            Icons.autorenew_rounded,
          ),
          const Divider(color: Color(0xFF2A3045), height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Current Installed Version', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(_currentAppVersion, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              FilledButton.icon(
                onPressed: _checkingUpdate ? null : _checkForUpdate,
                icon: _checkingUpdate
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Icon(Icons.refresh_rounded, size: 16),
                label: Text(_checkingUpdate ? 'Checking...' : 'Check GitHub'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFFC107),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Repository: jumagee7/QuotiMate',
            style: TextStyle(color: Color(0xFFFFC107), fontSize: 12, fontWeight: FontWeight.w600),
          ),
          if (_updateError != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(_updateError!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],
          if (hasRelease) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF0F162C),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2A3045)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFF10B981)),
                            ),
                            child: const Text('Latest Release', style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 8),
                          Text(tagName, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      if (releaseName.isNotEmpty && releaseName != tagName)
                        Text(releaseName, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                  if (releaseBody.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      releaseBody,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (apkDownloadUrl != null)
                        FilledButton.icon(
                          onPressed: () => _openUpdatePrompt(release),
                          icon: const Icon(Icons.system_update_alt_rounded, size: 15),
                          label: Text('$apkLabel$apkSize'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final uri = Uri.parse(htmlUrl);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        },
                        icon: const Icon(Icons.open_in_new_rounded, size: 15),
                        label: const Text('GitHub'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFFFC107),
                          side: const BorderSide(color: Color(0xFFFFC107)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          if (!_checkingUpdate && _hasCheckedUpdate && !hasRelease && _updateError == null) ...[
            const SizedBox(height: 12),
            const Text('You have the latest version of QuotiMate installed.', style: TextStyle(color: Color(0xFF10B981), fontSize: 13)),
          ],
        ],
      ),
    );
  }

  // ── Account & Cloud Workspace Section ─────────────────────────────────────
  Widget _buildAccountSection(BuildContext context, AppState appState) {
    final user = AuthService().currentUser;
    final isGuest = user?.isGuest ?? (appState.userEmail.isEmpty || appState.userEmail.endsWith('.local'));
    final syncStatus = CloudSyncService().status;
    final syncMessage = CloudSyncService().statusMessage;

    return Card(
      color: const Color(0xFF161B26),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF2A3045)),
      ),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text(
                      'G',
                      style: TextStyle(
                        color: Color(0xFF4285F4),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Roboto',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Google Account & Cloud Sync',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Sync Status Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: syncStatus == SyncStatus.synced
                        ? Colors.green.withValues(alpha: 0.15)
                        : const Color(0xFF2A3045),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: syncStatus == SyncStatus.synced
                          ? Colors.green.withValues(alpha: 0.4)
                          : const Color(0xFF3A4460),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: syncStatus == SyncStatus.synced
                              ? Colors.greenAccent
                              : (syncStatus == SyncStatus.syncing ? const Color(0xFFFFC107) : Colors.grey),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        syncMessage,
                        style: TextStyle(
                          color: syncStatus == SyncStatus.synced
                              ? Colors.greenAccent
                              : const Color(0xFFB0B8D0),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(color: Color(0xFF2A3045), height: 24),

            // Profile info row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFFFFC107).withValues(alpha: 0.15),
                  child: Text(
                    appState.userName.isNotEmpty ? appState.userName[0].toUpperCase() : 'U',
                    style: const TextStyle(
                      color: Color(0xFFFFC107),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name + Role tag — use Wrap so tag never overlaps on narrow screens
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            appState.userName.isNotEmpty ? appState.userName : 'QuotiMate Member',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFC107).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              appState.userRole,
                              style: const TextStyle(
                                color: Color(0xFFFFC107),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        appState.userEmail.isNotEmpty
                            ? appState.userEmail
                            : (isGuest ? 'Guest Session' : 'Signed in with Google'),
                        style: const TextStyle(color: Color(0xFF616C88), fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      // Action button sits below — guaranteed no overlap
                      if (isGuest)
                        FilledButton.icon(
                          onPressed: () {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) => const SignInPage(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.login, size: 16),
                          label: const Text('Sign in with Google'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFFFC107),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        )
                      else
                        OutlinedButton.icon(
                          onPressed: () => _confirmSignOut(context),
                          icon: const Icon(Icons.logout, size: 16, color: Colors.redAccent),
                          label: const Text('Sign Out', style: TextStyle(color: Colors.redAccent)),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.5)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF131722),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF2A3045)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.cloud_done_outlined, color: Color(0xFFFFC107), size: 16),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'All quotations, sequential quote numbers, invoices, schedules, and client records are synchronized in real-time across your team.',
                      style: TextStyle(color: Color(0xFF8A92A6), fontSize: 11, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmSignOut(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B26),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF2A3045)),
        ),
        title: const Text('Sign Out?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'Are you sure you want to sign out of your Google account? You can sign back in anytime to access your shared workspace.',
          style: TextStyle(color: Color(0xFFB0B8D0), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF616C88))),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await AuthService().signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (_) => const SignInPage(),
                  ),
                  (route) => false,
                );
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({required IconData icon, required String title, required Widget child}) {
    return Card(
      color: const Color(0xFF161B26),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF2A3045)),
      ),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFFFFC107), size: 18),
                const SizedBox(width: 10),
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 4),
            const Divider(color: Color(0xFF2A3045), height: 24),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, String initialValue, void Function(String) onSaved, {int maxLines = 1, TextInputType? keyboardType}) {
    return TextFormField(
      initialValue: initialValue,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: _inputDecoration(label),
      onSaved: (val) {
        if (val != null) onSaved(val);
      },
      onChanged: (val) {
        onSaved(val);
      },
    );
  }

  Widget _switchTile(String title, String subtitle, bool value, ValueChanged<bool> onChanged, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFFFC107).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFFFFC107), size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
              Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 12)),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: const Color(0xFFFFC107),
          activeTrackColor: const Color(0xFFFFC107).withValues(alpha: 0.3),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF2A3045))),
      focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFFFC107))),
      filled: true,
      fillColor: const Color(0xFF0F162C),
    );
  }

  void _confirmClearQuotes(BuildContext ctx, AppState appState) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF161B26),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear All Quotes?', style: TextStyle(color: Colors.white)),
        content: const Text('This will permanently delete all quotes. This cannot be undone.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () {
              appState.clearAllQuotes();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('All quotes cleared')));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  void _confirmResetDefaults(BuildContext ctx, AppState appState) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF161B26),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reset Settings to Defaults?', style: TextStyle(color: Colors.white)),
        content: const Text('This will reset your company phone, email, and other settings to their default values.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () {
              appState.resetSettings();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Settings reset to defaults')));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}
