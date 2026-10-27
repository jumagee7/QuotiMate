// pages/project_quickbook_page.dart — Project QuickBook & Financial Hub
// Dedicated P&L, Quotations, Invoices, Payments, Bought Products/Expenses, and Statement

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import '../app_state.dart';
import '../models.dart';
import '../services/pdf_service.dart';
import '../services/html_review_service.dart';
import '../services/review_server_service.dart';
import '../services/cloud_sync_service.dart';
import 'quote_editor_page.dart';
import 'pdf_viewer_page.dart';
import 'signature_page.dart';
import '../widgets/money_text.dart';
import '../widgets/scrollable_panel.dart';
import '../widgets/send_contact_buttons.dart';

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
  String _currency = 'Ksh';
  final _dateFmt = DateFormat('dd MMM yyyy');
  final _timeFmt = DateFormat('h:mm a');

  String _fmt(double val) => formatAmount(val, _currency);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 8,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 7),
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
    _currency = appState.currency;
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

    // Project tasks (tracked work items)
    final projectTasks = appState.tasksForProject(project.id)
      ..sort((a, b) {
        // Open tasks first (by priority then due date), done tasks last.
        final doneCompare =
            (a.status == TaskStatus.done ? 1 : 0).compareTo(b.status == TaskStatus.done ? 1 : 0);
        if (doneCompare != 0) return doneCompare;
        const order = {TaskPriority.high: 0, TaskPriority.medium: 1, TaskPriority.low: 2};
        final pc = order[a.priority]!.compareTo(order[b.priority]!);
        return pc != 0 ? pc : a.dueDate.compareTo(b.dueDate);
      });

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
                GestureDetector(
                  onTap: () => _showStatusPicker(context, appState, project),
                  child: _statusBadge(project.status),
                ),
              ],
            ),
            Text(
              '${project.numberLabel} • Client: ${project.clientName} • ${project.location.isNotEmpty ? project.location : "No location"}',
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
              PopupMenuItem(
                value: 'complete',
                child: Row(
                  children: [
                    Icon(
                      project.status == ProjectStatus.completed
                          ? Icons.replay_rounded
                          : Icons.check_circle_outline_rounded,
                      color: _green,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      project.status == ProjectStatus.completed
                          ? 'Reopen Project'
                          : 'Mark Project Completed',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ],
                ),
              ),
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
              } else if (val == 'complete') {
                _setProjectStatus(
                  appState,
                  project,
                  project.status == ProjectStatus.completed
                      ? ProjectStatus.inProgress
                      : ProjectStatus.completed,
                );
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
              icon: const Icon(Icons.checklist_rtl_outlined, size: 18),
              text: 'Tasks (${projectTasks.where((t) => t.status != TaskStatus.done).length})',
            ),
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
            const Tab(icon: Icon(Icons.account_tree_outlined, size: 18), text: 'Workflow'),
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
          // 2. Tasks Tab
          _buildTasksTab(context, appState, project, projectTasks),
          // 3. Quotations Tab
          _buildQuotesTab(context, appState, project, linkedQuotes),
          // 4. Invoices Tab
          _buildInvoicesTab(context, appState, project, linkedInvoices, linkedQuotes),
          // 5. Payments (Income) Tab
          _buildPaymentsTab(context, appState, project),
          // 6. Bought Products & Expenses Tab
          _buildExpensesTab(context, appState, project),
          // 7. Statement & Export Tab
          _buildStatementTab(context, appState, project, linkedQuotes, linkedInvoices),
          // 8. Workflow — Notes & Photos
          _buildWorkflowTab(context, appState, project),
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
                            title: 'Annual Expenditure ($currentYear)',
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
                          title: 'Annual Expenditure ($currentYear)',
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

          // Budget vs Actual & Timeline
          _buildBudgetVsActualSection(context, appState, project, totalInvoiced, totalExpenses),
          const SizedBox(height: 16),

          // Cashflow Collection Rate
          _buildCashflowCollectionRate(totalInvoiced, totalQuoted, totalPaid),
          const SizedBox(height: 16),

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
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _setProjectStatus(
                appState,
                project,
                project.status == ProjectStatus.completed
                    ? ProjectStatus.inProgress
                    : ProjectStatus.completed,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: project.status == ProjectStatus.completed
                    ? _gold.withValues(alpha: 0.15)
                    : _green.withValues(alpha: 0.18),
                foregroundColor:
                    project.status == ProjectStatus.completed ? _gold : _green,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                side: BorderSide(
                  color: project.status == ProjectStatus.completed ? _gold : _green,
                ),
              ),
              icon: Icon(
                project.status == ProjectStatus.completed
                    ? Icons.replay_rounded
                    : Icons.check_circle_rounded,
                size: 18,
              ),
              label: Text(
                project.status == ProjectStatus.completed
                    ? 'Reopen Project'
                    : 'Mark Project as Completed',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _exportFullProjectPdf(context, appState, project, linkedQuotes, linkedInvoices),
              style: OutlinedButton.styleFrom(
                foregroundColor: _purple,
                side: const BorderSide(color: _purple),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
              label: const Text('Export Full Project PDF', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
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
              const Flexible(
                child: Text(
                  'Expense Breakdown by Category',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 10),
              MoneyText(
                'Total: ${_fmt(total)}',
                maxWidth: 140,
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
                        Flexible(
                          child: Row(
                            children: [
                              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(entry.key, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        MoneyText(
                          '${_fmt(entry.value)} (${(pct * 100).toStringAsFixed(0)}%)',
                          maxWidth: 150,
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

  // ── Images & Notes Helpers ────────────────────────────────────────────────

  Future<void> _pickImage(AppState appState, Project project, bool isSummary) async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: _surface,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt, color: _gold),
            title: const Text('Camera', style: TextStyle(color: Colors.white)),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library, color: _gold),
            title: const Text('Gallery', style: TextStyle(color: Colors.white)),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
        ],
      ),
    );

    if (source == null) return;
    final image = await picker.pickImage(source: source, imageQuality: 70);
    if (image == null) return;

    final bytes = await image.readAsBytes();
    final base64 = base64Encode(bytes);

    final updated = project.copyWith(
      summaryImages: isSummary ? [...project.summaryImages, base64] : project.summaryImages,
      noteImages: !isSummary ? [...project.noteImages, base64] : project.noteImages,
    );
    appState.updateProject(updated);
  }

  Widget _buildImageSection(
    BuildContext context,
    AppState appState,
    Project project,
    String title,
    List<String> images,
    bool isSummary,
  ) {
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
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
              IconButton(
                onPressed: () => _pickImage(appState, project, isSummary),
                icon: const Icon(Icons.add_a_photo_outlined, color: _gold, size: 20),
                tooltip: 'Add Image',
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (images.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'No images added yet',
                  style: TextStyle(color: _white38, fontSize: 13),
                ),
              ),
            )
          else
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: images.length,
                itemBuilder: (ctx, i) => _imageThumbnail(context, appState, project, images[i], i, isSummary),
              ),
            ),
        ],
      ),
    );
  }

  Widget _imageThumbnail(
    BuildContext context,
    AppState appState,
    Project project,
    String base64,
    int index,
    bool isSummary,
  ) {
    return Stack(
      children: [
        GestureDetector(
          onTap: () => _showFullImage(context, base64),
          child: Container(
            margin: const EdgeInsets.only(right: 12),
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _border),
              image: DecorationImage(
                image: MemoryImage(base64Decode(base64)),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 16,
          child: GestureDetector(
            onTap: () {
              final newImages = List<String>.from(isSummary ? project.summaryImages : project.noteImages);
              newImages.removeAt(index);
              final updated = project.copyWith(
                summaryImages: isSummary ? newImages : project.summaryImages,
                noteImages: !isSummary ? newImages : project.noteImages,
              );
              appState.updateProject(updated);
            },
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 14),
            ),
          ),
        ),
      ],
    );
  }

  void _showFullImage(BuildContext context, String base64) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              child: Image.memory(base64Decode(base64)),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectNotesSection(BuildContext context, AppState appState, Project project) {
    final cards = project.workflowNotes;
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
            children: [
              const Expanded(
                child: Text(
                  'Workflow notes',
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
              TextButton.icon(
                onPressed: () => _showNoteCardDialog(context, appState, project),
                icon: const Icon(Icons.add_a_photo_outlined, size: 16, color: _gold),
                label: const Text('Add note', style: TextStyle(color: _gold, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            cards.isEmpty
                ? 'One card per update — write the note, then stick camera or gallery photos on it.'
                : '${cards.length} note card${cards.length == 1 ? '' : 's'} (printed in the full project PDF).',
            style: const TextStyle(color: _white38, fontSize: 12),
          ),
          if (cards.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...cards.map((note) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _workflowNoteCard(context, appState, project, note, compact: true),
                )),
          ],
        ],
      ),
    );
  }

  // ── 8. Workflow Tab — Note cards with stuck photos ───────────────────────

  Widget _buildWorkflowTab(BuildContext context, AppState appState, Project project) {
    final cards = project.workflowNotes;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sticky_note_2_outlined, color: _gold, size: 22),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Project Workflow',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              _completeProjectButton(context, appState, project),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'One card per update — write the note, then stick camera or gallery photos on it.',
            style: TextStyle(color: _white70, fontSize: 13),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showNoteCardDialog(context, appState, project),
              style: ElevatedButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add note card', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 16),
          if (cards.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _border),
              ),
              child: const Column(
                children: [
                  Icon(Icons.note_add_outlined, color: _white38, size: 40),
                  SizedBox(height: 8),
                  Text(
                    'Example: “First floor skimming almost done”\nthen attach a site photo on the same card.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _white38, fontSize: 13),
                  ),
                ],
              ),
            )
          else
            ...cards.map((note) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _workflowNoteCard(context, appState, project, note),
                )),
        ],
      ),
    );
  }

  Widget _workflowNoteCard(
    BuildContext context,
    AppState appState,
    Project project,
    ProjectNote note, {
    bool compact = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: compact ? _bg : _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.sticky_note_2_outlined, color: _gold, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  note.text.trim().isEmpty ? '(No text)' : note.text.trim(),
                  style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
                ),
              ),
              if (!compact) ...[
                IconButton(
                  tooltip: 'Edit card',
                  onPressed: () => _showNoteCardDialog(context, appState, project, existing: note),
                  icon: const Icon(Icons.edit_outlined, color: _white70, size: 18),
                ),
                IconButton(
                  tooltip: 'Delete card',
                  onPressed: () => _deleteNoteCard(appState, project, note.id),
                  icon: const Icon(Icons.delete_outline, color: _red, size: 18),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _dateFmt.format(note.createdAt),
            style: const TextStyle(color: _white38, fontSize: 11),
          ),
          if (note.images.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: note.images
                  .map((img) => GestureDetector(
                        onTap: () => _showFullImage(context, img),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            base64Decode(img),
                            width: compact ? 72 : 110,
                            height: compact ? 72 : 110,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Future<String?> _pickImageBase64() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: _surface,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt, color: _gold),
            title: const Text('Camera', style: TextStyle(color: Colors.white)),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library, color: _gold),
            title: const Text('Gallery', style: TextStyle(color: Colors.white)),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
        ],
      ),
    );
    if (source == null) return null;
    // A modern phone camera shot is 5–12 MB; storing it raw would blow past the
    // 1 MB Firestore document limit and strand the project locally. Cap the
    // long edge and quality so note cards stay syncable.
    final image = await picker.pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 75,
    );
    if (image == null) return null;
    final bytes = await image.readAsBytes();
    return base64Encode(bytes);
  }

  void _showNoteCardDialog(
    BuildContext context,
    AppState appState,
    Project project, {
    ProjectNote? existing,
  }) {
    final textCtrl = TextEditingController(text: existing?.text ?? '');
    var images = List<String>.from(existing?.images ?? const []);

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: _surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: _border),
          ),
          title: Text(
            existing == null ? 'New note card' : 'Edit note card',
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: textCtrl,
                    maxLines: 4,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'e.g. First floor skimming almost done',
                      hintStyle: const TextStyle(color: _white38),
                      filled: true,
                      fillColor: _bg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: _border),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('Stuck photos', style: TextStyle(color: _white70, fontSize: 12)),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () async {
                          final b64 = await _pickImageBase64();
                          if (b64 != null) setDlg(() => images = [...images, b64]);
                        },
                        icon: const Icon(Icons.add_a_photo_outlined, size: 16, color: _gold),
                        label: const Text('Attach photo', style: TextStyle(color: _gold)),
                      ),
                    ],
                  ),
                  if (images.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(images.length, (i) {
                        return Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(
                                base64Decode(images[i]),
                                width: 84,
                                height: 84,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 2,
                              right: 2,
                              child: GestureDetector(
                                onTap: () => setDlg(() {
                                  images = List<String>.from(images)..removeAt(i);
                                }),
                                child: const CircleAvatar(
                                  radius: 10,
                                  backgroundColor: Colors.black54,
                                  child: Icon(Icons.close, size: 12, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        );
                      }),
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
                final text = textCtrl.text.trim();
                if (text.isEmpty && images.isEmpty) return;
                final cards = List<ProjectNote>.from(project.workflowNotes);
                if (existing == null) {
                  cards.insert(
                    0,
                    ProjectNote(
                      id: 'N-${DateTime.now().millisecondsSinceEpoch}',
                      text: text,
                      images: images,
                    ),
                  );
                } else {
                  final idx = cards.indexWhere((n) => n.id == existing.id);
                  if (idx != -1) {
                    cards[idx] = existing.copyWith(text: text, images: images);
                  }
                }
                appState.updateProject(project.withWorkflowNotes(cards));
                Navigator.pop(dialogCtx);
              },
              style: ElevatedButton.styleFrom(backgroundColor: _gold, foregroundColor: Colors.black),
              child: const Text('Save card', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteNoteCard(AppState appState, Project project, String noteId) {
    final cards = project.workflowNotes.where((n) => n.id != noteId).toList();
    appState.updateProject(project.withWorkflowNotes(cards));
  }

  Widget _completeProjectButton(BuildContext context, AppState appState, Project project) {
    final done = project.status == ProjectStatus.completed;
    return TextButton.icon(
      onPressed: () => _setProjectStatus(
        appState,
        project,
        done ? ProjectStatus.inProgress : ProjectStatus.completed,
      ),
      icon: Icon(
        done ? Icons.replay_rounded : Icons.check_circle_rounded,
        color: done ? _gold : _green,
        size: 18,
      ),
      label: Text(
        done ? 'Reopen' : 'Mark completed',
        style: TextStyle(color: done ? _gold : _green, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }

  Future<void> _setProjectStatus(
    AppState appState,
    Project project,
    ProjectStatus status,
  ) async {
    if (status == ProjectStatus.completed && project.status != ProjectStatus.completed) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: _surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: _border),
          ),
          title: const Text('Mark project completed?',
              style: TextStyle(color: Colors.white, fontSize: 16)),
          content: Text(
            '“${project.name}” will be filed under Completed with today’s completion date. '
            'You can reopen it at any time.',
            style: const TextStyle(color: _white70, fontSize: 13, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: _white70)),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.black,
              ),
              child: const Text('Mark completed',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    appState.updateProject(project.copyWith(
      status: status,
      completedAt: status == ProjectStatus.completed ? DateTime.now() : null,
      clearCompletedAt: status != ProjectStatus.completed,
    ));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          status == ProjectStatus.completed
              ? 'Project marked completed'
              : 'Project status: ${status.label}',
        ),
      ),
    );
  }

  void _showStatusPicker(BuildContext context, AppState appState, Project project) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('Project status', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            ...ProjectStatus.values.map((s) {
              final selected = s == project.status;
              return ListTile(
                leading: Icon(s.icon, color: s.color),
                title: Text(s.label, style: TextStyle(color: selected ? s.color : Colors.white)),
                trailing: selected ? Icon(Icons.check, color: s.color) : null,
                onTap: () {
                  Navigator.pop(ctx);
                  _setProjectStatus(appState, project, s);
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
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
    final isSigned = quote.signatureData != null && quote.signatureData!.isNotEmpty;
    final isExpired = quote.expiryDate.isBefore(DateTime.now()) &&
        quote.status != QuoteStatus.approved &&
        quote.status != QuoteStatus.rejected;
    final totalItems = quote.categories.fold<int>(0, (s, c) => s + c.items.length);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => PdfViewerPage.openQuotePdf(context, quote, appState),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header row ─────────────────────────────────────────────
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color: _gold.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: _gold.withValues(alpha: 0.3)),
                      ),
                      child: Text(quote.id,
                          style: const TextStyle(color: _gold, fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                    const SizedBox(width: 8),
                    if (isSigned)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _green.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: _green),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle, color: _green, size: 11),
                            SizedBox(width: 3),
                            Text('Signed', style: TextStyle(color: _green, fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: quote.status.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: quote.status.color.withValues(alpha: 0.5)),
                      ),
                      child: Text(quote.status.label,
                          style: TextStyle(color: quote.status.color, fontSize: 10, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // ── Meta row ───────────────────────────────────────────────
                Wrap(
                  spacing: 14,
                  runSpacing: 4,
                  children: [
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.calendar_today_outlined, color: _white38, size: 12),
                      const SizedBox(width: 4),
                      Text(_dateFmt.format(quote.date), style: const TextStyle(color: _white70, fontSize: 11)),
                    ]),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.event_available_outlined,
                          color: isExpired ? Colors.purpleAccent : _white38, size: 12),
                      const SizedBox(width: 4),
                      Text('Exp: ${_dateFmt.format(quote.expiryDate)}',
                          style: TextStyle(
                            color: isExpired ? Colors.purpleAccent : _white70,
                            fontSize: 11,
                            fontWeight: isExpired ? FontWeight.w600 : FontWeight.normal,
                          )),
                    ]),
                    if (totalItems > 0)
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.inventory_2_outlined, color: _white38, size: 12),
                        const SizedBox(width: 4),
                        Text('$totalItems item${totalItems != 1 ? 's' : ''}',
                            style: const TextStyle(color: _white70, fontSize: 11)),
                      ]),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(color: _border, height: 1),
                const SizedBox(height: 8),
                // ── Bottom row: amount + actions ───────────────────────────
                Wrap(
                  spacing: 6,
                  runSpacing: 2,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    MoneyText(_fmt(quote.total),
                        maxWidth: 220,
                        alignment: Alignment.centerLeft,
                        style: const TextStyle(color: _gold, fontSize: 17, fontWeight: FontWeight.bold)),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Edit
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, color: _white70, size: 19),
                          tooltip: 'Edit Quote',
                          onPressed: () => openQuoteEditorPage(context, appState, quote: quote),
                        ),
                        // PDF
                        IconButton(
                          icon: const Icon(Icons.picture_as_pdf, color: _white70, size: 19),
                          tooltip: 'View & Share PDF',
                          onPressed: () => PdfViewerPage.openQuotePdf(context, quote, appState),
                        ),
                        // Sign / Share
                        IconButton(
                          icon: Icon(
                            isSigned ? Icons.draw_outlined : Icons.edit_document,
                            color: isSigned ? _green : _gold,
                            size: 19,
                          ),
                          tooltip: isSigned ? 'Signed — options' : 'Sign / Review',
                          onPressed: () => _showSignOrShareQuoteSheet(context, quote, appState),
                        ),
                        // Overflow
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, color: _white70, size: 19),
                          color: _sidebar,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: const BorderSide(color: _border)),
                          onSelected: (val) {
                            if (val == 'view_pdf') {
                              PdfViewerPage.openQuotePdf(context, quote, appState);
                            } else if (val == 'edit') {
                              openQuoteEditorPage(context, appState, quote: quote);
                            } else if (val == 'sign_share') {
                              _showSignOrShareQuoteSheet(context, quote, appState);
                            } else if (val == 'convert_invoice') {
                              _showCreateInvoiceDialog(context, appState, project, [quote]);
                            } else if (val == 'unlink') {
                              appState.unlinkQuoteFromProject(project.id, quote.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Unlinked ${quote.id} from project')));
                            } else if (val == 'delete') {
                              _confirmDeleteQuote(context, appState, quote);
                            } else {
                              final status = QuoteStatus.values.firstWhere((e) => e.name == val);
                              quote.status = status;
                              appState.updateQuote(quote);
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(value: 'view_pdf', child: _PMenuItem(icon: Icons.picture_as_pdf, color: _gold, label: 'View & Share PDF')),
                            const PopupMenuItem(value: 'sign_share', child: _PMenuItem(icon: Icons.draw_outlined, color: _gold, label: 'Sign / Share Webpage')),
                            const PopupMenuItem(value: 'edit', child: _PMenuItem(icon: Icons.edit_outlined, color: _white70, label: 'Edit Quote')),
                            const PopupMenuItem(value: 'convert_invoice', child: _PMenuItem(icon: Icons.receipt_long_outlined, color: _blue, label: 'Convert to Invoice')),
                            const PopupMenuDivider(),
                            ...QuoteStatus.values.map((s) => PopupMenuItem(
                              value: s.name,
                              child: Row(children: [
                                Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: s.color)),
                                const SizedBox(width: 8),
                                Text('Mark as ${s.label}', style: const TextStyle(color: _white70, fontSize: 13)),
                              ]),
                            )),
                            const PopupMenuDivider(),
                            const PopupMenuItem(value: 'unlink', child: _PMenuItem(icon: Icons.link_off_rounded, color: _white38, label: 'Unlink from Project')),
                            const PopupMenuItem(value: 'delete', child: _PMenuItem(icon: Icons.delete_outline, color: _red, label: 'Delete Quote')),
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
                const SizedBox(height: 10),
                // Invoice status summary chips
                _buildInvoiceStatusSummary(invoices),
                const SizedBox(height: 12),
                ...invoices.map((inv) => _invoiceCard(context, appState, project, inv)),
              ],
            ),
    );
  }

  Widget _invoiceCard(BuildContext context, AppState appState, Project project, Invoice inv) {
    final isSigned = inv.signatureData != null && inv.signatureData!.isNotEmpty;
    final isOverdue = inv.dueDate.isBefore(DateTime.now()) && inv.status != InvoiceStatus.paid;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => PdfViewerPage.openInvoicePdf(context, inv, appState),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header row ─────────────────────────────────────────────
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color: _gold.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: _gold.withValues(alpha: 0.3)),
                      ),
                      child: Text(inv.id,
                          style: const TextStyle(color: _gold, fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                    const SizedBox(width: 6),
                    if (inv.quoteId.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: _blue.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('Ref: ${inv.quoteId}',
                            style: const TextStyle(color: _blue, fontSize: 10, fontWeight: FontWeight.w600)),
                      ),
                    if (isSigned) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _green.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: _green),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle, color: _green, size: 11),
                            SizedBox(width: 3),
                            Text('Signed', style: TextStyle(color: _green, fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: inv.status.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: inv.status.color.withValues(alpha: 0.5)),
                      ),
                      child: Text(inv.status.label,
                          style: TextStyle(color: inv.status.color, fontSize: 10, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // ── Meta row ───────────────────────────────────────────────
                Wrap(
                  spacing: 14,
                  runSpacing: 4,
                  children: [
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.calendar_today_outlined, color: _white38, size: 12),
                      const SizedBox(width: 4),
                      Text(_dateFmt.format(inv.date), style: const TextStyle(color: _white70, fontSize: 11)),
                    ]),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.event_available_outlined,
                          color: isOverdue ? _red : _white38, size: 12),
                      const SizedBox(width: 4),
                      Text('Due: ${_dateFmt.format(inv.dueDate)}',
                          style: TextStyle(
                            color: isOverdue ? _red : _white70,
                            fontSize: 11,
                            fontWeight: isOverdue ? FontWeight.w600 : FontWeight.normal,
                          )),
                    ]),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(color: _border, height: 1),
                const SizedBox(height: 8),
                // ── Bottom row: amount + actions ───────────────────────────
                Wrap(
                  spacing: 6,
                  runSpacing: 2,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    MoneyText(_fmt(inv.total > 0 ? inv.total : inv.amount),
                        maxWidth: 220,
                        alignment: Alignment.centerLeft,
                        style: const TextStyle(color: _green, fontSize: 17, fontWeight: FontWeight.bold)),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Record payment shortcut
                        TextButton.icon(
                          onPressed: () => _showRecordPaymentDialog(context, appState, project, linkedInvoiceId: inv.id),
                          icon: const Icon(Icons.add_card_rounded, size: 13, color: _green),
                          label: const Text('Pay', style: TextStyle(color: _green, fontSize: 11)),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                          ),
                        ),
                        // PDF
                        IconButton(
                          icon: const Icon(Icons.picture_as_pdf, color: _white70, size: 19),
                          tooltip: 'View & Share PDF',
                          onPressed: () => PdfViewerPage.openInvoicePdf(context, inv, appState),
                        ),
                        // Sign / Share
                        IconButton(
                          icon: Icon(
                            isSigned ? Icons.draw_outlined : Icons.edit_document,
                            color: isSigned ? _green : _gold,
                            size: 19,
                          ),
                          tooltip: isSigned ? 'Signed — options' : 'Sign / Review',
                          onPressed: () => _showSignOrShareInvoiceSheet(context, inv, appState),
                        ),
                        // Overflow
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, color: _white70, size: 19),
                          color: _sidebar,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: const BorderSide(color: _border)),
                          onSelected: (val) {
                            if (val == 'view_pdf') {
                              PdfViewerPage.openInvoicePdf(context, inv, appState);
                            } else if (val == 'sign_share') {
                              _showSignOrShareInvoiceSheet(context, inv, appState);
                            } else if (val == 'record_payment') {
                              _showRecordPaymentDialog(context, appState, project, linkedInvoiceId: inv.id);
                            } else if (val == 'unlink') {
                              appState.unlinkInvoiceFromProject(project.id, inv.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Unlinked ${inv.id} from project')));
                            } else if (val == 'delete') {
                              _confirmDeleteInvoice(context, appState, inv);
                            } else {
                              final status = InvoiceStatus.values.firstWhere((e) => e.name == val);
                              appState.updateInvoiceStatus(inv.id, status);
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(value: 'view_pdf', child: _PMenuItem(icon: Icons.picture_as_pdf, color: _gold, label: 'View & Share PDF')),
                            const PopupMenuItem(value: 'sign_share', child: _PMenuItem(icon: Icons.draw_outlined, color: _gold, label: 'Sign / Share Webpage')),
                            const PopupMenuItem(value: 'record_payment', child: _PMenuItem(icon: Icons.add_card_rounded, color: _green, label: 'Record Payment')),
                            const PopupMenuDivider(),
                            ...InvoiceStatus.values.map((s) => PopupMenuItem(
                              value: s.name,
                              child: Row(children: [
                                Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: s.color)),
                                const SizedBox(width: 8),
                                Text('Mark as ${s.label}', style: const TextStyle(color: _white70, fontSize: 13)),
                              ]),
                            )),
                            const PopupMenuDivider(),
                            const PopupMenuItem(value: 'unlink', child: _PMenuItem(icon: Icons.link_off_rounded, color: _white38, label: 'Unlink from Project')),
                            const PopupMenuItem(value: 'delete', child: _PMenuItem(icon: Icons.delete_outline, color: _red, label: 'Delete Invoice')),
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
                      Flexible(
                        child: Text(
                          'Total Collected (${payments.length} payments):',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: _white70, fontSize: 14),
                        ),
                      ),
                      const SizedBox(width: 10),
                      MoneyText(
                        _fmt(total),
                        maxWidth: 165,
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
                    MoneyText(
                      _fmt(p.amount),
                      maxWidth: 165,
                      alignment: Alignment.centerLeft,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Flexible(
                      child: Text(
                        _dateFmt.format(p.date),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: const TextStyle(color: _white70, fontSize: 12),
                      ),
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
                      Flexible(child: Text('Ref: ${p.reference}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _white70, fontSize: 12))),
                    ],
                    if (p.invoiceId != null && p.invoiceId!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Flexible(child: Text('• Inv: ${p.invoiceId}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _blue, fontSize: 12))),
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
            icon: const Icon(Icons.edit_outlined, color: _gold, size: 18),
            tooltip: 'Edit Payment',
            onPressed: () => _showRecordPaymentDialog(context, appState, project, paymentToEdit: p),
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
    return _ExpensesTabBody(
      project: project,
      appState: appState,
      fmt: _fmt,
      dateFmt: _dateFmt,
      getCategoryColor: _getCategoryColor,
      onAdd: () => _showAddExpenseDialog(context, appState, project),
      onEdit: (e) => _showAddExpenseDialog(context, appState, project, expenseToEdit: e),
      onDelete: (e) => _confirmDeleteExpense(context, appState, project, e),
    );
  }
  
  // ── 2. Tasks Tab ───────────────────────────────────────────────────────────

  Widget _buildTasksTab(
    BuildContext context,
    AppState appState,
    Project project,
    List<AppTask> tasks,
  ) {
    final open = tasks.where((t) => t.status != TaskStatus.done).length;
    final done = tasks.where((t) => t.status == TaskStatus.done).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Flexible(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _taskStatChip('Open', open, _gold),
                      const SizedBox(width: 8),
                      _taskStatChip('Done', done, _green),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => _showTaskDialog(context, appState, project),
                icon: const Icon(Icons.add, size: 18, color: _gold),
                label: const Text('Add Task', style: TextStyle(color: _gold, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
        Expanded(
          child: tasks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.checklist_rtl_outlined, size: 48, color: _white38.withValues(alpha: 0.6)),
                      const SizedBox(height: 12),
                      const Text('No tasks yet', style: TextStyle(color: _white70, fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      const Text('Track project work by adding a task', style: TextStyle(color: _white38, fontSize: 12)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: tasks.length,
                  itemBuilder: (ctx, i) => _taskCard(context, appState, project, tasks[i]),
                ),
        ),
      ],
    );
  }

  Widget _taskStatChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        '$label $count',
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }

  Widget _taskCard(BuildContext context, AppState appState, Project project, AppTask task) {
    final isDone = task.status == TaskStatus.done;
    final overdue = !isDone && task.dueDate.isBefore(DateTime.now());

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDone ? _green.withValues(alpha: 0.3) : _border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              task.status = isDone ? TaskStatus.todo : TaskStatus.done;
              appState.updateTask(task);
            },
            child: Padding(
              padding: const EdgeInsets.only(top: 2, right: 10),
              child: Icon(
                isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                color: isDone ? _green : _white38,
                size: 22,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: TextStyle(
                    color: isDone ? _white38 : Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (task.description.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    task.description,
                    style: const TextStyle(color: _white38, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _taskTag(task.priority.label, task.priority.color, task.priority.icon),
                    _taskTag(
                      task.status.label,
                      task.status.color,
                      isDone ? Icons.check : Icons.pending_outlined,
                    ),
                    _taskTag(
                      '${_dateFmt.format(task.dueDate)} · ${_timeFmt.format(task.dueDate)}',
                      overdue ? _red : _white70,
                      Icons.event_outlined,
                    ),
                    if (task.alarmEnabled)
                      _taskTag(
                        task.reminderLeadMinutes > 0
                            ? 'Alarm ${task.reminderLeadMinutes}m before'
                            : 'Alarm',
                        _gold,
                        Icons.alarm_on,
                      ),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: _white38, size: 20),
            color: _surface,
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'edit',
                child: Row(children: [
                  Icon(Icons.edit_outlined, color: _blue, size: 18),
                  SizedBox(width: 10),
                  Text('Edit', style: TextStyle(color: Colors.white, fontSize: 13)),
                ]),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(children: [
                  Icon(Icons.delete_outline, color: _red, size: 18),
                  SizedBox(width: 10),
                  Text('Delete', style: TextStyle(color: _red, fontSize: 13)),
                ]),
              ),
            ],
            onSelected: (val) {
              if (val == 'edit') {
                _showTaskDialog(context, appState, project, task: task);
              } else if (val == 'delete') {
                appState.deleteTask(task.id);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _taskTag(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _showTaskDialog(BuildContext context, AppState appState, Project project, {AppTask? task}) {
    final titleCtrl = TextEditingController(text: task?.title ?? '');
    final descCtrl = TextEditingController(text: task?.description ?? '');
    TaskPriority priority = task?.priority ?? TaskPriority.medium;
    TaskStatus status = task?.status ?? TaskStatus.todo;
    // Same as the Schedule page: a bare date meant midnight, so alarms either
    // fired at 00:00 or were skipped as already past.
    DateTime dueDate = task?.dueDate ??
        DateTime.now().add(const Duration(days: 1)).copyWith(hour: 9, minute: 0);
    bool alarm = task?.alarmEnabled ?? false;
    int lead = task?.reminderLeadMinutes ?? 0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) {
          final alarmAt = dueDate.subtract(Duration(minutes: lead));
          final willRing = dueDate.isAfter(DateTime.now());
          final leadWillRing = alarmAt.isAfter(DateTime.now());
          return AlertDialog(
          backgroundColor: _surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: _border),
          ),
          title: Text(
            task == null ? 'Add Project Task' : 'Edit Task',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: _taskFieldDecoration('Task title'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    maxLines: 2,
                    style: const TextStyle(color: Colors.white),
                    decoration: _taskFieldDecoration('Description (optional)'),
                  ),
                  const SizedBox(height: 16),
                  const Text('Priority', style: TextStyle(color: _white70, fontSize: 13)),
                  const SizedBox(height: 8),
                  Row(
                    children: TaskPriority.values.map((p) {
                      final sel = priority == p;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => setDlg(() => priority = p),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: sel ? p.color.withValues(alpha: 0.2) : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: sel ? p.color : Colors.white24),
                            ),
                            child: Row(
                              children: [
                                Icon(p.icon, color: p.color, size: 14),
                                const SizedBox(width: 6),
                                Text(p.label, style: TextStyle(color: p.color, fontSize: 13, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  const Text('Status', style: TextStyle(color: _white70, fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: TaskStatus.values.map((s) {
                      final sel = status == s;
                      return GestureDetector(
                        onTap: () => setDlg(() => status = s),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: sel ? s.color.withValues(alpha: 0.2) : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: sel ? s.color : Colors.white24),
                          ),
                          child: Text(s.label, style: TextStyle(color: sel ? s.color : _white70, fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('Due date:', style: TextStyle(color: _white70, fontSize: 13)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: dueDate,
                              firstDate: DateTime.now().subtract(const Duration(days: 365)),
                              lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                              builder: (c, child) => Theme(
                                data: ThemeData.dark().copyWith(
                                  colorScheme: const ColorScheme.dark(primary: _gold),
                                ),
                                child: child!,
                              ),
                            );
                            if (picked != null) {
                              setDlg(() => dueDate = DateTime(
                                picked.year, picked.month, picked.day, dueDate.hour, dueDate.minute,
                              ));
                            }
                          },
                          style: TextButton.styleFrom(foregroundColor: _gold),
                          icon: const Icon(Icons.calendar_today, size: 15),
                          label: Text(_dateFmt.format(dueDate)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextButton.icon(
                          onPressed: () async {
                            final picked = await showTimePicker(
                              context: ctx,
                              initialTime: TimeOfDay.fromDateTime(dueDate),
                              builder: (c, child) => Theme(
                                data: ThemeData.dark().copyWith(
                                  colorScheme: const ColorScheme.dark(primary: _gold),
                                ),
                                child: child!,
                              ),
                            );
                            if (picked != null) {
                              setDlg(() => dueDate = dueDate.copyWith(hour: picked.hour, minute: picked.minute));
                            }
                          },
                          style: TextButton.styleFrom(foregroundColor: _gold),
                          icon: const Icon(Icons.access_time, size: 15),
                          label: Text(_timeFmt.format(dueDate)),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(Icons.notifications_active_outlined, color: _gold, size: 18),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text('Reminder / alarm', style: TextStyle(color: _white70, fontSize: 13)),
                      ),
                      Switch(
                        value: alarm,
                        activeThumbColor: _gold,
                        onChanged: (v) => setDlg(() => alarm = v),
                      ),
                    ],
                  ),
                  if (alarm) ...[
                    Row(
                      children: [
                        const SizedBox(width: 28),
                        const Text('Remind me', style: TextStyle(color: _white70, fontSize: 13)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: kLeadOptions.containsKey(lead) ? lead : 0,
                              isExpanded: true,
                              dropdownColor: _surface,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              items: kLeadOptions.entries.map((e) => DropdownMenuItem(
                                value: e.key,
                                child: Text(e.value),
                              )).toList(),
                              onChanged: (v) => setDlg(() => lead = v ?? 0),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      !willRing
                          ? 'That time has already passed — the task saves, but no device alert is set.'
                          : leadWillRing
                              ? 'Rings ${AppState.whenPhrase(alarmAt)}'
                              : 'Rings at ${_timeFmt.format(dueDate)} only — the heads-up window has already passed.',
                      style: TextStyle(
                        color: willRing ? _white38 : Colors.redAccent,
                        fontSize: 11.5,
                      ),
                    ),
                  ] else if (!willRing) ...[
                    const SizedBox(height: 2),
                    const Text(
                      'That time has already passed — the task saves, but no device alert is set.',
                      style: TextStyle(color: Colors.redAccent, fontSize: 11.5),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: _white38)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _gold, foregroundColor: Colors.black),
              onPressed: () {
                final title = titleCtrl.text.trim();
                if (title.isEmpty) return;
                appState.upsertTask(AppTask(
                  id: task?.id ?? appState.nextTaskId,
                  title: title,
                  description: descCtrl.text.trim(),
                  priority: priority,
                  status: status,
                  dueDate: dueDate,
                  linkedQuoteId: task?.linkedQuoteId,
                  projectId: task?.projectId ?? project.id,
                  alarmEnabled: alarm,
                  reminderLeadMinutes: alarm ? lead : 0,
                ));
                Navigator.pop(ctx);
              },
              child: Text(task == null ? 'Add Task' : 'Save'),
            ),
          ],
          );
        },
      ),
    );
  }

  InputDecoration _taskFieldDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _white38),
        filled: true,
        fillColor: _bg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
      );

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
    final totalInvoicedPaid = project.totalInvoicedPaid(appState.invoices);
    final totalInvoicedUnpaid = (totalInvoiced - totalInvoicedPaid).clamp(0.0, double.infinity);
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
                Text('Project No: ${project.numberLabel}',
                    style: const TextStyle(color: _white70, fontSize: 13)),
                Text('Client: ${project.clientName}', style: const TextStyle(color: _white70, fontSize: 13)),
                if (project.location.isNotEmpty)
                  Text('Location: ${project.location}', style: const TextStyle(color: _white38, fontSize: 12)),
                const SizedBox(height: 4),
                Text('Generated: ${_dateFmt.format(DateTime.now())}',
                    style: const TextStyle(color: _white38, fontSize: 12)),
                const SizedBox(height: 16),
                // PDF Export Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _exportStatementPdf(context, appState, project, quotes, invoices),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _gold,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                    label: const Text('Export as PDF Statement', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _exportFullProjectPdf(context, appState, project, quotes, invoices),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _purple,
                      side: const BorderSide(color: _purple),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.folder_zip_outlined, size: 18),
                    label: const Text('Export Full Project Dossier PDF', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Project Notes Section
          _buildProjectNotesSection(context, appState, project),
          const SizedBox(height: 16),

          // Project Documentation Images
          _buildImageSection(
            context,
            appState,
            project,
            'Project Documentation Images',
            project.noteImages,
            false,
          ),
          const SizedBox(height: 24),

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
                _statementRow('Total Quoted Value', _fmt(totalQuoted), _blue),
                _statementRow('Total Invoiced Value', _fmt(totalInvoiced), Colors.white),
                _statementRow('Total Payments Received (Cashflow In)', _fmt(totalPaid), _green),
                _statementRow('Total Project Expenses & Materials (Cashflow Out)', _fmt(totalExpenses), _gold),
                const Divider(color: _border, height: 20),
                _statementRow('Net Profit Realized', _fmt(netProfit), netProfit >= 0 ? _green : _red, isBold: true),
                _statementRow('Client Outstanding Balance', _fmt(balance), balance > 0 ? Colors.orange : _green, isBold: true),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Invoice Paid vs Unpaid Breakdown
          if (invoices.isNotEmpty) ...[
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
                  const Text('INVOICE COLLECTION STATUS',
                      style: TextStyle(color: _purple, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  const SizedBox(height: 12),
                  _statementRow('Total Invoiced', _fmt(totalInvoiced), Colors.white),
                  _statementRow('  → Paid Invoices', _fmt(totalInvoicedPaid), _green),
                  _statementRow('  → Unpaid / Outstanding', _fmt(totalInvoicedUnpaid), Colors.orange),
                  const SizedBox(height: 8),
                  if (totalInvoiced > 0) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: totalInvoicedPaid / totalInvoiced,
                        backgroundColor: Colors.orange.withValues(alpha: 0.3),
                        valueColor: const AlwaysStoppedAnimation(_green),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${((totalInvoicedPaid / totalInvoiced) * 100).toStringAsFixed(1)}% of invoiced amount collected',
                      style: const TextStyle(color: _white38, fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

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
          Flexible(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: isBold ? Colors.white : _white70, fontSize: isBold ? 14 : 13, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          ),
          const SizedBox(width: 12),
          MoneyText(value, maxWidth: 140, style: TextStyle(color: color, fontSize: isBold ? 15 : 13, fontWeight: isBold ? FontWeight.bold : FontWeight.w600)),
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
    ProjectPayment? paymentToEdit,
  }) {
    final amountCtrl = TextEditingController(
      text: paymentToEdit != null ? formatMoney(paymentToEdit.amount) : '',
    );
    final refCtrl = TextEditingController(text: paymentToEdit?.reference ?? '');
    final notesCtrl = TextEditingController(text: paymentToEdit?.notes ?? '');
    String paymentMethod = paymentToEdit?.paymentMethod ?? 'M-Pesa';
    DateTime selectedDate = paymentToEdit?.date ?? DateTime.now();
    String? selectedInvoice = paymentToEdit?.invoiceId ?? linkedInvoiceId;
    final isEditing = paymentToEdit != null;

    // Auto-populate amount from linked invoice when recording a new payment
    if (!isEditing && linkedInvoiceId != null && amountCtrl.text.isEmpty) {
      final inv = appState.invoices.firstWhere(
        (i) => i.id == linkedInvoiceId,
        orElse: () => Invoice(
          id: '', quoteId: '', clientId: '', clientName: '',
          categories: [], amount: 0, date: DateTime.now(), dueDate: DateTime.now(),
        ),
      );
      if (inv.id.isNotEmpty) {
        amountCtrl.text = formatMoney(inv.total > 0 ? inv.total : inv.amount);
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
          title: Row(
            children: [
              Icon(isEditing ? Icons.edit_rounded : Icons.add_card_rounded, color: _green, size: 22),
              const SizedBox(width: 8),
              Text(isEditing ? 'Edit Payment' : 'Record Client Payment',
                  style: const TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Payment Amount (${appState.currency})', style: const TextStyle(color: _white70, fontSize: 12)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: moneyInputFormatters(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                    decoration: InputDecoration(
                      prefixText: currencyPrefix(appState.currency),
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
                final amount = parseMoneyOr(amountCtrl.text);
                if (amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid payment amount.')),
                  );
                  return;
                }

                if (isEditing) {
                  // Build updated payment preserving its original id
                  final updatedPayment = ProjectPayment(
                    id: paymentToEdit.id,
                    projectId: project.id,
                    invoiceId: selectedInvoice,
                    amount: amount,
                    date: selectedDate,
                    paymentMethod: paymentMethod,
                    reference: refCtrl.text.trim(),
                    notes: notesCtrl.text.trim(),
                  );
                  appState.updateProjectPayment(project.id, updatedPayment);
                  Navigator.pop(dialogCtx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Payment updated to ${_fmt(amount)}')),
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
    final unitPriceCtrl = TextEditingController(
      text: expenseToEdit != null ? formatMoney(expenseToEdit.unitPrice, decimalDigits: 2) : '',
    );
    final amountCtrl = TextEditingController(
      text: expenseToEdit != null ? formatMoney(expenseToEdit.amount, decimalDigits: 2) : '',
    );
    final supplierCtrl = TextEditingController(text: expenseToEdit?.supplier ?? '');
    final receiptCtrl = TextEditingController(text: expenseToEdit?.receiptNo ?? '');
    final notesCtrl = TextEditingController(text: expenseToEdit?.notes ?? '');

    String category = expenseToEdit?.category ?? 'Materials';
    String paymentMethod = expenseToEdit?.paymentMethod ?? 'M-Pesa';
    DateTime selectedDate = expenseToEdit?.date ?? DateTime.now();

    void updateAmount() {
      final q = parseMoneyOr(qtyCtrl.text, 1.0);
      final up = parseMoneyOr(unitPriceCtrl.text);
      amountCtrl.text = formatMoney(q * up, decimalDigits: 2);
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
                          unitPriceCtrl.text = formatMoney(p.unitPrice, decimalDigits: 2);
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
                              inputFormatters: moneyInputFormatters(decimalDigits: 2),
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                prefixText: currencyPrefix(appState.currency),
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

                  Text('Total Amount (${appState.currency})', style: const TextStyle(color: _white70, fontSize: 12)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: moneyInputFormatters(decimalDigits: 2),
                    style: const TextStyle(color: _gold, fontWeight: FontWeight.bold, fontSize: 18),
                    decoration: InputDecoration(
                      prefixText: currencyPrefix(appState.currency),
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
                final qty = parseMoneyOr(qtyCtrl.text, 1.0);
                final unitPrice = parseMoneyOr(unitPriceCtrl.text);
                final amount = parseMoneyOr(amountCtrl.text, qty * unitPrice);

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

  Future<void> _createNewQuoteForProject(BuildContext context, AppState appState, Project project) async {
    // Quotation numbers come from the cloud counter so they stay unique across
    // devices; this requires an active connection.
    final newId = await appState.allocateQuoteNumber();
    if (newId == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('You need to be online to generate a new quotation number.'),
          backgroundColor: Colors.orange,
        ));
      }
      return;
    }
    final newQuote = Quote(
      id: newId,
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

    if (context.mounted) {
      openQuoteEditorPage(context, appState, quote: newQuote);
    }
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
    final budgetCtrl = TextEditingController(
      text: project.budget > 0 ? formatMoney(project.budget) : '',
    );
    final descCtrl = TextEditingController(text: project.description);
    ProjectStatus status = project.status;
    DateTime startDate = project.startDate;
    DateTime? deadline = project.deadline;

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

                  Text('Estimated Budget (${appState.currency})', style: const TextStyle(color: _white70, fontSize: 12)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: budgetCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: moneyInputFormatters(),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      prefixText: currencyPrefix(appState.currency),
                      prefixStyle: const TextStyle(color: _gold, fontWeight: FontWeight.bold),
                      hintText: '1,250,000',
                      hintStyle: const TextStyle(color: _white38),
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
                  const SizedBox(height: 12),

                  // Dates row
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Start Date', style: TextStyle(color: _white70, fontSize: 12)),
                            const SizedBox(height: 4),
                            InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: startDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2030),
                                );
                                if (picked != null) setDlgState(() => startDate = picked);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F162C),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: _border),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.calendar_today_rounded, color: _gold, size: 14),
                                    const SizedBox(width: 6),
                                    Text(_dateFmt.format(startDate), style: const TextStyle(color: Colors.white, fontSize: 13)),
                                  ],
                                ),
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
                            const Text('Deadline (Optional)', style: TextStyle(color: _white70, fontSize: 12)),
                            const SizedBox(height: 4),
                            InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: deadline ?? DateTime.now().add(const Duration(days: 30)),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2030),
                                );
                                if (picked != null) setDlgState(() => deadline = picked);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F162C),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: _border),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.event_rounded, color: _red, size: 14),
                                        const SizedBox(width: 6),
                                        Text(
                                          deadline != null ? _dateFmt.format(deadline!) : 'Set deadline',
                                          style: TextStyle(color: deadline != null ? Colors.white : _white38, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                    if (deadline != null)
                                      GestureDetector(
                                        onTap: () => setDlgState(() => deadline = null),
                                        child: const Icon(Icons.close_rounded, color: _red, size: 14),
                                      ),
                                  ],
                                ),
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
                  budget: parseMoney(budgetCtrl.text) ?? project.budget,
                  location: locationCtrl.text.trim(),
                  description: descCtrl.text.trim(),
                  startDate: startDate,
                  // To support clearing deadline we update via a rebuilt Project
                );
                // We need to handle deadline clearing separately since copyWith
                // cannot distinguish null-to-clear from null-no-change
                final withDeadline = Project(
                  id: updated.id,
                  number: updated.number,
                  name: updated.name,
                  clientId: updated.clientId,
                  clientName: updated.clientName,
                  status: updated.status,
                  startDate: updated.startDate,
                  deadline: deadline,
                  budget: updated.budget,
                  description: updated.description,
                  notes: updated.notes,
                  location: updated.location,
                  quoteIds: updated.quoteIds,
                  invoiceIds: updated.invoiceIds,
                  expenses: updated.expenses,
                  payments: updated.payments,
                  summaryImages: updated.summaryImages,
                  noteImages: updated.noteImages,
                  workflowNotes: updated.workflowNotes,
                  createdAt: updated.createdAt,
                  completedAt: status == ProjectStatus.completed
                      ? (project.completedAt ?? DateTime.now())
                      : null,
                );
                appState.updateProject(withDeadline);
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

  void _confirmDeleteQuote(BuildContext context, AppState appState, Quote quote) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: _border)),
        title: const Text('Delete Quote?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Delete ${quote.id} (${_fmt(quote.total)})?\nThis will also remove it from cloud and any linked project.',
          style: const TextStyle(color: _white70, fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: _white70))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _red),
            onPressed: () { appState.deleteQuote(quote.id); Navigator.pop(ctx); },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteInvoice(BuildContext context, AppState appState, Invoice inv) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: _border)),
        title: const Text('Delete Invoice?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Delete ${inv.id} (${_fmt(inv.amount)})?\nThis will also remove it from cloud.',
          style: const TextStyle(color: _white70, fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: _white70))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _red),
            onPressed: () { appState.deleteInvoice(inv.id); Navigator.pop(ctx); },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── Sign / Share sheets (mirrors quotes_page.dart & invoices_page.dart) ────

  void _showSignOrShareQuoteSheet(BuildContext context, Quote quote, AppState appState) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.draw_outlined, color: _gold),
              const SizedBox(width: 10),
              Expanded(child: Text('Client Review & Signature — ${quote.id}',
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold))),
            ]),
            const SizedBox(height: 6),
            const Text(
              'Send a review link, capture a signature on-device, or sync one already submitted online.',
              style: TextStyle(color: _white70, fontSize: 12),
            ),
            const SizedBox(height: 14),
            _signSheetTile(
              icon: Icons.link, color: _blue,
              title: 'Send Review Link to Client',
              subtitle: 'Client opens in browser, reviews & signs — syncs back automatically',
              onTap: () { Navigator.pop(context); _showQuoteReviewLinkDialog(context, quote, appState); },
            ),
            _signSheetTile(
              icon: Icons.edit, color: _gold,
              title: 'Capture Signature Now',
              subtitle: 'Client signs directly on this screen',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => SignaturePage(quote: quote)));
              },
            ),
            _signSheetTile(
              icon: Icons.sync, color: Colors.teal,
              title: 'Check / Sync Signature from Cloud',
              subtitle: 'Fetch signature from Firebase if signed remotely',
              onTap: () async {
                Navigator.pop(context);
                final found = await appState.checkCloudSignatureForQuote(quote.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(found ? '✓ Signature retrieved! Quote is now signed.' : 'No remote signature found yet.'),
                    backgroundColor: found ? _green : Colors.orange,
                  ));
                }
              },
            ),
            _signSheetTile(
              icon: Icons.html_outlined, color: Colors.blue,
              title: 'Export Client Review Webpage',
              subtitle: 'Self-contained HTML the client opens in any browser',
              onTap: () async { Navigator.pop(context); await _exportQuoteHtml(context, quote, appState); },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showSignOrShareInvoiceSheet(BuildContext context, Invoice inv, AppState appState) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.draw_outlined, color: _gold),
              const SizedBox(width: 10),
              Expanded(child: Text('Client Review & Signature — ${inv.id}',
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold))),
            ]),
            const SizedBox(height: 6),
            const Text(
              'Send a review link, capture a signature on-device, or sync one already submitted online.',
              style: TextStyle(color: _white70, fontSize: 12),
            ),
            const SizedBox(height: 14),
            _signSheetTile(
              icon: Icons.link, color: _green,
              title: 'Send Review Link to Client',
              subtitle: 'Client opens in browser, signs — sent back automatically',
              onTap: () { Navigator.pop(context); _showInvoiceReviewLinkDialog(context, inv, appState); },
            ),
            _signSheetTile(
              icon: Icons.edit, color: _gold,
              title: 'Capture Signature Now',
              subtitle: 'Client signs directly on this screen, generates certified PDF',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => SignaturePage(invoice: inv)));
              },
            ),
            _signSheetTile(
              icon: Icons.sync, color: Colors.teal,
              title: 'Check / Sync Signature from Cloud',
              subtitle: 'Fetch signature from Firebase if signed remotely',
              onTap: () async {
                Navigator.pop(context);
                final found = await appState.checkCloudSignatureForInvoice(inv.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(found ? '✓ Signature retrieved! Invoice is now signed.' : 'No remote signature found yet.'),
                    backgroundColor: found ? _green : Colors.orange,
                  ));
                }
              },
            ),
            _signSheetTile(
              icon: Icons.html_outlined, color: Colors.blue,
              title: 'Export Client Review Webpage',
              subtitle: 'Self-contained HTML file for client review & signing',
              onTap: () async { Navigator.pop(context); await _exportInvoiceHtml(context, inv, appState); },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _signSheetTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
      subtitle: Text(subtitle, style: const TextStyle(color: _white70, fontSize: 11)),
      onTap: onTap,
    );
  }

  void _showQuoteReviewLinkDialog(BuildContext context, Quote quote, AppState appState) {
    CloudSyncService().saveQuote(quote);
    final url = ReviewServerService().getReviewUrl(type: 'quote', id: quote.id);
    _showReviewLinkDialog(context, title: 'Client Review Link — ${quote.id}', url: url,
      appState: appState, clientId: quote.clientId, clientName: quote.clientName,
      docLabel: 'Quotation ${quote.id}',
      onShareHtml: () => _exportQuoteHtml(context, quote, appState));
  }

  void _showInvoiceReviewLinkDialog(BuildContext context, Invoice inv, AppState appState) {
    CloudSyncService().saveInvoice(inv);
    final url = ReviewServerService().getReviewUrl(type: 'invoice', id: inv.id);
    _showReviewLinkDialog(context, title: 'Client Review Link — ${inv.id}', url: url,
      appState: appState, clientId: inv.clientId, clientName: inv.clientName,
      docLabel: 'Invoice ${inv.id}',
      onShareHtml: () => _exportInvoiceHtml(context, inv, appState));
  }

  void _showReviewLinkDialog(BuildContext context, {
    required String title,
    required String url,
    required AppState appState,
    required String clientId,
    required String clientName,
    required String docLabel,
    required VoidCallback onShareHtml,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _border)),
        title: Row(children: [
          const Icon(Icons.link, color: _gold, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold))),
        ]),
        content: ScrollablePanel(
          maxHeightFactor: 0.6,
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Send this link to the client. They can review and sign in their browser — no app required. Signature syncs back automatically.',
              style: TextStyle(color: _white70, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8), border: Border.all(color: _border)),
              child: Row(children: [
                Expanded(child: Text(url,
                    style: const TextStyle(color: _gold, fontSize: 11, fontFamily: 'monospace'),
                    maxLines: 2, overflow: TextOverflow.ellipsis)),
                IconButton(
                  icon: const Icon(Icons.copy, color: Colors.white, size: 17),
                  tooltip: 'Copy',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: url));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Link copied!'), backgroundColor: _green));
                  },
                ),
              ]),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: _border)),
                  icon: const Icon(Icons.open_in_browser, size: 15),
                  label: const Text('Open in Browser', style: TextStyle(fontSize: 11)),
                  onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: _gold, foregroundColor: Colors.black),
                  icon: const Icon(Icons.share, size: 15),
                  label: const Text('Share Webpage', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  onPressed: () { Navigator.pop(ctx); onShareHtml(); },
                ),
              ),
            ]),
            const SizedBox(height: 12),
            const Divider(color: _border, height: 1),
            const SizedBox(height: 10),
            const Text(
              'Send directly — the client\'s WhatsApp number or email is saved to their record.',
              style: TextStyle(color: _white38, fontSize: 11),
            ),
            const SizedBox(height: 8),
            SendContactButtons(
              appState: appState,
              clientId: clientId,
              clientName: clientName,
              docLabel: docLabel,
              url: url,
            ),
          ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close', style: TextStyle(color: _white70)))],
      ),
    );
  }

  Future<void> _exportQuoteHtml(BuildContext context, Quote quote, AppState appState) async {
    try {
      CloudSyncService().saveQuote(quote);
      final serverUrl = ReviewServerService().isRunning
          ? 'http://${ReviewServerService().localIp}:${ReviewServerService().port}'
          : null;
      final html = HtmlReviewService.generateQuoteHtml(quote, appState, serverUrl: serverUrl);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/Quote_${quote.id}_Review.html');
      await file.writeAsString(html, encoding: utf8);
      await Printing.sharePdf(bytes: await file.readAsBytes(), filename: 'Quote_${quote.id}_Review.html');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: _red));
      }
    }
  }

  Future<void> _exportInvoiceHtml(BuildContext context, Invoice inv, AppState appState) async {
    try {
      CloudSyncService().saveInvoice(inv);
      final serverUrl = ReviewServerService().isRunning
          ? 'http://${ReviewServerService().localIp}:${ReviewServerService().port}'
          : null;
      final html = HtmlReviewService.generateInvoiceHtml(inv, appState, serverUrl: serverUrl);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/Invoice_${inv.id}_Review.html');
      await file.writeAsString(html, encoding: utf8);
      await Printing.sharePdf(bytes: await file.readAsBytes(), filename: 'Invoice_${inv.id}_Review.html');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: _red));
      }
    }
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

  // ── New Professional Helper Widgets ────────────────────────────────────────

  /// Budget vs Actual + Project Timeline section
  Widget _buildBudgetVsActualSection(
    BuildContext context,
    AppState appState,
    Project project,
    double totalInvoiced,
    double totalExpenses,
  ) {
    final hasBudget = project.budget > 0;
    final budgetUsedPct = hasBudget ? (totalExpenses / project.budget).clamp(0.0, 1.5) : 0.0;
    final isOverBudget = hasBudget && totalExpenses > project.budget;
    final budgetColor = isOverBudget ? _red : _green;

    final now = DateTime.now();
    int? daysRemaining;
    bool isOverdue = false;
    if (project.deadline != null) {
      daysRemaining = project.deadline!.difference(now).inDays;
      isOverdue = daysRemaining < 0;
    }

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
          const Text(
            'Project Timeline & Budget',
            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),
          // Timeline row
          Row(
            children: [
              _timelineChip(
                icon: Icons.play_circle_outline_rounded,
                label: 'Start',
                value: _dateFmt.format(project.startDate),
                color: _blue,
              ),
              const Spacer(),
              const Icon(Icons.arrow_forward_rounded, color: _white38, size: 16),
              const Spacer(),
              _timelineChip(
                icon: project.deadline != null
                    ? (isOverdue ? Icons.alarm_off_rounded : Icons.flag_rounded)
                    : Icons.flag_outlined,
                label: 'Deadline',
                value: project.deadline != null ? _dateFmt.format(project.deadline!) : 'Not set',
                color: project.deadline == null
                    ? _white38
                    : (isOverdue ? _red : Colors.orange),
              ),
              if (project.status == ProjectStatus.completed) ...[
                const Spacer(),
                _timelineChip(
                  icon: Icons.check_circle_rounded,
                  label: 'Completed',
                  value: project.completedAt != null
                      ? _dateFmt.format(project.completedAt!)
                      : 'Yes',
                  color: _green,
                ),
              ] else if (daysRemaining != null) ...[
                const Spacer(),
                _timelineChip(
                  icon: isOverdue ? Icons.warning_amber_rounded : Icons.timer_outlined,
                  label: isOverdue ? 'Overdue by' : 'Days left',
                  value: '${isOverdue ? (-daysRemaining) : daysRemaining} day${daysRemaining.abs() != 1 ? 's' : ''}',
                  color: isOverdue ? _red : _green,
                ),
              ],
            ],
          ),
          // Budget section
          if (hasBudget) ...[
            const SizedBox(height: 16),
            const Divider(color: _border, height: 1),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Budget vs Actual Expenses', style: TextStyle(color: _white70, fontSize: 13)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: budgetColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: budgetColor.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    isOverBudget ? 'Over Budget' : 'Within Budget',
                    style: TextStyle(color: budgetColor, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                MoneyText(_fmt(totalExpenses), maxWidth: 150, alignment: Alignment.centerLeft, style: TextStyle(color: budgetColor, fontSize: 16, fontWeight: FontWeight.bold)),
                Flexible(
                  child: Text('of ${_fmt(project.budget)}', maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right, style: const TextStyle(color: _white70, fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: budgetUsedPct.clamp(0.0, 1.0),
                backgroundColor: _border,
                valueColor: AlwaysStoppedAnimation(budgetColor),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${(budgetUsedPct * 100).toStringAsFixed(1)}% of budget used${isOverBudget ? " (${_fmt(totalExpenses - project.budget)} over)" : " (${_fmt(project.budget - totalExpenses)} remaining)"}',
              style: TextStyle(color: isOverBudget ? _red : _white38, fontSize: 11),
            ),
          ] else ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => _showEditProjectDialog(context, appState, project),
              icon: const Icon(Icons.add_circle_outline, color: _gold, size: 16),
              label: const Text('Set project budget', style: TextStyle(color: _gold, fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _timelineChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: _white38, fontSize: 10)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  /// Cashflow collection rate progress bar
  Widget _buildCashflowCollectionRate(double totalInvoiced, double totalQuoted, double totalPaid) {
    final revenue = totalInvoiced > 0 ? totalInvoiced : totalQuoted;
    if (revenue <= 0) return const SizedBox.shrink();

    final collected = totalPaid.clamp(0.0, revenue);
    final pct = collected / revenue;
    final pctLabel = '${(pct * 100).toStringAsFixed(1)}%';
    final remaining = (revenue - totalPaid).clamp(0.0, double.infinity);
    final isFullyCollected = totalPaid >= revenue;

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
                'Revenue Collection Rate',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (isFullyCollected ? _green : _blue).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isFullyCollected ? _green : _blue),
                ),
                child: Text(
                  '$pctLabel Collected',
                  style: TextStyle(
                    color: isFullyCollected ? _green : _blue,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct.clamp(0.0, 1.0),
              backgroundColor: _blue.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation(isFullyCollected ? _green : _blue),
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Collected', style: TextStyle(color: _white38, fontSize: 11)),
                    MoneyText(_fmt(totalPaid), maxWidth: 145, alignment: Alignment.centerLeft, style: const TextStyle(color: _green, fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(isFullyCollected ? 'Fully Collected' : 'Remaining', style: const TextStyle(color: _white38, fontSize: 11)),
                    MoneyText(
                      isFullyCollected ? '✓ Done' : _fmt(remaining),
                      maxWidth: 145,
                      style: TextStyle(
                        color: isFullyCollected ? _green : Colors.orange,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Invoice status summary chips for Invoices tab
  Widget _buildInvoiceStatusSummary(List<Invoice> invoices) {
    final paid = invoices.where((i) => i.status == InvoiceStatus.paid).length;
    final sent = invoices.where((i) => i.status == InvoiceStatus.sent).length;
    final draft = invoices.where((i) => i.status == InvoiceStatus.draft).length;
    final overdue = invoices.where((i) => i.status == InvoiceStatus.overdue).length;

    return Wrap(
      spacing: 8,
      children: [
        if (paid > 0) _statusChip('$paid Paid', _green),
        if (sent > 0) _statusChip('$sent Sent', _blue),
        if (overdue > 0) _statusChip('$overdue Overdue', _red),
        if (draft > 0) _statusChip('$draft Draft', _white38),
      ],
    );
  }

  Widget _statusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  /// Export Statement as PDF
  void _exportStatementPdf(
    BuildContext context,
    AppState appState,
    Project project,
    List<Quote> quotes,
    List<Invoice> invoices,
  ) {
    PdfViewerPage.openDocumentPdf(
      context: context,
      title: 'Statement — ${project.name}',
      filename: 'Statement_${project.name.replaceAll(' ', '_')}.pdf',
      buildPdf: (pageFormat) => PdfService.generateProjectFinancialStatementPdf(
        appState: appState,
        project: project,
        quotes: quotes,
        invoices: invoices,
      ),
    );
  }

  /// Export Full Project Dossier PDF (cover + all quotes, invoices, payments, expenses)
  void _exportFullProjectPdf(
    BuildContext context,
    AppState appState,
    Project project,
    List<Quote> quotes,
    List<Invoice> invoices,
  ) {
    PdfViewerPage.openDocumentPdf(
      context: context,
      title: 'Full Dossier — ${project.name}',
      filename: 'ProjectDossier_${project.name.replaceAll(RegExp(r'[^\w]'), '_')}.pdf',
      buildPdf: (pageFormat) => PdfService.generateFullProjectPdf(
        appState: appState,
        project: project,
        quotes: quotes,
        invoices: invoices,
      ),
    );
  }
}

// ── Expenses Tab with Sort & Filter ────────────────────────────────────────────

class _ExpensesTabBody extends StatefulWidget {
  final Project project;
  final AppState appState;
  final String Function(double) fmt;
  final DateFormat dateFmt;
  final Color Function(String) getCategoryColor;
  final VoidCallback onAdd;
  final void Function(ProjectExpense) onEdit;
  final void Function(ProjectExpense) onDelete;

  const _ExpensesTabBody({
    required this.project,
    required this.appState,
    required this.fmt,
    required this.dateFmt,
    required this.getCategoryColor,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_ExpensesTabBody> createState() => _ExpensesTabBodyState();
}

class _ExpensesTabBodyState extends State<_ExpensesTabBody> {
  String _filterCategory = 'All';
  String _sortBy = 'Date';

  static const _categories = ['All', 'Materials', 'Labor', 'Transport', 'Tools', 'Subcontractor', 'Other'];
  static const _sortOptions = ['Date', 'Amount', 'Category'];

  @override
  Widget build(BuildContext context) {
    final allExpenses = widget.project.expenses;
    final total = widget.project.totalExpenses;

    // Filter
    var filtered = _filterCategory == 'All'
        ? List<ProjectExpense>.from(allExpenses)
        : allExpenses.where((e) => e.category == _filterCategory).toList();

    // Sort
    if (_sortBy == 'Date') {
      filtered.sort((a, b) => b.date.compareTo(a.date));
    } else if (_sortBy == 'Amount') {
      filtered.sort((a, b) => b.amount.compareTo(a.amount));
    } else if (_sortBy == 'Category') {
      filtered.sort((a, b) => a.category.compareTo(b.category));
    }

    final filteredTotal = filtered.fold(0.0, (s, e) => s + e.amount);

    return Scaffold(
      backgroundColor: _bg,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _gold,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add_shopping_cart_rounded),
        label: const Text('Add Bought Product', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: widget.onAdd,
      ),
      body: allExpenses.isEmpty
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
                    onPressed: widget.onAdd,
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
                // Header: total + filter/sort controls
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _border),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Expenses (${filtered.length}${_filterCategory != 'All' ? ' filtered' : ''}):',
                            style: const TextStyle(color: _white70, fontSize: 13),
                          ),
                          Text(
                            widget.fmt(filteredTotal),
                            style: const TextStyle(color: _gold, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      if (_filterCategory != 'All' && filtered.length != allExpenses.length) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Total all: ${widget.fmt(total)}',
                          style: const TextStyle(color: _white38, fontSize: 11),
                        ),
                      ],
                      const SizedBox(height: 10),
                      // Filter row
                      Row(
                        children: [
                          const Icon(Icons.filter_list_rounded, color: _white38, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: _categories.map((cat) {
                                  final isActive = _filterCategory == cat;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: GestureDetector(
                                      onTap: () => setState(() => _filterCategory = cat),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isActive ? _gold.withValues(alpha: 0.2) : const Color(0xFF0F162C),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: isActive ? _gold : _border,
                                          ),
                                        ),
                                        child: Text(
                                          cat,
                                          style: TextStyle(
                                            color: isActive ? _gold : _white70,
                                            fontSize: 11,
                                            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Sort dropdown
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F162C),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _border),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _sortBy,
                                dropdownColor: _surface,
                                style: const TextStyle(color: _white70, fontSize: 11),
                                isDense: true,
                                icon: const Icon(Icons.sort_rounded, color: _white38, size: 14),
                                items: _sortOptions.map((s) => DropdownMenuItem(
                                  value: s,
                                  child: Text(s),
                                )).toList(),
                                onChanged: (v) { if (v != null) setState(() => _sortBy = v); },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        'No expenses in "$_filterCategory" category.',
                        style: const TextStyle(color: _white38, fontSize: 13),
                      ),
                    ),
                  )
                else
                  ...filtered.map((e) => _buildExpenseCard(e)),
                const SizedBox(height: 80),
              ],
            ),
    );
  }

  Widget _buildExpenseCard(ProjectExpense e) {
    final catColor = widget.getCategoryColor(e.category);
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
                widget.fmt(e.amount),
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
                  '${e.quantity % 1 == 0 ? e.quantity.toInt() : e.quantity} ${e.unit} @ ${widget.fmt(e.unitPrice)}',
                  style: const TextStyle(color: _white70, fontSize: 12),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Date: ${widget.dateFmt.format(e.date)}${e.supplier.isNotEmpty ? " • ${e.supplier}" : ""}',
                style: const TextStyle(color: _white38, fontSize: 11),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: Colors.white70, size: 18),
                    tooltip: 'Edit Expense',
                    onPressed: () => widget.onEdit(e),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: _red, size: 18),
                    tooltip: 'Delete Expense',
                    onPressed: () => widget.onDelete(e),
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
}

// ── Shared popup menu item widget ────────────────────────────────────────────

class _PMenuItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  const _PMenuItem({required this.icon, required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, color: color, size: 16),
    const SizedBox(width: 8),
    Text(label, style: TextStyle(color: color == const Color(0xFF616C88) ? Colors.white70 : Colors.white, fontSize: 13)),
  ]);
}
