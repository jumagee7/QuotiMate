// pages/quote_sign_share_sheet.dart — Client review & signature actions for a
// quote. Shared by the Quotes list and the quote editor so both offer the same
// link, on-device capture, cloud sync and verification-code import.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../models.dart';
import '../services/cloud_sync_service.dart';
import '../services/html_review_service.dart';
import '../services/review_server_service.dart';
import '../widgets/scrollable_panel.dart';
import '../widgets/send_contact_buttons.dart';
import 'signature_page.dart';

const _surface = Color(0xFF161B26);
const _border = Color(0xFF2A3045);
const _gold = Color(0xFFFFC107);
const _white54 = Colors.white54;
const _white70 = Color(0xFFB0B8D0);

Future<void> showQuoteSignShareSheet(
  BuildContext context,
  Quote quote,
  AppState state,
) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: _surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.draw_outlined, color: _gold),
              const SizedBox(width: 10),
              Text(
                'Client Review & Signature — ${quote.id}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Send a review link to the client (they sign in their browser, no app needed), capture on device, or sync signature.',
            style: TextStyle(color: _white70, fontSize: 13),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.link, color: Colors.blue),
            ),
            title: const Text('Send Review Link to Client',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: const Text(
                'Client opens in browser, reviews & signs — sent back to QuotiMate in real time',
                style: TextStyle(color: _white70, fontSize: 12)),
            onTap: () {
              Navigator.pop(context);
              _showReviewLinkDialog(context, quote, state);
            },
          ),
          const SizedBox(height: 6),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: _gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.edit, color: _gold),
            ),
            title: const Text('Capture Signature Now',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: const Text('Client signs directly on this screen',
                style: TextStyle(color: _white70, fontSize: 12)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => SignaturePage(quote: quote)),
              );
            },
          ),
          const SizedBox(height: 6),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.sync, color: Colors.teal),
            ),
            title: const Text('Check / Sync Signature from Cloud',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: const Text(
                'Fetch client signature from Firebase cloud if signed remotely',
                style: TextStyle(color: _white70, fontSize: 12)),
            onTap: () async {
              Navigator.pop(context);
              final found = await state.checkCloudSignatureForQuote(quote.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(found
                        ? '✓ Cloud signature retrieved! Quote is now signed.'
                        : 'No remote signature found in cloud yet. Client has not signed.'),
                    backgroundColor:
                        found ? const Color(0xFF10B981) : Colors.orange,
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 6),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.paste, color: Colors.purpleAccent),
            ),
            title: const Text('Import Signature Verification Code',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: const Text(
                'Paste signature code or payload sent by client offline',
                style: TextStyle(color: _white70, fontSize: 12)),
            onTap: () {
              Navigator.pop(context);
              _showImportSignatureDialog(context, quote, state);
            },
          ),
        ],
      ),
    ),
  );
}

void _showReviewLinkDialog(BuildContext context, Quote quote, AppState state) {
  CloudSyncService().saveQuote(quote);
  final server = ReviewServerService();
  final url = server.getReviewUrl(type: 'quote', id: quote.id);

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: _surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _border)),
      title: Row(
        children: [
          const Icon(Icons.link, color: _gold, size: 22),
          const SizedBox(width: 8),
          Text('Client Review Link — ${quote.id}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
        ],
      ),
      content: ScrollablePanel(
        maxHeightFactor: 0.6,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Send this link to the client. The client can review the quotation, sign in their browser (no app required), and the signature is sent back to QuotiMate automatically.',
              style: TextStyle(color: _white70, fontSize: 13),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _border)),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      url,
                      style: const TextStyle(
                          color: _gold,
                          fontSize: 12,
                          fontFamily: 'monospace'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, color: Colors.white, size: 18),
                    tooltip: 'Copy Link',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: url));
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                            content: Text('Review link copied to clipboard!'),
                            backgroundColor: Color(0xFF10B981)),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: _border),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.open_in_browser, size: 16),
                    label: const Text('Open in Browser',
                        style: TextStyle(fontSize: 11)),
                    onPressed: () => launchUrl(Uri.parse(url),
                        mode: LaunchMode.externalApplication),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _gold,
                      foregroundColor: const Color(0xFF1E2733),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.share, size: 16),
                    label: const Text('Share Webpage',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _exportQuoteHtml(context, quote, state);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(color: _border, height: 1),
            const SizedBox(height: 10),
            const Text(
              'Send directly — the client\'s WhatsApp number or email is saved to their record.',
              style: TextStyle(color: _white54, fontSize: 11.5),
            ),
            const SizedBox(height: 8),
            SendContactButtons(
              appState: state,
              clientId: quote.clientId,
              clientName: quote.clientName,
              docLabel: 'Quotation ${quote.id}',
              url: url,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Close', style: TextStyle(color: _white70)),
        ),
      ],
    ),
  );
}

