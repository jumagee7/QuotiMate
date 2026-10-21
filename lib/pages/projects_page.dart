// pages/projects_page.dart — QuotiMate Projects Management Page
// Modern cards, financial KPIs, quickbook navigation, and project creation

import '../widgets/project_card.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_state.dart';
import '../models.dart';
import 'project_quickbook_page.dart';

const _surface = Color(0xFF161B26);
const _border  = Color(0xFF2A3045);
const _gold    = Color(0xFFFFC107);
const _white38 = Color(0xFF616C88);
const _white70 = Color(0xFFB0B8D0);
const _green   = Color(0xFF10B981);
const _red     = Color(0xFFEF4444);
const _blue    = Color(0xFF3B82F6);

enum ProjectSort { dateDesc, dateAsc, name, client, budgetDesc, budgetAsc, status }

class ProjectsPage extends StatefulWidget {
  const ProjectsPage({super.key});

  @override
  State<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends State<ProjectsPage> {
  ProjectStatus? _statusFilter;
  String _search = '';
  ProjectSort _sort = ProjectSort.dateDesc;
  final _currencyFmt = NumberFormat.currency(symbol: 'KES ', decimalDigits: 0);
  final _compactFmt = NumberFormat.compact();
  final _dateFmt = DateFormat('dd MMM yyyy');

  String _fmt(double val) => _currencyFmt.format(val);
  String _fmtCompact(double val) => 'KES ${_compactFmt.format(val)}';

  @override
  Widget build(BuildContext context) {
    final appState = AppStateProvider.of(context);

    final filtered = appState.projects.where((p) {
      final matchStatus = _statusFilter == null || p.status == _statusFilter;
      final matchSearch = _search.isEmpty ||
          p.name.toLowerCase().contains(_search.toLowerCase()) ||
          p.clientName.toLowerCase().contains(_search.toLowerCase()) ||
          p.location.toLowerCase().contains(_search.toLowerCase());
      return matchStatus && matchSearch;
    }).toList();

    switch (_sort) {
      case ProjectSort.dateDesc:
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case ProjectSort.dateAsc:
        filtered.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case ProjectSort.name:
        filtered.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case ProjectSort.client:
        filtered.sort((a, b) => a.clientName.toLowerCase().compareTo(b.clientName.toLowerCase()));
        break;
      case ProjectSort.budgetDesc:
        filtered.sort((a, b) => b.budget.compareTo(a.budget));
        break;
      case ProjectSort.budgetAsc:
        filtered.sort((a, b) => a.budget.compareTo(b.budget));
        break;
      case ProjectSort.status:
        filtered.sort((a, b) => a.status.index.compareTo(b.status.index));
        break;
    }

    // Aggregate KPIs across all projects
    final totalProjects = appState.projects.length;
    final activeProjects = appState.activeProjects.length;
    final totalInvoiced = appState.projects.fold<double>(0.0, (s, p) => s + p.totalInvoiced(appState.invoices));
    final totalCollected = appState.projects.fold<double>(0.0, (s, p) => s + p.totalPaymentsReceived);
    final totalExpenses = appState.projects.fold<double>(0.0, (s, p) => s + p.totalExpenses);
    final totalNetProfit = totalCollected - totalExpenses;
    final overallMargin = totalCollected > 0 ? (totalNetProfit / totalCollected) * 100 : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Top KPI Strip ───────────────────────────────────────────────────
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _kpi('Active Projects', '$activeProjects / $totalProjects', Icons.business_center_rounded, _gold),
              const SizedBox(width: 12),
              _kpi('Total Invoiced', _fmtCompact(totalInvoiced), Icons.receipt_long_rounded, _blue),
              const SizedBox(width: 12),
              _kpi('Total Collected', _fmtCompact(totalCollected), Icons.payments_rounded, _green),
              const SizedBox(width: 12),
              _kpi('Project Costs', _fmtCompact(totalExpenses), Icons.shopping_bag_outlined, Colors.orange),
              const SizedBox(width: 12),
              _kpi(
                'Net Profit',
                _fmtCompact(totalNetProfit),
                totalNetProfit >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                totalNetProfit >= 0 ? _green : _red,
                subtitle: '${overallMargin.toStringAsFixed(1)}% margin',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Toolbar: Search, Filters & Create ───────────────────────────────
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 42,
                child: TextField(
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search projects by name, client, or site location...',
                    hintStyle: const TextStyle(color: _white38, fontSize: 13),
                    prefixIcon: const Icon(Icons.search, color: _white38, size: 18),
                    filled: true,
                    fillColor: _surface,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
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
                  ),
                  onChanged: (v) => setState(() => _search = v.trim()),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Sort Button
            PopupMenuButton<ProjectSort>(
              tooltip: 'Sort Projects',
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
                _sortMenuItem(ProjectSort.dateDesc, 'Created: Newest First', Icons.calendar_today),
                _sortMenuItem(ProjectSort.dateAsc, 'Created: Oldest First', Icons.history),
                _sortMenuItem(ProjectSort.name, 'Project Name', Icons.title),
                _sortMenuItem(ProjectSort.client, 'Client Name', Icons.person_outline),
                _sortMenuItem(ProjectSort.budgetDesc, 'Budget: High to Low', Icons.arrow_downward),
                _sortMenuItem(ProjectSort.budgetAsc, 'Budget: Low to High', Icons.arrow_upward),
                _sortMenuItem(ProjectSort.status, 'Status', Icons.flag_outlined),
              ],
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () => _showCreateProjectDialog(context, appState),
              style: ElevatedButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('New Project', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Filter Chips ────────────────────────────────────────────────────
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _filterChip('All (${appState.projects.length})', null),
              ...ProjectStatus.values.map((s) {
                final count = appState.projects.where((p) => p.status == s).length;
                return _filterChip('${s.label} ($count)', s);
              }),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ── Projects List / Grid ────────────────────────────────────────────
        Expanded(
          child: filtered.isEmpty
              ? _buildEmptyState(context, appState)
              : ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (ctx, idx) => _buildProjectCard(context, appState, filtered[idx]),
                ),
        ),
      ],
    );
  }

