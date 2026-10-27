// widgets/send_contact_buttons.dart — Send a review link via WhatsApp or email
// and capture the recipient's number/address on the client record.
//
// The OS share sheet never reports which app or contact was chosen, so a
// recipient can only be captured when QuotiMate opens WhatsApp/email itself.

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../models.dart';
import 'scrollable_panel.dart';

const _surface = Color(0xFF161B26);
const _bg = Color(0xFF0F162C);
const _border = Color(0xFF2A3045);
const _muted = Color(0xFFB0B8D0);
const _dim = Color(0xFF616C88);
const _whatsapp = Color(0xFF25D366);
const _email = Color(0xFF60A5FA);

class SendContactButtons extends StatelessWidget {
  final AppState appState;
  final String clientId;
  final String clientName;
  final String docLabel;
  final String url;

  const SendContactButtons({
    super.key,
    required this.appState,
    required this.clientId,
    required this.clientName,
    required this.docLabel,
    required this.url,
  });

  Client? get _client =>
      appState.clients.where((c) => c.id == clientId).firstOrNull;

  String get _message =>
      'Hello${clientName.trim().isEmpty ? '' : ' $clientName'}, '
      'please find $docLabel from ${appState.companyName}.\n\n'
      'Review and sign here:\n$url';

  /// wa.me expects a full international number with no '+' or separators.
  /// Local Kenyan numbers (07..., 7..., 1...) are promoted to +254.
  static String normaliseWhatsApp(String raw) {
    var digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('00')) digits = digits.substring(2);
    if (digits.startsWith('0') && digits.length == 10) {
      digits = '254${digits.substring(1)}';
    } else if (digits.length == 9 &&
        (digits.startsWith('7') || digits.startsWith('1'))) {
      digits = '254$digits';
    }
    return digits;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _button(
            label: 'WhatsApp',
            icon: Icons.chat_outlined,
            color: _whatsapp,
            onPressed: () => _sendWhatsApp(context),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _button(
            label: 'Email',
            icon: Icons.email_outlined,
            color: _email,
            onPressed: () => _sendEmail(context),
          ),
        ),
      ],
    );
  }

  Widget _button({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.5)),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      icon: Icon(icon, size: 16),
      label: Text(label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
    );
  }

  Future<void> _sendWhatsApp(BuildContext context) async {
    final client = _client;
    final value = await showDialog<String>(
      context: context,
      builder: (_) => _ContactPrompt(
        forEmail: false,
        clientName: clientName,
        initial: client?.phone ?? '',
      ),
    );
    if (value == null || !context.mounted) return;

    final digits = normaliseWhatsApp(value);
    if (client != null && client.phone != value) {
      appState.updateClient(client.copyWith(phone: value));
    }

    final uri = Uri.parse(
        'https://wa.me/$digits?text=${Uri.encodeComponent(_message)}');
    await _launch(context, uri,
        success: 'Opening WhatsApp for +$digits',
        failure: 'Could not open WhatsApp');
  }

  Future<void> _sendEmail(BuildContext context) async {
    final client = _client;
    final value = await showDialog<String>(
      context: context,
      builder: (_) => _ContactPrompt(
        forEmail: true,
        clientName: clientName,
        initial: client?.email ?? '',
      ),
    );
    if (value == null || !context.mounted) return;

    if (client != null && client.email != value) {
      appState.updateClient(client.copyWith(email: value));
    }

    final subject = '$docLabel from ${appState.companyName}';
    final uri = Uri.parse('mailto:$value'
        '?subject=${Uri.encodeComponent(subject)}'
        '&body=${Uri.encodeComponent(_message)}');
    await _launch(context, uri,
        success: 'Opening email app for $value',
        failure: 'Could not open an email app');
  }

  Future<void> _launch(
    BuildContext context,
    Uri uri, {
    required String success,
    required String failure,
  }) async {
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(opened ? success : failure),
      backgroundColor: opened ? const Color(0xFF10B981) : Colors.redAccent,
    ));
  }
}

/// Recipient prompt, prefilled from the client record. Returns the confirmed
/// value; the caller persists it back to the client.
class _ContactPrompt extends StatefulWidget {
  final bool forEmail;
  final String clientName;
  final String initial;

  const _ContactPrompt({
    required this.forEmail,
    required this.clientName,
    required this.initial,
  });

  @override
  State<_ContactPrompt> createState() => _ContactPromptState();
}

class _ContactPromptState extends State<_ContactPrompt> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.initial);
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _ctrl.text.trim();
    if (widget.forEmail) {
      if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {
        setState(() => _error = 'Enter a valid email address');
        return;
      }
    } else if (SendContactButtons.normaliseWhatsApp(value).length < 8) {
      setState(() => _error = 'Enter a valid WhatsApp number');
      return;
    }
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.forEmail ? _email : _whatsapp;
    return AlertDialog(
      backgroundColor: _surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: _border),
      ),
      title: Row(
        children: [
          Icon(widget.forEmail ? Icons.email_outlined : Icons.chat_outlined,
              color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.forEmail ? 'Send via Email' : 'Send via WhatsApp',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: ScrollablePanel(
        maxHeightFactor: 0.45,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.clientName.trim().isEmpty
                  ? 'Recipient'
                  : 'To: ${widget.clientName}',
              style: const TextStyle(color: _muted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ctrl,
              autofocus: true,
              keyboardType: widget.forEmail
                  ? TextInputType.emailAddress
                  : TextInputType.phone,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText:
                    widget.forEmail ? 'Email address' : 'WhatsApp number',
                labelStyle: const TextStyle(color: _muted),
                hintText:
                    widget.forEmail ? 'client@example.com' : '+254 712 345 678',
                hintStyle: const TextStyle(color: _dim, fontSize: 13),
                errorText: _error,
                errorMaxLines: 2,
                prefixIcon: Icon(
                    widget.forEmail
                        ? Icons.alternate_email
                        : Icons.phone_outlined,
                    size: 18,
                    color: color.withValues(alpha: 0.8)),
                filled: true,
                fillColor: _bg,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _border)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: color)),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              widget.forEmail
                  ? 'Saved to the client record, then your email app opens with the message ready.'
                  : 'Use the full international number. It is saved to the client record, then WhatsApp opens with the message ready.',
              style: const TextStyle(color: _dim, fontSize: 11.5),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: _muted)),
        ),
        FilledButton(
          onPressed: _submit,
          style: FilledButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.black,
          ),
          child: const Text('Send'),
        ),
      ],
    );
  }
}
