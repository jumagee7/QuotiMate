// pages/clients_page.dart — QuotiMate Clients Page
// Themed to match the dark-blue design system (Invoices & Products).

import 'package:flutter/material.dart';
import '../app_state.dart';
import '../models.dart';
import 'client_detail_page.dart';

// ─── Design Tokens ────────────────────────────────────────────────────────────
const _cSurface = Color(0xFF161B26);
const _cBorder  = Color(0xFF2A3045);
const _cGold    = Color(0xFFFFC107);
const _cW38     = Color(0xFF616C88);
const _cW70     = Color(0xFFB0B8D0);

enum ClientSort { nameAsc, nameDesc, quoteCount, company }

class ClientsPage extends StatefulWidget {
  const ClientsPage({super.key});
  @override
  State<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends State<ClientsPage> {
  String _search = '';
  ClientSort _sort = ClientSort.nameAsc;

  @override
  Widget build(BuildContext context) {
    final appState = AppStateProvider.of(context);
    final filtered = appState.clients.where((c) {
      final q = _search.toLowerCase();
      return q.isEmpty ||
          c.name.toLowerCase().contains(q) ||
          c.company.toLowerCase().contains(q) ||
          c.email.toLowerCase().contains(q);
    }).toList();

    switch (_sort) {
      case ClientSort.nameAsc:
        filtered.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case ClientSort.nameDesc:
        filtered.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
        break;
      case ClientSort.quoteCount:
        filtered.sort((a, b) => appState.quoteCountForClient(b.id).compareTo(appState.quoteCountForClient(a.id)));
        break;
      case ClientSort.company:
        filtered.sort((a, b) => a.company.toLowerCase().compareTo(b.company.toLowerCase()));
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Toolbar
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 42,
                child: TextField(
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search clients...',
                    hintStyle: const TextStyle(color: _cW38, fontSize: 13),
                    prefixIcon: const Icon(Icons.search, color: _cW38, size: 18),
                    suffixIcon: _search.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: _cW38, size: 16),
                            onPressed: () => setState(() => _search = ''),
                          )
                        : null,
                    filled: true,
                    fillColor: _cSurface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _cBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _cBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _cGold),
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Sort button
            PopupMenuButton<ClientSort>(
              tooltip: 'Sort Clients',
              color: const Color(0xFF161B26),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: _cBorder)),
              icon: Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: _cSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _cBorder),
                ),
                child: const Icon(Icons.sort_rounded, color: _cGold, size: 20),
              ),
              onSelected: (s) => setState(() => _sort = s),
              itemBuilder: (_) => [
                _sortMenuItem(ClientSort.nameAsc, 'Name: A to Z', Icons.arrow_upward),
                _sortMenuItem(ClientSort.nameDesc, 'Name: Z to A', Icons.arrow_downward),
                _sortMenuItem(ClientSort.quoteCount, 'Most Quotes', Icons.format_list_numbered),
                _sortMenuItem(ClientSort.company, 'Company Name', Icons.business_outlined),
              ],
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: () => _showClientDialog(context, appState, null),
              icon: const Icon(Icons.person_add, size: 16),
              label: const Text('New Client', style: TextStyle(fontWeight: FontWeight.bold)),
              style: FilledButton.styleFrom(
                backgroundColor: _cGold,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Table
        Expanded(
          child: Card(
            color: _cSurface,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: _cBorder),
            ),
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.people_outline, color: _cGold.withValues(alpha: 0.3), size: 48),
                        const SizedBox(height: 12),
                        const Text('No clients found.', style: TextStyle(color: _cW70, fontSize: 15)),
                        const SizedBox(height: 6),
                        const Text('Add a new client to get started.', style: TextStyle(color: _cW38, fontSize: 13)),
                      ],
                    ),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Column(
                      children: [
                        // Header
                        const _ClientTableHeader(),
                        const Divider(color: _cBorder, height: 1),
                        // Rows
                        Expanded(
                          child: ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (context, i) {
                              final c = filtered[i];
                              return _ClientRow(
                                client: c,
                                quoteCount: appState.quoteCountForClient(c.id),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => ClientDetailPage(client: c)),
                                  );
                                },
                                onEdit: () => _showClientDialog(context, appState, c),
                                onDelete: () => _confirmDelete(context, appState, c),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  PopupMenuItem<ClientSort> _sortMenuItem(ClientSort val, String label, IconData icon) {
    final isSelected = _sort == val;
    return PopupMenuItem(
      value: val,
      child: Row(
        children: [
          Icon(icon, size: 16, color: isSelected ? _cGold : _cW70),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: isSelected ? _cGold : Colors.white, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
        ],
      ),
    );
  }

  void _showClientDialog(BuildContext context, AppState appState, Client? existing) {
    showDialog(
      context: context,
      builder: (_) => _ClientFormDialog(appState: appState, existing: existing),
    );
  }

  void _confirmDelete(BuildContext context, AppState appState, Client client) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _cSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: _cBorder),
        ),
        title: const Text('Delete Client?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete "${client.name}"?',
              style: const TextStyle(color: _cW70, fontSize: 13),
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
                      'Warning: This client will also be permanently deleted from your Cloud backup and synced devices. This action cannot be undone.',
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
            child: const Text('Cancel', style: TextStyle(color: _cW38)),
          ),
          FilledButton(
            onPressed: () {
              appState.deleteClient(client.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Deleted client "${client.name}"'),
                  backgroundColor: Colors.redAccent,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// â”€â”€ Table Header â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _ClientTableHeader extends StatelessWidget {
  const _ClientTableHeader();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      color: _cW38,
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
    );
    return Container(
      color: const Color(0xFF131722),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: const Row(
        children: [
          Expanded(flex: 4, child: Text('NAME', style: style)),
          SizedBox(width: 76, child: Text('QUOTES', style: style, textAlign: TextAlign.center)),
          SizedBox(width: 80, child: Text('ACTIONS', style: style, textAlign: TextAlign.center)),
        ],
      ),
    );
  }
}

