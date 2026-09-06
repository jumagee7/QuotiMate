// pages/project_quickbook_page.dart — Project QuickBook & Financial Hub
// Dedicated P&L, Quotations, Invoices, Payments, Bought Products/Expenses, and Statement

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_state.dart';
import '../models.dart';
import '../services/pdf_service.dart';
import 'quote_editor_page.dart';
import 'pdf_viewer_page.dart';

const _bg      = Color(0xFF0B0E17);
const _sidebar = Color(0xFF0F162C);
const _surface = Color(0xFF161B26);
const _border  = Color(0xFF2A3045);
const _gold    = Color(0xFFFFC107);
const _white38 = Color(0xFF616C88);
const _white70 = Color(0xFFB0B8D0);
const _green   = Color(0xFF10B981);
const _red     = Color(0xFFEF4444);
const _blue    = Color(0xFF3B82F6);
const _purple  = Color(0xFF8B5CF6);

Future<void> openProjectQuickBookPage(
  BuildContext context, {
  required String projectId,
  int initialTab = 0,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ProjectQuickBookPage(projectId: projectId, initialTab: initialTab),
    ),
  );
}

class ProjectQuickBookPage extends StatefulWidget {
  final String projectId;
  final int initialTab;
  const ProjectQuickBookPage({
    super.key,
    required this.projectId,
    this.initialTab = 0,
  });

  @override
  State<ProjectQuickBookPage> createState() => _ProjectQuickBookPageState();
}

