import 'dart:convert';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart' show debugPrint;
import 'package:intl/intl.dart';
import '../models.dart';
import '../app_state.dart';

class PdfService {
  static Future<Uint8List> generateQuotePdf(
    Quote quote,
    AppState state, {
    bool appendCertificate = false,
  }) async {
    if (state.pdfTemplate == 'minimalist') {
      return _generateMinimalistPdf(quote, state, appendCertificate: appendCertificate);
    }
    return _generateMajumaPdf(quote, state, appendCertificate: appendCertificate);
  }

  /// Convenience: generates an Invoice PDF from an Invoice model.
  static Future<Uint8List> generateInvoicePdf(
    Invoice invoice,
    AppState state, {
    bool appendCertificate = false,
  }) async {
    return generateEnquiryInvoicePdf(
      state: state,
      customerName: invoice.clientName.isEmpty ? 'Valued Customer' : invoice.clientName,
      telephone: '',
      kraPin: invoice.kraPin,
      quotationNo: invoice.id,
      date: invoice.date,
      agreedTotal: invoice.amount,
      depositPct: 50,
      midPct: 25,
      completionPct: 25,
      requestLabel: 'Invoice Amount',
      requestAmount: invoice.amount,
      nb: '',
      preparedBy: state.preparedBy,
      terms: '1. Terms Inclusive of VAT where applicable\n2. Payment due within agreed period',
      categories: invoice.categories,
      signatureData: invoice.signatureData,
      signedAt: invoice.signedAt,
      signerInfo: invoice.signerInfo,
      appendCertificate: appendCertificate,
    );
  }

