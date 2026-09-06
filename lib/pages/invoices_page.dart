// pages/invoices_page.dart — QuotiMate Invoices Page
// Sleek, modern cards matching the QuotiMate design system, fully clickable with in-app PDF preview and status management.

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import '../app_state.dart';
import '../models.dart';
import '../services/pdf_service.dart';
import '../services/html_review_service.dart';
import '../services/cloud_sync_service.dart';
import '../services/review_server_service.dart';
import 'enquiry_invoice_page.dart';
import 'pdf_viewer_page.dart';
import 'signature_page.dart';

const _surface = Color(0xFF161B26);
const _border  = Color(0xFF2A3045);
const _gold    = Color(0xFFFFC107);
const _white38 = Color(0xFF616C88);
const _white54 = Colors.white54;
const _white70 = Color(0xFFB0B8D0);

enum InvoiceSort { dateDesc, dateAsc, dueDate, amountDesc, amountAsc, client, status }

class InvoicesPage extends StatefulWidget {
  const InvoicesPage({super.key});

  @override
  State<InvoicesPage> createState() => _InvoicesPageState();
}

class _InvoicesPageState extends State<InvoicesPage> {
  InvoiceStatus? _filterStatus;
  String _search = '';
  InvoiceSort _sort = InvoiceSort.dateDesc;

  final _currencyFmt = NumberFormat.currency(symbol: 'KES ', decimalDigits: 0);