  Widget _kpi(String label, String value, IconData icon, Color color, {String? subtitle}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: _white70, fontSize: 11)),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text(
                    value,
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(width: 6),
                    Text(subtitle, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  PopupMenuItem<ProjectSort> _sortMenuItem(ProjectSort val, String label, IconData icon) {
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

  Widget _filterChip(String label, ProjectStatus? status) {
    final isSelected = _statusFilter == status;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => setState(() => _statusFilter = status),
        backgroundColor: _surface,
        selectedColor: _gold.withValues(alpha: 0.2),
        labelStyle: TextStyle(
          color: isSelected ? _gold : _white70,
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        side: BorderSide(color: isSelected ? _gold : _border),
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, AppState appState) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _surface,
              shape: BoxShape.circle,
              border: Border.all(color: _border),
            ),
            child: const Icon(Icons.business_center_outlined, size: 48, color: _gold),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Projects Found',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            _search.isNotEmpty || _statusFilter != null
                ? 'Try adjusting your filters or search terms.'
                : 'Create your first project to organize quotes, invoices, purchases & profits.',
            style: const TextStyle(color: _white70, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => _showCreateProjectDialog(context, appState),
            style: ElevatedButton.styleFrom(backgroundColor: _gold, foregroundColor: Colors.black),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Create New Project', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectCard(BuildContext context, AppState appState, Project project) {
    return ProjectCard(project: project, appState: appState);
  }

  Widget _miniFinancial(String label, String value, Color color, {String? tag}) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: _white38, fontSize: 10)),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
            if (tag != null) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                child: Text(tag, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _divider() {
    return Container(height: 24, width: 1, color: _border);
  }

  Widget _countPill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF0F162C),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _white70, size: 12),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(color: _white70, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _statusBadge(ProjectStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: status.color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, color: status.color, size: 11),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: TextStyle(color: status.color, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // ── Project Creation Dialog ────────────────────────────────────────────────

  void _showCreateProjectDialog(BuildContext context, AppState appState) {
    final nameCtrl = TextEditingController();
    final budgetCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final clientNameCtrl = TextEditingController();

    String? selectedClientId;
    String selectedClientName = '';
    bool isNewClient = false;
    ProjectStatus status = ProjectStatus.inProgress;
    DateTime startDate = DateTime.now();
    DateTime? deadline;

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
              Icon(Icons.business_center_rounded, color: _gold, size: 22),
              SizedBox(width: 8),
              Text('Create New Project', style: TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Project Name
                  const Text('Project Name *', style: TextStyle(color: _white70, fontSize: 12)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF0F162C),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
                      hintText: 'e.g. Westlands Penthouse Kitchen Fitout',
                      hintStyle: const TextStyle(color: _white38),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Client Picker with Auto-Create
                  const Text('Client *', style: TextStyle(color: _white70, fontSize: 12)),
                  const SizedBox(height: 6),
                  Autocomplete<String>(
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return const Iterable<String>.empty();
                      }
                      return appState.clients
                          .where((client) => client.name.toLowerCase().contains(textEditingValue.text.toLowerCase()))
                          .map((client) => client.name);
                    },
                    onSelected: (String selection) {
                      final client = appState.clients.firstWhere((c) => c.name == selection);
                      setDlgState(() {
                        selectedClientId = client.id;
                        selectedClientName = client.name;
                        clientNameCtrl.text = client.name;
                        isNewClient = false;
                      });
                    },
                    fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                      clientNameCtrl.text = textEditingController.text;
                      textEditingController.addListener(() {
                        clientNameCtrl.text = textEditingController.text;
                      });
                      return TextField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFF0F162C),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
                          hintText: 'Type client name or select from list...',
                          hintStyle: const TextStyle(color: _white38),
                          suffixIcon: selectedClientId != null && !isNewClient
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18, color: _white38),
                                  onPressed: () {
                                    setDlgState(() {
                                      selectedClientId = null;
                                      selectedClientName = '';
                                      isNewClient = false;
                                      textEditingController.clear();
                                    });
                                  },
                                )
                              : null,
                        ),
                      );
                    },
                  ),
                  if (clientNameCtrl.text.isNotEmpty && selectedClientId == null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _gold.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _gold),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: _gold, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '"${clientNameCtrl.text}" will be created as a new client',
                              style: const TextStyle(color: _gold, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),

                  // Status & Budget
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Initial Status', style: TextStyle(color: _white70, fontSize: 12)),
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
                                  .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) setDlgState(() => status = val);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Estimated Budget (KES)', style: TextStyle(color: _white70, fontSize: 12)),
                            const SizedBox(height: 6),
                            TextField(
                              controller: budgetCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                prefixText: 'KES ',
                                filled: true,
                                fillColor: const Color(0xFF0F162C),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
                                hintText: '0.00',
                                hintStyle: const TextStyle(color: _white38),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Location / Site
                  const Text('Site Location', style: TextStyle(color: _white70, fontSize: 12)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: locationCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF0F162C),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
                      hintText: 'e.g. Parklands, Nairobi',
                      hintStyle: const TextStyle(color: _white38),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Start Date & Target Deadline
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Start Date', style: TextStyle(color: _white70, fontSize: 12)),
                            const SizedBox(height: 4),
                            TextButton.icon(
                              style: TextButton.styleFrom(padding: EdgeInsets.zero),
                              icon: const Icon(Icons.calendar_today, size: 14, color: _gold),
                              label: Text(_dateFmt.format(startDate), style: const TextStyle(color: Colors.white, fontSize: 12)),
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: startDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2035),
                                );
                                if (picked != null) setDlgState(() => startDate = picked);
                              },
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Target Completion', style: TextStyle(color: _white70, fontSize: 12)),
                            const SizedBox(height: 4),
                            TextButton.icon(
                              style: TextButton.styleFrom(padding: EdgeInsets.zero),
                              icon: const Icon(Icons.event_available, size: 14, color: _gold),
                              label: Text(
                                deadline != null ? _dateFmt.format(deadline!) : 'Not set',
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                              ),
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: deadline ?? DateTime.now().add(const Duration(days: 30)),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2035),
                                );
                                if (picked != null) setDlgState(() => deadline = picked);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Description / Notes
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
                      hintText: 'Brief summary of project scope...',
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
                final name = nameCtrl.text.trim();
                final clientName = clientNameCtrl.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a project name.')),
                  );
                  return;
                }
                if (clientName.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a client name for this project.')),
                  );
                  return;
                }

                // Auto-create client if not selected from list
                String finalClientId = selectedClientId ?? '';
                String finalClientName = selectedClientName;
                
                if (finalClientId.isEmpty) {
                  // Create new client
                  final newClient = Client(
                    id: appState.nextClientId,
                    name: clientName,
                    company: '',
                    email: '',
                    phone: '',
                    address: '',
                  );
                  appState.addClient(newClient);
                  finalClientId = newClient.id;
                  finalClientName = newClient.name;
                }

                final newProject = Project(
                  id: appState.nextProjectId,
                  name: name,
                  clientId: finalClientId,
                  clientName: finalClientName,
                  status: status,
                  startDate: startDate,
                  deadline: deadline,
                  budget: double.tryParse(budgetCtrl.text.trim()) ?? 0.0,
                  location: locationCtrl.text.trim(),
                  description: descCtrl.text.trim(),
                );

                appState.addProject(newProject);
                Navigator.pop(dialogCtx);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Project "${name}" created successfully!')),
                );

                // Open the QuickBook hub immediately for the new project
                openProjectQuickBookPage(context, projectId: newProject.id);
              },
              style: ElevatedButton.styleFrom(backgroundColor: _gold, foregroundColor: Colors.black),
              child: const Text('Create Project', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
