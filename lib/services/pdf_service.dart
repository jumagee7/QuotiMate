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
  /// Decodes a base64 photo (raw data or a data: URI) into a PDF image.
  /// Returns null for empty or corrupt data so a single bad photo can't abort
  /// the whole export.
  static pw.MemoryImage? _imageFromBase64(String data) {
    final raw = data.contains(',') ? data.substring(data.indexOf(',') + 1) : data;
    if (raw.trim().isEmpty) return null;
    try {
      final bytes = base64Decode(raw.trim());
      if (bytes.isEmpty) return null;
      return pw.MemoryImage(bytes);
    } catch (_) {
      return null;
    }
  }

  static Future<Uint8List> generateQuotePdf(
    Quote quote,
    AppState state, {
    bool appendCertificate = false,
  }) async {
    if (state.pdfTemplate == 'minimalist') {
      return _generateMinimalistPdf(quote, state, appendCertificate: appendCertificate);
    }
    return _generateModernEdgePdf(quote, state, appendCertificate: appendCertificate);
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
      signerMeta: invoice.signerMetadata,
      appendCertificate: appendCertificate,
    );
  }

  static Future<Uint8List> _generateModernEdgePdf(
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
    final goldColor = PdfColor.fromHex('#E7C67B'); // Gold text

    pw.MemoryImage? logoImage;
    try {
      final logoBytes = await rootBundle.load('assets/logo.png');
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
                                  'MODERN EDGE',
                                  style: pw.TextStyle(
                                    color: goldColor,
                                    fontSize: 22,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                                pw.SizedBox(height: 2),
                                pw.Text(
                                  'Modern Solutions, Edge Designs',
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
                                    'MODERN EDGE',
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
            evidence: quote.signerMetadata.rows,
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
    bool appendCertificate = false,
    SignatureMetadata? signerMeta,
  }) async {
    if (state.pdfTemplate == 'minimalist') {
      return _generateMinimalistInvoicePdf(
        state: state, customerName: customerName, kraPin: kraPin,
        quotationNo: quotationNo, date: date, agreedTotal: agreedTotal,
        categories: categories, signatureData: signatureData,
        signedAt: signedAt, appendCertificate: appendCertificate,
        signerMeta: signerMeta,
        terms: terms, preparedBy: preparedBy,
      );
    }
    return _generateModernEdgeEnquiryInvoicePdf(
      state: state,
      customerName: customerName,
      telephone: telephone,
      kraPin: kraPin,
      quotationNo: quotationNo,
      date: date,
      agreedTotal: agreedTotal,
      depositPct: depositPct,
      midPct: midPct,
      completionPct: completionPct,
      requestLabel: requestLabel,
      requestAmount: requestAmount,
      nb: nb,
      preparedBy: preparedBy,
      terms: terms,
      categories: categories,
      signatureData: signatureData,
      signedAt: signedAt,
      appendCertificate: appendCertificate,
      signerMeta: signerMeta,
    );
  }

  static Future<Uint8List> _generateModernEdgeEnquiryInvoicePdf({
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
    bool appendCertificate = false,
    SignatureMetadata? signerMeta,
  }) async {
    final pdf = pw.Document();

    final dateStr = DateFormat('dd/MM/yyyy').format(date);
    final fmt = NumberFormat.currency(symbol: '${state.currency} ', decimalDigits: 0);
    final goldColor = PdfColor.fromHex('#E7C67B');
    final darkHeader = PdfColor.fromHex('#1E2733');
    final grandTotal = requestAmount > 0 ? requestAmount : agreedTotal;

    pw.MemoryImage? logoImage;
    try {
      final logoBytes = await rootBundle.load('assets/logo.png');
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
                                  'MODERN EDGE',
                                  style: pw.TextStyle(
                                    color: goldColor,
                                    fontSize: 20,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                                pw.SizedBox(height: 2),
                                pw.Text(
                                  'Modern Solutions, Edge Designs',
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
                                    'MODERN EDGE',
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
            evidence: signerMeta?.rows ?? const [],
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
            evidence: quote.signerMetadata.rows,
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
                  quote.clientName.isEmpty ? 'Client Signature' : quote.clientName,
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
    List<MapEntry<String, String>> evidence = const [],
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
            pw.SizedBox(height: 40),

            if (evidence.isNotEmpty) ...[
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey50,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  border: pw.Border.all(color: goldColor, width: 0.8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'SIGNING EVIDENCE',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey800,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    for (final row in evidence)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 2),
                        child: pw.Row(children: [
                          pw.SizedBox(
                            width: 110,
                            child: pw.Text(row.key,
                                style: const pw.TextStyle(
                                    fontSize: 8, color: PdfColors.grey600)),
                          ),
                          pw.Expanded(
                            child: pw.Text(row.value,
                                style: pw.TextStyle(
                                    fontSize: 8, fontWeight: pw.FontWeight.bold)),
                          ),
                        ]),
                      ),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),
            ],

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

  // ── Project Financial Statement PDF ────────────────────────────────────────

  static Future<Uint8List> generateProjectFinancialStatementPdf({
    required AppState appState,
    required Project project,
    required List<Quote> quotes,
    required List<Invoice> invoices,
  }) async {
    if (appState.pdfTemplate == 'minimalist') {
      return _generateMinimalistStatementPdf(
        appState: appState, project: project,
        quotes: quotes, invoices: invoices,
      );
    }
    return _generateModernEdgeStatementPdf(
      appState: appState, project: project,
      quotes: quotes, invoices: invoices,
    );
  }

  static Future<Uint8List> _generateModernEdgeStatementPdf({
    required AppState appState,
    required Project project,
    required List<Quote> quotes,
    required List<Invoice> invoices,
  }) async {
    final pdf = pw.Document();
    final fmt = NumberFormat.currency(symbol: '${appState.currency} ', decimalDigits: 2);
    final dateFmt = DateFormat('dd/MM/yyyy');
    final goldColor = PdfColor.fromHex('#FFC107');
    final greenColor = PdfColor.fromHex('#10B981');
    final redColor = PdfColor.fromHex('#EF4444');
    final blueColor = PdfColor.fromHex('#3B82F6');
    final darkBg = PdfColor.fromHex('#0F162C');
    final surfaceBg = PdfColor.fromHex('#1A2035');

    final totalQuoted = project.totalQuoted(quotes);
    final totalInvoiced = project.totalInvoiced(invoices);
    final totalPaid = project.totalPaymentsReceived;
    final totalExpenses = project.totalExpenses;
    final netProfit = project.netProfitRealized();
    final balance = project.outstandingBalance(invoices, quotes);
    final isProfit = netProfit >= 0;

    pw.MemoryImage? logoImage;
    try {
      final logoBytes = await rootBundle.load('assets/logo.png');
      logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (_) {}

    pw.Widget sRow(String label, String value, PdfColor color, {bool bold = false}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label,
                style: pw.TextStyle(
                  fontSize: bold ? 10 : 9,
                  fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                  color: bold ? PdfColors.white : PdfColors.grey400,
                )),
            pw.Text(value,
                style: pw.TextStyle(
                  fontSize: bold ? 11 : 9,
                  fontWeight: pw.FontWeight.bold,
                  color: color,
                )),
          ],
        ),
      );
    }

    pw.Widget sectionTitle(String text, PdfColor color) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 8),
          child: pw.Text(text,
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: color,
                letterSpacing: 1,
              )),
        );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        footer: (pw.Context ctx) => pw.Container(
          alignment: pw.Alignment.center,
          margin: const pw.EdgeInsets.only(top: 8),
          child: pw.Text(
            'Page ${ctx.pageNumber} of ${ctx.pagesCount} • Generated ${DateFormat('dd MMM yyyy HH:mm').format(DateTime.now())}',
            style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 7),
          ),
        ),
        build: (pw.Context ctx) {
          return [
            // ── Header ────────────────────────────────────────────────────
            pw.Container(
              padding: const pw.EdgeInsets.all(20),
              color: PdfColor.fromHex('#1E2733'),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (logoImage != null)
                    pw.Container(
                      width: 70,
                      height: 70,
                      child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                    )
                  else
                    pw.Container(width: 70, height: 70),
                  pw.SizedBox(width: 16),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(appState.companyName,
                            style: pw.TextStyle(
                              color: goldColor,
                              fontSize: 18,
                              fontWeight: pw.FontWeight.bold,
                            )),
                        pw.SizedBox(height: 4),
                        pw.Text(appState.companyAddress,
                            style: const pw.TextStyle(color: PdfColors.grey400, fontSize: 9)),
                        pw.Text('${appState.companyPhone}  •  ${appState.companyEmail}',
                            style: const pw.TextStyle(color: PdfColors.grey400, fontSize: 9)),
                      ],
                    ),
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('PROJECT FINANCIAL STATEMENT',
                          style: pw.TextStyle(
                            color: goldColor,
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            letterSpacing: 1,
                          )),
                      pw.SizedBox(height: 6),
                      pw.Text('Date: ${dateFmt.format(DateTime.now())}',
                          style: const pw.TextStyle(color: PdfColors.grey400, fontSize: 9)),
                      if (project.deadline != null)
                        pw.Text('Deadline: ${dateFmt.format(project.deadline!)}',
                            style: const pw.TextStyle(color: PdfColors.grey400, fontSize: 9)),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // ── Project Info ───────────────────────────────────────────────
            pw.Container(
              padding: const pw.EdgeInsets.all(14),
              color: surfaceBg,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    children: [
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('PROJECT', style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 8)),
                            pw.SizedBox(height: 2),
                            pw.Text(project.name,
                                style: pw.TextStyle(
                                  color: PdfColors.white,
                                  fontSize: 14,
                                  fontWeight: pw.FontWeight.bold,
                                )),
                          ],
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('CLIENT', style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 8)),
                            pw.SizedBox(height: 2),
                            pw.Text(project.clientName,
                                style: const pw.TextStyle(color: PdfColors.white, fontSize: 11)),
                          ],
                        ),
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text('STATUS', style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 8)),
                          pw.SizedBox(height: 2),
                          pw.Text(project.status.label,
                              style: const pw.TextStyle(color: PdfColors.white, fontSize: 11)),
                          pw.SizedBox(height: 4),
                          pw.Text('Start: ${dateFmt.format(project.startDate)}',
                              style: const pw.TextStyle(color: PdfColors.grey400, fontSize: 9)),
                        ],
                      ),
                    ],
                  ),
                  if (project.location.isNotEmpty) ...[
                    pw.SizedBox(height: 8),
                    pw.Text('Location: ${project.location}',
                        style: const pw.TextStyle(color: PdfColors.grey400, fontSize: 9)),
                  ],
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // ── Financial Summary ──────────────────────────────────────────
            pw.Container(
              padding: const pw.EdgeInsets.all(14),
              color: surfaceBg,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  sectionTitle('FINANCIAL SUMMARY', goldColor),
                  pw.Divider(color: PdfColors.grey700, height: 1),
                  pw.SizedBox(height: 8),
                  sRow('Total Quoted Value', fmt.format(totalQuoted), blueColor),
                  sRow('Total Invoiced Value', fmt.format(totalInvoiced), PdfColors.white),
                  sRow('Total Payments Received (Income)', fmt.format(totalPaid), greenColor),
                  sRow('Total Expenses & Materials (Costs)', fmt.format(totalExpenses), goldColor),
                  pw.SizedBox(height: 8),
                  pw.Divider(color: PdfColors.grey700, height: 1),
                  pw.SizedBox(height: 8),
                  sRow(
                    'Net Profit Realized',
                    fmt.format(netProfit),
                    isProfit ? greenColor : redColor,
                    bold: true,
                  ),
                  sRow(
                    'Client Outstanding Balance',
                    fmt.format(balance),
                    balance > 0 ? PdfColors.orange : greenColor,
                    bold: true,
                  ),
                  if (project.budget > 0) ...[
                    pw.SizedBox(height: 4),
                    sRow('Estimated Budget', fmt.format(project.budget), PdfColors.grey400),
                    sRow(
                      totalExpenses > project.budget ? 'Budget Overrun' : 'Budget Remaining',
                      fmt.format((project.budget - totalExpenses).abs()),
                      totalExpenses > project.budget ? redColor : greenColor,
                    ),
                  ],
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // ── Income Log ─────────────────────────────────────────────────
            if (project.payments.isNotEmpty) ...[
              pw.Container(
                padding: const pw.EdgeInsets.all(14),
                color: surfaceBg,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    sectionTitle('INCOME / PAYMENTS LOG', greenColor),
                    pw.Divider(color: PdfColors.grey700, height: 1),
                    pw.SizedBox(height: 8),
                    pw.Table(
                      columnWidths: {
                        0: const pw.FlexColumnWidth(2),
                        1: const pw.FlexColumnWidth(2),
                        2: const pw.FlexColumnWidth(2),
                        3: const pw.FlexColumnWidth(2),
                      },
                      children: [
                        pw.TableRow(
                          decoration: const pw.BoxDecoration(color: PdfColors.grey800),
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(5),
                              child: pw.Text('Date', style: pw.TextStyle(color: PdfColors.white, fontSize: 8, fontWeight: pw.FontWeight.bold)),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(5),
                              child: pw.Text('Method', style: pw.TextStyle(color: PdfColors.white, fontSize: 8, fontWeight: pw.FontWeight.bold)),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(5),
                              child: pw.Text('Reference', style: pw.TextStyle(color: PdfColors.white, fontSize: 8, fontWeight: pw.FontWeight.bold)),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(5),
                              child: pw.Text('Amount', textAlign: pw.TextAlign.right, style: pw.TextStyle(color: PdfColors.white, fontSize: 8, fontWeight: pw.FontWeight.bold)),
                            ),
                          ],
                        ),
                        ...project.payments.map((p) => pw.TableRow(
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(5),
                              child: pw.Text(dateFmt.format(p.date), style: const pw.TextStyle(color: PdfColors.grey300, fontSize: 8)),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(5),
                              child: pw.Text(p.paymentMethod, style: const pw.TextStyle(color: PdfColors.grey300, fontSize: 8)),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(5),
                              child: pw.Text(p.reference.isEmpty ? '—' : p.reference, style: const pw.TextStyle(color: PdfColors.grey300, fontSize: 8)),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(5),
                              child: pw.Text(fmt.format(p.amount), textAlign: pw.TextAlign.right, style: pw.TextStyle(color: greenColor, fontSize: 8, fontWeight: pw.FontWeight.bold)),
                            ),
                          ],
                        )),
                        pw.TableRow(
                          decoration: const pw.BoxDecoration(color: PdfColors.grey900),
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(5),
                              child: pw.Text('TOTAL', style: pw.TextStyle(color: PdfColors.white, fontSize: 8, fontWeight: pw.FontWeight.bold)),
                            ),
                            pw.Container(),
                            pw.Container(),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(5),
                              child: pw.Text(fmt.format(totalPaid), textAlign: pw.TextAlign.right,
                                  style: pw.TextStyle(color: greenColor, fontSize: 9, fontWeight: pw.FontWeight.bold)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),
            ],

            // ── Expenses Log ───────────────────────────────────────────────
            if (project.expenses.isNotEmpty) ...[
              pw.Container(
                padding: const pw.EdgeInsets.all(14),
                color: surfaceBg,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    sectionTitle('BOUGHT PRODUCTS & EXPENSES LOG', goldColor),
                    pw.Divider(color: PdfColors.grey700, height: 1),
                    pw.SizedBox(height: 8),
                    pw.Table(
                      columnWidths: {
                        0: const pw.FlexColumnWidth(3),
                        1: const pw.FlexColumnWidth(2),
                        2: const pw.FlexColumnWidth(2),
                        3: const pw.FlexColumnWidth(2),
                      },
                      children: [
                        pw.TableRow(
                          decoration: const pw.BoxDecoration(color: PdfColors.grey800),
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(5),
                              child: pw.Text('Item', style: pw.TextStyle(color: PdfColors.white, fontSize: 8, fontWeight: pw.FontWeight.bold)),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(5),
                              child: pw.Text('Category', style: pw.TextStyle(color: PdfColors.white, fontSize: 8, fontWeight: pw.FontWeight.bold)),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(5),
                              child: pw.Text('Date', style: pw.TextStyle(color: PdfColors.white, fontSize: 8, fontWeight: pw.FontWeight.bold)),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(5),
                              child: pw.Text('Amount', textAlign: pw.TextAlign.right, style: pw.TextStyle(color: PdfColors.white, fontSize: 8, fontWeight: pw.FontWeight.bold)),
                            ),
                          ],
                        ),
                        ...project.expenses.map((e) => pw.TableRow(
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(5),
                              child: pw.Text(e.title, style: const pw.TextStyle(color: PdfColors.grey300, fontSize: 8)),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(5),
                              child: pw.Text(e.category, style: const pw.TextStyle(color: PdfColors.grey300, fontSize: 8)),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(5),
                              child: pw.Text(dateFmt.format(e.date), style: const pw.TextStyle(color: PdfColors.grey300, fontSize: 8)),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(5),
                              child: pw.Text(fmt.format(e.amount), textAlign: pw.TextAlign.right,
                                  style: pw.TextStyle(color: goldColor, fontSize: 8, fontWeight: pw.FontWeight.bold)),
                            ),
                          ],
                        )),
                        pw.TableRow(
                          decoration: const pw.BoxDecoration(color: PdfColors.grey900),
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(5),
                              child: pw.Text('TOTAL', style: pw.TextStyle(color: PdfColors.white, fontSize: 8, fontWeight: pw.FontWeight.bold)),
                            ),
                            pw.Container(),
                            pw.Container(),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(5),
                              child: pw.Text(fmt.format(totalExpenses), textAlign: pw.TextAlign.right,
                                  style: pw.TextStyle(color: goldColor, fontSize: 9, fontWeight: pw.FontWeight.bold)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),
            ],

            // ── Footer ─────────────────────────────────────────────────────
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              color: darkBg,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Prepared by: ${appState.preparedBy}',
                      style: const pw.TextStyle(color: PdfColors.grey400, fontSize: 8)),
                  pw.Text('${appState.companyName}  •  ${appState.companyPhone}',
                      style: const pw.TextStyle(color: PdfColors.grey400, fontSize: 8)),
                ],
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  // ── Minimalist Invoice PDF ─────────────────────────────────────────────────

  static Future<Uint8List> _generateMinimalistInvoicePdf({
    required AppState state,
    required String customerName,
    required String kraPin,
    required String quotationNo,
    required DateTime date,
    required double agreedTotal,
    required List<QuoteCategory> categories,
    String? signatureData,
    DateTime? signedAt,
    bool appendCertificate = false,
    SignatureMetadata? signerMeta,
    String terms = '',
    String preparedBy = '',
  }) async {
    final pdf = pw.Document();
    final fmt = NumberFormat.currency(symbol: '${state.currency} ', decimalDigits: 0);
    final dateStr = DateFormat('dd/MM/yyyy').format(date);

    // Build item rows
    final List<pw.TableRow> itemRows = [];
    for (final cat in categories) {
      if (cat.items.isEmpty) continue;
      if (cat.name.trim().isNotEmpty) {
        itemRows.add(pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              child: pw.Text(cat.name.toUpperCase(),
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Container(), pw.Container(), pw.Container(), pw.Container(),
          ],
        ));
      }
      for (final item in cat.items) {
        itemRows.add(pw.TableRow(
          decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5))),
          children: [
            _mCell(item.name),
            _mCell(item.qty.toStringAsFixed(0), align: pw.Alignment.centerRight),
            _mCell(item.unit),
            _mCell(fmt.format(item.unitPrice), align: pw.Alignment.centerRight),
            _mCell(fmt.format(item.total), align: pw.Alignment.centerRight),
          ],
        ));
      }
    }

    // Signature block
    pw.Widget? sigWidget;
    if (signatureData != null && signatureData.isNotEmpty) {
      final sigBytes = _safeDecodeBase64(signatureData);
      if (sigBytes != null) {
        final sigDateStr = signedAt != null
            ? DateFormat('dd MMM yyyy').format(signedAt)
            : DateFormat('dd MMM yyyy').format(DateTime.now());
        sigWidget = pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Client Signature',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.Container(
              width: 200, height: 70, color: PdfColors.white,
              child: pw.Image(pw.MemoryImage(sigBytes), fit: pw.BoxFit.contain),
            ),
            pw.Divider(color: PdfColors.grey400, thickness: 0.5),
            pw.Text(customerName,
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
            pw.Text('Signed: $sigDateStr',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
          ],
        );
      }
    }

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      footer: (pw.Context ctx) => pw.Container(
        alignment: pw.Alignment.center,
        margin: const pw.EdgeInsets.only(top: 8),
        child: pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
            style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 8)),
      ),
      build: (pw.Context ctx) => [
        // Header
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(state.companyName,
                    style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 3),
                if (state.companyAddress.isNotEmpty)
                  pw.Text(state.companyAddress,
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                pw.Text(state.companyPhone,
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                pw.Text(state.companyEmail,
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('INVOICE',
                    style: pw.TextStyle(
                        fontSize: 26, fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey300)),
                pw.Text('#$quotationNo',
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.Text('Date: $dateStr',
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 24),

        // Bill To
        pw.Text('Bill To:',
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey600)),
        pw.SizedBox(height: 3),
        pw.Text(customerName.isEmpty ? 'Valued Customer' : customerName,
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
        if (kraPin.isNotEmpty) ...[
          pw.SizedBox(height: 2),
          pw.Text('KRA PIN: $kraPin',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
        ],
        pw.SizedBox(height: 20),

        // Items table
        pw.Table(
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
                  border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 1.2))),
              children: ['Description', 'Qty', 'Unit', 'Price', 'Total']
                  .map((h) => pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 7),
                        child: pw.Text(h,
                            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      ))
                  .toList(),
            ),
            ...itemRows,
          ],
        ),
        pw.SizedBox(height: 16),

        // Total
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Container(
              width: 200,
              child: pw.Column(
                children: [
                  pw.Divider(color: PdfColors.black, thickness: 0.8),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('TOTAL AMOUNT',
                          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      pw.Text(fmt.format(agreedTotal),
                          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 30),

        // Terms + signature
        pw.Divider(color: PdfColors.grey300),
        pw.SizedBox(height: 10),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (terms.isNotEmpty) ...[
                    pw.Text('Terms & Conditions',
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    ...terms.split('\n').map((l) => pw.Text(l.trim(),
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700))),
                  ],
                  pw.SizedBox(height: 6),
                  if (preparedBy.isNotEmpty)
                    pw.Text('Prepared by: $preparedBy',
                        style: pw.TextStyle(
                            fontSize: 8, fontStyle: pw.FontStyle.italic,
                            color: PdfColors.grey600)),
                ],
              ),
            ),
            if (sigWidget != null) ...[
              pw.SizedBox(width: 20),
              sigWidget,
            ],
          ],
        ),
      ],
    ));

    if (appendCertificate && signatureData != null && signatureData.isNotEmpty) {
      final sigBytes = _safeDecodeBase64(signatureData);
      if (sigBytes != null) {
        final signedDate = signedAt != null
            ? DateFormat('dd MMM yyyy, HH:mm').format(signedAt)
            : DateFormat('dd MMM yyyy, HH:mm').format(DateTime.now());
        pdf.addPage(_buildCertificatePage(
          docId: quotationNo,
          docType: 'Invoice',
          clientName: customerName.isEmpty ? 'Valued Customer' : customerName,
          signedDate: signedDate,
          sigImage: pw.MemoryImage(sigBytes),
          goldColor: PdfColor.fromHex('#E7C67B'),
          evidence: signerMeta?.rows ?? const [],
        ));
      }
    }

    return pdf.save();
  }

  // ── Minimalist Project Statement PDF ──────────────────────────────────────

  static Future<Uint8List> _generateMinimalistStatementPdf({
    required AppState appState,
    required Project project,
    required List<Quote> quotes,
    required List<Invoice> invoices,
  }) async {
    final pdf = pw.Document();
    final fmt = NumberFormat.currency(symbol: '${appState.currency} ', decimalDigits: 2);
    final dateFmt = DateFormat('dd/MM/yyyy');

    final totalQuoted   = project.totalQuoted(quotes);
    final totalInvoiced = project.totalInvoiced(invoices);
    final totalPaid     = project.totalPaymentsReceived;
    final totalExpenses = project.totalExpenses;
    final netProfit     = project.netProfitRealized();
    final balance       = project.outstandingBalance(invoices, quotes);
    final isProfit      = netProfit >= 0;

    pw.Widget sRow(String label, String value, {bool bold = false, bool positive = true}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 3),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(label,
                  style: pw.TextStyle(
                    fontSize: bold ? 10 : 9,
                    fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                    color: bold ? PdfColors.black : PdfColors.grey700,
                  )),
              pw.Text(value,
                  style: pw.TextStyle(
                    fontSize: bold ? 11 : 9,
                    fontWeight: pw.FontWeight.bold,
                    color: bold
                        ? (positive ? PdfColors.green800 : PdfColors.red700)
                        : PdfColors.black,
                  )),
            ],
          ),
        );

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      footer: (pw.Context ctx) => pw.Container(
        alignment: pw.Alignment.center,
        margin: const pw.EdgeInsets.only(top: 8),
        child: pw.Text(
          'Page ${ctx.pageNumber} of ${ctx.pagesCount}  •  Generated ${DateFormat('dd MMM yyyy').format(DateTime.now())}',
          style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 7),
        ),
      ),
      build: (pw.Context ctx) => [
        // Header
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(appState.companyName,
                  style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 2),
              pw.Text(appState.companyAddress,
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
              pw.Text(appState.companyPhone,
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
            ]),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text('PROJECT STATEMENT',
                  style: pw.TextStyle(
                      fontSize: 20, fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey300)),
              pw.Text('Generated: ${dateFmt.format(DateTime.now())}',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
            ]),
          ],
        ),
        pw.SizedBox(height: 20),
        pw.Divider(color: PdfColors.black, thickness: 1),
        pw.SizedBox(height: 10),

        // Project details
        pw.Row(children: [
          pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('PROJECT', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
            pw.Text(project.name,
                style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
            pw.Text('No. ${project.numberLabel}',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          ])),
          pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('CLIENT', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
            pw.Text(project.clientName,
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          ])),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text('STATUS', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
            pw.Text(project.status.label,
                style: const pw.TextStyle(fontSize: 10)),
            pw.SizedBox(height: 2),
            pw.Text('Start: ${dateFmt.format(project.startDate)}',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
            if (project.deadline != null)
              pw.Text('Deadline: ${dateFmt.format(project.deadline!)}',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          ]),
        ]),
        pw.SizedBox(height: 20),

        // Financial Summary
        pw.Text('FINANCIAL SUMMARY',
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))),
          child: pw.Column(children: [
            sRow('Total Quoted Value', fmt.format(totalQuoted)),
            sRow('Total Invoiced Value', fmt.format(totalInvoiced)),
            sRow('Total Payments Received', fmt.format(totalPaid)),
            sRow('Total Expenses & Materials', fmt.format(totalExpenses)),
            pw.Divider(color: PdfColors.grey300, height: 12),
            sRow('Net Profit Realized', fmt.format(netProfit),
                bold: true, positive: isProfit),
            sRow('Client Outstanding Balance', fmt.format(balance),
                bold: true, positive: balance <= 0),
            if (project.budget > 0)
              sRow('Estimated Budget', fmt.format(project.budget)),
          ]),
        ),
        pw.SizedBox(height: 20),

        // Payments log
        if (project.payments.isNotEmpty) ...[
          pw.Text('INCOME / PAYMENTS',
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Table(
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FlexColumnWidth(2),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.8))),
                children: ['Date', 'Method', 'Reference', 'Amount'].map((h) =>
                  pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 5),
                    child: pw.Text(h, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)))).toList(),
              ),
              ...project.payments.map((p) => pw.TableRow(
                decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5))),
                children: [
                  _mCell(dateFmt.format(p.date), size: 8),
                  _mCell(p.paymentMethod, size: 8),
                  _mCell(p.reference.isEmpty ? '—' : p.reference, size: 8),
                  _mCell(fmt.format(p.amount), align: pw.Alignment.centerRight, size: 8),
                ],
              )),
              pw.TableRow(children: [
                pw.Container(),
                pw.Container(),
                pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 4),
                  child: pw.Text('TOTAL', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 4),
                  child: pw.Align(alignment: pw.Alignment.centerRight,
                    child: pw.Text(fmt.format(totalPaid),
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)))),
              ]),
            ],
          ),
          pw.SizedBox(height: 20),
        ],

        // Expenses log
        if (project.expenses.isNotEmpty) ...[
          pw.Text('BOUGHT PRODUCTS & EXPENSES',
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Table(
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FlexColumnWidth(2),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.8))),
                children: ['Item', 'Category', 'Date', 'Amount'].map((h) =>
                  pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 5),
                    child: pw.Text(h, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)))).toList(),
              ),
              ...project.expenses.map((e) => pw.TableRow(
                decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5))),
                children: [
                  _mCell(e.title, size: 8),
                  _mCell(e.category, size: 8),
                  _mCell(dateFmt.format(e.date), size: 8),
                  _mCell(fmt.format(e.amount), align: pw.Alignment.centerRight, size: 8),
                ],
              )),
              pw.TableRow(children: [
                pw.Container(), pw.Container(),
                pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 4),
                  child: pw.Text('TOTAL', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 4),
                  child: pw.Align(alignment: pw.Alignment.centerRight,
                    child: pw.Text(fmt.format(totalExpenses),
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)))),
              ]),
            ],
          ),
          pw.SizedBox(height: 16),
        ],

        // Footer
        pw.Divider(color: PdfColors.grey300),
        pw.SizedBox(height: 6),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Prepared by: ${appState.preparedBy}',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
            pw.Text('${appState.companyName}  •  ${appState.companyPhone}',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          ],
        ),
      ],
    ));

    return pdf.save();
  }

  /// Shared minimalist cell helper
  static pw.Widget _mCell(String text,
      {pw.Alignment align = pw.Alignment.centerLeft, double size = 9}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      child: pw.Align(
        alignment: align,
        child: pw.Text(text, style: pw.TextStyle(fontSize: size, color: PdfColors.grey800)),
      ),
    );
  }

  // ── Full Project PDF (complete dossier) ────────────────────────────────────

  /// Generates a complete project PDF dossier containing:
  /// cover page, financial summary, all quote line items, invoice list,
  /// payments log, and expenses log. Respects the user's selected pdfTemplate.
  static Future<Uint8List> generateFullProjectPdf({
    required AppState appState,
    required Project project,
    required List<Quote> quotes,
    required List<Invoice> invoices,
  }) async {
    if (appState.pdfTemplate == 'minimalist') {
      return _generateMinimalistFullProjectPdf(
        appState: appState, project: project,
        quotes: quotes, invoices: invoices,
      );
    }
    return _generateModernEdgeFullProjectPdf(
      appState: appState, project: project,
      quotes: quotes, invoices: invoices,
    );
  }

  // ── Majuma Full Project PDF ─────────────────────────────────────────────────

  static Future<Uint8List> _generateModernEdgeFullProjectPdf({
    required AppState appState,
    required Project project,
    required List<Quote> quotes,
    required List<Invoice> invoices,
  }) async {
    final pdf = pw.Document();
    final fmt = NumberFormat.currency(symbol: '${appState.currency} ', decimalDigits: 2);
    final dateFmt = DateFormat('dd/MM/yyyy');
    final goldColor = PdfColor.fromHex('#FFC107');
    final greenColor = PdfColor.fromHex('#10B981');
    final redColor = PdfColor.fromHex('#EF4444');
    final blueColor = PdfColor.fromHex('#3B82F6');
    final darkBg = PdfColor.fromHex('#0F162C');
    final headerBg = PdfColor.fromHex('#1E2733');
    final surfaceBg = PdfColor.fromHex('#1A2035');

    final totalQuoted = project.totalQuoted(quotes);
    final totalInvoiced = project.totalInvoiced(invoices);
    final totalPaid = project.totalPaymentsReceived;
    final totalExpenses = project.totalExpenses;
    final netProfit = project.netProfitRealized();
    final balance = project.outstandingBalance(invoices, quotes);
    final isProfit = netProfit >= 0;

    final workflowCards = [...project.workflowNotes]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final siteImages = project.summaryImages
        .map(_imageFromBase64)
        .whereType<pw.MemoryImage>()
        .toList();
    final projectTasks = appState.tasksForProject(project.id)
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

    pw.MemoryImage? logoImage;
    try {
      final logoBytes = await rootBundle.load('assets/logo.png');
      logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (_) {}

    // ── Shared helpers ──────────────────────────────────────────────────────
    pw.Widget sRow(String label, String value, PdfColor color, {bool bold = false}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 3),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(label, style: pw.TextStyle(
                fontSize: bold ? 10 : 9,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: bold ? PdfColors.white : PdfColors.grey400)),
              pw.Text(value, style: pw.TextStyle(
                fontSize: bold ? 11 : 9,
                fontWeight: pw.FontWeight.bold,
                color: color)),
            ],
          ),
        );

    pw.Widget sectionHeader(String title, PdfColor accent) => pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          color: accent.shade(0.25),
          child: pw.Row(children: [
            pw.Container(width: 4, height: 14, color: accent),
            pw.SizedBox(width: 8),
            pw.Text(title, style: pw.TextStyle(
                fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.white,
                letterSpacing: 0.5)),
          ]),
        );

    pw.Widget sharedHeader() => pw.Container(
          padding: const pw.EdgeInsets.all(16),
          color: headerBg,
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (logoImage != null)
                pw.Container(width: 55, height: 55,
                    child: pw.Image(logoImage, fit: pw.BoxFit.contain))
              else
                pw.Container(width: 55),
              pw.SizedBox(width: 12),
              pw.Expanded(child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(appState.companyName,
                      style: pw.TextStyle(color: goldColor, fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  pw.Text('${appState.companyPhone}  •  ${appState.companyEmail}',
                      style: const pw.TextStyle(color: PdfColors.grey400, fontSize: 8)),
                ],
              )),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                pw.Text('PROJECT DOSSIER',
                    style: pw.TextStyle(color: goldColor, fontSize: 10,
                        fontWeight: pw.FontWeight.bold, letterSpacing: 1)),
                pw.SizedBox(height: 3),
                pw.Text('${project.numberLabel}  |  ${project.name}',
                    style: const pw.TextStyle(color: PdfColors.white, fontSize: 9)),
                pw.Text('Generated: ${dateFmt.format(DateTime.now())}',
                    style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 8)),
              ]),
            ],
          ),
        );

    // Photos are chunked into fixed-height rows so a note with many photos can
    // still flow across pages inside a MultiPage.
    List<pw.Widget> photoRows(List<pw.MemoryImage> images) {
      final rows = <pw.Widget>[];
      for (var i = 0; i < images.length; i += 3) {
        final chunk = images.sublist(i, i + 3 > images.length ? images.length : i + 3);
        rows.add(pw.Padding(
          padding: const pw.EdgeInsets.only(top: 6),
          child: pw.Row(children: [
            for (final img in chunk)
              pw.Container(
                width: 155,
                height: 110,
                margin: const pw.EdgeInsets.only(right: 6),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColor.fromHex('#2A3045')),
                ),
                child: pw.Image(img, fit: pw.BoxFit.cover),
              ),
          ]),
        ));
      }
      return rows;
    }

    List<pw.Widget> noteCardWidgets(ProjectNote note) {
      final imgs = note.images
          .map(_imageFromBase64)
          .whereType<pw.MemoryImage>()
          .toList();
      return [
        pw.Container(
          margin: const pw.EdgeInsets.only(top: 8),
          padding: const pw.EdgeInsets.all(9),
          decoration: pw.BoxDecoration(
            color: surfaceBg,
            border: pw.Border.all(color: PdfColor.fromHex('#2A3045')),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('SITE NOTE',
                      style: pw.TextStyle(
                          color: blueColor,
                          fontSize: 7,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 0.8)),
                  pw.Text(dateFmt.format(note.createdAt),
                      style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 7)),
                ],
              ),
              if (note.text.trim().isNotEmpty) ...[
                pw.SizedBox(height: 4),
                pw.Text(note.text.trim(),
                    style: const pw.TextStyle(color: PdfColors.white, fontSize: 9)),
              ],
            ],
          ),
        ),
        ...photoRows(imgs),
      ];
    }

    // ── Cover page ──────────────────────────────────────────────────────────
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      build: (ctx) => pw.Container(
        color: darkBg,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            // Top gold bar
            pw.Container(height: 8, color: goldColor),
            pw.SizedBox(height: 60),
            // Logo block
            pw.Center(
              child: pw.Container(
                width: 110,
                height: 110,
                child: logoImage != null
                    ? pw.Image(logoImage, fit: pw.BoxFit.contain)
                    : pw.Container(color: PdfColor.fromHex('#1E2733')),
              ),
            ),
            pw.SizedBox(height: 32),
            pw.Center(child: pw.Text(
              appState.companyName,
              style: pw.TextStyle(color: goldColor, fontSize: 26,
                  fontWeight: pw.FontWeight.bold, letterSpacing: 2),
            )),
            pw.SizedBox(height: 8),
            pw.Center(child: pw.Text(
              'PROJECT FINANCIAL DOSSIER',
              style: pw.TextStyle(color: PdfColors.grey400, fontSize: 13,
                  letterSpacing: 3),
            )),
            pw.SizedBox(height: 60),
            // Project info box
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 60),
              child: pw.Container(
                padding: const pw.EdgeInsets.all(24),
                decoration: pw.BoxDecoration(
                  color: surfaceBg,
                  border: pw.Border.all(color: goldColor.shade(0.4)),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Row(children: [
                    pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                      pw.Text('PROJECT', style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 8)),
                      pw.SizedBox(height: 2),
                      pw.Text(project.name, style: pw.TextStyle(color: PdfColors.white, fontSize: 15,
                          fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 2),
                      pw.Text('Project No. ${project.numberLabel}',
                          style: const pw.TextStyle(color: PdfColors.grey400, fontSize: 9)),
                    ])),
                    pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                      pw.Text('STATUS', style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 8)),
                      pw.SizedBox(height: 2),
                      pw.Text(project.status.label, style: pw.TextStyle(
                          color: goldColor, fontSize: 11, fontWeight: pw.FontWeight.bold)),
                    ]),
                  ]),
                  pw.SizedBox(height: 14),
                  pw.Row(children: [
                    pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                      pw.Text('CLIENT', style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 8)),
                      pw.SizedBox(height: 2),
                      pw.Text(project.clientName, style: const pw.TextStyle(color: PdfColors.white, fontSize: 12)),
                    ])),
                    if (project.location.isNotEmpty)
                      pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                        pw.Text('LOCATION', style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 8)),
                        pw.SizedBox(height: 2),
                        pw.Text(project.location, style: const pw.TextStyle(color: PdfColors.white, fontSize: 10)),
                      ]),
                  ]),
                  pw.SizedBox(height: 14),
                  pw.Divider(color: PdfColor.fromHex('#2A3045')),
                  pw.SizedBox(height: 10),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                        pw.Text('START DATE', style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 8)),
                        pw.Text(dateFmt.format(project.startDate),
                            style: const pw.TextStyle(color: PdfColors.white, fontSize: 10)),
                      ]),
                      if (project.deadline != null)
                        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                          pw.Text('DEADLINE', style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 8)),
                          pw.Text(dateFmt.format(project.deadline!),
                              style: const pw.TextStyle(color: PdfColors.white, fontSize: 10)),
                        ]),
                      if (project.status == ProjectStatus.completed)
                        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                          pw.Text('COMPLETED', style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 8)),
                          pw.Text(project.completedAt != null ? dateFmt.format(project.completedAt!) : 'Yes',
                              style: pw.TextStyle(color: greenColor, fontSize: 10)),
                        ]),
                      if (project.budget > 0)
                        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                          pw.Text('BUDGET', style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 8)),
                          pw.Text(fmt.format(project.budget),
                              style: pw.TextStyle(color: goldColor, fontSize: 10)),
                        ]),
                    ],
                  ),
                ]),
              ),
            ),
            pw.Spacer(),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 60, vertical: 20),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Prepared by: ${appState.preparedBy}',
                      style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 8)),
                  pw.Text(dateFmt.format(DateTime.now()),
                      style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 8)),
                ],
              ),
            ),
            pw.Container(height: 4, color: goldColor),
          ],
        ),
      ),
    ));

    // ── Financial Summary page ──────────────────────────────────────────────
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      header: (_) => sharedHeader(),
      footer: (ctx) => pw.Container(
        alignment: pw.Alignment.center,
        margin: const pw.EdgeInsets.only(top: 6),
        child: pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
            style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 7)),
      ),
      build: (ctx) => [
        pw.SizedBox(height: 16),
        sectionHeader('FINANCIAL SUMMARY', goldColor),
        pw.SizedBox(height: 12),
        pw.Container(
          padding: const pw.EdgeInsets.all(14),
          color: surfaceBg,
          child: pw.Column(children: [
            sRow('Total Quoted Value', fmt.format(totalQuoted), blueColor),
            sRow('Total Invoiced Value', fmt.format(totalInvoiced), PdfColors.white),
            sRow('Total Payments Received', fmt.format(totalPaid), greenColor),
            sRow('Total Expenses & Materials', fmt.format(totalExpenses), goldColor),
            pw.Divider(color: PdfColors.grey700, height: 14),
            sRow('Net Profit Realized', fmt.format(netProfit),
                isProfit ? greenColor : redColor, bold: true),
            sRow('Client Outstanding Balance', fmt.format(balance),
                balance > 0 ? PdfColors.orange : greenColor, bold: true),
            if (project.budget > 0) ...[
              pw.SizedBox(height: 4),
              sRow('Estimated Budget', fmt.format(project.budget), PdfColors.grey400),
              sRow(
                totalExpenses > project.budget ? 'Budget Overrun' : 'Budget Remaining',
                fmt.format((project.budget - totalExpenses).abs()),
                totalExpenses > project.budget ? redColor : greenColor,
              ),
            ],
          ]),
        ),
        pw.SizedBox(height: 24),

        // Project brief
        if (project.description.trim().isNotEmpty ||
            (workflowCards.isEmpty && project.notes.trim().isNotEmpty)) ...[
          sectionHeader('PROJECT BRIEF', goldColor),
          pw.SizedBox(height: 10),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            color: surfaceBg,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (project.description.trim().isNotEmpty) ...[
                  pw.Text('DESCRIPTION',
                      style: pw.TextStyle(
                          color: goldColor,
                          fontSize: 7,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 0.8)),
                  pw.SizedBox(height: 3),
                  pw.Text(project.description.trim(),
                      style: const pw.TextStyle(color: PdfColors.grey300, fontSize: 9)),
                ],
                if (project.description.trim().isNotEmpty &&
                    workflowCards.isEmpty &&
                    project.notes.trim().isNotEmpty)
                  pw.SizedBox(height: 10),
                if (workflowCards.isEmpty && project.notes.trim().isNotEmpty) ...[
                  pw.Text('NOTES',
                      style: pw.TextStyle(
                          color: goldColor,
                          fontSize: 7,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 0.8)),
                  pw.SizedBox(height: 3),
                  pw.Text(project.notes.trim(),
                      style: const pw.TextStyle(color: PdfColors.grey300, fontSize: 9)),
                ],
              ],
            ),
          ),
          pw.SizedBox(height: 24),
        ],

        // Workflow notes with attached photos
        if (workflowCards.isNotEmpty) ...[
          sectionHeader('WORKFLOW NOTES (${workflowCards.length})', blueColor),
          pw.SizedBox(height: 4),
          ...workflowCards.expand(noteCardWidgets),
          pw.SizedBox(height: 20),
        ],

        // Site photos
        if (siteImages.isNotEmpty) ...[
          sectionHeader('SITE PHOTOS (${siteImages.length})', goldColor),
          ...photoRows(siteImages),
          pw.SizedBox(height: 20),
        ],

        // Project tasks
        if (projectTasks.isNotEmpty) ...[
          sectionHeader('PROJECT TASKS (${projectTasks.length})', PdfColors.purple),
          pw.SizedBox(height: 10),
          pw.Table(
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(5),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FlexColumnWidth(2),
              4: const pw.FlexColumnWidth(2),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: surfaceBg),
                children: ['Status', 'Task', 'Priority', 'Due', 'Reminder']
                    .map((h) => pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(h,
                            style: pw.TextStyle(
                                color: goldColor,
                                fontSize: 8,
                                fontWeight: pw.FontWeight.bold))))
                    .toList(),
              ),
              ...projectTasks.map((t) => pw.TableRow(
                    decoration: pw.BoxDecoration(
                        color: projectTasks.indexOf(t).isEven
                            ? PdfColor.fromHex('#111827')
                            : darkBg),
                    children: [
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(t.status.label,
                              style: pw.TextStyle(
                                  color: t.status == TaskStatus.done
                                      ? greenColor
                                      : PdfColors.grey300,
                                  fontSize: 8))),
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(t.title,
                                  style: const pw.TextStyle(
                                      color: PdfColors.white, fontSize: 8)),
                              if (t.description.trim().isNotEmpty)
                                pw.Text(t.description.trim(),
                                    style: const pw.TextStyle(
                                        color: PdfColors.grey500, fontSize: 7)),
                            ],
                          )),
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(t.priority.label,
                              style: const pw.TextStyle(
                                  color: PdfColors.grey300, fontSize: 8))),
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(dateFmt.format(t.dueDate),
                              style: const pw.TextStyle(
                                  color: PdfColors.grey400, fontSize: 8))),
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(
                              t.alarmEnabled
                                  ? 'On${t.reminderLeadMinutes > 0 ? ' (${t.reminderLeadMinutes}m before)' : ''}'
                                  : 'Off',
                              style: pw.TextStyle(
                                  color: t.alarmEnabled ? greenColor : PdfColors.grey500,
                                  fontSize: 8))),
                    ],
                  )),
            ],
          ),
          pw.SizedBox(height: 24),
        ],

        // Quotes overview
        if (quotes.isNotEmpty) ...[
          sectionHeader('QUOTATIONS (${quotes.length})', blueColor),
          pw.SizedBox(height: 10),
          pw.Table(
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(3),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FlexColumnWidth(2),
              4: const pw.FlexColumnWidth(2),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: surfaceBg),
                children: ['Quote #', 'Client', 'Date', 'Status', 'Total']
                    .map((h) => pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(h, style: pw.TextStyle(
                            color: goldColor, fontSize: 8, fontWeight: pw.FontWeight.bold))))
                    .toList(),
              ),
              ...quotes.map((q) => pw.TableRow(
                decoration: pw.BoxDecoration(
                    color: quotes.indexOf(q).isEven
                        ? PdfColor.fromHex('#111827')
                        : darkBg),
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(5),
                      child: pw.Text(q.id, style: const pw.TextStyle(color: PdfColors.white, fontSize: 8))),
                  pw.Padding(padding: const pw.EdgeInsets.all(5),
                      child: pw.Text(q.clientName, style: const pw.TextStyle(color: PdfColors.grey400, fontSize: 8))),
                  pw.Padding(padding: const pw.EdgeInsets.all(5),
                      child: pw.Text(dateFmt.format(q.date), style: const pw.TextStyle(color: PdfColors.grey400, fontSize: 8))),
                  pw.Padding(padding: const pw.EdgeInsets.all(5),
                      child: pw.Text(q.status.label, style: const pw.TextStyle(color: PdfColors.grey300, fontSize: 8))),
                  pw.Padding(padding: const pw.EdgeInsets.all(5),
                      child: pw.Align(alignment: pw.Alignment.centerRight,
                        child: pw.Text(fmt.format(q.total),
                            style: pw.TextStyle(color: blueColor, fontSize: 8, fontWeight: pw.FontWeight.bold)))),
                ],
              )),
            ],
          ),
          pw.SizedBox(height: 24),
        ],

        // Invoices overview
        if (invoices.isNotEmpty) ...[
          sectionHeader('INVOICES (${invoices.length})', PdfColors.purple),
          pw.SizedBox(height: 10),
          pw.Table(
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(3),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FlexColumnWidth(2),
              4: const pw.FlexColumnWidth(2),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: surfaceBg),
                children: ['Invoice #', 'Client', 'Due', 'Status', 'Amount']
                    .map((h) => pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(h, style: pw.TextStyle(
                            color: goldColor, fontSize: 8, fontWeight: pw.FontWeight.bold))))
                    .toList(),
              ),
              ...invoices.map((inv) => pw.TableRow(
                decoration: pw.BoxDecoration(
                    color: invoices.indexOf(inv).isEven
                        ? PdfColor.fromHex('#111827')
                        : darkBg),
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(5),
                      child: pw.Text(inv.id, style: const pw.TextStyle(color: PdfColors.white, fontSize: 8))),
                  pw.Padding(padding: const pw.EdgeInsets.all(5),
                      child: pw.Text(inv.clientName, style: const pw.TextStyle(color: PdfColors.grey400, fontSize: 8))),
                  pw.Padding(padding: const pw.EdgeInsets.all(5),
                      child: pw.Text(dateFmt.format(inv.dueDate), style: const pw.TextStyle(color: PdfColors.grey400, fontSize: 8))),
                  pw.Padding(padding: const pw.EdgeInsets.all(5),
                      child: pw.Text(inv.status.label, style: const pw.TextStyle(color: PdfColors.grey300, fontSize: 8))),
                  pw.Padding(padding: const pw.EdgeInsets.all(5),
                      child: pw.Align(alignment: pw.Alignment.centerRight,
                        child: pw.Text(fmt.format(inv.total > 0 ? inv.total : inv.amount),
                            style: pw.TextStyle(color: greenColor, fontSize: 8, fontWeight: pw.FontWeight.bold)))),
                ],
              )),
            ],
          ),
          pw.SizedBox(height: 24),
        ],

        // Detailed quote line items
        if (quotes.isNotEmpty) ...[
          sectionHeader('QUOTATION LINE ITEMS', blueColor),
          pw.SizedBox(height: 10),
          ...quotes.expand((q) {
            final rows = <pw.Widget>[];
            rows.add(pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              color: PdfColor.fromHex('#0F1A2C'),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('${q.id}  •  ${q.clientName}  •  ${dateFmt.format(q.date)}',
                      style: pw.TextStyle(color: goldColor, fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  pw.Text(fmt.format(q.total),
                      style: pw.TextStyle(color: blueColor, fontSize: 9, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ));
            for (final cat in q.categories) {
              if (cat.items.isEmpty) continue;
              if (cat.name.trim().isNotEmpty) {
                rows.add(pw.Container(
                  color: PdfColor.fromHex('#1A2035'),
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: pw.Text(cat.name.toUpperCase(),
                      style: pw.TextStyle(color: PdfColors.grey400, fontSize: 8, fontWeight: pw.FontWeight.bold)),
                ));
              }
              for (final item in cat.items) {
                rows.add(pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  child: pw.Row(children: [
                    pw.Expanded(flex: 4, child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(item.name,
                            style: const pw.TextStyle(color: PdfColors.grey300, fontSize: 8)),
                        if (item.description.trim().isNotEmpty)
                          pw.Text(item.description,
                              style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 7)),
                      ],
                    )),
                    pw.SizedBox(width: 4, child: pw.Text(
                        '${item.qty % 1 == 0 ? item.qty.toInt() : item.qty} ${item.unit}',
                        style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 7))),
                    pw.Expanded(flex: 2, child: pw.Align(
                      alignment: pw.Alignment.centerRight,
                      child: pw.Text(fmt.format(item.total),
                          style: const pw.TextStyle(color: PdfColors.white, fontSize: 8)),
                    )),
                  ]),
                ));
              }
            }
            rows.add(pw.SizedBox(height: 8));
            return rows;
          }),
          pw.SizedBox(height: 16),
        ],

        // Payments log
        if (project.payments.isNotEmpty) ...[
          sectionHeader('PAYMENTS RECEIVED (${project.payments.length})', greenColor),
          pw.SizedBox(height: 10),
          pw.Table(
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(3),
              3: const pw.FlexColumnWidth(3),
              4: const pw.FlexColumnWidth(2),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: surfaceBg),
                children: ['Date', 'Method', 'Reference', 'Notes', 'Amount']
                    .map((h) => pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(h, style: pw.TextStyle(
                            color: goldColor, fontSize: 8, fontWeight: pw.FontWeight.bold))))
                    .toList(),
              ),
              ...project.payments.map((p) => pw.TableRow(
                decoration: pw.BoxDecoration(
                    color: project.payments.indexOf(p).isEven
                        ? PdfColor.fromHex('#111827')
                        : darkBg),
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(5),
                      child: pw.Text(dateFmt.format(p.date), style: const pw.TextStyle(color: PdfColors.grey300, fontSize: 8))),
                  pw.Padding(padding: const pw.EdgeInsets.all(5),
                      child: pw.Text(p.paymentMethod, style: const pw.TextStyle(color: PdfColors.grey400, fontSize: 8))),
                  pw.Padding(padding: const pw.EdgeInsets.all(5),
                      child: pw.Text(p.reference.isEmpty ? '—' : p.reference,
                          style: const pw.TextStyle(color: PdfColors.grey400, fontSize: 8))),
                  pw.Padding(padding: const pw.EdgeInsets.all(5),
                      child: pw.Text(p.notes.trim().isEmpty ? '—' : p.notes.trim(),
                          style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 7))),
                  pw.Padding(padding: const pw.EdgeInsets.all(5),
                      child: pw.Align(alignment: pw.Alignment.centerRight,
                        child: pw.Text(fmt.format(p.amount),
                            style: pw.TextStyle(color: greenColor, fontSize: 8, fontWeight: pw.FontWeight.bold)))),
                ],
              )),
              pw.TableRow(
                decoration: pw.BoxDecoration(color: PdfColor.fromHex('#0F1A2C')),
                children: [
                  pw.Container(), pw.Container(), pw.Container(), pw.Container(),
                  pw.Padding(padding: const pw.EdgeInsets.all(6),
                      child: pw.Align(alignment: pw.Alignment.centerRight,
                        child: pw.Text(fmt.format(totalPaid),
                            style: pw.TextStyle(color: greenColor, fontSize: 9, fontWeight: pw.FontWeight.bold)))),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 24),
        ],

        // Expenses log
        if (project.expenses.isNotEmpty) ...[
          sectionHeader('BOUGHT PRODUCTS & EXPENSES (${project.expenses.length})', goldColor),
          pw.SizedBox(height: 10),
          pw.Table(
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FlexColumnWidth(2),
              4: const pw.FlexColumnWidth(2),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: surfaceBg),
                children: ['Item', 'Category', 'Supplier', 'Date', 'Amount']
                    .map((h) => pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(h, style: pw.TextStyle(
                            color: goldColor, fontSize: 8, fontWeight: pw.FontWeight.bold))))
                    .toList(),
              ),
              ...project.expenses.map((e) => pw.TableRow(
                decoration: pw.BoxDecoration(
                    color: project.expenses.indexOf(e).isEven
                        ? PdfColor.fromHex('#111827')
                        : darkBg),
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(5),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(e.title, style: const pw.TextStyle(color: PdfColors.grey300, fontSize: 8)),
                          pw.Text(
                              '${e.quantity % 1 == 0 ? e.quantity.toInt() : e.quantity} ${e.unit} @ ${fmt.format(e.unitPrice)}',
                              style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 7)),
                          if (e.receiptNo.trim().isNotEmpty)
                            pw.Text('Receipt: ${e.receiptNo.trim()}',
                                style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 7)),
                          if (e.notes.trim().isNotEmpty)
                            pw.Text(e.notes.trim(),
                                style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 7)),
                        ],
                      )),
                  pw.Padding(padding: const pw.EdgeInsets.all(5),
                      child: pw.Text(e.category, style: const pw.TextStyle(color: PdfColors.grey400, fontSize: 8))),
                  pw.Padding(padding: const pw.EdgeInsets.all(5),
                      child: pw.Text(e.supplier.isEmpty ? '—' : e.supplier,
                          style: const pw.TextStyle(color: PdfColors.grey400, fontSize: 8))),
                  pw.Padding(padding: const pw.EdgeInsets.all(5),
                      child: pw.Text(dateFmt.format(e.date), style: const pw.TextStyle(color: PdfColors.grey400, fontSize: 8))),
                  pw.Padding(padding: const pw.EdgeInsets.all(5),
                      child: pw.Align(alignment: pw.Alignment.centerRight,
                        child: pw.Text(fmt.format(e.amount),
                            style: pw.TextStyle(color: goldColor, fontSize: 8, fontWeight: pw.FontWeight.bold)))),
                ],
              )),
              pw.TableRow(
                decoration: pw.BoxDecoration(color: PdfColor.fromHex('#0F1A2C')),
                children: [
                  pw.Container(), pw.Container(), pw.Container(),
                  pw.Padding(padding: const pw.EdgeInsets.all(6),
                      child: pw.Text('TOTAL COSTS',
                          style: pw.TextStyle(color: PdfColors.white, fontSize: 8, fontWeight: pw.FontWeight.bold))),
                  pw.Padding(padding: const pw.EdgeInsets.all(6),
                      child: pw.Align(alignment: pw.Alignment.centerRight,
                        child: pw.Text(fmt.format(totalExpenses),
                            style: pw.TextStyle(color: goldColor, fontSize: 9, fontWeight: pw.FontWeight.bold)))),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 24),
        ],

        // Closing P&L
        sectionHeader('FINAL PROFIT & LOSS', isProfit ? greenColor : redColor),
        pw.SizedBox(height: 10),
        pw.Container(
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(
            color: surfaceBg,
            border: pw.Border.all(
                color: isProfit ? greenColor.shade(0.4) : redColor.shade(0.4)),
          ),
          child: pw.Column(children: [
            sRow('Total Revenue (Payments In)', fmt.format(totalPaid), greenColor),
            sRow('Total Costs (Expenses Out)', fmt.format(totalExpenses), goldColor),
            pw.Divider(color: PdfColors.grey700, height: 10),
            sRow('NET PROFIT', fmt.format(netProfit),
                isProfit ? greenColor : redColor, bold: true),
            sRow('CLIENT BALANCE DUE', fmt.format(balance),
                balance > 0 ? PdfColors.orange : greenColor, bold: true),
          ]),
        ),
        pw.SizedBox(height: 20),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Prepared by: ${appState.preparedBy}',
                style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 8)),
            pw.Text('${appState.companyName}  •  ${appState.companyPhone}',
                style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 8)),
          ],
        ),
      ],
    ));

    return pdf.save();
  }

  // ── Minimalist Full Project PDF ─────────────────────────────────────────────

  static Future<Uint8List> _generateMinimalistFullProjectPdf({
    required AppState appState,
    required Project project,
    required List<Quote> quotes,
    required List<Invoice> invoices,
  }) async {
    final pdf = pw.Document();
    final fmt = NumberFormat.currency(symbol: '${appState.currency} ', decimalDigits: 2);
    final dateFmt = DateFormat('dd/MM/yyyy');

    final totalQuoted   = project.totalQuoted(quotes);
    final totalInvoiced = project.totalInvoiced(invoices);
    final totalPaid     = project.totalPaymentsReceived;
    final totalExpenses = project.totalExpenses;
    final netProfit     = project.netProfitRealized();
    final balance       = project.outstandingBalance(invoices, quotes);
    final isProfit      = netProfit >= 0;

    final workflowCards = [...project.workflowNotes]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final siteImages = project.summaryImages
        .map(_imageFromBase64)
        .whereType<pw.MemoryImage>()
        .toList();
    final projectTasks = appState.tasksForProject(project.id)
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

    pw.Widget mRow(String label, String value, {bool bold = false, bool positive = true}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 3),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(label, style: pw.TextStyle(
                fontSize: bold ? 10 : 9,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: bold ? PdfColors.black : PdfColors.grey700)),
              pw.Text(value, style: pw.TextStyle(
                fontSize: bold ? 11 : 9,
                fontWeight: pw.FontWeight.bold,
                color: bold
                    ? (positive ? PdfColors.green800 : PdfColors.red700)
                    : PdfColors.black)),
            ],
          ),
        );

    pw.Widget sectionTitleMin(String text) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 6),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(text, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              pw.Divider(color: PdfColors.black, thickness: 0.8, height: 6),
            ],
          ),
        );

    pw.Widget minHeader() => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(appState.companyName,
                style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
            pw.Text('PROJECT DOSSIER  •  ${dateFmt.format(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          ],
        );

    List<pw.Widget> photoRows(List<pw.MemoryImage> images) {
      final rows = <pw.Widget>[];
      for (var i = 0; i < images.length; i += 3) {
        final chunk = images.sublist(i, i + 3 > images.length ? images.length : i + 3);
        rows.add(pw.Padding(
          padding: const pw.EdgeInsets.only(top: 6),
          child: pw.Row(children: [
            for (final img in chunk)
              pw.Container(
                width: 155,
                height: 110,
                margin: const pw.EdgeInsets.only(right: 6),
                decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300)),
                child: pw.Image(img, fit: pw.BoxFit.cover),
              ),
          ]),
        ));
      }
      return rows;
    }

    List<pw.Widget> noteCardWidgets(ProjectNote note) {
      final imgs = note.images
          .map(_imageFromBase64)
          .whereType<pw.MemoryImage>()
          .toList();
      return [
        pw.Container(
          margin: const pw.EdgeInsets.only(top: 8),
          padding: const pw.EdgeInsets.all(9),
          decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3))),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('SITE NOTE',
                      style: pw.TextStyle(
                          fontSize: 7,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 0.8,
                          color: PdfColors.grey700)),
                  pw.Text(dateFmt.format(note.createdAt),
                      style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                ],
              ),
              if (note.text.trim().isNotEmpty) ...[
                pw.SizedBox(height: 4),
                pw.Text(note.text.trim(),
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.black)),
              ],
            ],
          ),
        ),
        ...photoRows(imgs),
      ];
    }

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      header: (_) => minHeader(),
      footer: (ctx) => pw.Container(
        alignment: pw.Alignment.center,
        margin: const pw.EdgeInsets.only(top: 8),
        child: pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
            style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 7)),
      ),
      build: (ctx) => [
        pw.SizedBox(height: 16),

        // Project identity
        pw.Text(project.name,
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text('${project.numberLabel}  |  Client: ${project.clientName}  |  Status: ${project.status.label}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
        if (project.location.isNotEmpty)
          pw.Text('Location: ${project.location}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
        pw.Text(
          'Start: ${dateFmt.format(project.startDate)}'
          '${project.deadline != null ? '  •  Deadline: ${dateFmt.format(project.deadline!)}' : ''}'
          '${project.status == ProjectStatus.completed ? '  •  Completed: ${project.completedAt != null ? dateFmt.format(project.completedAt!) : 'Yes'}' : ''}'
          '${project.budget > 0 ? '  •  Budget: ${fmt.format(project.budget)}' : ''}',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
        ),
        pw.SizedBox(height: 20),

        // Project brief
        if (project.description.trim().isNotEmpty ||
            (workflowCards.isEmpty && project.notes.trim().isNotEmpty)) ...[
          sectionTitleMin('PROJECT BRIEF'),
          if (project.description.trim().isNotEmpty) ...[
            pw.Text(project.description.trim(),
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800)),
            pw.SizedBox(height: 6),
          ],
          if (workflowCards.isEmpty && project.notes.trim().isNotEmpty)
            pw.Text(project.notes.trim(),
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800)),
          pw.SizedBox(height: 20),
        ],

        // Workflow notes with attached photos
        if (workflowCards.isNotEmpty) ...[
          sectionTitleMin('WORKFLOW NOTES (${workflowCards.length})'),
          ...workflowCards.expand(noteCardWidgets),
          pw.SizedBox(height: 20),
        ],

        // Site photos
        if (siteImages.isNotEmpty) ...[
          sectionTitleMin('SITE PHOTOS (${siteImages.length})'),
          ...photoRows(siteImages),
          pw.SizedBox(height: 20),
        ],

        // Project tasks
        if (projectTasks.isNotEmpty) ...[
          sectionTitleMin('PROJECT TASKS (${projectTasks.length})'),
          pw.Table(
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(5),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FlexColumnWidth(2),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(width: 0.8))),
                children: ['Status', 'Task', 'Priority', 'Due'].map((h) => pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 6),
                    child: pw.Text(h, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)))).toList(),
              ),
              ...projectTasks.map((t) => pw.TableRow(
                    decoration: const pw.BoxDecoration(
                        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.4))),
                    children: [
                      _mCell(t.status.label, size: 8),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(t.title, style: const pw.TextStyle(fontSize: 8)),
                            if (t.description.trim().isNotEmpty)
                              pw.Text(t.description.trim(),
                                  style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                            if (t.alarmEnabled)
                              pw.Text(
                                  'Reminder on${t.reminderLeadMinutes > 0 ? ' (${t.reminderLeadMinutes}m before)' : ''}',
                                  style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                          ],
                        ),
                      ),
                      _mCell(t.priority.label, size: 8),
                      _mCell(dateFmt.format(t.dueDate), size: 8),
                    ],
                  )),
            ],
          ),
          pw.SizedBox(height: 20),
        ],

        // Financial summary
        sectionTitleMin('FINANCIAL SUMMARY'),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))),
          child: pw.Column(children: [
            mRow('Total Quoted', fmt.format(totalQuoted)),
            mRow('Total Invoiced', fmt.format(totalInvoiced)),
            mRow('Total Payments Received', fmt.format(totalPaid)),
            mRow('Total Expenses & Materials', fmt.format(totalExpenses)),
            pw.Divider(color: PdfColors.grey300, height: 12),
            mRow('Net Profit Realized', fmt.format(netProfit),
                bold: true, positive: isProfit),
            mRow('Client Outstanding Balance', fmt.format(balance),
                bold: true, positive: balance <= 0),
          ]),
        ),
        pw.SizedBox(height: 24),

        // Quotes
        if (quotes.isNotEmpty) ...[
          sectionTitleMin('QUOTATIONS (${quotes.length})'),
          pw.Table(
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FlexColumnWidth(2),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(width: 0.8))),
                children: ['Quote #', 'Date', 'Status', 'Total'].map((h) => pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 6),
                    child: pw.Text(h, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)))).toList(),
              ),
              ...quotes.map((q) => pw.TableRow(
                decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.4))),
                children: [
                  _mCell(q.id, size: 8),
                  _mCell(dateFmt.format(q.date), size: 8),
                  _mCell(q.status.label, size: 8),
                  _mCell(fmt.format(q.total), align: pw.Alignment.centerRight, size: 8),
                ],
              )),
            ],
          ),
          pw.SizedBox(height: 20),
        ],

        // Quote line items detail
        if (quotes.isNotEmpty) ...[
          sectionTitleMin('QUOTATION ITEM DETAIL'),
          ...quotes.expand((q) {
            final rows = <pw.Widget>[];
            rows.add(pw.Container(
              color: PdfColors.grey100,
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text(q.id, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                pw.Text(fmt.format(q.total),
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
              ]),
            ));
            for (final cat in q.categories) {
              if (cat.items.isEmpty) continue;
              if (cat.name.trim().isNotEmpty) {
                rows.add(pw.Padding(
                  padding: const pw.EdgeInsets.only(left: 8, top: 4, bottom: 2),
                  child: pw.Text(cat.name.toUpperCase(),
                      style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                ));
              }
              for (final item in cat.items) {
                rows.add(pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  child: pw.Row(children: [
                    pw.Expanded(child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(item.name,
                            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800)),
                        if (item.description.trim().isNotEmpty)
                          pw.Text(item.description,
                              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                      ],
                    )),
                    pw.Text(fmt.format(item.total),
                        style: const pw.TextStyle(fontSize: 8)),
                  ]),
                ));
              }
            }
            rows.add(pw.SizedBox(height: 6));
            return rows;
          }),
          pw.SizedBox(height: 20),
        ],

        // Invoices
        if (invoices.isNotEmpty) ...[
          sectionTitleMin('INVOICES (${invoices.length})'),
          pw.Table(
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FlexColumnWidth(2),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(width: 0.8))),
                children: ['Invoice #', 'Due Date', 'Status', 'Amount'].map((h) => pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 6),
                    child: pw.Text(h, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)))).toList(),
              ),
              ...invoices.map((inv) => pw.TableRow(
                decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.4))),
                children: [
                  _mCell(inv.id, size: 8),
                  _mCell(dateFmt.format(inv.dueDate), size: 8),
                  _mCell(inv.status.label, size: 8),
                  _mCell(fmt.format(inv.total > 0 ? inv.total : inv.amount),
                      align: pw.Alignment.centerRight, size: 8),
                ],
              )),
            ],
          ),
          pw.SizedBox(height: 20),
        ],

        // Payments
        if (project.payments.isNotEmpty) ...[
          sectionTitleMin('PAYMENTS RECEIVED'),
          pw.Table(
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FlexColumnWidth(3),
              4: const pw.FlexColumnWidth(2),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(width: 0.8))),
                children: ['Date', 'Method', 'Reference', 'Notes', 'Amount'].map((h) => pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 6),
                    child: pw.Text(h, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)))).toList(),
              ),
              ...project.payments.map((p) => pw.TableRow(
                decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.4))),
                children: [
                  _mCell(dateFmt.format(p.date), size: 8),
                  _mCell(p.paymentMethod, size: 8),
                  _mCell(p.reference.isEmpty ? '—' : p.reference, size: 8),
                  _mCell(p.notes.trim().isEmpty ? '—' : p.notes.trim(), size: 7),
                  _mCell(fmt.format(p.amount), align: pw.Alignment.centerRight, size: 8),
                ],
              )),
              pw.TableRow(children: [
                pw.Container(), pw.Container(), pw.Container(), pw.Container(),
                pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 4),
                    child: pw.Align(alignment: pw.Alignment.centerRight,
                      child: pw.Text(fmt.format(totalPaid),
                          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)))),
              ]),
            ],
          ),
          pw.SizedBox(height: 20),
        ],

        // Expenses
        if (project.expenses.isNotEmpty) ...[
          sectionTitleMin('BOUGHT PRODUCTS & EXPENSES'),
          pw.Table(
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FlexColumnWidth(2),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(width: 0.8))),
                children: ['Item', 'Category', 'Date', 'Amount'].map((h) => pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 6),
                    child: pw.Text(h, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)))).toList(),
              ),
              ...project.expenses.map((e) => pw.TableRow(
                decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.4))),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(e.title, style: const pw.TextStyle(fontSize: 8)),
                        pw.Text(
                            '${e.quantity % 1 == 0 ? e.quantity.toInt() : e.quantity} ${e.unit} @ ${fmt.format(e.unitPrice)}',
                            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                        if (e.supplier.trim().isNotEmpty)
                          pw.Text('Supplier: ${e.supplier.trim()}',
                              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                        if (e.receiptNo.trim().isNotEmpty)
                          pw.Text('Receipt: ${e.receiptNo.trim()}',
                              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                        if (e.notes.trim().isNotEmpty)
                          pw.Text(e.notes.trim(),
                              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                      ],
                    ),
                  ),
                  _mCell(e.category, size: 8),
                  _mCell(dateFmt.format(e.date), size: 8),
                  _mCell(fmt.format(e.amount), align: pw.Alignment.centerRight, size: 8),
                ],
              )),
              pw.TableRow(children: [
                pw.Container(), pw.Container(),
                pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 4),
                    child: pw.Text('TOTAL', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 4),
                    child: pw.Align(alignment: pw.Alignment.centerRight,
                      child: pw.Text(fmt.format(totalExpenses),
                          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)))),
              ]),
            ],
          ),
          pw.SizedBox(height: 20),
        ],

        // Final P&L
        sectionTitleMin('FINAL PROFIT & LOSS'),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))),
          child: pw.Column(children: [
            mRow('Total Revenue (Payments In)', fmt.format(totalPaid)),
            mRow('Total Costs (Expenses Out)', fmt.format(totalExpenses)),
            pw.Divider(color: PdfColors.grey300, height: 12),
            mRow('NET PROFIT', fmt.format(netProfit), bold: true, positive: isProfit),
            mRow('CLIENT BALANCE DUE', fmt.format(balance),
                bold: true, positive: balance <= 0),
          ]),
        ),
        pw.SizedBox(height: 16),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Prepared by: ${appState.preparedBy}',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
            pw.Text('${appState.companyName}  •  ${appState.companyPhone}',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          ],
        ),
      ],
    ));

    return pdf.save();
  }
}