// â”€â”€ Client Row â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _ClientRow extends StatelessWidget {
  final Client client;
  final int quoteCount;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ClientRow({
    required this.client,
    required this.quoteCount,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final c = client;
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            splashColor: _cGold.withValues(alpha: 0.1),
            highlightColor: _cGold.withValues(alpha: 0.05),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  // NAME (flex:4)
                  Expanded(
                    flex: 4,
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: _cGold.withValues(alpha: 0.15),
                          child: Text(
                            c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                            style: const TextStyle(
                              color: _cGold,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.name,
                                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (c.company.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  c.company,
                                  style: const TextStyle(color: _cW70, fontSize: 11),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // QUOTES badge (width:76)
                  SizedBox(
                    width: 76,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _cBorder,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$quoteCount',
                          style: const TextStyle(color: _cGold, fontSize: 12, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                  // ACTIONS (width:80)
                  SizedBox(
                    width: 80,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: onEdit,
                          icon: const Icon(Icons.edit_outlined, size: 16, color: Colors.white54),
                          tooltip: 'Edit',
                        ),
                        IconButton(
                          onPressed: onDelete,
                          icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                          tooltip: 'Delete',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const Divider(color: _cBorder, height: 1),
      ],
    );
  }
}

// â”€â”€ Client Form Dialog â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _ClientFormDialog extends StatefulWidget {
  final AppState appState;
  final Client? existing;
  const _ClientFormDialog({required this.appState, this.existing});

  @override
  State<_ClientFormDialog> createState() => _ClientFormDialogState();
}

class _ClientFormDialogState extends State<_ClientFormDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _companyCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _addressCtrl;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl    = TextEditingController(text: e?.name    ?? '');
    _companyCtrl = TextEditingController(text: e?.company ?? '');
    _emailCtrl   = TextEditingController(text: e?.email   ?? '');
    _phoneCtrl   = TextEditingController(text: e?.phone   ?? '');
    _addressCtrl = TextEditingController(text: e?.address ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _companyCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Dialog(
      backgroundColor: const Color(0xFF161B26),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 520,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isEdit ? 'Edit Client' : 'New Client',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white54),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: _field(_nameCtrl, 'Full Name', required: true)),
                    const SizedBox(width: 12),
                    Expanded(child: _field(_companyCtrl, 'Company')),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _field(_emailCtrl, 'Email')),
                    const SizedBox(width: 12),
                    Expanded(child: _field(_phoneCtrl, 'Phone')),
                  ],
                ),
                const SizedBox(height: 12),
                _field(_addressCtrl, 'Address'),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      onPressed: _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFFC107),
                        foregroundColor: Colors.black,
                      ),
                      child: Text(isEdit ? 'Save Changes' : 'Add Client'),
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

  Widget _field(TextEditingController ctrl, String label, {bool required = false}) {
    return TextFormField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white),
      validator: required ? (v) => (v == null || v.isEmpty) ? 'Required' : null : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: const Color(0xFF0F162C),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Color(0xFF2A3045))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2A3045))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFFFC107))),
        errorStyle: const TextStyle(color: Colors.red),
      ),
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final existing = widget.existing;
    if (existing != null) {
      widget.appState.updateClient(existing.copyWith(
        name: _nameCtrl.text.trim(),
        company: _companyCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
      ));
    } else {
      widget.appState.addClient(Client(
        id: widget.appState.nextClientId,
        name: _nameCtrl.text.trim(),
        company: _companyCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
      ));
    }
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(existing != null ? 'Client updated!' : 'Client added!'),
        backgroundColor: Colors.green,
      ),
    );
  }
}