void _showImportSignatureDialog(
    BuildContext context, Quote quote, AppState state) {
  final ctrl = TextEditingController();
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: _surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _border)),
      title: const Row(
        children: [
          Icon(Icons.paste, color: _gold, size: 20),
          SizedBox(width: 8),
          Text('Import Client Signature',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Paste the verification code or JSON payload copied from the client review page:',
            style: TextStyle(color: _white70, fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            maxLines: 4,
            style: const TextStyle(
                color: Colors.white, fontSize: 12, fontFamily: 'monospace'),
            decoration: InputDecoration(
              hintText:
                  'Paste the code the client copied after signing — it carries the signature plus signer name, WhatsApp, device and location.',
              hintStyle: const TextStyle(color: Colors.white30),
              filled: true,
              fillColor: Colors.black26,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _border)),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel', style: TextStyle(color: _white70)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: _gold,
              foregroundColor: const Color(0xFF1E2733)),
          onPressed: () {
            final text = ctrl.text.trim();
            if (text.isEmpty) return;

            String sig = text;
            DateTime? signedAt;
            SignatureMetadata? meta;
            try {
              final json = jsonDecode(text) as Map<String, dynamic>;
              if (json['signatureData'] != null) {
                sig = json['signatureData'] as String;
              }
              if (json['signedAt'] != null) {
                signedAt = DateTime.tryParse(json['signedAt'].toString());
              }
              String? field(String key) {
                final v = json[key];
                return v is String && v.trim().isNotEmpty ? v.trim() : null;
              }

              if (field('signerName') != null ||
                  field('signerDevice') != null) {
                meta = SignatureMetadata(
                  signerName: field('signerName'),
                  signerPhone: field('signerPhone'),
                  device: field('signerDevice'),
                  appVersion: field('signerAppVersion'),
                  location: field('signerLocation'),
                );
              }
            } catch (_) {}

            state.markQuoteSigned(quote.id, sig, signedAt, meta);
            Navigator.pop(ctx);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    '✓ Signature applied! Quote PDF now includes this signature.'),
                backgroundColor: Color(0xFF10B981),
              ),
            );
          },
          child: const Text('Apply Signature',
              style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
}

Future<void> _exportQuoteHtml(
    BuildContext context, Quote quote, AppState state) async {
  try {
    CloudSyncService().saveQuote(quote);
    final serverUrl = ReviewServerService().isRunning
        ? 'http://${ReviewServerService().localIp}:${ReviewServerService().port}'
        : null;
    final html =
        HtmlReviewService.generateQuoteHtml(quote, state, serverUrl: serverUrl);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/Quote_${quote.id}_Review.html');
    await file.writeAsString(html, encoding: utf8);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exported client review HTML to ${file.path}'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    await Printing.sharePdf(
        bytes: await file.readAsBytes(),
        filename: 'Quote_${quote.id}_Review.html');
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to export: $e'),
            backgroundColor: Colors.redAccent),
      );
    }
  }
}