class _ProjectQuickBookPageState extends State<ProjectQuickBookPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _currencyFmt = NumberFormat.currency(symbol: 'KES ', decimalDigits: 2);
  final _dateFmt = DateFormat('dd MMM yyyy');

  String _fmt(double val) => _currencyFmt.format(val);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 6,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 5),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateProvider.of(context);
    final project = appState.getProject(widget.projectId);

    if (project == null) {
      return Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _sidebar,
          title: const Text('Project Not Found', style: TextStyle(color: Colors.white)),
        ),
        body: const Center(
          child: Text('Project has been deleted or cannot be found.',
              style: TextStyle(color: _white70)),
        ),
      );
    }

    // Linked quotes & invoices
    final linkedQuotes = appState.quotes
        .where((q) => project.quoteIds.contains(q.id) || q.projectId == project.id)
        .toList();
    final linkedInvoices = appState.invoices
        .where((i) => project.invoiceIds.contains(i.id) || i.projectId == project.id)
        .toList();

    // Financial totals
    final totalQuoted = project.totalQuoted(appState.quotes);
    final totalInvoiced = project.totalInvoiced(appState.invoices);
    final totalPaid = project.totalPaymentsReceived;
    final totalExpenses = project.totalExpenses;
    final balance = project.outstandingBalance(appState.invoices, appState.quotes);
    final netProfit = project.netProfitRealized();
    final profitMargin = project.profitMarginRealized();
    final projectedProfit = project.netProfitProjected(appState.invoices, appState.quotes);
    final projectedMargin = project.profitMarginProjected(appState.invoices, appState.quotes);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _sidebar,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _gold),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    project.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _statusBadge(project.status),
              ],
            ),
            Text(
              'Client: ${project.clientName} • ${project.location.isNotEmpty ? project.location : "No location"}',
              style: const TextStyle(color: _white70, fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Edit Project',
            icon: const Icon(Icons.edit_note_rounded, color: Colors.white70),
            onPressed: () => _showEditProjectDialog(context, appState, project),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white70),
            color: _surface,
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'record_payment',
                child: Row(
                  children: [
                    Icon(Icons.add_card_rounded, color: _green, size: 18),
                    SizedBox(width: 10),
                    Text('Record Payment', style: TextStyle(color: Colors.white, fontSize: 13)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'add_expense',
                child: Row(
                  children: [
                    Icon(Icons.shopping_bag_outlined, color: _gold, size: 18),
                    SizedBox(width: 10),
                    Text('Add Bought Product', style: TextStyle(color: Colors.white, fontSize: 13)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'new_quote',
                child: Row(
                  children: [
                    Icon(Icons.request_quote_outlined, color: _blue, size: 18),
                    SizedBox(width: 10),
                    Text('Create Quote', style: TextStyle(color: Colors.white, fontSize: 13)),
                  ],
                ),
              ),
              const PopupMenuDivider(height: 1),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: _red, size: 18),
                    SizedBox(width: 10),
                    Text('Delete Project', style: TextStyle(color: _red, fontSize: 13)),
                  ],
                ),
              ),
            ],
            onSelected: (val) {
              if (val == 'record_payment') {
                _showRecordPaymentDialog(context, appState, project);
              } else if (val == 'add_expense') {
                _showAddExpenseDialog(context, appState, project);
              } else if (val == 'new_quote') {
                _createNewQuoteForProject(context, appState, project);
              } else if (val == 'delete') {
                _confirmDeleteProject(context, appState, project);
              }
            },
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: _gold,
          indicatorWeight: 3,
          labelColor: _gold,
          unselectedLabelColor: _white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: [
            const Tab(icon: Icon(Icons.analytics_outlined, size: 18), text: 'QuickBook P&L'),
            Tab(
              icon: const Icon(Icons.article_outlined, size: 18),
              text: 'Quotations (${linkedQuotes.length})',
            ),
            Tab(
              icon: const Icon(Icons.receipt_long_outlined, size: 18),
              text: 'Invoices (${linkedInvoices.length})',
            ),
            Tab(
              icon: const Icon(Icons.payments_outlined, size: 18),
              text: 'Income (${project.payments.length})',
            ),
            Tab(
              icon: const Icon(Icons.shopping_cart_outlined, size: 18),
              text: 'Bought Products (${project.expenses.length})',
            ),
            const Tab(icon: Icon(Icons.description_outlined, size: 18), text: 'Statement'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 1. QuickBook P&L Overview
          _buildQuickBookOverviewTab(
            context,
            appState,
            project,
            totalQuoted,
            totalInvoiced,
            totalPaid,
            totalExpenses,
            balance,
            netProfit,
            profitMargin,
            projectedProfit,
            projectedMargin,
            linkedQuotes,
            linkedInvoices,
          ),
          // 2. Quotations Tab
          _buildQuotesTab(context, appState, project, linkedQuotes),
          // 3. Invoices Tab
          _buildInvoicesTab(context, appState, project, linkedInvoices, linkedQuotes),
          // 4. Payments (Income) Tab
          _buildPaymentsTab(context, appState, project),
          // 5. Bought Products & Expenses Tab
          _buildExpensesTab(context, appState, project),
          // 6. Statement & Export Tab
          _buildStatementTab(context, appState, project, linkedQuotes, linkedInvoices),
        ],
      ),
    );
  }

  // ── 1. QuickBook P&L Overview ───────────────────────────────────────────────

  Widget _buildQuickBookOverviewTab(
    BuildContext context,
    AppState appState,
    Project project,
    double totalQuoted,
    double totalInvoiced,
    double totalPaid,
    double totalExpenses,
    double balance,
    double netProfit,
    double profitMargin,
    double projectedProfit,
    double projectedMargin,
    List<Quote> linkedQuotes,
    List<Invoice> linkedInvoices,
  ) {
    final isProfit = netProfit >= 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Summary Banner
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isProfit
                    ? [const Color(0xFF132F24), const Color(0xFF161B26)]
                    : [const Color(0xFF3B1518), const Color(0xFF161B26)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isProfit ? _green.withValues(alpha: 0.4) : _red.withValues(alpha: 0.4),
                width: 1.5,
              ),
              boxShadow: const [
                BoxShadow(color: Colors.black45, blurRadius: 16, offset: Offset(0, 6)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isProfit ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                          color: isProfit ? _green : _red,
                          size: 28,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'REALIZED NET PROFIT',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (isProfit ? _green : _red).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isProfit ? _green : _red),
                      ),
                      child: Text(
                        '${profitMargin.toStringAsFixed(1)}% Margin',
                        style: TextStyle(
                          color: isProfit ? _green : _red,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _fmt(netProfit),
                  style: TextStyle(
                    color: isProfit ? const Color(0xFF4ADE80) : const Color(0xFFF87171),
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Projected Final Profit (from Invoices): ${_fmt(projectedProfit)} (${projectedMargin.toStringAsFixed(1)}% margin)',
                  style: const TextStyle(color: _white70, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 4 Big Metrics Grid
          LayoutBuilder(builder: (context, constraints) {
            final isWide = constraints.maxWidth > 700;
            
            // Calculate annual and monthly expenses
            final now = DateTime.now();
            final currentYear = now.year;
            final currentMonth = now.month;
            
            final annualExpenses = project.expenses
                .where((e) => e.date.year == currentYear)
                .fold(0.0, (sum, e) => sum + e.amount);
            
            final monthlyExpenses = project.expenses
                .where((e) => e.date.year == currentYear && e.date.month == currentMonth)
                .fold(0.0, (sum, e) => sum + e.amount);
            
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: isWide ? (constraints.maxWidth - 36) / 4 : (constraints.maxWidth - 12) / 2,
                  child: _quickMetricCard(
                    title: 'Total Quoted',
                    value: _fmt(totalQuoted),
                    subtitle: '${linkedQuotes.length} quotation(s)',
                    icon: Icons.request_quote_rounded,
                    color: _blue,
                  ),
                ),
                SizedBox(
                  width: isWide ? (constraints.maxWidth - 36) / 4 : (constraints.maxWidth - 12) / 2,
                  child: _quickMetricCard(
                    title: 'Total Invoiced',
                    value: _fmt(totalInvoiced),
                    subtitle: '${linkedInvoices.length} invoice(s)',
                    icon: Icons.receipt_long_rounded,
                    color: _purple,
                  ),
                ),
                SizedBox(
                  width: isWide ? (constraints.maxWidth - 36) / 4 : (constraints.maxWidth - 12) / 2,
                  child: _quickMetricCard(
                    title: 'Payments Received',
                    value: _fmt(totalPaid),
                    subtitle: '${project.payments.length} payment(s)',
                    icon: Icons.check_circle_outline_rounded,
                    color: _green,
                  ),
                ),
                SizedBox(
                  width: isWide ? (constraints.maxWidth - 36) / 4 : (constraints.maxWidth - 12) / 2,
                  child: _quickMetricCard(
                    title: 'Material & Labor Costs',
                    value: _fmt(totalExpenses),
                    subtitle: '${project.expenses.length} purchase(s)',
                    icon: Icons.shopping_bag_outlined,
                    color: _gold,
                  ),
                ),
              ],
            );
          }),
          const SizedBox(height: 16),

          // Annual & Monthly Expenditure Tracking
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Expenditure Tracking',
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                LayoutBuilder(builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 600;
                  
                  // Calculate annual and monthly expenses
                  final now = DateTime.now();
                  final currentYear = now.year;
                  final currentMonth = now.month;
                  
                  final annualExpenses = project.expenses
                      .where((e) => e.date.year == currentYear)
                      .fold(0.0, (sum, e) => sum + e.amount);
                  
                  final monthlyExpenses = project.expenses
                      .where((e) => e.date.year == currentYear && e.date.month == currentMonth)
                      .fold(0.0, (sum, e) => sum + e.amount);
                  
                  if (isWide) {
                    return Row(
                      children: [
                        Expanded(
                          child: _expenditureCard(
                            title: 'Annual Expenditure (${currentYear})',
                            amount: annualExpenses,
                            icon: Icons.calendar_today_rounded,
                            color: _blue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _expenditureCard(
                            title: 'Monthly Expenditure (${DateFormat('MMM yyyy').format(now)})',
                            amount: monthlyExpenses,
                            icon: Icons.date_range_rounded,
                            color: _purple,
                          ),
                        ),
                      ],
                    );
                  } else {
                    return Column(
                      children: [
                        _expenditureCard(
                          title: 'Annual Expenditure (${currentYear})',
                          amount: annualExpenses,
                          icon: Icons.calendar_today_rounded,
                          color: _blue,
                        ),
                        const SizedBox(height: 12),
                        _expenditureCard(
                          title: 'Monthly Expenditure (${DateFormat('MMM yyyy').format(now)})',
                          amount: monthlyExpenses,
                          icon: Icons.date_range_rounded,
                          color: _purple,
                        ),
                      ],
                    );
                  }
                }),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Outstanding Balance Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.hourglass_top_rounded, color: Colors.orange, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Outstanding Client Balance',
                        style: TextStyle(color: _white70, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _fmt(balance),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showRecordPaymentDialog(context, appState, project),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.add_card_rounded, size: 16),
                  label: const Text('Record Payment', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Cashflow Progress & Expense Breakdown
          _buildExpenseCategoryBreakdown(project),
          const SizedBox(height: 20),

          // Quick Actions Bar
          const Text(
            'Quick Project Actions',
            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _actionButton(
                  icon: Icons.add_card_rounded,
                  label: 'Record Payment',
                  color: _green,
                  onTap: () => _showRecordPaymentDialog(context, appState, project),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _actionButton(
                  icon: Icons.add_shopping_cart_rounded,
                  label: 'Add Expense',
                  color: _gold,
                  onTap: () => _showAddExpenseDialog(context, appState, project),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _actionButton(
                  icon: Icons.note_add_outlined,
                  label: 'New Quote',
                  color: _blue,
                  onTap: () => _createNewQuoteForProject(context, appState, project),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _quickMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(color: _white70, fontSize: 12)),
              Icon(icon, color: color, size: 18),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: _white38, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _expenditureCard({
    required String title,
    required double amount,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _fmt(amount),
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseCategoryBreakdown(Project project) {
    final Map<String, double> categoryMap = {};
    for (final e in project.expenses) {
      categoryMap[e.category] = (categoryMap[e.category] ?? 0.0) + e.amount;
    }

    final total = project.totalExpenses;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Expense Breakdown by Category',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              ),
              Text(
                'Total: ${_fmt(total)}',
                style: const TextStyle(color: _gold, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (categoryMap.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text('No bought products or expenses logged yet.',
                    style: TextStyle(color: _white38, fontSize: 13)),
              ),
            )
          else ...[
            ...categoryMap.entries.map((entry) {
              final pct = total > 0 ? (entry.value / total) : 0.0;
              final color = _getCategoryColor(entry.key);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Text(entry.key, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                          ],
                        ),
                        Text(
                          '${_fmt(entry.value)} (${(pct * 100).toStringAsFixed(0)}%)',
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        backgroundColor: const Color(0xFF0F162C),
                        valueColor: AlwaysStoppedAnimation(color),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  // ── 2. Quotations Tab ───────────────────────────────────────────────────────

  Widget _buildQuotesTab(
    BuildContext context,
    AppState appState,
    Project project,
    List<Quote> quotes,
  ) {
    return Scaffold(
      backgroundColor: _bg,
      body: quotes.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.request_quote_outlined, size: 54, color: _white38),
                  const SizedBox(height: 12),
                  const Text('No quotations linked to this project yet.',
                      style: TextStyle(color: _white70, fontSize: 15)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _createNewQuoteForProject(context, appState, project),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _gold,
                          foregroundColor: Colors.black,
                        ),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Create New Quote'),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: () => _showLinkQuoteDialog(context, appState, project),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _gold,
                          side: const BorderSide(color: _gold),
                        ),
                        icon: const Icon(Icons.link_rounded, size: 18),
                        label: const Text('Link Existing Quote'),
                      ),
                    ],
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Linked Quotations (${quotes.length})',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _showLinkQuoteDialog(context, appState, project),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _gold,
                            side: const BorderSide(color: _gold),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          ),
                          icon: const Icon(Icons.link_rounded, size: 16),
                          label: const Text('Link Quote', style: TextStyle(fontSize: 12)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () => _createNewQuoteForProject(context, appState, project),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _gold,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          ),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('New Quote', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...quotes.map((q) => _quoteCard(context, appState, project, q)),
              ],
            ),
    );
  }

  Widget _quoteCard(BuildContext context, AppState appState, Project project, Quote quote) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                quote.id,
                style: const TextStyle(color: _gold, fontWeight: FontWeight.bold, fontSize: 15),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: quote.status.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: quote.status.color),
                ),
                child: Text(
                  quote.status.label,
                  style: TextStyle(color: quote.status.color, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Date: ${_dateFmt.format(quote.date)} • Expiry: ${_dateFmt.format(quote.expiryDate)}',
                style: const TextStyle(color: _white70, fontSize: 12),
              ),
              Text(
                _fmt(quote.total),
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const Divider(color: _border, height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${quote.categories.fold(0, (s, c) => s + c.items.length)} items in ${quote.categories.length} categories',
                style: const TextStyle(color: _white38, fontSize: 12),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.picture_as_pdf_outlined, color: _blue, size: 20),
                    tooltip: 'View PDF',
                    onPressed: () => PdfViewerPage.openQuotePdf(context, quote, appState),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: _gold, size: 20),
                    tooltip: 'Edit Quote',
                    onPressed: () => openQuoteEditorPage(context, appState, quote: quote),
                  ),
                  IconButton(
                    icon: const Icon(Icons.link_off_rounded, color: _red, size: 20),
                    tooltip: 'Unlink from Project',
                    onPressed: () {
                      appState.unlinkQuoteFromProject(project.id, quote.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Unlinked ${quote.id} from project')),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 3. Invoices Tab ────────────────────────────────────────────────────────

  Widget _buildInvoicesTab(
    BuildContext context,
    AppState appState,
    Project project,
    List<Invoice> invoices,
    List<Quote> quotes,
  ) {
    return Scaffold(
      backgroundColor: _bg,
      body: invoices.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.receipt_long_outlined, size: 54, color: _white38),
                  const SizedBox(height: 12),
                  const Text('No invoices linked to this project yet.',
                      style: TextStyle(color: _white70, fontSize: 15)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _showCreateInvoiceDialog(context, appState, project, quotes),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _gold,
                          foregroundColor: Colors.black,
                        ),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Generate Invoice from Quote'),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: () => _showLinkInvoiceDialog(context, appState, project),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _gold,
                          side: const BorderSide(color: _gold),
                        ),
                        icon: const Icon(Icons.link_rounded, size: 18),
                        label: const Text('Link Existing Invoice'),
                      ),
                    ],
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Linked Invoices (${invoices.length})',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _showLinkInvoiceDialog(context, appState, project),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _gold,
                            side: const BorderSide(color: _gold),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          ),
                          icon: const Icon(Icons.link_rounded, size: 16),
                          label: const Text('Link Invoice', style: TextStyle(fontSize: 12)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () => _showCreateInvoiceDialog(context, appState, project, quotes),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _gold,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          ),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('New Invoice', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...invoices.map((inv) => _invoiceCard(context, appState, project, inv)),
              ],
            ),
    );
  }

  Widget _invoiceCard(BuildContext context, AppState appState, Project project, Invoice inv) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    inv.id,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  if (inv.quoteId.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _blue.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Ref: ${inv.quoteId}',
                        style: const TextStyle(color: _blue, fontSize: 10, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: inv.status.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: inv.status.color),
                ),
                child: Text(
                  inv.status.label,
                  style: TextStyle(color: inv.status.color, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Date: ${_dateFmt.format(inv.date)} • Due: ${_dateFmt.format(inv.dueDate)}',
                style: const TextStyle(color: _white70, fontSize: 12),
              ),
              Text(
                _fmt(inv.total > 0 ? inv.total : inv.amount),
                style: const TextStyle(color: _green, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const Divider(color: _border, height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: () => _showRecordPaymentDialog(context, appState, project, linkedInvoiceId: inv.id),
                icon: const Icon(Icons.add_card_rounded, size: 14, color: _green),
                label: const Text('Record Payment', style: TextStyle(color: _green, fontSize: 12)),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.picture_as_pdf_outlined, color: _blue, size: 20),
                    tooltip: 'View Invoice PDF',
                    onPressed: () {
                      PdfViewerPage.openDocumentPdf(
                        context: context,
                        title: 'Invoice ${inv.id}',
                        filename: 'Invoice_${inv.id}.pdf',
                        buildPdf: (pageFormat) async {
                          final matchingQuote = appState.quotes.where((q) => q.id == inv.quoteId).firstOrNull;
                          if (matchingQuote != null) {
                            return PdfService.generateQuotePdf(matchingQuote, appState);
                          }
                          return PdfService.generateEnquiryInvoicePdf(
                            state: appState,
                            customerName: inv.clientName.isEmpty ? 'Valued Customer' : inv.clientName,
                            telephone: '',
                            kraPin: inv.kraPin,
                            quotationNo: inv.id,
                            date: inv.date,
                            agreedTotal: inv.amount,
                            depositPct: 50,
                            midPct: 25,
                            completionPct: 25,
                            requestLabel: 'Invoice Amount Request',
                            requestAmount: inv.amount,
                            nb: '',
                            preparedBy: appState.preparedBy,
                            terms: '1. Terms Inclusive of VAT where applicable\n2. Quotation valid for 7 days',
                            categories: inv.categories,
                          );
                        },
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.link_off_rounded, color: _red, size: 20),
                    tooltip: 'Unlink from Project',
                    onPressed: () {
                      appState.unlinkInvoiceFromProject(project.id, inv.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Unlinked ${inv.id} from project')),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 4. Payments (Income) Tab ───────────────────────────────────────────────

  Widget _buildPaymentsTab(BuildContext context, AppState appState, Project project) {
    final payments = project.payments;
    final total = project.totalPaymentsReceived;

    return Scaffold(
      backgroundColor: _bg,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _green,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add_card_rounded),
        label: const Text('Record Payment', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => _showRecordPaymentDialog(context, appState, project),
      ),
      body: payments.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.payments_outlined, size: 54, color: _white38),
                  const SizedBox(height: 12),
                  const Text('No payments recorded for this project yet.',
                      style: TextStyle(color: _white70, fontSize: 15)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showRecordPaymentDialog(context, appState, project),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _green,
                      foregroundColor: Colors.black,
                    ),
                    icon: const Icon(Icons.add_card_rounded, size: 18),
                    label: const Text('Record First Payment'),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Collected (${payments.length} payments):',
                        style: const TextStyle(color: _white70, fontSize: 14),
                      ),
                      Text(
                        _fmt(total),
                        style: const TextStyle(color: _green, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                ...payments.map((p) => _paymentCard(context, appState, project, p)),
                const SizedBox(height: 80),
              ],
            ),
    );
  }

  Widget _paymentCard(BuildContext context, AppState appState, Project project, ProjectPayment p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _green.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.check_circle_rounded, color: _green, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _fmt(p.amount),
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      _dateFmt.format(p.date),
                      style: const TextStyle(color: _white70, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F162C),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: _border),
                      ),
                      child: Text(
                        p.paymentMethod,
                        style: const TextStyle(color: _gold, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (p.reference.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text('Ref: ${p.reference}', style: const TextStyle(color: _white70, fontSize: 12)),
                    ],
                    if (p.invoiceId != null && p.invoiceId!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text('• Inv: ${p.invoiceId}', style: const TextStyle(color: _blue, fontSize: 12)),
                    ],
                  ],
                ),
                if (p.notes.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(p.notes, style: const TextStyle(color: _white38, fontSize: 11, fontStyle: FontStyle.italic)),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: _red, size: 18),
            tooltip: 'Delete Payment',
            onPressed: () => _confirmDeletePayment(context, appState, project, p),
          ),
        ],
      ),
    );
  }

  // ── 5. Bought Products & Expenses Tab ──────────────────────────────────────

  Widget _buildExpensesTab(BuildContext context, AppState appState, Project project) {
    final expenses = project.expenses;
    final total = project.totalExpenses;

    return Scaffold(
      backgroundColor: _bg,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _gold,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add_shopping_cart_rounded),
        label: const Text('Add Bought Product', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => _showAddExpenseDialog(context, appState, project),
      ),
      body: expenses.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.shopping_bag_outlined, size: 54, color: _white38),
                  const SizedBox(height: 12),
                  const Text('No bought products or expenses tracked yet.',
                      style: TextStyle(color: _white70, fontSize: 15)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showAddExpenseDialog(context, appState, project),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _gold,
                      foregroundColor: Colors.black,
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add First Bought Product / Material'),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Expenses & Purchases (${expenses.length}):',
                        style: const TextStyle(color: _white70, fontSize: 14),
                      ),
                      Text(
                        _fmt(total),
                        style: const TextStyle(color: _gold, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                ...expenses.map((e) => _expenseCard(context, appState, project, e)),
                const SizedBox(height: 80),
              ],
            ),
    );
  }

  Widget _expenseCard(BuildContext context, AppState appState, Project project, ProjectExpense e) {
    final catColor = _getCategoryColor(e.category);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  e.title,
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                _fmt(e.amount),
                style: const TextStyle(color: _gold, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: catColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: catColor),
                ),
                child: Text(
                  e.category,
                  style: TextStyle(color: catColor, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              if (e.quantity > 0)
                Text(
                  '${e.quantity % 1 == 0 ? e.quantity.toInt() : e.quantity} ${e.unit} @ ${_fmt(e.unitPrice)}',
                  style: const TextStyle(color: _white70, fontSize: 12),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Date: ${_dateFmt.format(e.date)}${e.supplier.isNotEmpty ? " • Supplier: ${e.supplier}" : ""}',
                style: const TextStyle(color: _white38, fontSize: 11),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: Colors.white70, size: 18),
                    tooltip: 'Edit Expense',
                    onPressed: () => _showAddExpenseDialog(context, appState, project, expenseToEdit: e),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: _red, size: 18),
                    tooltip: 'Delete Expense',
                    onPressed: () => _confirmDeleteExpense(context, appState, project, e),
                  ),
                ],
              ),
            ],
          ),
          if (e.receiptNo.isNotEmpty || e.notes.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '${e.receiptNo.isNotEmpty ? "Receipt #${e.receiptNo} " : ""}${e.notes.isNotEmpty ? "(${e.notes})" : ""}',
              style: const TextStyle(color: _white38, fontSize: 11, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }

  // ── 6. Statement & Export Tab ──────────────────────────────────────────────

  Widget _buildStatementTab(
    BuildContext context,
    AppState appState,
    Project project,
    List<Quote> quotes,
    List<Invoice> invoices,
  ) {
    final totalQuoted = project.totalQuoted(appState.quotes);
    final totalInvoiced = project.totalInvoiced(appState.invoices);
    final totalPaid = project.totalPaymentsReceived;
    final totalExpenses = project.totalExpenses;
    final balance = project.outstandingBalance(appState.invoices, appState.quotes);
    final netProfit = project.netProfitRealized();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      appState.companyName,
                      style: const TextStyle(color: _gold, fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                    const Text(
                      'STATEMENT OF ACCOUNT',
                      style: TextStyle(color: _white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(color: _border),
                const SizedBox(height: 12),
                Text('Project: ${project.name}',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Client: ${project.clientName}', style: const TextStyle(color: _white70, fontSize: 13)),
                Text('Generated: ${_dateFmt.format(DateTime.now())}',
                    style: const TextStyle(color: _white38, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // P&L Summary Table
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('FINANCIAL SUMMARY',
                    style: TextStyle(color: _gold, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1)),
                const SizedBox(height: 12),
                _statementRow('Total Contract / Invoiced Value', _fmt(totalInvoiced > 0 ? totalInvoiced : totalQuoted), Colors.white),
                _statementRow('Total Payments Received (Cashflow In)', _fmt(totalPaid), _green),
                _statementRow('Total Project Expenses & Materials (Cashflow Out)', _fmt(totalExpenses), _gold),
                const Divider(color: _border, height: 20),
                _statementRow('Net Profit Realized', _fmt(netProfit), netProfit >= 0 ? _green : _red, isBold: true),
                _statementRow('Client Outstanding Balance', _fmt(balance), balance > 0 ? Colors.orange : _green, isBold: true),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Income Log
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('INCOME / PAYMENTS LOG',
                    style: TextStyle(color: _green, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1)),
                const SizedBox(height: 10),
                if (project.payments.isEmpty)
                  const Text('No payments recorded.', style: TextStyle(color: _white38, fontSize: 12))
                else
                  ...project.payments.map((p) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${_dateFmt.format(p.date)} (${p.paymentMethod})',
                                style: const TextStyle(color: _white70, fontSize: 12)),
                            Text(_fmt(p.amount),
                                style: const TextStyle(color: _green, fontSize: 13, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      )),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Expenses Log
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('BOUGHT PRODUCTS & EXPENSES LOG',
                    style: TextStyle(color: _gold, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1)),
                const SizedBox(height: 10),
                if (project.expenses.isEmpty)
                  const Text('No expenses recorded.', style: TextStyle(color: _white38, fontSize: 12))
                else
                  ...project.expenses.map((e) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text('${e.title} (${e.category})',
                                  style: const TextStyle(color: _white70, fontSize: 12),
                                  overflow: TextOverflow.ellipsis),
                            ),
                            Text(_fmt(e.amount),
                                style: const TextStyle(color: _gold, fontSize: 13, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statementRow(String label, String value, Color color, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: isBold ? Colors.white : _white70, fontSize: isBold ? 14 : 13, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(color: color, fontSize: isBold ? 15 : 13, fontWeight: isBold ? FontWeight.bold : FontWeight.w600)),
        ],
      ),
    );
  }

  // ── Dialogs & Action Handlers ───────────────────────────────────────────────

  void _showRecordPaymentDialog(
    BuildContext context,
    AppState appState,
    Project project, {
    String? linkedInvoiceId,
  }) {
    final amountCtrl = TextEditingController();
    final refCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String paymentMethod = 'M-Pesa';
    DateTime selectedDate = DateTime.now();
    String? selectedInvoice = linkedInvoiceId;

    if (linkedInvoiceId != null) {
      final inv = appState.invoices.firstWhere(
        (i) => i.id == linkedInvoiceId,
        orElse: () => Invoice(
          id: '',
          quoteId: '',
          clientId: '',
          clientName: '',
          categories: [],
          amount: 0,
          date: DateTime.now(),
          dueDate: DateTime.now(),
        ),
      );
      if (inv.id.isNotEmpty) {
        amountCtrl.text = (inv.total > 0 ? inv.total : inv.amount).toStringAsFixed(0);
      }
    }

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: _surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: _border),
          ),
          title: const Row(
            children: [
              Icon(Icons.add_card_rounded, color: _green, size: 22),
              SizedBox(width: 8),
              Text('Record Client Payment', style: TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Payment Amount (KES)', style: TextStyle(color: _white70, fontSize: 12)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                    decoration: InputDecoration(
                      prefixText: 'KES ',
                      prefixStyle: const TextStyle(color: _green, fontWeight: FontWeight.bold),
                      filled: true,
                      fillColor: const Color(0xFF0F162C),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
                      hintText: '0.00',
                      hintStyle: const TextStyle(color: _white38),
                    ),
                  ),
                  const SizedBox(height: 12),

                  const Text('Payment Method', style: TextStyle(color: _white70, fontSize: 12)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: paymentMethod,
                    dropdownColor: _surface,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF0F162C),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'M-Pesa', child: Text('M-Pesa')),
                      DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                      DropdownMenuItem(value: 'Bank Transfer', child: Text('Bank Transfer')),
                      DropdownMenuItem(value: 'Cheque', child: Text('Cheque')),
                      DropdownMenuItem(value: 'Credit Card', child: Text('Credit Card')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDlgState(() => paymentMethod = val);
                    },
                  ),
                  const SizedBox(height: 12),

                  const Text('Reference / Receipt / Transaction ID', style: TextStyle(color: _white70, fontSize: 12)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: refCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF0F162C),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
                      hintText: 'e.g. QKJ8923XYZ or Cheque #1042',
                      hintStyle: const TextStyle(color: _white38),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Date Paid', style: TextStyle(color: _white70, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(_dateFmt.format(selectedDate), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.calendar_today_rounded, size: 16, color: _gold),
                        label: const Text('Change Date', style: TextStyle(color: _gold, fontSize: 12)),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
                          );
                          if (picked != null) setDlgState(() => selectedDate = picked);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  const Text('Notes (Optional)', style: TextStyle(color: _white70, fontSize: 12)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: notesCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF0F162C),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
                      hintText: 'e.g. 70% Initial deposit',
                      hintStyle: const TextStyle(color: _white38),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel', style: TextStyle(color: _white70)),
            ),
            ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                if (amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid payment amount.')),
                  );
                  return;
                }

                final newPayment = ProjectPayment(
                  id: appState.nextPaymentId,
                  projectId: project.id,
                  invoiceId: selectedInvoice,
                  amount: amount,
                  date: selectedDate,
                  paymentMethod: paymentMethod,
                  reference: refCtrl.text.trim(),
                  notes: notesCtrl.text.trim(),
                );

                appState.addProjectPayment(project.id, newPayment);

                if (selectedInvoice != null && selectedInvoice.isNotEmpty) {
                  final inv = appState.invoices.firstWhere((i) => i.id == selectedInvoice);
                  final invTotal = inv.total > 0 ? inv.total : inv.amount;
                  if (amount >= invTotal) {
                    appState.updateInvoiceStatus(inv.id, InvoiceStatus.paid);
                  }
                }

                Navigator.pop(dialogCtx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Payment of ${_fmt(amount)} recorded successfully!')),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: _green, foregroundColor: Colors.black),
              child: const Text('Save Payment', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddExpenseDialog(
    BuildContext context,
    AppState appState,
    Project project, {
    ProjectExpense? expenseToEdit,
  }) {
    final titleCtrl = TextEditingController(text: expenseToEdit?.title ?? '');
    final qtyCtrl = TextEditingController(text: (expenseToEdit?.quantity ?? 1.0).toString());
    final unitCtrl = TextEditingController(text: expenseToEdit?.unit ?? 'pcs');
    final unitPriceCtrl = TextEditingController(text: (expenseToEdit?.unitPrice ?? 0.0).toString());
    final amountCtrl = TextEditingController(text: (expenseToEdit?.amount ?? 0.0).toString());
    final supplierCtrl = TextEditingController(text: expenseToEdit?.supplier ?? '');
    final receiptCtrl = TextEditingController(text: expenseToEdit?.receiptNo ?? '');
    final notesCtrl = TextEditingController(text: expenseToEdit?.notes ?? '');

    String category = expenseToEdit?.category ?? 'Materials';
    String paymentMethod = expenseToEdit?.paymentMethod ?? 'M-Pesa';
    DateTime selectedDate = expenseToEdit?.date ?? DateTime.now();

    void updateAmount() {
      final q = double.tryParse(qtyCtrl.text.trim()) ?? 1.0;
      final up = double.tryParse(unitPriceCtrl.text.trim()) ?? 0.0;
      amountCtrl.text = (q * up).toStringAsFixed(2);
    }

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: _surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: _border),
          ),
          title: Row(
            children: [
              const Icon(Icons.add_shopping_cart_rounded, color: _gold, size: 22),
              const SizedBox(width: 8),
              Text(
                expenseToEdit == null ? 'Add Bought Product / Expense' : 'Edit Expense',
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Product / Material / Expense Title', style: TextStyle(color: _white70, fontSize: 12)),
                  const SizedBox(height: 6),
                  Autocomplete<String>(
                    initialValue: TextEditingValue(text: titleCtrl.text),
                    optionsBuilder: (textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return const Iterable<String>.empty();
                      }
                      return appState.productNames.where((option) {
                        return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                      });
                    },
                    onSelected: (selection) {
                      titleCtrl.text = selection;
                      final p = appState.productByName(selection);
                      if (p != null) {
                        setDlgState(() {
                          unitPriceCtrl.text = p.unitPrice.toString();
                          unitCtrl.text = p.unit;
                          updateAmount();
                        });
                      }
                    },
                    fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                      controller.text = titleCtrl.text;
                      controller.selection = TextSelection.fromPosition(TextPosition(offset: controller.text.length));
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'e.g. MDF Boards 18mm, Site Labor, Transport',
                          hintStyle: const TextStyle(color: _white38),
                          filled: true,
                          fillColor: const Color(0xFF0F162C),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
                        ),
                        onChanged: (v) => titleCtrl.text = v,
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Category', style: TextStyle(color: _white70, fontSize: 12)),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              initialValue: category,
                              dropdownColor: _surface,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: const Color(0xFF0F162C),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'Materials', child: Text('Materials')),
                                DropdownMenuItem(value: 'Labor', child: Text('Labor')),
                                DropdownMenuItem(value: 'Transport', child: Text('Transport')),
                                DropdownMenuItem(value: 'Tools', child: Text('Tools')),
                                DropdownMenuItem(value: 'Subcontractor', child: Text('Subcontractor')),
                                DropdownMenuItem(value: 'Other', child: Text('Other')),
                              ],
                              onChanged: (val) {
                                if (val != null) setDlgState(() => category = val);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Payment Method', style: TextStyle(color: _white70, fontSize: 12)),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              initialValue: paymentMethod,
                              dropdownColor: _surface,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: const Color(0xFF0F162C),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'M-Pesa', child: Text('M-Pesa')),
                                DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                                DropdownMenuItem(value: 'Bank Transfer', child: Text('Bank Transfer')),
                                DropdownMenuItem(value: 'Credit', child: Text('Credit')),
                              ],
                              onChanged: (val) {
                                if (val != null) setDlgState(() => paymentMethod = val);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Quantity', style: TextStyle(color: _white70, fontSize: 12)),
                            const SizedBox(height: 6),
                            TextField(
                              controller: qtyCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: const Color(0xFF0F162C),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
                              ),
                              onChanged: (_) => setDlgState(() => updateAmount()),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Unit', style: TextStyle(color: _white70, fontSize: 12)),
                            const SizedBox(height: 6),
                            TextField(
                              controller: unitCtrl,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: const Color(0xFF0F162C),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
                                hintText: 'pcs, bags',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Unit Price', style: TextStyle(color: _white70, fontSize: 12)),
                            const SizedBox(height: 6),
                            TextField(
                              controller: unitPriceCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                prefixText: 'KES ',
                                filled: true,
                                fillColor: const Color(0xFF0F162C),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
                              ),
                              onChanged: (_) => setDlgState(() => updateAmount()),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  const Text('Total Amount (KES)', style: TextStyle(color: _white70, fontSize: 12)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: _gold, fontWeight: FontWeight.bold, fontSize: 18),
                    decoration: InputDecoration(
                      prefixText: 'KES ',
                      prefixStyle: const TextStyle(color: _gold, fontWeight: FontWeight.bold),
                      filled: true,
                      fillColor: const Color(0xFF0F162C),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Supplier / Vendor', style: TextStyle(color: _white70, fontSize: 12)),
                            const SizedBox(height: 6),
                            TextField(
                              controller: supplierCtrl,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: const Color(0xFF0F162C),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
                                hintText: 'e.g. Simba Timber Yard',
                                hintStyle: const TextStyle(color: _white38),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Receipt / Invoice #', style: TextStyle(color: _white70, fontSize: 12)),
                            const SizedBox(height: 6),
                            TextField(
                              controller: receiptCtrl,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: const Color(0xFF0F162C),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
                                hintText: 'e.g. INV-9041',
                                hintStyle: const TextStyle(color: _white38),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Purchase Date', style: TextStyle(color: _white70, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(_dateFmt.format(selectedDate), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.calendar_today_rounded, size: 16, color: _gold),
                        label: const Text('Change Date', style: TextStyle(color: _gold, fontSize: 12)),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
                          );
                          if (picked != null) setDlgState(() => selectedDate = picked);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  const Text('Notes / Description', style: TextStyle(color: _white70, fontSize: 12)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: notesCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF0F162C),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
                      hintText: 'Additional details...',
                      hintStyle: const TextStyle(color: _white38),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel', style: TextStyle(color: _white70)),
            ),
            ElevatedButton(
              onPressed: () {
                final title = titleCtrl.text.trim();
                if (title.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter an item or expense title.')),
                  );
                  return;
                }
                final qty = double.tryParse(qtyCtrl.text.trim()) ?? 1.0;
                final unitPrice = double.tryParse(unitPriceCtrl.text.trim()) ?? 0.0;
                final amount = double.tryParse(amountCtrl.text.trim()) ?? (qty * unitPrice);

                if (expenseToEdit == null) {
                  final newExpense = ProjectExpense(
                    id: appState.nextExpenseId,
                    projectId: project.id,
                    title: title,
                    category: category,
                    quantity: qty,
                    unit: unitCtrl.text.trim(),
                    unitPrice: unitPrice,
                    amount: amount,
                    supplier: supplierCtrl.text.trim(),
                    receiptNo: receiptCtrl.text.trim(),
                    date: selectedDate,
                    paymentMethod: paymentMethod,
                    notes: notesCtrl.text.trim(),
                  );
                  appState.addProjectExpense(project.id, newExpense);
                } else {
                  final updated = expenseToEdit.copyWith(
                    title: title,
                    category: category,
                    quantity: qty,
                    unit: unitCtrl.text.trim(),
                    unitPrice: unitPrice,
                    amount: amount,
                    supplier: supplierCtrl.text.trim(),
                    receiptNo: receiptCtrl.text.trim(),
                    date: selectedDate,
                    paymentMethod: paymentMethod,
                    notes: notesCtrl.text.trim(),
                  );
                  appState.updateProjectExpense(project.id, updated);
                }

                Navigator.pop(dialogCtx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Expense "$title" saved successfully!')),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: _gold, foregroundColor: Colors.black),
              child: const Text('Save Expense', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _createNewQuoteForProject(BuildContext context, AppState appState, Project project) {
    final nextNumber = appState.nextQuoteNumber;
    final newQuote = Quote(
      id: 'Q-$nextNumber',
      clientId: project.clientId,
      clientName: project.clientName,
      projectId: project.id,
      projectName: project.name,
      categories: [
        QuoteCategory(id: 'cat_1', name: project.name, items: []),
      ],
      status: QuoteStatus.draft,
      date: DateTime.now(),
      expiryDate: DateTime.now().add(Duration(days: appState.defaultExpiryDays)),
      notes: appState.defaultNotes,
      vatPercent: appState.defaultVatPercent,
    );

    appState.addQuote(newQuote);
    appState.linkQuoteToProject(project.id, newQuote.id);
    appState.updateSettings(nextQuoteNumber: nextNumber + 1);

    openQuoteEditorPage(context, appState, quote: newQuote);
  }

  void _showLinkQuoteDialog(BuildContext context, AppState appState, Project project) {
    final unlinked = appState.quotes
        .where((q) => !project.quoteIds.contains(q.id) && q.projectId != project.id)
        .toList();

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _border)),
        title: const Text('Link Existing Quote to Project', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: SizedBox(
          width: 400,
          height: 300,
          child: unlinked.isEmpty
              ? const Center(
                  child: Text('No unlinked quotes available.', style: TextStyle(color: _white70)),
                )
              : ListView.builder(
                  itemCount: unlinked.length,
                  itemBuilder: (ctx, idx) {
                    final q = unlinked[idx];
                    return ListTile(
                      title: Text('${q.id} - ${q.clientName}', style: const TextStyle(color: Colors.white, fontSize: 13)),
                      subtitle: Text('${_fmt(q.total)} • ${_dateFmt.format(q.date)}', style: const TextStyle(color: _white38, fontSize: 11)),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: _gold, foregroundColor: Colors.black),
                        onPressed: () {
                          appState.linkQuoteToProject(project.id, q.id);
                          Navigator.pop(dialogCtx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Linked quote ${q.id} to ${project.name}')),
                          );
                        },
                        child: const Text('Link', style: TextStyle(fontSize: 12)),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Close', style: TextStyle(color: _white70)),
          ),
        ],
      ),
    );
  }

  void _showCreateInvoiceDialog(BuildContext context, AppState appState, Project project, List<Quote> quotes) {
    if (quotes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please create or link a quotation to generate an invoice from it.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _border)),
        title: const Text('Generate Invoice from Project Quote', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select Quote to Convert:', style: TextStyle(color: _white70, fontSize: 13)),
              const SizedBox(height: 10),
              ...quotes.map((q) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F162C),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _border),
                    ),
                    child: ListTile(
                      title: Text('${q.id} (${_fmt(q.total)})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text('${q.clientName} • ${_dateFmt.format(q.date)}', style: const TextStyle(color: _white38, fontSize: 11)),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, color: _gold, size: 14),
                      onTap: () {
                        Navigator.pop(dialogCtx);
                        final newInvoice = Invoice(
                          id: 'INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
                          quoteId: q.id,
                          clientId: q.clientId,
                          clientName: q.clientName,
                          projectId: project.id,
                          projectName: project.name,
                          categories: q.categories,
                          amount: q.total,
                          status: InvoiceStatus.sent,
                          date: DateTime.now(),
                          dueDate: DateTime.now().add(const Duration(days: 30)),
                          labourInput: q.labourInput,
                          notes: q.notes,
                        );
                        appState.addInvoice(newInvoice);
                        appState.linkInvoiceToProject(project.id, newInvoice.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Generated Invoice ${newInvoice.id} for ${project.name}')),
                        );
                      },
                    ),
                  )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel', style: TextStyle(color: _white70)),
          ),
        ],
      ),
    );
  }

  void _showLinkInvoiceDialog(BuildContext context, AppState appState, Project project) {
    final unlinked = appState.invoices
        .where((i) => !project.invoiceIds.contains(i.id) && i.projectId != project.id)
        .toList();

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _border)),
        title: const Text('Link Existing Invoice to Project', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: SizedBox(
          width: 400,
          height: 300,
          child: unlinked.isEmpty
              ? const Center(
                  child: Text('No unlinked invoices available.', style: TextStyle(color: _white70)),
                )
              : ListView.builder(
                  itemCount: unlinked.length,
                  itemBuilder: (ctx, idx) {
                    final inv = unlinked[idx];
                    return ListTile(
                      title: Text('${inv.id} - ${inv.clientName}', style: const TextStyle(color: Colors.white, fontSize: 13)),
                      subtitle: Text('${_fmt(inv.total > 0 ? inv.total : inv.amount)} • ${_dateFmt.format(inv.date)}', style: const TextStyle(color: _white38, fontSize: 11)),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: _gold, foregroundColor: Colors.black),
                        onPressed: () {
                          appState.linkInvoiceToProject(project.id, inv.id);
                          Navigator.pop(dialogCtx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Linked invoice ${inv.id} to ${project.name}')),
                          );
                        },
                        child: const Text('Link', style: TextStyle(fontSize: 12)),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Close', style: TextStyle(color: _white70)),
          ),
        ],
      ),
    );
  }

  void _showEditProjectDialog(BuildContext context, AppState appState, Project project) {
    final nameCtrl = TextEditingController(text: project.name);
    final locationCtrl = TextEditingController(text: project.location);
    final budgetCtrl = TextEditingController(text: project.budget.toString());
    final descCtrl = TextEditingController(text: project.description);
    ProjectStatus status = project.status;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: _surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _border)),
          title: const Text('Edit Project Details', style: TextStyle(color: Colors.white, fontSize: 16)),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Project Name', style: TextStyle(color: _white70, fontSize: 12)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF0F162C),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  const Text('Status', style: TextStyle(color: _white70, fontSize: 12)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<ProjectStatus>(
                    initialValue: status,
                    dropdownColor: _surface,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF0F162C),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
                    ),
                    items: ProjectStatus.values
                        .map((s) => DropdownMenuItem(
                              value: s,
                              child: Text(s.label),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setDlgState(() => status = val);
                    },
                  ),
                  const SizedBox(height: 12),

                  const Text('Estimated Budget (KES)', style: TextStyle(color: _white70, fontSize: 12)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: budgetCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF0F162C),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  const Text('Location / Site', style: TextStyle(color: _white70, fontSize: 12)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: locationCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF0F162C),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
                      hintText: 'e.g. Westlands, Nairobi',
                    ),
                  ),
                  const SizedBox(height: 12),

                  const Text('Description / Scope of Work', style: TextStyle(color: _white70, fontSize: 12)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: descCtrl,
                    maxLines: 2,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF0F162C),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel', style: TextStyle(color: _white70)),
            ),
            ElevatedButton(
              onPressed: () {
                final updated = project.copyWith(
                  name: nameCtrl.text.trim().isNotEmpty ? nameCtrl.text.trim() : project.name,
                  status: status,
                  budget: double.tryParse(budgetCtrl.text.trim()) ?? project.budget,
                  location: locationCtrl.text.trim(),
                  description: descCtrl.text.trim(),
                );
                appState.updateProject(updated);
                Navigator.pop(dialogCtx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Project updated successfully!')),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: _gold, foregroundColor: Colors.black),
              child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeletePayment(BuildContext context, AppState appState, Project project, ProjectPayment p) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        title: const Text('Delete Payment Record?', style: TextStyle(color: Colors.white)),
        content: Text('Are you sure you want to delete this payment of ${_fmt(p.amount)}?',
            style: const TextStyle(color: _white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: _white70))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _red),
            onPressed: () {
              appState.deleteProjectPayment(project.id, p.id);
              Navigator.pop(ctx);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteExpense(BuildContext context, AppState appState, Project project, ProjectExpense e) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        title: const Text('Delete Expense Record?', style: TextStyle(color: Colors.white)),
        content: Text('Are you sure you want to delete "${e.title}" (${_fmt(e.amount)})?',
            style: const TextStyle(color: _white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: _white70))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _red),
            onPressed: () {
              appState.deleteProjectExpense(project.id, e.id);
              Navigator.pop(ctx);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteProject(BuildContext context, AppState appState, Project project) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        title: const Text('Delete Entire Project?', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete project "${project.name}"?\nAll expense records and payment logs will be removed. Linked quotes & invoices will remain in QuotiMate.',
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
                      'Warning: This project will also be permanently deleted from your Cloud backup and synced devices. This action cannot be undone.',
                      style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: _white70))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _red),
            onPressed: () {
              appState.deleteProject(project.id);
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Delete Project', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(ProjectStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: status.color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, color: status.color, size: 12),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: TextStyle(color: status.color, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'materials':
        return _gold;
      case 'labor':
        return _blue;
      case 'transport':
        return Colors.orange;
      case 'tools':
        return _purple;
      case 'subcontractor':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }
}
