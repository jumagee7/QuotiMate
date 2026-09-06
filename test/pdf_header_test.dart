import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quotimate/app_state.dart';
import 'package:quotimate/services/pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('generates enquiry invoice PDF for visual inspection', () async {
    late AppState state;
    await runZonedGuarded(() async {
      state = AppState();
      // Let the constructor's fire-and-forget _init fail harmlessly.
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }, (_, __) {});

    final bytes = await PdfService.generateEnquiryInvoicePdf(
      state: state,
      customerName: 'Test Customer',
      telephone: '0700000000',
      kraPin: 'A011821254M',
      quotationNo: 'ME-001',
      date: DateTime(2026, 8, 31),
      agreedTotal: 150000,
      depositPct: 50,
      midPct: 25,
      completionPct: 25,
      requestLabel: 'Invoice Amount Request',
      requestAmount: 150000,
      nb: 'Test note',
      preparedBy: 'Admin',
      terms: '1. Terms Inclusive of VAT where applicable',
      categories: const [],
    );

    final f = File('build/test_invoice.pdf');
    f.createSync(recursive: true);
    f.writeAsBytesSync(bytes);
    // ignore: avoid_print
    print('PDF written: ${f.absolute.path} (${bytes.length} bytes)');
  });
}
