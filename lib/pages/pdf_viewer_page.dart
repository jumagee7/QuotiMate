// pages/pdf_viewer_page.dart — In-app PDF Viewer with Edit & Share options

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../app_state.dart';
import '../models.dart';
import '../services/pdf_service.dart';
import 'quote_editor_page.dart';

class PdfViewerPage extends StatefulWidget {
  final String title;
  final String filename;
  final Future<Uint8List> Function(PdfPageFormat format) buildPdf;
  final Quote? quote;
  final VoidCallback? onEdit;

  const PdfViewerPage({
    super.key,
    required this.title,
    required this.filename,
    required this.buildPdf,
    this.quote,
    this.onEdit,
  });

  /// Quick helper to open a Quote PDF preview with Edit & Share
  static Future<void> openQuotePdf(BuildContext context, Quote quote, AppState appState) {
    final isSigned = quote.signatureData != null && quote.signatureData!.isNotEmpty;
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PdfViewerPage(
          title: 'Quotation ${quote.id}',
          filename: 'Quotation_${quote.id}.pdf',
          quote: quote,
          buildPdf: (format) => isSigned
              ? PdfService.generateSignedQuotePdf(
                  quote,
                  appState,
                  base64Decode(quote.signatureData!),
                  quote.signedAt ?? DateTime.now(),
                )
              : PdfService.generateQuotePdf(quote, appState),
        ),
      ),
    );
  }

  /// Quick helper to open an Invoice PDF preview with signed support
  static Future<void> openInvoicePdf(BuildContext context, Invoice invoice, AppState appState) {
    final isSigned = invoice.signatureData != null && invoice.signatureData!.isNotEmpty;
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PdfViewerPage(
          title: 'Invoice ${invoice.id}',
          filename: 'Invoice_${invoice.id}.pdf',
          buildPdf: (format) => isSigned
              ? PdfService.generateSignedInvoicePdf(
                  invoice,
                  appState,
                  base64Decode(invoice.signatureData!),
                  invoice.signedAt ?? DateTime.now(),
                )
              : PdfService.generateInvoicePdf(invoice, appState),
        ),
      ),
    );
  }

  /// Quick helper to open a generic PDF preview (e.g. Enquiry Invoice)
  static Future<void> openDocumentPdf({
    required BuildContext context,
    required String title,
    required String filename,
    required Future<Uint8List> Function(PdfPageFormat format) buildPdf,
    VoidCallback? onEdit,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PdfViewerPage(
          title: title,
          filename: filename,
          buildPdf: buildPdf,
          onEdit: onEdit,
        ),
      ),
    );
  }

  @override
  State<PdfViewerPage> createState() => _PdfViewerPageState();
}

class _PdfViewerPageState extends State<PdfViewerPage> {
  static const _bg      = Color(0xFF0F162C);
  static const _surface = Color(0xFF161B26);
  static const _border  = Color(0xFF2A3045);
  static const _gold    = Color(0xFFFFC107);
  static const _white70 = Color(0xFFB0B8D0);

  // Key to force refresh when quote is edited
  int _refreshKey = 0;

  @override
  Widget build(BuildContext context) {
    final appState = AppStateProvider.of(context);
    final hasEditOption = widget.quote != null || widget.onEdit != null;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            if (widget.quote != null)
              Text(
                'Client: ${widget.quote!.clientName}',
                style: const TextStyle(color: _white70, fontSize: 11),
              ),
          ],
        ),
        actions: [
          // ── Edit Button ───────────────────────────────────────────────────
          if (hasEditOption)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: ElevatedButton.icon(
                onPressed: () => _handleEdit(context, appState),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B),
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: _border),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
              ),
            ),

          // ── Share Button ──────────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: ElevatedButton.icon(
              onPressed: () => _handleShare(context),
              icon: const Icon(Icons.share_outlined, size: 16),
              label: const Text('Share'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 2,
              ),
            ),
          ),
        ],
      ),
      body: KeyedSubtree(
        key: ValueKey(_refreshKey),
        child: PdfPreview(
          build: widget.buildPdf,
          canChangePageFormat: false,
          canChangeOrientation: false,
          canDebug: false,
          pdfFileName: widget.filename,
          maxPageWidth: 700,
          previewPageMargin: const EdgeInsets.all(16),
          loadingWidget: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: _gold),
                SizedBox(height: 16),
                Text('Generating document...', style: TextStyle(color: _white70, fontSize: 13)),
              ],
            ),
          ),
          onError: (ctx, err) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                  const SizedBox(height: 12),
                  const Text('Error loading PDF preview',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('$err', style: const TextStyle(color: _white70, fontSize: 12), textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
          actionBarTheme: PdfActionBarTheme(
            backgroundColor: _surface,
            iconColor: Colors.white70,
            elevation: 0,
          ),
        ),
      ),
    );
  }

  Future<void> _handleEdit(BuildContext context, AppState appState) async {
    if (widget.quote != null) {
      // Open quote editor for the quote
      await openQuoteEditorPage(context, appState, quote: widget.quote);
      // When returning from quote editor, refresh the PDF preview
      if (mounted) {
        setState(() => _refreshKey++);
      }
    } else if (widget.onEdit != null) {
      Navigator.pop(context);
      widget.onEdit!();
    }
  }

  Future<void> _handleShare(BuildContext context) async {
    // Show filename input dialog
    final filenameCtrl = TextEditingController(text: widget.filename.replaceAll('.pdf', ''));
    
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _border),
        ),
        title: const Text('Save PDF As', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: filenameCtrl,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Filename',
            labelStyle: const TextStyle(color: _white70),
            filled: true,
            fillColor: const Color(0xFF0F162C),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _gold)),
            suffixText: '.pdf',
            suffixStyle: const TextStyle(color: _white70),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: _white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, filenameCtrl.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: _gold, foregroundColor: Colors.black),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    
    if (result == null || result.isEmpty) return;
    
    try {
      final bytes = await widget.buildPdf(PdfPageFormat.a4);
      if (bytes.isEmpty) {
        throw Exception('Generated PDF is empty');
      }
      var cleanFilename = result.replaceAll(RegExp(r'[^\w\.-]'), '_');
      if (!cleanFilename.toLowerCase().endsWith('.pdf')) {
        cleanFilename = '$cleanFilename.pdf';
      }
      await Printing.sharePdf(bytes: bytes, filename: cleanFilename);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing PDF: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