  static Future<Uint8List> _generateMajumaPdf(
    Quote quote,
    AppState state, {
    bool appendCertificate = false,
  }) async {
    final pdf = pw.Document();

    final dateStr = DateFormat('dd/MM/yyyy').format(quote.date);
    final currencyFormat = NumberFormat.currency(
      symbol: 'Ksh ',
      decimalDigits: 0,
    );
    final goldColor = PdfColor.fromHex('#E7C67B'); // Gold text

    pw.MemoryImage? logoImage;
    try {
      final logoBytes = await rootBundle.load('assets/modernedge_logo.png');
      logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (e, st) {
      debugPrint('Error loading logo: $e\n$st');
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        footer: (pw.Context context) => pw.Container(
          alignment: pw.Alignment.center,
          margin: const pw.EdgeInsets.only(top: 8),
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 8),
          ),
        ),
        build: (pw.Context context) {
          return [
            // Header Banner – Majuma style: dark bg + logo + blue border overlay
            pw.Stack(
              children: [
                pw.Container(
                  height: 112.5,
                  color: PdfColor.fromHex('#1E2733'),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      // Logo Block (full-bleed left)
                      if (logoImage != null)
                        pw.Expanded(
                          flex: 3,
                          child: pw.Image(logoImage, fit: pw.BoxFit.cover),
                        )
                      else
                        pw.Expanded(
                          flex: 3,
                          child: pw.Padding(
                            padding: const pw.EdgeInsets.all(24),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              mainAxisAlignment: pw.MainAxisAlignment.center,
                              children: [
                                pw.Text(
                                  'MAJUMA INTERIORS',
                                  style: pw.TextStyle(
                                    color: goldColor,
                                    fontSize: 22,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                                pw.SizedBox(height: 2),
                                pw.Text(
                                  'Your Dreams, Our Talent',
                                  style: pw.TextStyle(
                                    color: PdfColors.white,
                                    fontSize: 10,
                                    fontStyle: pw.FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      pw.Spacer(flex: 1),

                      // Company Details Block (right side)
                      pw.Expanded(
                        flex: 4,
                        child: pw.Padding(
                          padding: const pw.EdgeInsets.only(
                            right: 16, top: 16, bottom: 16,
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.end,
                            mainAxisAlignment: pw.MainAxisAlignment.center,
                            children: [
                              pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text(
                                    'MAJUMA INTERIORS',
                                    style: pw.TextStyle(
                                      color: PdfColors.white,
                                      fontSize: 14,
                                      fontWeight: pw.FontWeight.bold,
                                    ),
                                  ),
                                  pw.SizedBox(height: 8),
                                  if (state.companyAddress.trim().isNotEmpty)
                                    _headerRow('ADDRESS:', state.companyAddress),
                                  _headerRow('P.O.Box:', '00502-1003'),
                                  _headerRow('TEL:', state.companyPhone),
                                  _headerRow('EMAIL:', state.companyEmail),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Blue border overlay
                pw.Positioned.fill(
                  child: pw.Container(
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(
                        color: PdfColor.fromHex('#0000FF'),
                        width: 2.0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 20),


            // Quotation Title
            pw.Center(
              child: pw.Text(
                'QUOTATION',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Divider(thickness: 1.5, color: PdfColors.black),
            pw.SizedBox(height: 12),

            // Meta Information
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _metaRow('CUSTOMER NAME:', quote.clientName),
                      pw.SizedBox(height: 6),
                      _metaRow('CUSTOMER TEL:', ''),
                    ],
                  ),
                ),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _metaRow('DATE:', dateStr),
                      pw.SizedBox(height: 6),
                      _metaRow('QUOTATION NUMBER:', quote.id),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 20),

            // Table
            _buildTable(quote, currencyFormat),
            pw.SizedBox(height: 30),

            // Footer (Terms on Left, Signature Block on Right)
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (state.preparedBy.trim().isNotEmpty) ...[
                      pw.Text(
                        'Prepared By:  ${state.preparedBy}',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                      pw.SizedBox(height: 5),
                    ],
                    pw.Text('TERMS:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 3),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(6),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey500),
                      ),
                      width: 260,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            '1. Terms Inclusive of VAT where applicable',
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                          pw.SizedBox(height: 3),
                          pw.Text(
                            '2. Quotation valid for ${state.defaultExpiryDays} days',
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                          pw.SizedBox(height: 3),
                          pw.Text(
                            '3. 70% Payment to be made upon receipt of Quotation',
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                _buildQuoteSignatureBox(quote),
              ],
            ),
          ];
        },
      ),
    );

    if (appendCertificate) {
      final sigBytes = quote.signatureData != null && quote.signatureData!.isNotEmpty
          ? _safeDecodeBase64(quote.signatureData!)
          : null;
      if (sigBytes != null) {
        final signedDate = quote.signedAt != null
            ? DateFormat('dd MMM yyyy, HH:mm').format(quote.signedAt!)
            : DateFormat('dd MMM yyyy, HH:mm').format(DateTime.now());
        pdf.addPage(
          _buildCertificatePage(
            docId: quote.id,
            docType: 'Quotation',
            clientName: quote.clientName.isEmpty ? 'Valued Customer' : quote.clientName,
            signedDate: signedDate,
            sigImage: pw.MemoryImage(sigBytes),
            goldColor: goldColor,
            signer: quote.signerInfo,
          ),
        );
      }
    }

    return pdf.save();
  }

  static Future<Uint8List> generateEnquiryInvoicePdf({
    required AppState state,
    required String customerName,
    required String telephone,
    required String kraPin,
    required String quotationNo,
    required DateTime date,
    required double agreedTotal,
    required double depositPct,
    required double midPct,
    required double completionPct,
    required String requestLabel,
    required double requestAmount,
    required String nb,
    required String preparedBy,
    required String terms,
    required List<QuoteCategory> categories,
    String? signatureData,
    DateTime? signedAt,
    SignerInfo? signerInfo,
    bool appendCertificate = false,
  }) async {
    final pdf = pw.Document();

    final dateStr = DateFormat('dd/MM/yyyy').format(date);
    final fmt = NumberFormat.currency(symbol: 'Ksh ', decimalDigits: 0);
    final goldColor = PdfColor.fromHex('#E7C67B');
    final darkHeader = PdfColor.fromHex('#1E2733');
    final grandTotal = requestAmount > 0 ? requestAmount : agreedTotal;

    pw.MemoryImage? logoImage;
    try {
      final logoBytes = await rootBundle.load('assets/modernedge_logo.png');
      logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (e, st) {
      debugPrint('Error loading logo in invoice: $e\n$st');
    }

    pw.Widget cell(
      String text, {
      bool bold = false,
      pw.Alignment align = pw.Alignment.centerLeft,
      PdfColor? bg,
      PdfColor? fg,
      double fontSize = 9,
    }) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        color: bg,
        child: pw.Align(
          alignment: align,
          child: pw.Text(
            text,
            style: pw.TextStyle(
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: fg ?? PdfColors.black,
              fontSize: fontSize,
            ),
          ),
        ),
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        footer: (pw.Context context) => pw.Container(
          alignment: pw.Alignment.center,
          margin: const pw.EdgeInsets.only(top: 8),
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 8),
          ),
        ),
        build: (pw.Context context) {
          // ── User-added item rows (per category) ────────────────────────
          final itemRows = <pw.TableRow>[];
          for (final cat in categories) {
            if (cat.items.isEmpty) continue;
            if (cat.name.trim().isNotEmpty) {
              itemRows.add(pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  cell(cat.name.toUpperCase(), bold: true, fontSize: 9),
                  cell(''),
                  cell(''),
                  cell(''),
                  cell(''),
                ],
              ));
            }
            for (final item in cat.items) {
              itemRows.add(pw.TableRow(
                children: [
                  cell(item.name),
                  cell(item.qty.toStringAsFixed(0), align: pw.Alignment.centerRight),
                  cell(item.unit),
                  cell(fmt.format(item.unitPrice), align: pw.Alignment.centerRight),
                  cell(fmt.format(item.total), align: pw.Alignment.centerRight),
                ],
              ));
            }
            if (cat.showSubtotals) {
              itemRows.add(pw.TableRow(
                children: [
                  cell('${cat.name} Subtotal', bold: true),
                  cell(''),
                  cell(''),
                  cell(''),
                  cell(fmt.format(cat.subtotal), bold: true, align: pw.Alignment.centerRight),
                ],
              ));
            }
            if (cat.labourInput.trim().isNotEmpty) {
              itemRows.add(pw.TableRow(
                children: [
                  cell('Labour (${cat.labourInput})'),
                  cell(''),
                  cell(''),
                  cell(''),
                  cell(fmt.format(cat.labourCost), align: pw.Alignment.centerRight),
                ],
              ));
            }
          }
          return [
            // ── Header Banner (Majuma Style) ──────────────────────────────────
            pw.Stack(
              children: [
                pw.Container(
                  height: 145,
                  color: darkHeader,
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      // Logo Block
                      if (logoImage != null)
                        pw.Expanded(
                          flex: 3,
                          child: pw.Image(logoImage, fit: pw.BoxFit.cover),
                        )
                      else
                        pw.Expanded(
                          flex: 3,
                          child: pw.Padding(
                            padding: const pw.EdgeInsets.all(24),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              mainAxisAlignment: pw.MainAxisAlignment.center,
                              children: [
                                pw.Text(
                                  'MAJUMA INTERIORS',
                                  style: pw.TextStyle(
                                    color: goldColor,
                                    fontSize: 20,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                                pw.SizedBox(height: 2),
                                pw.Text(
                                  'Your Dreams, Our Talent',
                                  style: pw.TextStyle(
                                    color: PdfColors.white,
                                    fontSize: 9,
                                    fontStyle: pw.FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      pw.Spacer(flex: 1),

                      // Company Details Block
                      pw.Expanded(
                        flex: 4,
                        child: pw.Padding(
                          padding: const pw.EdgeInsets.only(right: 16, top: 16, bottom: 16),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.end,
                            mainAxisAlignment: pw.MainAxisAlignment.center,
                            children: [
                              pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text(
                                    'MAJUMA INTERIORS',
                                    style: pw.TextStyle(
                                      color: PdfColors.white,
                                      fontSize: 14,
                                      fontWeight: pw.FontWeight.bold,
                                    ),
                                  ),
                                  pw.SizedBox(height: 8),
                                  if (state.companyAddress.trim().isNotEmpty)
                                    _headerRow('ADDRESS:', state.companyAddress),
                                  _headerRow('P.O.Box:', '00502-1003'),
                                  _headerRow('TEL:', state.companyPhone),
                                  _headerRow('EMAIL:', state.companyEmail),
                                  if (kraPin.trim().isNotEmpty)
                                    _headerRow('KRA PIN:', kraPin),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Blue border overlay
                pw.Positioned.fill(
                  child: pw.Container(
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(
                        color: PdfColor.fromHex('#0000FF'),
                        width: 2.0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 20),

            // ── Invoice Title (Centered below the blue rectangle) ─────────────
            pw.Center(
              child: pw.Text(
                'INVOICE',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Divider(thickness: 1.5, color: PdfColors.black),
            pw.SizedBox(height: 12),

            // ── Customer Meta Info ───────────────────────────────────────────
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _metaRow('CUSTOMER NAME:', customerName),
                      pw.SizedBox(height: 6),
                      _metaRow('CUSTOMER TEL:', telephone),
                    ],
                  ),
                ),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _metaRow('DATE:', dateStr),
                      pw.SizedBox(height: 6),
                      _metaRow('QUOTATION NUMBER:', quotationNo),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 16),

            // ── Table ────────────────────────────────────────────────────────
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.8),
              columnWidths: {
                0: const pw.FlexColumnWidth(3.5),
                1: const pw.FlexColumnWidth(1.0),
                2: const pw.FlexColumnWidth(1.0),
                3: const pw.FlexColumnWidth(1.5),
                4: const pw.FlexColumnWidth(1.5),
              },
              children: [
                // Table Header
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey800),
                  children: [
                    'Description',
                    'Quantity',
                    'Type',
                    'Unit Price',
                    'Line Total',
                  ].map((h) => cell(h, bold: true, fg: PdfColors.white)).toList(),
                ),

                // User-added Items (per category)
                ...itemRows,
                if (itemRows.isNotEmpty) ...[
                  // Blank separator row
                  pw.TableRow(
                    children: [cell(''), cell(''), cell(''), cell(''), cell('')],
                  ),
                ],

                // Labour Section Banner
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    cell('Labour and Material Per Agreement', bold: true),
                    cell(''),
                    cell(''),
                    cell(''),
                    cell(''),
                  ],
                ),
                pw.TableRow(
                  children: [
                    cell('Agreed Total'),
                    cell('1'),
                    cell(''),
                    cell(fmt.format(agreedTotal), align: pw.Alignment.centerRight),
                    cell(fmt.format(agreedTotal), align: pw.Alignment.centerRight),
                  ],
                ),

                // Blank row
                pw.TableRow(
                  children: [cell(''), cell(''), cell(''), cell(''), cell('')],
                ),

                // Payment Terms - Merged cell with highlighted background
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    cell(
                      'Payment Terms: ${depositPct.toInt()}% Deposit to commence work, ${midPct.toInt()}% upon ${midPct.toInt()}% work done, ${completionPct.toInt()}% upon Completion of work',
                      bold: true,
                    ),
                    cell(''),
                    cell(''),
                    cell(''),
                    cell(''),
                  ],
                ),

                // Blank row
                pw.TableRow(
                  children: [cell(''), cell(''), cell(''), cell(''), cell('')],
                ),

                // Amount Requested Section
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    cell('Amount Requested', bold: true),
                    cell(''),
                    cell(''),
                    cell(''),
                    cell(''),
                  ],
                ),
                pw.TableRow(
                  children: [
                    cell(requestLabel.isEmpty ? '100% Request' : requestLabel),
                    cell('1'),
                    cell(''),
                    cell(fmt.format(requestAmount), align: pw.Alignment.centerRight),
                    cell(fmt.format(requestAmount), align: pw.Alignment.centerRight),
                  ],
                ),

                // Total Invoice Amount Row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    cell('Total Invoice Amount', bold: true),
                    cell(''),
                    cell(''),
                    cell(''),
                    cell(fmt.format(grandTotal), bold: true, align: pw.Alignment.centerRight),
                  ],
                ),

                // Blank row
                pw.TableRow(
                  children: [cell(''), cell(''), cell(''), cell(''), cell('')],
                ),

                // Grand Total Row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey900),
                  children: [
                    cell('GRAND TOTAL', bold: true, fg: PdfColors.white, fontSize: 10),
                    cell('', fg: PdfColors.white),
                    cell('', fg: PdfColors.white),
                    cell('', fg: PdfColors.white),
                    cell(
                      fmt.format(grandTotal),
                      bold: true,
                      fg: goldColor,
                      align: pw.Alignment.centerRight,
                      fontSize: 11,
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 20),

            // ── Footer Notes & Terms ─────────────────────────────────────────
            if (nb.trim().isNotEmpty) ...[
              pw.Text(
                'NB: $nb',
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 6),
            ],

            if (preparedBy.trim().isNotEmpty) ...[
              pw.Text(
                'Prepared By:  $preparedBy',
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.SizedBox(height: 8),
            ],

            // Terms & Signature Row
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('TERMS:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(6),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey500),
                      ),
                      width: 270,
                      child: pw.Text(
                        terms,
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ),
                  ],
                ),
                _buildInvoiceSignatureBox(customerName, signatureData, signedAt),
              ],
            ),
          ];
        },
      ),
    );

    if (appendCertificate) {
      final sigBytes = signatureData != null && signatureData.isNotEmpty
          ? _safeDecodeBase64(signatureData)
          : null;
      if (sigBytes != null) {
        final signedDate = signedAt != null
            ? DateFormat('dd MMM yyyy, HH:mm').format(signedAt)
            : DateFormat('dd MMM yyyy, HH:mm').format(DateTime.now());
        pdf.addPage(
          _buildCertificatePage(
            docId: quotationNo,
            docType: 'Invoice',
            clientName: customerName.isEmpty ? 'Valued Customer' : customerName,
            signedDate: signedDate,
            sigImage: pw.MemoryImage(sigBytes),
            goldColor: goldColor,
            signer: signerInfo,
          ),
        );
      }
    }

    return pdf.save();
  }

  static pw.Widget _headerRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.SizedBox(
            width: 75,
            child: pw.Text(
              label,
              style: const pw.TextStyle(color: PdfColors.white, fontSize: 9),
            ),
          ),
          pw.Text(
            value,
            style: const pw.TextStyle(color: PdfColors.white, fontSize: 9),
          ),
        ],
      ),
    );
  }

  static pw.Widget _metaRow(String label, String value) {
    return pw.Row(
      children: [
        pw.SizedBox(
          width: 140,
          child: pw.Text(label, style: const pw.TextStyle(fontSize: 11)),
        ),
        pw.Text(value, style: const pw.TextStyle(fontSize: 11)),
      ],
    );
  }

  static pw.Widget _buildTable(Quote quote, NumberFormat fmt) {
    final headers = ['NO.', 'ITEM', 'QUANTITY', 'TYPE', 'UNIT PRICE', 'PRICE'];

    final colWidths = <int, pw.TableColumnWidth>{
      0: const pw.FlexColumnWidth(0.5),
      1: const pw.FlexColumnWidth(2.5),
      2: const pw.FlexColumnWidth(1.2),
      3: const pw.FlexColumnWidth(1),
      4: const pw.FlexColumnWidth(1.5),
      5: const pw.FlexColumnWidth(1.5),
    };

    final mergedColWidths = <int, pw.TableColumnWidth>{
      0: const pw.FlexColumnWidth(0.5),
      1: const pw.FlexColumnWidth(6.2), // 2.5 + 1.2 + 1 + 1.5
      2: const pw.FlexColumnWidth(1.5),
    };

    pw.Widget buildMergedTable(List<pw.TableRow> rows) {
      return pw.Table(
        border: const pw.TableBorder(
          left: pw.BorderSide(color: PdfColors.grey600),
          right: pw.BorderSide(color: PdfColors.grey600),
          bottom: pw.BorderSide(color: PdfColors.grey600),
          verticalInside: pw.BorderSide(color: PdfColors.grey600),
          horizontalInside: pw.BorderSide(color: PdfColors.grey600),
        ),
        columnWidths: mergedColWidths,
        children: rows,
      );
    }

    final headerTable = pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey600, width: 1),
      columnWidths: colWidths,
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey800),
          children: headers.map((h) => _cell(h, isHeader: true)).toList(),
        ),
      ],
    );

    int globalItemIndex = 1;
    final categoryBlocks = quote.categories.map((cat) {
      final blocks = <pw.Widget>[];

      if (cat.name.trim().isNotEmpty) {
        blocks.add(
          pw.Container(
            width: double.infinity,
            decoration: const pw.BoxDecoration(
              color: PdfColors.grey800,
              border: pw.Border(
                left: pw.BorderSide(color: PdfColors.grey600),
                right: pw.BorderSide(color: PdfColors.grey600),
                bottom: pw.BorderSide(color: PdfColors.grey600),
              )
            ),
            padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            child: pw.Text(
              cat.name.toUpperCase(),
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10),
            ),
          )
        );
      }

      final itemRows = <pw.TableRow>[];
      for (int i = 0; i < cat.items.length; i++) {
        itemRows.add(pw.TableRow(
          children: [
            _cell('${globalItemIndex++}'),
            _cell(cat.items[i].name),
            _cell(cat.items[i].qty.toStringAsFixed(0)),
            _cell(cat.items[i].unit),
            _cell(fmt.format(cat.items[i].unitPrice)),
            _cell(fmt.format(cat.items[i].total)),
          ],
        ));
      }

      if (itemRows.isNotEmpty) {
        blocks.add(
          pw.Table(
            border: const pw.TableBorder(
              left: pw.BorderSide(color: PdfColors.grey600),
              right: pw.BorderSide(color: PdfColors.grey600),
              bottom: pw.BorderSide(color: PdfColors.grey600),
              verticalInside: pw.BorderSide(color: PdfColors.grey600),
              horizontalInside: pw.BorderSide(color: PdfColors.grey600),
            ),
            columnWidths: colWidths,
            children: itemRows,
          )
        );
      }

      final mergedRows = <pw.TableRow>[];
      
      // Empty separator row at the end of items
      mergedRows.add(pw.TableRow(
        children: [_cell(''), _cell(''), _cell('')]
      ));

      if (cat.showSubtotals && cat.items.isNotEmpty) {
        mergedRows.add(pw.TableRow(
          children: [
            _cell(''),
            _cell('${cat.name} Subtotal', isBold: true),
            _cell(fmt.format(cat.subtotal), isBold: true),
          ],
        ));
      }

      if (cat.showSubtotals && cat.labourCost > 0) {
        mergedRows.add(pw.TableRow(
          children: [
            _cell(''),
            _cell('${cat.name} Labour/Markup (${cat.labourInput})'),
            _cell(fmt.format(cat.labourCost)),
          ],
        ));
        
        mergedRows.add(pw.TableRow(
          children: [
            _cell(''),
            _cell('${cat.name} Total', isBold: true),
            _cell(fmt.format(cat.subtotal + cat.labourCost), isBold: true),
          ],
        ));
      }

      if (mergedRows.isNotEmpty) {
        blocks.add(buildMergedTable(mergedRows));
      }

      return pw.Column(children: blocks);
    }).toList();

