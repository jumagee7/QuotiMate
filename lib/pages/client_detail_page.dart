// pages/client_detail_page.dart — QuotiMate Client Detail Page
// Shows client info + 3 tabs: Quotes, Invoices, Projects done for this client.

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import '../app_state.dart';
import '../models.dart';
import '../services/html_review_service.dart';
import '../services/cloud_sync_service.dart';
import '../services/review_server_service.dart';
import 'quote_editor_page.dart';
import 'enquiry_invoice_page.dart';
import 'pdf_viewer_page.dart';
import 'signature_page.dart';
import 'project_quickbook_page.dart';
import '../widgets/money_text.dart';
import '../widgets/scrollable_panel.dart';
import '../widgets/send_contact_buttons.dart';

const _cSurface = Color(0xFF161B26);
const _cBorder  = Color(0xFF2A3045);
const _cGold    = Color(0xFFFFC107);
const _cW38     = Color(0xFF616C88);
const _cW70     = Color(0xFFB0B8D0);

class ClientDetailPage extends StatefulWidget {
  final Client client;
  const ClientDetailPage({super.key, required this.client});

  @override
  State<ClientDetailPage> createState() => _ClientDetailPageState();
}

class _ClientDetailPageState extends State<ClientDetailPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _dateFmt = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateProvider.of(context);
    // Find client in state to stay reactive if updated
    final client = appState.clients.firstWhere(
      (c) => c.id == widget.client.id,
      orElse: () => widget.client,
    );

    final quotes = appState.quotes.where((q) => q.clientId == client.id).toList();
    final invoices = appState.invoices.where((i) => i.clientId == client.id).toList();
    final projects = appState.projects.where((p) => p.clientId == client.id).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0B0E17),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F162C),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(client.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: _cGold),
            tooltip: 'Edit Client Info',
            onPressed: () => _showEditClientDialog(context, appState, client),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Client Header Card ─────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _cSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _cBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: _cGold.withValues(alpha: 0.15),
                      child: Text(
                        client.name.isNotEmpty ? client.name[0].toUpperCase() : '?',
                        style: const TextStyle(color: _cGold, fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            client.name,
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          if (client.company.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              client.company,
                              style: const TextStyle(color: _cGold, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 16,
                            runSpacing: 6,
                            children: [
                              if (client.phone.isNotEmpty)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.phone_outlined, size: 14, color: _cW38),
                                    const SizedBox(width: 4),
                                    Flexible(child: Text(client.phone, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _cW70, fontSize: 12))),
                                  ],
                                ),
                              if (client.email.isNotEmpty)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.email_outlined, size: 14, color: _cW38),
                                    const SizedBox(width: 4),
                                    Flexible(child: Text(client.email, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _cW70, fontSize: 12))),
                                  ],
                                ),
                              if (client.address.isNotEmpty)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.location_on_outlined, size: 14, color: _cW38),
                                    const SizedBox(width: 4),
                                    Flexible(child: Text(client.address, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _cW70, fontSize: 12))),
                                  ],
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(color: _cBorder, height: 1),
                const SizedBox(height: 12),
                // Quick KPI Badges
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _kpiBadge('Quotes', quotes.length.toString(), _cGold),
                    _kpiBadge('Invoices', invoices.length.toString(), const Color(0xFF34D399)),
                    _kpiBadge('Projects', projects.length.toString(), const Color(0xFF60A5FA)),
                  ],
                ),
              ],
            ),
          ),

          // ── Tabs ───────────────────────────────────────────────────────────
          Container(
            color: const Color(0xFF0F162C),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: _cGold,
              labelColor: _cGold,
              unselectedLabelColor: _cW70,
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.article_outlined, size: 18),
                      const SizedBox(width: 6),
                      Text('Quotes (${quotes.length})'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.receipt_long_outlined, size: 18),
                      const SizedBox(width: 6),
                      Text('Invoices (${invoices.length})'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.business_center_outlined, size: 18),
                      const SizedBox(width: 6),
                      Text('Projects (${projects.length})'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Tab Views ──────────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildQuotesTab(context, appState, quotes, client),
                _buildInvoicesTab(context, appState, invoices, client),
                _buildProjectsTab(context, appState, projects, client),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpiBadge(String label, String count, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 6),
        Text('$count $label', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }

  // ── Quotes Tab ─────────────────────────────────────────────────────────────
  Widget _buildQuotesTab(BuildContext context, AppState appState, List<Quote> quotes, Client client) {
    if (quotes.isEmpty) {
      return _emptyState(
        icon: Icons.article_outlined,
        title: 'No Quotes for ${client.name}',
        subtitle: 'Create a quotation tailored for this client.',
        buttonLabel: 'Create Quote',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => QuoteEditorPage(
                appState: appState,
              ),
            ),
          );
        },
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: quotes.length,
      itemBuilder: (context, i) {
        final q = quotes[i];
        final isSigned = q.signatureData != null && q.signatureData!.isNotEmpty;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: _cSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _cBorder),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        q.id,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
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
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: q.status.color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: q.status.color.withValues(alpha: 0.5)),
                          ),
                          child: Text(
                            q.status.label,
                            style: TextStyle(color: q.status.color, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, color: _cW38, size: 12),
                    const SizedBox(width: 4),
                    Flexible(child: Text(_dateFmt.format(q.date), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _cW70, fontSize: 12))),
                    const SizedBox(width: 14),
                    const Icon(Icons.event_available_outlined, color: _cW38, size: 12),
                    const SizedBox(width: 4),
                    Text('Exp: ${_dateFmt.format(q.expiryDate)}', style: const TextStyle(color: _cW70, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 2,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    MoneyText(
                      formatAmount(q.total, appState.currency),
                      maxWidth: 200,
                      alignment: Alignment.centerLeft,
                      style: const TextStyle(color: _cGold, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // View / Share PDF
                        IconButton(
                          icon: const Icon(Icons.picture_as_pdf, color: Colors.white70, size: 18),
                          tooltip: 'View PDF',
                          onPressed: () => _openQuotePdf(context, q, appState),
                        ),
                        // Sign / Share Link
                        IconButton(
                          icon: Icon(isSigned ? Icons.draw_outlined : Icons.edit_document, color: _cGold, size: 18),
                          tooltip: isSigned ? 'View / Resign' : 'Sign / Share',
                          onPressed: () => _showSignOrShareQuoteDialog(context, q, appState),
                        ),
                        // Edit
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, color: Colors.white54, size: 18),
                          tooltip: 'Edit Quote',
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => QuoteEditorPage(appState: appState, quote: q)),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Invoices Tab ───────────────────────────────────────────────────────────
  Widget _buildInvoicesTab(BuildContext context, AppState appState, List<Invoice> invoices, Client client) {
    if (invoices.isEmpty) {
      return _emptyState(
        icon: Icons.receipt_long_outlined,
        title: 'No Invoices for ${client.name}',
        subtitle: 'Create an invoice or convert an approved quote.',
        buttonLabel: 'Create Invoice',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EnquiryInvoicePage(
                appState: appState,
              ),
            ),
          );
        },
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: invoices.length,
      itemBuilder: (context, i) {
        final inv = invoices[i];
        final isSigned = inv.signatureData != null && inv.signatureData!.isNotEmpty;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: _cSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _cBorder),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        inv.id,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
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
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: inv.status.color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: inv.status.color.withValues(alpha: 0.5)),
                          ),
                          child: Text(
                            inv.status.label,
                            style: TextStyle(color: inv.status.color, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, color: _cW38, size: 12),
                    const SizedBox(width: 4),
                    Flexible(child: Text(_dateFmt.format(inv.date), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _cW70, fontSize: 12))),
                    const SizedBox(width: 14),
                    const Icon(Icons.event_available_outlined, color: _cW38, size: 12),
                    const SizedBox(width: 4),
                    Text('Due: ${_dateFmt.format(inv.dueDate)}', style: const TextStyle(color: _cW70, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 2,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    MoneyText(
                      formatAmount(inv.amount, appState.currency),
                      maxWidth: 200,
                      alignment: Alignment.centerLeft,
                      style: const TextStyle(color: Color(0xFF34D399), fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // View / Share PDF
                        IconButton(
                          icon: const Icon(Icons.picture_as_pdf, color: Colors.white70, size: 18),
                          tooltip: 'View PDF',
                          onPressed: () => _openInvoicePdf(context, inv, appState),
                        ),
                        // Sign / Share Link
                        IconButton(
                          icon: Icon(isSigned ? Icons.draw_outlined : Icons.edit_document, color: _cGold, size: 18),
                          tooltip: isSigned ? 'View / Resign' : 'Sign / Share',
                          onPressed: () => _showSignOrShareInvoiceDialog(context, inv, appState),
                        ),
                        // Edit
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, color: Colors.white54, size: 18),
                          tooltip: 'Edit Invoice',
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => EnquiryInvoicePage(appState: appState, invoice: inv)),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Projects Tab ───────────────────────────────────────────────────────────
  Widget _buildProjectsTab(BuildContext context, AppState appState, List<Project> projects, Client client) {
    if (projects.isEmpty) {
      return _emptyState(
        icon: Icons.business_center_outlined,
        title: 'No Projects for ${client.name}',
        subtitle: 'Start a project to track milestones, quotes, invoices, and expenses.',
        buttonLabel: 'Create Project',
        onPressed: () => _showCreateProjectDialog(context, appState, client),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: projects.length,
      itemBuilder: (context, i) {
        final p = projects[i];
        final collected = p.totalPaymentsReceived;
        final profit = p.netProfitRealized();

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: _cSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _cBorder),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => openProjectQuickBookPage(context, projectId: p.id),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            p.name,
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: p.status.color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: p.status.color.withValues(alpha: 0.5)),
                          ),
                          child: Text(
                            p.status.label,
                            style: TextStyle(color: p.status.color, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    if (p.location.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.place_outlined, size: 12, color: _cW38),
                          const SizedBox(width: 4),
                          Flexible(child: Text(p.location, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _cW70, fontSize: 12))),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('BUDGET', style: TextStyle(color: _cW38, fontSize: 10, fontWeight: FontWeight.w600)),
                              MoneyText(formatAmount(p.budget, appState.currency), maxWidth: 108, alignment: Alignment.centerLeft, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('COLLECTED', style: TextStyle(color: _cW38, fontSize: 10, fontWeight: FontWeight.w600)),
                              MoneyText(formatAmount(collected, appState.currency), maxWidth: 108, alignment: Alignment.centerLeft, style: const TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('PROFIT', style: TextStyle(color: _cW38, fontSize: 10, fontWeight: FontWeight.w600)),
                              MoneyText(
                                formatAmount(profit, appState.currency),
                                maxWidth: 108,
                                style: TextStyle(
                                  color: profit >= 0 ? const Color(0xFF34D399) : Colors.redAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Helper Empty State ─────────────────────────────────────────────────────
  Widget _emptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required String buttonLabel,
    required VoidCallback onPressed,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: _cGold.withValues(alpha: 0.3)),
            const SizedBox(height: 14),
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(subtitle, style: const TextStyle(color: _cW70, fontSize: 13), textAlign: TextAlign.center),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.add, size: 16),
              label: Text(buttonLabel),
              style: FilledButton.styleFrom(
                backgroundColor: _cGold,
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── PDF Helpers ────────────────────────────────────────────────────────────
  void _openQuotePdf(BuildContext context, Quote quote, AppState state) {
    PdfViewerPage.openQuotePdf(context, quote, state);
  }

  void _openInvoicePdf(BuildContext context, Invoice invoice, AppState state) {
    PdfViewerPage.openInvoicePdf(context, invoice, state);
  }

  // ── Sign or Share Dialogs ──────────────────────────────────────────────────
  void _showSignOrShareQuoteDialog(BuildContext context, Quote quote, AppState state) {
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
                const Icon(Icons.draw_outlined, color: _cGold),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Client Review & Signature — ${quote.id}',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Send a review link, capture a signature on-device, or sync a signature already submitted by the client online.',
              style: TextStyle(color: _cW70, fontSize: 13),
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
              subtitle: const Text('Client opens link in their browser, signs, and signature appears here automatically', style: TextStyle(color: _cW70, fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                _showQuoteReviewLinkDialog(context, quote, state);
              },
            ),
            const SizedBox(height: 6),
            // Option 2: Capture Now
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: _cGold.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.edit, color: _cGold),
              ),
              title: const Text('Capture Signature Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: const Text('Client signs on this device, generates a certified PDF', style: TextStyle(color: _cW70, fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => SignaturePage(quote: quote)),
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
              subtitle: const Text('Fetch client signature from Firebase if signed remotely on their browser', style: TextStyle(color: _cW70, fontSize: 12)),
              onTap: () async {
                Navigator.pop(context);
                final found = await state.checkCloudSignatureForQuote(quote.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(found
                          ? '✓ Cloud signature retrieved! Quote is now signed.'
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
              subtitle: const Text('Self-contained HTML file the client opens in any browser to review & sign', style: TextStyle(color: _cW70, fontSize: 12)),
              onTap: () async {
                Navigator.pop(context);
                await _exportQuoteHtml(quote, state);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showQuoteReviewLinkDialog(BuildContext context, Quote quote, AppState state) {
    CloudSyncService().saveQuote(quote);
    final server = ReviewServerService();
    final url = server.getReviewUrl(type: 'quote', id: quote.id);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _cBorder)),
        title: Row(
          children: [
            const Icon(Icons.link, color: _cGold, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Client Review Link — ${quote.id}',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: ScrollablePanel(
          maxHeightFactor: 0.6,
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Send this link to the client. They can review and sign in their browser (no app required), and the signature returns to QuotiMate automatically.',
              style: TextStyle(color: _cW70, fontSize: 13),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8), border: Border.all(color: _cBorder)),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      url,
                      style: const TextStyle(color: _cGold, fontSize: 12, fontFamily: 'monospace'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, color: Colors.white, size: 18),
                    tooltip: 'Copy Link',
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Review link copied!'), backgroundColor: Color(0xFF10B981)),
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
                  backgroundColor: _cGold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.share, size: 16),
                label: const Text('Share Webpage File', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: () {
                  Navigator.pop(ctx);
                  _exportQuoteHtml(quote, state);
                },
              ),
            ),
            const SizedBox(height: 14),
            const Divider(color: _cBorder, height: 1),
            const SizedBox(height: 10),
            const Text(
              'Send directly — the client\'s WhatsApp number or email is saved to their record.',
              style: TextStyle(color: _cW38, fontSize: 11.5),
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
            child: const Text('Close', style: TextStyle(color: _cW70)),
          ),
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
                const Icon(Icons.draw_outlined, color: _cGold),
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
              style: TextStyle(color: _cW70, fontSize: 13),
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
              subtitle: const Text('Client opens link in browser, signs, and signature appears here automatically', style: TextStyle(color: _cW70, fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                _showInvoiceReviewLinkDialogCd(context, invoice, state);
              },
            ),
            const SizedBox(height: 6),
            // Option 2: Capture Now
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: _cGold.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.edit, color: _cGold),
              ),
              title: const Text('Capture Signature Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: const Text('Client signs on this device, generates a certified PDF', style: TextStyle(color: _cW70, fontSize: 12)),
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
              subtitle: const Text('Fetch client signature from Firebase if signed remotely on their browser', style: TextStyle(color: _cW70, fontSize: 12)),
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
              subtitle: const Text('Self-contained HTML file the client opens in any browser to review & sign', style: TextStyle(color: _cW70, fontSize: 12)),
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

  void _showInvoiceReviewLinkDialogCd(BuildContext context, Invoice invoice, AppState state) {
    CloudSyncService().saveInvoice(invoice);
    final server = ReviewServerService();
    final url = server.getReviewUrl(type: 'invoice', id: invoice.id);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _cBorder)),
        title: Row(
          children: [
            const Icon(Icons.link, color: _cGold, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Client Review Link — ${invoice.id}',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: ScrollablePanel(
          maxHeightFactor: 0.6,
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Send this link to the client. They can review and sign in their browser (no app required), and the signature returns to QuotiMate automatically.',
              style: TextStyle(color: _cW70, fontSize: 13),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8), border: Border.all(color: _cBorder)),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      url,
                      style: const TextStyle(color: _cGold, fontSize: 12, fontFamily: 'monospace'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, color: Colors.white, size: 18),
                    tooltip: 'Copy Link',
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Review link copied!'), backgroundColor: Color(0xFF10B981)),
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
                  backgroundColor: _cGold,
                  foregroundColor: Colors.black,
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
            const SizedBox(height: 14),
            const Divider(color: _cBorder, height: 1),
            const SizedBox(height: 10),
            const Text(
              'Send directly — the client\'s WhatsApp number or email is saved to their record.',
              style: TextStyle(color: _cW38, fontSize: 11.5),
            ),
            const SizedBox(height: 8),
            SendContactButtons(
              appState: state,
              clientId: invoice.clientId,
              clientName: invoice.clientName,
              docLabel: 'Invoice ${invoice.id}',
              url: url,
            ),
          ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: _cW70)),
          ),
        ],
      ),
    );
  }

  Future<void> _exportQuoteHtml(Quote quote, AppState state) async {
    try {
      CloudSyncService().saveQuote(quote);
      final serverUrl = ReviewServerService().isRunning
          ? 'http://${ReviewServerService().localIp}:${ReviewServerService().port}'
          : null;
      final html = HtmlReviewService.generateQuoteHtml(quote, state, serverUrl: serverUrl);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/Quote_${quote.id}_Review.html');
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
      await Printing.sharePdf(bytes: await file.readAsBytes(), filename: 'Quote_${quote.id}_Review.html');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _exportInvoiceHtml(Invoice invoice, AppState state) async {
    try {
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

  // ── Edit Client Dialog ─────────────────────────────────────────────────────
  void _showEditClientDialog(BuildContext context, AppState appState, Client client) {
    final nameCtrl = TextEditingController(text: client.name);
    final compCtrl = TextEditingController(text: client.company);
    final emailCtrl = TextEditingController(text: client.email);
    final phoneCtrl = TextEditingController(text: client.phone);
    final addrCtrl = TextEditingController(text: client.address);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _cSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: _cBorder)),
        title: const Text('Edit Client', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogField('Client Name', nameCtrl),
              _dialogField('Company', compCtrl),
              _dialogField('Email', emailCtrl),
              _dialogField('Phone', phoneCtrl),
              _dialogField('Address', addrCtrl),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: _cW38))),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              appState.updateClient(client.copyWith(
                name: nameCtrl.text.trim(),
                company: compCtrl.text.trim(),
                email: emailCtrl.text.trim(),
                phone: phoneCtrl.text.trim(),
                address: addrCtrl.text.trim(),
              ));
              Navigator.pop(context);
              setState(() {});
            },
            style: FilledButton.styleFrom(backgroundColor: _cGold, foregroundColor: Colors.black),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _dialogField(
    String label,
    TextEditingController ctrl, {
    List<TextInputFormatter>? inputFormatters,
    String? prefixText,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        inputFormatters: inputFormatters,
        keyboardType: inputFormatters == null
            ? TextInputType.text
            : const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          prefixText: prefixText,
          labelStyle: const TextStyle(color: _cW70, fontSize: 12),
          filled: true,
          fillColor: const Color(0xFF0F162C),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _cBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _cBorder)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _cGold)),
        ),
      ),
    );
  }

  void _showCreateProjectDialog(BuildContext context, AppState appState, Client client) {
    final nameCtrl = TextEditingController();
    final budgetCtrl = TextEditingController();
    final locCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _cSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: _cBorder)),
        title: Text('New Project for ${client.name}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dialogField('Project Title', nameCtrl),
            _dialogField('Budget (${appState.currency})', budgetCtrl,
                inputFormatters: moneyInputFormatters(),
                prefixText: currencyPrefix(appState.currency)),
            _dialogField('Location / Site', locCtrl),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: _cW38))),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              final p = Project(
                id: 'PRJ-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
                number: appState.nextProjectNumber,
                name: nameCtrl.text.trim(),
                clientId: client.id,
                clientName: client.name,
                startDate: DateTime.now(),
                budget: parseMoney(budgetCtrl.text) ?? 0.0,
                location: locCtrl.text.trim(),
                createdAt: DateTime.now(),
              );
              appState.addProject(p);
              Navigator.pop(context);
              setState(() {});
            },
            style: FilledButton.styleFrom(backgroundColor: _cGold, foregroundColor: Colors.black),
            child: const Text('Create Project'),
          ),
        ],
      ),
    );
  }
}