  @override
  Widget build(BuildContext context) {
    final appState = AppStateProvider.of(context);
    final filtered = appState.invoices.where((inv) {
      final matchStatus = _filterStatus == null || inv.status == _filterStatus;
      final matchSearch = _search.isEmpty ||
          inv.id.toLowerCase().contains(_search) ||
          inv.clientName.toLowerCase().contains(_search) ||
          inv.quoteId.toLowerCase().contains(_search);
      return matchStatus && matchSearch;
    }).toList();

    switch (_sort) {
      case InvoiceSort.dateDesc:
        filtered.sort((a, b) => b.date.compareTo(a.date));
        break;
      case InvoiceSort.dateAsc:
        filtered.sort((a, b) => a.date.compareTo(b.date));
        break;
      case InvoiceSort.dueDate:
        filtered.sort((a, b) => a.dueDate.compareTo(b.dueDate));
        break;
      case InvoiceSort.amountDesc:
        filtered.sort((a, b) => b.amount.compareTo(a.amount));
        break;
      case InvoiceSort.amountAsc:
        filtered.sort((a, b) => a.amount.compareTo(b.amount));
        break;
      case InvoiceSort.client:
        filtered.sort((a, b) => a.clientName.toLowerCase().compareTo(b.clientName.toLowerCase()));
        break;
      case InvoiceSort.status:
        filtered.sort((a, b) => a.status.index.compareTo(b.status.index));
        break;
    }

    // Aggregate KPIs
    final totalAmount  = appState.invoices.fold<double>(0, (s, i) => s + i.amount);
    final paidAmount   = appState.invoices.where((i) => i.status == InvoiceStatus.paid).fold<double>(0, (s, i) => s + i.amount);
    final overdueCount = appState.invoices.where((i) => i.status == InvoiceStatus.overdue).length;
    final outstanding  = totalAmount - paidAmount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── KPI Strip ───────────────────────────────────────────────────────
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _kpi('Total Invoiced', _fmtKpi(totalAmount), Icons.receipt_long, _gold),
              const SizedBox(width: 12),
              _kpi('Paid', _fmtKpi(paidAmount), Icons.check_circle_outline, Colors.green),
              const SizedBox(width: 12),
              _kpi('Outstanding', _fmtKpi(outstanding), Icons.hourglass_top, Colors.orange),
              const SizedBox(width: 12),
              _kpi('Overdue', '$overdueCount overdue', Icons.warning_amber_rounded, Colors.redAccent),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Toolbar ─────────────────────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 42,
                child: TextField(
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search invoices, clients, or quote ref...',
                    hintStyle: const TextStyle(color: _white38, fontSize: 13),
                    prefixIcon: const Icon(Icons.search, color: _white38, size: 18),
                    suffixIcon: _search.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: _white38, size: 16),
                            onPressed: () => setState(() => _search = ''),
                          )
                        : null,
                    filled: true,
                    fillColor: _surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _gold),
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Sort Button
            PopupMenuButton<InvoiceSort>(
              tooltip: 'Sort Invoices',
              color: const Color(0xFF161B26),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: _border)),
              icon: Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _border),
                ),
                child: const Icon(Icons.sort_rounded, color: _gold, size: 20),
              ),
              onSelected: (s) => setState(() => _sort = s),
              itemBuilder: (_) => [
                _sortMenuItem(InvoiceSort.dateDesc, 'Date: Newest First', Icons.calendar_today),
                _sortMenuItem(InvoiceSort.dateAsc, 'Date: Oldest First', Icons.history),
                _sortMenuItem(InvoiceSort.dueDate, 'Due Date', Icons.event_available),
                _sortMenuItem(InvoiceSort.amountDesc, 'Amount: High to Low', Icons.arrow_downward),
                _sortMenuItem(InvoiceSort.amountAsc, 'Amount: Low to High', Icons.arrow_upward),
                _sortMenuItem(InvoiceSort.client, 'Client Name', Icons.person_outline),
                _sortMenuItem(InvoiceSort.status, 'Status', Icons.flag_outlined),
              ],
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: () => openEnquiryInvoicePage(context, appState),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Enquiry Invoice', style: TextStyle(fontWeight: FontWeight.bold)),
              style: FilledButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Filter Chips ────────────────────────────────────────────────────
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _filterChip('All (${appState.invoices.length})', null),
              const SizedBox(width: 8),
              ...InvoiceStatus.values.map((s) {
                final count = appState.invoices.where((i) => i.status == s).length;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _filterChip('${s.label} ($count)', s),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── Invoices List ───────────────────────────────────────────────────
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.receipt_long_outlined, color: _gold.withValues(alpha: 0.3), size: 48),
                      const SizedBox(height: 12),
                      const Text('No invoices found.', style: TextStyle(color: _white70, fontSize: 15)),
                      const SizedBox(height: 6),
                      const Text('Create an enquiry invoice or convert a quotation.', style: TextStyle(color: _white38, fontSize: 13)),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final invoice = filtered[index];
                    return _InvoiceCard(
                      invoice: invoice,
                      currencyFmt: _currencyFmt,
                      onTap: () => _openInvoicePdf(context, invoice, appState),
                      onEdit: () => openEnquiryInvoicePage(context, appState, invoice: invoice),
                      onSignOrShare: () => _showSignOrShareInvoiceDialog(context, invoice, appState),
                      onStatusChange: (status) => appState.updateInvoiceStatus(invoice.id, status),
                      onDelete: () => _confirmDelete(context, invoice, appState),
                    );
                  },
                ),
        ),
      ],
    );
  }

  PopupMenuItem<InvoiceSort> _sortMenuItem(InvoiceSort val, String label, IconData icon) {
    final isSelected = _sort == val;
    return PopupMenuItem(
      value: val,
      child: Row(
        children: [
          Icon(icon, size: 16, color: isSelected ? _gold : _white70),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: isSelected ? _gold : Colors.white, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
        ],
      ),
    );
  }

  void _showSignOrShareInvoiceDialog(BuildContext context, Invoice invoice, AppState state) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161B26),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
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
                Expanded(
                  child: Text('Client Review & Signature — ${invoice.id}',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Send a review link, capture a signature on-device, or sync a signature already submitted by the client online.',
              style: TextStyle(color: _white70, fontSize: 13),
            ),
            const SizedBox(height: 16),
            // Option 1: Send Review Link
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.link_rounded, color: Colors.greenAccent),
              ),
              title: const Text('Send Review Link to Client', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: const Text('Client opens link in their browser, signs, and signature appears here automatically', style: TextStyle(color: _white70, fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                _showInvoiceReviewLinkDialog(context, invoice, state);
              },
            ),
            const SizedBox(height: 6),
            // Option 2: Capture Now
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: _gold.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.edit, color: _gold),
              ),
              title: const Text('Capture Signature Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: const Text('Client signs on this screen, generates a certified PDF', style: TextStyle(color: _white70, fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => SignaturePage(invoice: invoice)),
                );
              },
            ),
            const SizedBox(height: 6),
            // Option 3: Check Cloud
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.teal.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.sync, color: Colors.teal),
              ),
              title: const Text('Check / Sync Signature from Cloud', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: const Text('Fetch client signature from Firebase if signed remotely on their browser', style: TextStyle(color: _white70, fontSize: 12)),
              onTap: () async {
                Navigator.pop(context);
                final found = await state.checkCloudSignatureForInvoice(invoice.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(found
                          ? '✓ Cloud signature retrieved! Invoice is now signed.'
                          : 'No remote signature found in cloud yet. Client has not signed.'),
                      backgroundColor: found ? const Color(0xFF10B981) : Colors.orange,
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 6),
            // Option 4: Export HTML
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.html_outlined, color: Colors.blue),
              ),
              title: const Text('Export Client Review Webpage', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: const Text('Self-contained HTML file the client opens in any browser to review & sign', style: TextStyle(color: _white70, fontSize: 12)),
              onTap: () async {
                Navigator.pop(context);
                await _exportInvoiceHtml(invoice, state);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showInvoiceReviewLinkDialog(BuildContext context, Invoice invoice, AppState state) {
    CloudSyncService().saveInvoice(invoice);
    final server = ReviewServerService();
    final url = server.getReviewUrl(type: 'invoice', id: invoice.id);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _border)),
        title: Row(
          children: [
            const Icon(Icons.link, color: _gold, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Client Review Link — ${invoice.id}',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Send this link to the client. They can review the invoice, sign in their browser (no app required), and the signature returns to QuotiMate automatically.',
              style: TextStyle(color: _white70, fontSize: 13),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8), border: Border.all(color: _border)),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      url,
                      style: const TextStyle(color: _gold, fontSize: 12, fontFamily: 'monospace'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, color: Colors.white, size: 18),
                    tooltip: 'Copy Link',
                    onPressed: () {
                      // ignore: avoid_build_context_in_providers
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Review link copied to clipboard!'), backgroundColor: Color(0xFF10B981)),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _gold,
                  foregroundColor: const Color(0xFF1E2733),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.share, size: 16),
                label: const Text('Share Webpage File', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: () {
                  Navigator.pop(ctx);
                  _exportInvoiceHtml(invoice, state);
                },
              ),
            ),
          ],
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

  Future<void> _exportInvoiceHtml(Invoice invoice, AppState state) async {
    try {
      // Sync to cloud so Firestore REST write-back can work
      CloudSyncService().saveInvoice(invoice);
      final serverUrl = ReviewServerService().isRunning
          ? 'http://${ReviewServerService().localIp}:${ReviewServerService().port}'
          : null;
      final html = HtmlReviewService.generateInvoiceHtml(invoice, state, serverUrl: serverUrl);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/Invoice_${invoice.id}_Review.html');
      await file.writeAsString(html, encoding: utf8);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported client review HTML to ${file.path}'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      await Printing.sharePdf(bytes: await file.readAsBytes(), filename: 'Invoice_${invoice.id}_Review.html');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  // ─── Open Invoice PDF ───────────────────────────────────────────────────────
  void _openInvoicePdf(BuildContext context, Invoice invoice, AppState appState) {
    final safeNo = invoice.id.replaceAll(RegExp(r'[^\w\.-]'), '_');
    final isSigned = invoice.signatureData != null && invoice.signatureData!.isNotEmpty;

    PdfViewerPage.openDocumentPdf(
      context: context,
      title: 'Invoice ${invoice.id}',
      filename: 'Invoice_$safeNo.pdf',
      onEdit: () => openEnquiryInvoicePage(context, appState, invoice: invoice),
      buildPdf: (pageFormat) async {
        if (isSigned) {
          return PdfService.generateSignedInvoicePdf(
            invoice,
            appState,
            base64Decode(invoice.signatureData!),
            invoice.signedAt ?? DateTime.now(),
          );
        }

        // If there's a matching quote for this quoteId, generate using quote
        final matchingQuote = appState.quotes.where((q) => q.id == invoice.quoteId).firstOrNull;
        if (matchingQuote != null) {
          return PdfService.generateQuotePdf(matchingQuote, appState);
        }

        // Otherwise generate clean Majuma Enquiry Invoice PDF
        return PdfService.generateEnquiryInvoicePdf(
          state: appState,
          customerName: invoice.clientName.isEmpty ? 'Valued Customer' : invoice.clientName,
          telephone: '',
          kraPin: invoice.kraPin,
          quotationNo: invoice.id,
          date: invoice.date,
          agreedTotal: invoice.amount,
          depositPct: 50,
          midPct: 25,
          completionPct: 25,
          requestLabel: 'Invoice Amount Request',
          requestAmount: invoice.amount,
          nb: '',
          preparedBy: appState.preparedBy,
          terms: '1. Terms Inclusive of VAT where applicable\n2. Quotation valid for 7 days',
          categories: invoice.categories,
        );
      },
    );
  }

  // ─── Delete Invoice Confirmation ───────────────────────────────────────────
  void _confirmDelete(BuildContext context, Invoice invoice, AppState appState) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: _border),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 22),
            SizedBox(width: 8),
            Text('Delete Invoice?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete Invoice "${invoice.id}" for ${invoice.clientName}?',
              style: const TextStyle(color: _white70, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.cloud_off_rounded, color: Colors.redAccent, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Warning: This invoice will also be permanently deleted from your Cloud backup and synced devices. This action cannot be undone.',
                      style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: _white38)),
          ),
          FilledButton(
            onPressed: () {
              appState.deleteInvoice(invoice.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Deleted Invoice ${invoice.id} from local & cloud storage'),
                  backgroundColor: Colors.redAccent,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
  }

  // ─── KPI Card ──────────────────────────────────────────────────────────────
  Widget _kpi(String label, String value, IconData icon, Color color) {
    return SizedBox(
      width: 175,
      child: Card(
        color: _surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: _border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: TextStyle(color: color, fontSize: 17, fontWeight: FontWeight.w800),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: const TextStyle(color: _white54, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterChip(String label, InvoiceStatus? status) {
    final selected = _filterStatus == status;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.black : _white70,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
      ),
      selected: selected,
      selectedColor: _gold,
      backgroundColor: _surface,
      checkmarkColor: Colors.black,
      side: BorderSide(color: selected ? _gold : _border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onSelected: (_) => setState(() => _filterStatus = selected ? null : status),
    );
  }

  String _fmtKpi(double v) {
    if (v >= 1000000) return 'KES ${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return 'KES ${(v / 1000).toStringAsFixed(0)}K';
    return 'KES ${v.toStringAsFixed(0)}';
  }
}

// ─── Sleek Invoice Card ───────────────────────────────────────────────────────
class _InvoiceCard extends StatelessWidget {
  final Invoice invoice;
  final NumberFormat currencyFmt;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onSignOrShare;
  final ValueChanged<InvoiceStatus> onStatusChange;
  final VoidCallback onDelete;

  const _InvoiceCard({
    required this.invoice,
    required this.currencyFmt,
    required this.onTap,
    required this.onEdit,
    required this.onSignOrShare,
    required this.onStatusChange,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final inv = invoice;
    final isSigned = inv.signatureData != null && inv.signatureData!.isNotEmpty;
    final isOverdue = inv.dueDate.isBefore(DateTime.now()) && inv.status != InvoiceStatus.paid;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: ID Badge + Client Name & Status
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Invoice ID Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _gold.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _gold.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        inv.id,
                        style: const TextStyle(
                          color: _gold,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Client Name
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.person_outline, color: _white54, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              inv.clientName.isNotEmpty ? inv.clientName : 'Valued Customer',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (isSigned) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF10B981)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle, color: Color(0xFF10B981), size: 12),
                            SizedBox(width: 4),
                            Text('Signed', style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],

                    // Status Badge
                    _StatusBadge(status: inv.status),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(color: _border, height: 1),
                const SizedBox(height: 12),

                // Middle Details & Metadata Row
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (inv.quoteId.isNotEmpty && inv.quoteId != inv.id) ...[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.description_outlined, color: _white38, size: 14),
                          const SizedBox(width: 4),
                          Text('Ref: ${inv.quoteId}', style: const TextStyle(color: _white70, fontSize: 12)),
                        ],
                      ),
                    ],
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_today_outlined, color: _white38, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('dd MMM yyyy').format(inv.date),
                          style: const TextStyle(color: _white70, fontSize: 12),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.event_available_outlined,
                          color: isOverdue ? Colors.redAccent : _white38,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Due: ${DateFormat('dd MMM yyyy').format(inv.dueDate)}',
                          style: TextStyle(
                            color: isOverdue ? Colors.redAccent : _white70,
                            fontSize: 12,
                            fontWeight: isOverdue ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Bottom Row: Total Amount + Quick Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      currencyFmt.format(inv.amount),
                      style: const TextStyle(
                        color: _gold,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, color: Colors.white70, size: 20),
                          tooltip: 'Edit Invoice',
                          onPressed: onEdit,
                        ),
                        IconButton(
                          icon: const Icon(Icons.picture_as_pdf, color: Colors.white70, size: 20),
                          tooltip: 'View & Share PDF',
                          onPressed: onTap,
                        ),
                        IconButton(
                          icon: Icon(
                            isSigned ? Icons.draw_outlined : Icons.edit_document,
                            color: isSigned ? const Color(0xFF10B981) : _gold,
                            size: 20,
                          ),
                          tooltip: isSigned ? 'Signed (Options)' : 'Sign / Share Review',
                          onPressed: onSignOrShare,
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, color: Colors.white54, size: 20),
                          color: const Color(0xFF0F162C),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: const BorderSide(color: _border),
                          ),
                          onSelected: (val) {
                            if (val == 'view_pdf') {
                              onTap();
                            } else if (val == 'edit') {
                              onEdit();
                            } else if (val == 'sign_share') {
                              onSignOrShare();
                            } else if (val == 'delete') {
                              onDelete();
                            } else {
                              final status = InvoiceStatus.values.firstWhere((e) => e.name == val);
                              onStatusChange(status);
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'view_pdf',
                              child: Row(
                                children: [
                                  Icon(Icons.picture_as_pdf, color: _gold, size: 16),
                                  SizedBox(width: 8),
                                  Text('View & Share PDF', style: TextStyle(color: Colors.white)),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'sign_share',
                              child: Row(
                                children: [
                                  Icon(Icons.draw_outlined, color: _gold, size: 16),
                                  SizedBox(width: 8),
                                  Text('Sign / Share Webpage', style: TextStyle(color: Colors.white)),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_outlined, color: Colors.white70, size: 16),
                                  SizedBox(width: 8),
                                  Text('Edit Invoice', style: TextStyle(color: Colors.white)),
                                ],
                              ),
                            ),
                            const PopupMenuDivider(),
                            ...InvoiceStatus.values.map((s) => PopupMenuItem(
                              value: s.name,
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(shape: BoxShape.circle, color: s.color),
                                  ),
                                  const SizedBox(width: 8),
                                  Text('Mark as ${s.label}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                ],
                              ),
                            )),
                            const PopupMenuDivider(),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline, color: Colors.redAccent, size: 16),
                                  SizedBox(width: 8),
                                  Text('Delete Invoice', style: TextStyle(color: Colors.redAccent)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Status Badge Widget ──────────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final InvoiceStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: status.color.withValues(alpha: 0.4)),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: status.color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