    final globalRows = <pw.TableRow>[
      pw.TableRow(children: [_cell(''), _cell(''), _cell('')]),
      pw.TableRow(
        children: [
          _cell(''),
          _cell('Global Sub Totals', isBold: true),
          _cell(fmt.format(quote.subtotal), isBold: true),
        ],
      ),
      if (quote.categoryLabourCost > 0)
        pw.TableRow(
          children: [
            _cell(''),
            _cell('Category Labour/Markup', isBold: true),
            _cell(fmt.format(quote.categoryLabourCost)),
          ],
        ),
      if (quote.labourCost > 0)
        pw.TableRow(
          children: [
            _cell(''),
            _cell('Global Labour', isBold: true),
            _cell(fmt.format(quote.labourCost), isBold: true),
          ],
        ),
      if (quote.tax > 0)
        pw.TableRow(
          children: [
            _cell(''),
            _cell('VAT (${quote.vatPercent.toStringAsFixed(quote.vatPercent == quote.vatPercent.truncateToDouble() ? 0 : 1)}%)', isBold: true),
            _cell(fmt.format(quote.tax), isBold: true),
          ],
        ),
      pw.TableRow(children: [_cell(''), _cell(''), _cell('')]),
      pw.TableRow(
        children: [
          _cell(''),
          _cell('GRAND TOTALS', isBold: true),
          _cell(fmt.format(quote.total), isBold: true),
        ],
      ),
    ];

