// pages/quotes_page.dart — QuotiMate Quotations Page
// Sleek, modern cards matching the QuotiMate design system (Invoices & Dashboard), fully clickable with PDF preview and status management.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_state.dart';
import '../models.dart';
import 'quote_editor_page.dart';
import 'quote_sign_share_sheet.dart';
import 'pdf_viewer_page.dart';
import '../widgets/money_text.dart';

// ─── Design Tokens (Dark-Blue Theme) ──────────────────────────────────────────
const _surface = Color(0xFF161B26);
const _border  = Color(0xFF2A3045);
const _gold    = Color(0xFFFFC107);
const _white38 = Color(0xFF616C88);
const _white54 = Colors.white54;
const _white70 = Color(0xFFB0B8D0);

enum QuoteSort { dateDesc, dateAsc, amountDesc, amountAsc, client, status }

class QuotesPage extends StatefulWidget {
  const QuotesPage({super.key});

  @override
  State<QuotesPage> createState() => _QuotesPageState();
}

class _QuotesPageState extends State<QuotesPage> {
  QuoteStatus? _filterStatus;
  String _search = '';
  QuoteSort _sort = QuoteSort.dateDesc;

  @override
  Widget build(BuildContext context) {
    final appState = AppStateProvider.of(context);
    final currency = appState.currency;
    final filtered = appState.quotes.where((q) {
      final matchStatus = _filterStatus == null || q.status == _filterStatus;
      final matchSearch = _search.isEmpty ||
          q.id.toLowerCase().contains(_search) ||
          q.clientName.toLowerCase().contains(_search);
      return matchStatus && matchSearch;
    }).toList();

    switch (_sort) {
      case QuoteSort.dateDesc:
        filtered.sort((a, b) => b.date.compareTo(a.date));
        break;
      case QuoteSort.dateAsc:
        filtered.sort((a, b) => a.date.compareTo(b.date));
        break;
      case QuoteSort.amountDesc:
        filtered.sort((a, b) => b.total.compareTo(a.total));
        break;
      case QuoteSort.amountAsc:
        filtered.sort((a, b) => a.total.compareTo(b.total));
        break;
      case QuoteSort.client:
        filtered.sort((a, b) => a.clientName.toLowerCase().compareTo(b.clientName.toLowerCase()));
        break;
      case QuoteSort.status:
        filtered.sort((a, b) => a.status.index.compareTo(b.status.index));
        break;
    }

    // Aggregate KPIs
    final totalAmount = appState.quotes.fold<double>(0, (s, q) => s + q.total);
    final approvedAmount = appState.quotes
        .where((q) => q.status == QuoteStatus.approved)
        .fold<double>(0, (s, q) => s + q.total);
    final pendingCount =
        appState.quotes.where((q) => q.status == QuoteStatus.pending).length;
    final expiredCount =
        appState.quotes.where((q) => q.status == QuoteStatus.expired).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── KPI Strip ───────────────────────────────────────────────────────
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _kpi('Total Quotes', _fmtKpi(totalAmount, currency), Icons.description_outlined, _gold),
              const SizedBox(width: 12),
              _kpi('Approved', _fmtKpi(approvedAmount, currency), Icons.check_circle_outline, Colors.green),
              const SizedBox(width: 12),
              _kpi('Pending', '$pendingCount pending', Icons.hourglass_top, Colors.orange),
              const SizedBox(width: 12),
              _kpi('Expired', '$expiredCount expired', Icons.warning_amber_rounded, Colors.purpleAccent),
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
                    hintText: 'Search quotations or clients...',
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
            PopupMenuButton<QuoteSort>(
              tooltip: 'Sort Quotes',
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
                _sortMenuItem(QuoteSort.dateDesc, 'Date: Newest First', Icons.calendar_today),
                _sortMenuItem(QuoteSort.dateAsc, 'Date: Oldest First', Icons.history),
                _sortMenuItem(QuoteSort.amountDesc, 'Amount: High to Low', Icons.arrow_downward),
                _sortMenuItem(QuoteSort.amountAsc, 'Amount: Low to High', Icons.arrow_upward),
                _sortMenuItem(QuoteSort.client, 'Client Name', Icons.person_outline),
                _sortMenuItem(QuoteSort.status, 'Status', Icons.flag_outlined),
              ],
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: () => _showQuoteDialog(context, appState),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New Quote', style: TextStyle(fontWeight: FontWeight.bold)),
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
              _filterChip('All (${appState.quotes.length})', null),
              const SizedBox(width: 8),
              ...QuoteStatus.values.map((s) {
                final count = appState.quotes.where((q) => q.status == s).length;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _filterChip('${s.label} ($count)', s),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── Quotes List ─────────────────────────────────────────────────────
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.description_outlined, color: _gold.withValues(alpha: 0.3), size: 48),
                      const SizedBox(height: 12),
                      const Text('No quotations found.', style: TextStyle(color: _white70, fontSize: 15)),
                      const SizedBox(height: 6),
                      const Text('Create a new quotation to get started.', style: TextStyle(color: _white38, fontSize: 13)),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final quote = filtered[index];
                    return _QuoteCard(
                      quote: quote,
                      currency: currency,
                      onTap: () => PdfViewerPage.openQuotePdf(context, quote, appState),
                      onEdit: () => _showQuoteDialog(context, appState, quote: quote),
                      onSignOrShare: () => showQuoteSignShareSheet(context, quote, appState),
                      onStatusChange: (status) {
                        quote.status = status;
                        appState.updateQuote(quote);
                      },
                      onDelete: () => _confirmDelete(context, quote, appState),
                    );
                  },
                ),
        ),
      ],
    );
  }

  PopupMenuItem<QuoteSort> _sortMenuItem(QuoteSort val, String label, IconData icon) {
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

  void _showQuoteDialog(BuildContext context, AppState appState, {Quote? quote}) {
    openQuoteEditorPage(context, appState, quote: quote);
  }

  // ─── Delete Quote Confirmation ─────────────────────────────────────────────
  void _confirmDelete(BuildContext context, Quote quote, AppState appState) {
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
            Text('Delete Quotation?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete Quotation "${quote.id}" for ${quote.clientName}?',
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
                      'Warning: This quote will also be permanently deleted from your Cloud backup and synced devices. This action cannot be undone.',
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
              appState.deleteQuote(quote.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Deleted Quotation ${quote.id} from local & cloud storage'),
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

  Widget _filterChip(String label, QuoteStatus? status) {
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

  String _fmtKpi(double v, String currency) => formatCompactAmount(v, currency);
}

// ─── Sleek Quote Card ─────────────────────────────────────────────────────────
class _QuoteCard extends StatelessWidget {
  final Quote quote;
  final String currency;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onSignOrShare;
  final ValueChanged<QuoteStatus> onStatusChange;
  final VoidCallback onDelete;

  const _QuoteCard({
    required this.quote,
    required this.currency,
    required this.onTap,
    required this.onEdit,
    required this.onSignOrShare,
    required this.onStatusChange,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final q = quote;
    final isSigned = q.signatureData != null && q.signatureData!.isNotEmpty;
    final isExpired = q.expiryDate.isBefore(DateTime.now()) &&
        q.status != QuoteStatus.approved &&
        q.status != QuoteStatus.rejected;
    final totalItems = q.categories.fold<int>(0, (sum, cat) => sum + cat.items.length);

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
                    // Quote ID Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _gold.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _gold.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        q.id,
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
                              q.clientName.isNotEmpty ? q.clientName : 'Valued Customer',
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
                    _StatusBadge(status: q.status),
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
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_today_outlined, color: _white38, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('dd MMM yyyy').format(q.date),
                          style: const TextStyle(color: _white70, fontSize: 12),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.event_available_outlined,
                          color: isExpired ? Colors.purpleAccent : _white38,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Expires: ${DateFormat('dd MMM yyyy').format(q.expiryDate)}',
                          style: TextStyle(
                            color: isExpired ? Colors.purpleAccent : _white70,
                            fontSize: 12,
                            fontWeight: isExpired ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    if (totalItems > 0)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.inventory_2_outlined, color: _white38, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            '$totalItems ${totalItems == 1 ? 'item' : 'items'}',
                            style: const TextStyle(color: _white70, fontSize: 12),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Bottom Row: Total Amount + Quick Actions
                Wrap(
                  spacing: 6,
                  runSpacing: 2,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    MoneyText(
                      formatAmount(q.total, currency),
                      maxWidth: 220,
                      alignment: Alignment.centerLeft,
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
                          tooltip: 'Edit Quote',
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
                              final status = QuoteStatus.values.firstWhere((e) => e.name == val);
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
                                  Text('Edit Quote', style: TextStyle(color: Colors.white)),
                                ],
                              ),
                            ),
                            const PopupMenuDivider(),
                            ...QuoteStatus.values.map((s) => PopupMenuItem(
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
                                  Text('Delete Quote', style: TextStyle(color: Colors.redAccent)),
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
  final QuoteStatus status;
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


