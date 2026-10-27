// The client review page is the only place a remote signature is born, so its
// identity capture and callback routing are pinned here.

import 'package:flutter_test/flutter_test.dart';
import 'package:quotimate/app_state.dart';
import 'package:quotimate/models.dart';
import 'package:quotimate/services/html_review_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppState state;
  late Quote quote;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    state = AppState();
    quote = Quote(
      id: 'Q-77',
      clientId: 'c1',
      clientName: 'Acme Interiors',
      date: DateTime(2026, 10, 26),
      expiryDate: DateTime(2026, 11, 25),
      status: QuoteStatus.pending,
      categories: [
        QuoteCategory(id: 'cat', name: 'Painting', items: [
          QuoteItem(productId: 'p', name: 'Silk', qty: 2, unitPrice: 1000),
        ]),
      ],
    );
    state.addQuote(quote);
    await Future<void>.delayed(Duration.zero);
  });

  test('asks the signer who they are before it will transmit', () {
    final html =
        HtmlReviewService.generateQuoteHtml(quote, state, serverUrl: null);

    expect(html, contains('id="signer-name"'));
    expect(html, contains('id="signer-phone"'));
    expect(html, contains('value="Acme Interiors"'));
    expect(html, contains('refreshApproveBtn()'));
  });

  test('prefers the origin that served the page over the baked-in LAN IP', () {
    final html = HtmlReviewService.generateQuoteHtml(
      quote,
      state,
      serverUrl: 'http://192.168.137.1:8080',
    );

    expect(html, contains('const pageOrigin'));
    expect(html, contains('localTargets.push(pageOrigin)'));
    expect(html, contains('if (configuredServer && localTargets.indexOf'));
  });

  test('every transport is time bounded so the client never hangs', () {
    final html =
        HtmlReviewService.generateQuoteHtml(quote, state, serverUrl: null);

    expect(html, contains('function fetchWithTimeout'));
    expect(html, contains('ctl.abort()'));
    // No bare fetch() left in the signature submission path.
    final approveBody =
        html.substring(html.indexOf('async function approveSig'));
    expect(approveBody.substring(0, approveBody.indexOf('function copySigCode')),
        isNot(contains('await fetch(')));
  });

  test('signer evidence travels with the signature on both transports', () {
    final html =
        HtmlReviewService.generateQuoteHtml(quote, state, serverUrl: null);

    // Firestore update mask is built from this field list.
    expect(
      html,
      contains('"signatureData","signedAt","status","signerName","signerPhone",'
          '"signerDevice","signerAppVersion","signerLocation"'),
    );

    for (final field in [
      'signerName',
      'signerPhone',
      'signerDevice',
      'signerAppVersion',
      'signerLocation',
    ]) {
      expect(html, contains('$field: { stringValue: evidence.$field }'),
          reason: '$field must be written to the cloud document');
    }

    // The LAN callback sends the same evidence object.
    expect(html, contains('}, evidence))'));
  });

  test('the app applies browser evidence into the signed record', () {
    quote.shareToken = 'tok-1';
    state.markQuoteSigned(
      quote.id,
      'AAAA',
      DateTime(2026, 10, 26, 13, 42),
      SignatureMetadata(
        signerName: 'Peter Otieno',
        signerPhone: '+254733555777',
        device: 'Android 14 - Samsung A54',
        appVersion: 'QuotiMate Web Review - 412x915 en-GB',
        location: '-1.28638, 36.81722',
      ),
    );

    final signed = state.quotes.firstWhere((q) => q.id == quote.id);
    expect(signed.status, QuoteStatus.approved);
    expect(signed.signerName, 'Peter Otieno');
    expect(signed.signerPhone, '+254733555777');
    expect(signed.signerDevice, 'Android 14 - Samsung A54');
    expect(signed.signerAppVersion, 'QuotiMate Web Review - 412x915 en-GB');
    expect(signed.signerLocation, '-1.28638, 36.81722');

    final rows = signed.signerMetadata.rows.map((e) => e.key).toList();
    expect(rows, containsAll(['Signed by', 'WhatsApp Number', 'Device', 'App build', 'Location']));
  });
}