    final globalTable = buildMergedTable(globalRows);

    return pw.Column(
      children: [
        headerTable,
        ...categoryBlocks,
        globalTable,
      ],
    );
  }
  static pw.Widget _cell(
    String text, {
    bool isHeader = false,
    bool isBold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          color: isHeader ? PdfColors.white : PdfColors.black,
          fontWeight: isHeader || isBold
              ? pw.FontWeight.bold
              : pw.FontWeight.normal,
          fontSize: 10,
        ),
      ),
    );
  }

  // ── Minimalist Template ──────────────────────────────────────────────────

  static Future<Uint8List> _generateMinimalistPdf(
    Quote quote,
    AppState state, {
    bool appendCertificate = false,
  }) async {
    final pdf = pw.Document();
    final dateStr = DateFormat('dd/MM/yyyy').format(quote.date);
    final currencyFormat = NumberFormat.currency(
      symbol: '${state.currency} ',
      decimalDigits: 0,
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        footer: (pw.Context context) => pw.Container(
          alignment: pw.Alignment.center,
          margin: const pw.EdgeInsets.only(top: 8),
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 8),
          ),
        ),
        build: (pw.Context context) {
          return [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      state.companyName,
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.black,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      state.companyAddress,
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.Text(
                      state.companyPhone,
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.Text(
                      state.companyEmail,
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'QUOTATION',
                      style: pw.TextStyle(
                        fontSize: 28,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey300,
                      ),
                    ),
                    pw.Text(
                      '#${quote.id}',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.black,
                      ),
                    ),
                    pw.Text(
                      'Date: $dateStr',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 30),
            pw.Text(
              'Prepared For:',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey600,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              quote.clientName,
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.black,
              ),
            ),
            pw.SizedBox(height: 20),

            // Minimalist Table
            _buildMinimalistTable(quote, currencyFormat),
            pw.SizedBox(height: 40),

            // Footer
            pw.Divider(color: PdfColors.grey300),
            pw.SizedBox(height: 10),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Terms & Conditions',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      '1. Valid for ${state.defaultExpiryDays} days.',
                      style: const pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.Text(
                      '2. 70% advance payment required.',
                      style: const pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey700,
                      ),
                    ),
                    if (state.preparedBy.trim().isNotEmpty) ...[
                      pw.SizedBox(height: 6),
                      pw.Text(
                        'Prepared by: ${state.preparedBy}',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontStyle: pw.FontStyle.italic,
                          color: PdfColors.grey600,
                        ),
                      ),
                    ],
                  ],
                ),
                _buildQuoteSignatureBox(quote),
              ],
            ),
          ];
        },
      ),
    );

    if (appendCertificate) {
      final sigBytes = quote.signatureData != null && quote.signatureData!.isNotEmpty
          ? _safeDecodeBase64(quote.signatureData!)
          : null;
      if (sigBytes != null) {
        final signedDate = quote.signedAt != null
            ? DateFormat('dd MMM yyyy, HH:mm').format(quote.signedAt!)
            : DateFormat('dd MMM yyyy, HH:mm').format(DateTime.now());
        pdf.addPage(
          _buildCertificatePage(
            docId: quote.id,
            docType: 'Quotation',
            clientName: quote.clientName.isEmpty ? 'Valued Customer' : quote.clientName,
            signedDate: signedDate,
            sigImage: pw.MemoryImage(sigBytes),
            goldColor: PdfColor.fromHex('#E7C67B'),
            signer: quote.signerInfo,
          ),
        );
      }
    }

    return pdf.save();
  }

  static pw.Widget _buildMinimalistTable(Quote quote, NumberFormat fmt) {
    final headers = ['Description', 'Qty', 'Unit', 'Price', 'Total'];
    return pw.Table(
      columnWidths: {
        0: const pw.FlexColumnWidth(4),
        1: const pw.FlexColumnWidth(1),
        2: const pw.FlexColumnWidth(1.5),
        3: const pw.FlexColumnWidth(2),
        4: const pw.FlexColumnWidth(2),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: PdfColors.black, width: 1.5),
            ),
          ),
          children: headers
              .map(
                (h) => pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 8),
                  child: pw.Text(
                    h,
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        for (final cat in quote.categories)
          for (final item in cat.items)
          pw.TableRow(
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
              ),
            ),
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 8),
                child: pw.Text(
                  item.name,
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 8),
                child: pw.Text(
                  item.qty.toStringAsFixed(0),
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 8),
                child: pw.Text(
                  item.unit,
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 8),
                child: pw.Text(
                  fmt.format(item.unitPrice),
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 8),
                child: pw.Text(
                  fmt.format(item.total),
                  style: const pw.TextStyle(fontSize: 10),
                  textAlign: pw.TextAlign.right,
                ),
              ),
            ],
          ),
        pw.TableRow(
          children: [
            pw.SizedBox(height: 10),
            pw.SizedBox(),
            pw.SizedBox(),
            pw.SizedBox(),
            pw.SizedBox(),
          ],
        ),

        pw.TableRow(
          children: [
            pw.SizedBox(),
            pw.SizedBox(),
            pw.SizedBox(),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 4),
              child: pw.Text(
                'Subtotal:',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 4),
              child: pw.Text(
                fmt.format(quote.subtotal),
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.right,
              ),
            ),
          ],
        ),
        if (quote.categoryLabourCost > 0)
          pw.TableRow(
            children: [
              pw.SizedBox(),
              pw.SizedBox(),
              pw.SizedBox(),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 4),
                child: pw.Text(
                  'Category Labour/Markup:',
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey700,
                  ),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 4),
                child: pw.Text(
                  fmt.format(quote.categoryLabourCost),
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey700,
                  ),
                  textAlign: pw.TextAlign.right,
                ),
              ),
            ],
          ),
        if (quote.labourCost > 0)
          pw.TableRow(
            children: [
              pw.SizedBox(),
              pw.SizedBox(),
              pw.SizedBox(),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 4),
                child: pw.Text(
                  'Labour:',
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey700,
                  ),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 4),
                child: pw.Text(
                  fmt.format(quote.labourCost),
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey700,
                  ),
                  textAlign: pw.TextAlign.right,
                ),
              ),
            ],
          ),
        if (quote.tax > 0)
          pw.TableRow(
            children: [
              pw.SizedBox(),
              pw.SizedBox(),
              pw.SizedBox(),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 4),
                child: pw.Text(
                  'VAT (${quote.vatPercent.toStringAsFixed(quote.vatPercent == quote.vatPercent.truncateToDouble() ? 0 : 1)}%):',
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey700,
                  ),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 4),
                child: pw.Text(
                  fmt.format(quote.tax),
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey700,
                  ),
                  textAlign: pw.TextAlign.right,
                ),
              ),
            ],
          ),
        pw.TableRow(
          children: [
            pw.SizedBox(),
            pw.SizedBox(),
            pw.SizedBox(),
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 8),
              child: pw.Text(
                'Total:',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 8),
              child: pw.Text(
                fmt.format(quote.total),
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#1a237e'),
                ),
                textAlign: pw.TextAlign.right,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Signed PDF generation ────────────────────────────────────────────────

  // ── Signed PDF generation ────────────────────────────────────────────────

  /// Generates a signed quote PDF: original content + signature certificate page.
  static Future<Uint8List> generateSignedQuotePdf(
    Quote quote,
    AppState state,
    Uint8List signatureImageBytes, [
    DateTime? signedAt,
  ]) async {
    quote.signatureData = base64Encode(signatureImageBytes);
    if (signedAt != null) quote.signedAt = signedAt;
    return generateQuotePdf(quote, state, appendCertificate: true);
  }

  /// Generates a signed invoice PDF: original content + signature certificate page.
  static Future<Uint8List> generateSignedInvoicePdf(
    Invoice invoice,
    AppState state,
    Uint8List signatureImageBytes, [
    DateTime? signedAt,
  ]) async {
    invoice.signatureData = base64Encode(signatureImageBytes);
    if (signedAt != null) invoice.signedAt = signedAt;
    return generateInvoicePdf(invoice, state, appendCertificate: true);
  }

  static Uint8List? _safeDecodeBase64(String str) {
    try {
      final clean = str.contains(',') ? str.split(',').last : str;
      return base64Decode(clean.trim());
    } catch (_) {
      return null;
    }
  }

  static pw.Widget _buildQuoteSignatureBox(Quote quote) {
    final sigBytes = quote.signatureData != null && quote.signatureData!.isNotEmpty
        ? _safeDecodeBase64(quote.signatureData!)
        : null;

    if (sigBytes != null) {
      final signedDateStr = quote.signedAt != null
          ? DateFormat('dd/MM/yyyy HH:mm').format(quote.signedAt!)
          : DateFormat('dd/MM/yyyy').format(DateTime.now());

      return pw.Container(
        width: 230,
        padding: const pw.EdgeInsets.all(6),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColor.fromHex('#1E2733'), width: 1),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'CLIENT ACCEPTANCE',
                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1E2733')),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.green100,
                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(2)),
                  ),
                  child: pw.Text(
                    'VERIFIED SIGNED',
                    style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.green900),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 3),
            pw.Container(
              height: 44,
              width: 218,
              alignment: pw.Alignment.centerLeft,
              child: pw.Image(
                pw.MemoryImage(sigBytes),
                fit: pw.BoxFit.contain,
              ),
            ),
            pw.Divider(color: PdfColors.grey400, thickness: 0.5),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  quote.signerInfo != null && quote.signerInfo!.name.isNotEmpty
                      ? '${quote.signerInfo!.name} • ${quote.signerInfo!.phone}'
                      : (quote.clientName.isEmpty ? 'Client Signature' : quote.clientName),
                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  signedDateStr,
                  style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return pw.Container(
      width: 230,
      padding: const pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 0.8),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'CLIENT ACCEPTANCE & SIGNATURE',
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 28),
          pw.Divider(color: PdfColors.grey400, thickness: 0.5),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Sign: __________________', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
              pw.Text('Date: ___________', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildInvoiceSignatureBox(String clientName, String? signatureData, DateTime? signedAt) {
    final sigBytes = signatureData != null && signatureData.isNotEmpty
        ? _safeDecodeBase64(signatureData)
        : null;

    if (sigBytes != null) {
      final signedDateStr = signedAt != null
          ? DateFormat('dd/MM/yyyy HH:mm').format(signedAt)
          : DateFormat('dd/MM/yyyy').format(DateTime.now());

      return pw.Container(
        width: 230,
        padding: const pw.EdgeInsets.all(6),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColor.fromHex('#1E2733'), width: 1),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'CLIENT APPROVAL',
                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1E2733')),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.green100,
                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(2)),
                  ),
                  child: pw.Text(
                    'VERIFIED SIGNED',
                    style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.green900),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 3),
            pw.Container(
              height: 44,
              width: 218,
              alignment: pw.Alignment.centerLeft,
              child: pw.Image(
                pw.MemoryImage(sigBytes),
                fit: pw.BoxFit.contain,
              ),
            ),
            pw.Divider(color: PdfColors.grey400, thickness: 0.5),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  clientName.isEmpty ? 'Client' : clientName,
                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  signedDateStr,
                  style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return pw.Container(
      width: 230,
      padding: const pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 0.8),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'CLIENT APPROVAL & SIGNATURE',
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 28),
          pw.Divider(color: PdfColors.grey400, thickness: 0.5),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Sign: __________________', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
              pw.Text('Date: ___________', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Page _buildCertificatePage({
    required String docId,
    required String docType,
    required String clientName,
    required String signedDate,
    required pw.ImageProvider sigImage,
    required PdfColor goldColor,
    SignerInfo? signer,
  }) {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(48),
      build: (ctx) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(20),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#1E2733'),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'SIGNED DOCUMENT CERTIFICATE',
                    style: pw.TextStyle(
                      color: goldColor,
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Row(children: [
                    pw.Text('Document Type: ',
                        style: const pw.TextStyle(color: PdfColors.grey300, fontSize: 11)),
                    pw.Text(docType,
                        style: pw.TextStyle(color: PdfColors.white, fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  ]),
                  pw.Row(children: [
                    pw.Text('Document ID: ',
                        style: const pw.TextStyle(color: PdfColors.grey300, fontSize: 11)),
                    pw.Text(docId,
                        style: pw.TextStyle(color: PdfColors.white, fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  ]),
                  pw.Row(children: [
                    pw.Text('Client: ',
                        style: const pw.TextStyle(color: PdfColors.grey300, fontSize: 11)),
                    pw.Text(clientName,
                        style: pw.TextStyle(color: PdfColors.white, fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  ]),
                  pw.Row(children: [
                    pw.Text('Signed on: ',
                        style: const pw.TextStyle(color: PdfColors.grey300, fontSize: 11)),
                    pw.Text(signedDate,
                        style: pw.TextStyle(color: goldColor, fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  ]),
                ],
              ),
            ),
            pw.SizedBox(height: 36),

            // Signature block
            pw.Text(
              'Client Signature',
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey800,
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Container(
              width: 320,
              height: 140,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey500),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                color: PdfColors.white,
              ),
              child: pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Image(sigImage, fit: pw.BoxFit.contain),
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Container(
              width: 320,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Divider(color: PdfColors.grey500, thickness: 0.5),
                  pw.Text(clientName,
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                  pw.Text('Date: $signedDate',
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                ],
              ),
            ),
            if (signer != null) ...[
              pw.SizedBox(height: 24),
              pw.Text('Signer Verification Details',
                  style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
              pw.SizedBox(height: 8),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                columnWidths: const {0: pw.FixedColumnWidth(120), 1: pw.FlexColumnWidth()},
                children: [
                  for (final row in signer.evidenceRows)
                    pw.TableRow(children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(row.key, style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(row.value, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                      ),
                    ]),
                ],
              ),
            ],
            pw.SizedBox(height: 40),

            // Legal notice
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Text(
                'This document has been digitally reviewed and approved by $clientName on $signedDate. '
                'The signature above constitutes binding acceptance of the terms and conditions '
                'contained in $docType $docId. This certificate serves as proof of agreement.',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
              ),
            ),
          ],
        );
      },
    );
  }
}

