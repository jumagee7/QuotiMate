// Manual end-to-end harness: starts the app's real embedded review server,
// publishes a quotation, prints the client URL and waits for a browser to sign.
//
//   QM_LIVE_SIGNING=1 flutter test test/live_review_signing_test.dart --timeout 6m
//
// It blocks on a human/browser, so it skips itself out of the normal suite.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quotimate/app_state.dart';
import 'package:quotimate/models.dart';
import 'package:quotimate/services/pdf_service.dart';
import 'package:quotimate/services/review_server_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final enabled = Platform.environment['QM_LIVE_SIGNING'] == '1';

  test('LIVE review signing', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final state = AppState();
    await Future<void>.delayed(const Duration(seconds: 3));

    final quote = Quote(
      id: 'Q-9001',
      clientId: 'c-live',
      clientName: 'Live Test Client Ltd',
      date: DateTime.now(),
      expiryDate: DateTime.now().add(const Duration(days: 30)),
      status: QuoteStatus.pending,
      notes: 'Harness quote for signing capture.',
      categories: [
        QuoteCategory(
          id: 'cat-live',
          name: 'Painting',
          items: [
            QuoteItem(
              productId: 'p-live',
              name: 'Silk Paint - Ivory',
              description: 'Code: SILK-204',
              qty: 4,
              unitPrice: 1250,
            ),
          ],
        ),
      ],
    );
    quote.shareToken = 'live-token-1';
    state.addQuote(quote);

    final server = ReviewServerService();
    await server.start(appState: state);
    final url = server.getReviewUrl(type: 'quote', id: quote.id);
    stdout.writeln('REVIEW_URL $url');
    stdout.writeln('HEALTH     http://127.0.0.1:${server.port}/health');

    // Wait for the browser submission to land in app state.
    Quote? signed;
    for (var i = 0; i < 300; i++) {
      await Future<void>.delayed(const Duration(seconds: 2));
      signed = state.quotes.where((q) => q.id == quote.id).firstOrNull;
      if (signed != null && (signed.signatureData ?? '').isNotEmpty) {
        stdout.writeln('SIGNATURE RECEIVED after ~${(i + 1) * 2}s');
        stdout.writeln('  status        = ${signed.status.name}');
        stdout.writeln('  signedAt      = ${signed.signedAt?.toIso8601String()}');
        stdout.writeln('  signatureData = ${(signed.signatureData ?? '').length} chars of base64 PNG');
        stdout.writeln('  signerName    = ${signed.signerName}');
        stdout.writeln('  signerPhone   = ${signed.signerPhone}');
        stdout.writeln('  signerDevice  = ${signed.signerDevice}');
        stdout.writeln('  signerAppVer  = ${signed.signerAppVersion}');
        stdout.writeln('  signerLocation= ${signed.signerLocation}');
        final raw = signed.signatureData!;
        final comma = raw.indexOf(',');
        final b64 = comma == -1 ? raw : raw.substring(comma + 1);
        File('scratch/captured_signature.png')
            .writeAsBytesSync(base64Decode(b64));
        stdout.writeln('  saved         -> scratch/captured_signature.png');
        final pdf = await PdfService.generateQuotePdf(signed, state,
            appendCertificate: true);
        File('scratch/signed_quote.pdf').writeAsBytesSync(pdf);
        stdout.writeln('  saved         -> scratch/signed_quote.pdf (${pdf.length} bytes)');
        break;
      }
    }

    await server.stop();
    expect(signed, isNotNull, reason: 'quote never appeared in app state');
    expect((signed!.signatureData ?? '').isNotEmpty, isTrue,
        reason: 'no signature arrived from the browser');
  },
      timeout: const Timeout(Duration(minutes: 31)),
      skip: enabled ? false : 'Manual browser harness — set QM_LIVE_SIGNING=1');
}
