// quote_editor_page.dart — Full-page Quote Editor (replaces the dialog)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../app_state.dart';
import '../models.dart';
import '../services/pdf_service.dart';
import '../services/groq_service.dart';
import '../widgets/money_text.dart';
import 'pdf_viewer_page.dart';

// Entry point — call this instead of showDialog
Future<void> openQuoteEditorPage(
  BuildContext context,
  AppState appState, {
  Quote? quote,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => QuoteEditorPage(appState: appState, quote: quote),
      fullscreenDialog: false,
    ),
  );
}

class QuoteEditorPage extends StatefulWidget {
  final AppState appState;
  final Quote? quote;
  const QuoteEditorPage({super.key, required this.appState, this.quote});
  @override
  State<QuoteEditorPage> createState() => _QuoteEditorPageState();
}

class _QuoteEditorPageState extends State<QuoteEditorPage> {
  String? _clientId;
  final TextEditingController _clientNameCtrl = TextEditingController();
  QuoteStatus _status = QuoteStatus.draft;
  String _notes = '';
  String _labourInput = '';
  String _markupInput = '';
  List<QuoteCategory> _categories = [];
  Map<String, dynamic> _autocompleteItems = {};
  final Set<String> _collapsedCategories = {};
  bool _isScanning = false;

  static const _bg      = Color(0xFF0F162C);
  static const _surface = Color(0xFF161B26);
  static const _gold    = Color(0xFFFFC107);
  static const _goldDim = Color(0x26FFC107);
  static const _white38 = Color(0xFF616C88);
  static const _white70 = Color(0xFFB0B8D0);
  static const _border  = Color(0xFF2A3045);

  String _kes(double v) =>
      formatAmount(v, widget.appState.currency, decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    _loadAutocompleteItems();
    if (widget.quote != null) {
      final q = widget.quote!;
      _clientId    = q.clientId;
      _status      = q.status;
      _notes       = q.notes;
      _labourInput = q.labourInput;
      // Deep-copy categories AND items: QuoteItem fields are mutable and the
      // item rows edit them in place, so sharing objects with the original
      // quote would leak changes even when the user cancels.
      _categories  = q.categories.map((c) => QuoteCategory(
        id: c.id, name: c.name, labourInput: c.labourInput,
        showSubtotals: c.showSubtotals,
        items: c.items.map((i) => QuoteItem(
          productId: i.productId, name: i.name, qty: i.qty,
          unitPrice: i.unitPrice, unit: i.unit,
        )).toList(),
      )).toList();
      // Pre-fill client name
      final existingClient = widget.appState.clients
          .where((c) => c.id == q.clientId).firstOrNull;
      if (existingClient != null) _clientNameCtrl.text = existingClient.name;
    } else if (widget.appState.clients.isNotEmpty) {
      final first = widget.appState.clients.first;
      _clientId = first.id;
      _clientNameCtrl.text = first.name;
    }
  }

  @override
  void dispose() {
    _clientNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAutocompleteItems() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final f = File('${dir.path}/custom_itemlist.json');
      final s = await f.exists()
          ? await f.readAsString()
          : await rootBundle.loadString('assets/itemlist.json');
      if (mounted) setState(() => _autocompleteItems = jsonDecode(s));
    } catch (e) { debugPrint('itemlist: $e'); }
  }

  double get _subtotal    => _categories.fold(0.0, (s, c) => s + c.subtotal);
  double get _catLabour   => _categories.fold(0.0, (s, c) => s + c.labourCost);

  double _parsePct(String raw, double base) {
    final s = raw.trim();
    if (s.isEmpty) return 0;
    final str = s.endsWith('%') ? s.substring(0, s.length - 1) : s;
    final v = double.tryParse(str);
    if (v == null) return 0;
    return v > 0 && v < 1 ? base * v : base * (v / 100);
  }

  double get _globalLabour => _parsePct(_labourInput, _subtotal);
  double get _markup       => _parsePct(_markupInput, _subtotal);
  double get _taxBase      => _subtotal + _catLabour + _globalLabour + _markup;
  double get _tax          => _taxBase * widget.appState.defaultVatPercent / 100;
  double get _taxAndLabour => _catLabour + _globalLabour + _markup + _tax;
  double get _grandTotal   => _subtotal + _taxAndLabour;

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.quote != null;
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(isEdit ? 'Edit Quote' : 'New Quote',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
        actions: [
          if (_subtotal > 0) ...[
            IconButton(
              icon: const Icon(Icons.picture_as_pdf, color: _gold),
              tooltip: 'Preview & Share PDF',
              onPressed: _previewPdf,
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: _goldDim, borderRadius: BorderRadius.circular(20)),
              child: Text('Total: ${_kes(_grandTotal)}',
                style: const TextStyle(color: _gold, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Scrollbar(
              thumbVisibility: true,
              trackVisibility: true,
              thickness: 6,
              radius: const Radius.circular(4),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildClientStatus(),
                  const SizedBox(height: 20),
                  _buildCategoriesHeader(),
                  if (isEdit) ...[
                    const SizedBox(height: 4),
                    Align(alignment: Alignment.centerRight,
                      child: Text(widget.quote!.id,
                        style: const TextStyle(color: _white38, fontSize: 12))),
                  ],
                  const SizedBox(height: 12),
                  if (_categories.isEmpty)
                    _buildEmptyState()
                  else ...[
                    ...List.generate(_categories.length, (i) => _buildCategoryCard(i)),
                    const SizedBox(height: 4),
                    Center(
                      child: OutlinedButton.icon(
                        onPressed: _addCategory,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add Another Category', style: TextStyle(fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _gold,
                          side: const BorderSide(color: _border),
                          backgroundColor: _surface,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  _buildLabourSection(),
                  const SizedBox(height: 20),
                  _buildSummary(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
        _buildBottomBar(isEdit),
      ],
    ),
  );
  }

  // ── Client & Status ──────────────────────────────────────────────────────────
  Widget _buildClientStatus() {
    final clients = widget.appState.clients;
    final typedName = _clientNameCtrl.text.trim();
    final hasMatch = _clientId != null ||
        clients.any((c) => c.name.toLowerCase() == typedName.toLowerCase());
    final isNewClient = typedName.isNotEmpty && !hasMatch;

    return Row(children: [
      Expanded(child: _labelWrap('CLIENT',
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Autocomplete<Client>(
              optionsBuilder: (v) {
                if (v.text.trim().isEmpty) return clients;
                final q = v.text.toLowerCase();
                return clients.where((c) =>
                  c.name.toLowerCase().contains(q) ||
                  c.company.toLowerCase().contains(q));
              },
              displayStringForOption: (c) => c.name,
              onSelected: (c) {
                setState(() {
                  _clientId = c.id;
                  _clientNameCtrl.text = c.name;
                });
              },
              fieldViewBuilder: (_, ctrl, fn, _) {
                // Sync our persistent controller with the autocomplete's internal one
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (ctrl.text != _clientNameCtrl.text) {
                    ctrl.text = _clientNameCtrl.text;
                    ctrl.selection = TextSelection.collapsed(offset: ctrl.text.length);
                  }
                });
                return TextField(
                  controller: ctrl,
                  focusNode: fn,
                  style: const TextStyle(color: Colors.white),
                  decoration: _dec('Type client name...').copyWith(
                    prefixIcon: const Icon(Icons.person_outline, color: _white38, size: 18),
                    suffixIcon: isNewClient
                        ? const Tooltip(
                            message: 'Will create a new client',
                            child: Icon(Icons.person_add_outlined, color: _gold, size: 18),
                          )
                        : null,
                  ),
                  onChanged: (v) {
                    _clientNameCtrl.text = v;
                    // If text no longer matches current selection, clear clientId
                    if (_clientId != null) {
                      final sel = clients.where((c) => c.id == _clientId).firstOrNull;
                      if (sel != null && v != sel.name) {
                        setState(() => _clientId = null);
                      }
                    } else {
                      setState(() {});
                    }
                  },
                );
              },
              optionsViewBuilder: (_, onSel, opts) => Align(
                alignment: Alignment.topLeft,
                child: Material(
                  color: const Color(0xFF161B26),
                  elevation: 6,
                  borderRadius: BorderRadius.circular(10),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220, maxWidth: 340),
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      shrinkWrap: true,
                      itemCount: opts.length,
                      itemBuilder: (_, i) {
                        final c = opts.elementAt(i);
                        return InkWell(
                          onTap: () {
                            onSel(c);
                            _clientNameCtrl.text = c.name;
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Row(children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: _gold.withValues(alpha: 0.15),
                                child: Text(c.name[0].toUpperCase(),
                                  style: const TextStyle(color: _gold, fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(c.name, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                                  if (c.company.isNotEmpty)
                                    Text(c.company, style: const TextStyle(color: _white38, fontSize: 11)),
                                ],
                              )),
                            ]),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            if (isNewClient) ...[  
              const SizedBox(height: 4),
              Text(
                '"$typedName" will be saved as a new client',
                style: const TextStyle(color: _gold, fontSize: 11),
              ),
            ],
          ],
        ),
      )),
      const SizedBox(width: 12),
      Expanded(child: _labelWrap('STATUS', DropdownButtonFormField<QuoteStatus>(
        initialValue: _status,
        dropdownColor: const Color(0xFF0F162C),
        style: const TextStyle(color: Colors.white),
        decoration: _dec('Status'),
        items: QuoteStatus.values.map((s) => DropdownMenuItem(value: s,
          child: Row(children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: s.color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(s.label, style: TextStyle(color: s.color, fontWeight: FontWeight.w600)),
          ]))).toList(),
        onChanged: (v) => setState(() => _status = v!),
        icon: const Icon(Icons.keyboard_arrow_down, color: _white38),
      ))),
    ]);
  }


  // ── Categories header ────────────────────────────────────────────────────────
  Widget _buildCategoriesHeader() {
    final allCollapsed = _categories.isNotEmpty && _collapsedCategories.length == _categories.length;

    return Row(
      children: [
        const Text(
          'Categories',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const Spacer(),
        if (_categories.length > 1) ...[
          TextButton.icon(
            onPressed: () {
              setState(() {
                if (allCollapsed) {
                  _collapsedCategories.clear();
                } else {
                  _collapsedCategories.addAll(_categories.map((c) => c.id));
                }
              });
            },
            icon: Icon(
              allCollapsed ? Icons.unfold_more : Icons.unfold_less,
              size: 15,
              color: _white70,
            ),
            label: Text(
              allCollapsed ? 'Expand All' : 'Collapse All',
              style: const TextStyle(color: _white70, fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
        ],
        OutlinedButton.icon(
          onPressed: _showFillFromTextDialog,
          icon: const Icon(Icons.text_fields, size: 14),
          label: const Text('Fill from Text', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11)),
          style: OutlinedButton.styleFrom(
            foregroundColor: _white70,
            side: const BorderSide(color: _border),
            backgroundColor: _surface,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: _addCategory,
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Add Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          style: FilledButton.styleFrom(
            backgroundColor: _gold,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(14),
        color: _surface,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _gold.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.create_new_folder_outlined, color: _gold, size: 36),
          ),
          const SizedBox(height: 14),
          const Text(
            'No categories yet',
            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Group quotation line items into organized sections (e.g. Living Room, Electrical, Paint).',
            style: TextStyle(color: _white38, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _addCategory,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add First Category', style: TextStyle(fontWeight: FontWeight.bold)),
            style: FilledButton.styleFrom(
              backgroundColor: _gold,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 3,
            ),
          ),
        ],
      ),
    );
  }

  // ── Category card ────────────────────────────────────────────────────────────
  Widget _buildCategoryCard(int catIdx) {
    final cat = _categories[catIdx];
    final isCollapsed = _collapsedCategories.contains(cat.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header bar (with collapse / expand toggle)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1220),
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(12),
              bottom: Radius.circular(isCollapsed ? 12 : 0),
            ),
          ),
          child: Row(children: [
            IconButton(
              icon: Icon(
                isCollapsed ? Icons.keyboard_arrow_right : Icons.keyboard_arrow_down,
                color: _gold,
                size: 22,
              ),
              tooltip: isCollapsed ? 'Expand category' : 'Collapse category',
              splashRadius: 18,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: () => setState(() {
                if (isCollapsed) {
                  _collapsedCategories.remove(cat.id);
                } else {
                  _collapsedCategories.add(cat.id);
                }
              }),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _CategoryNameField(
                key: ValueKey('catname_${cat.id}'),
                initialName: cat.name,
                onChanged: (v) { cat.name = v; setState(() {}); },
              ),
            ),
            if (isCollapsed) ...[
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Text(
                  '${cat.items.length} item${cat.items.length == 1 ? '' : 's'}',
                  style: const TextStyle(color: Color(0xFF93C5FD), fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ],
            if (cat.subtotal > 0)
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                const Text('CATEGORY SUBTOTAL',
                  style: TextStyle(color: _white38, fontSize: 9, letterSpacing: 0.5)),
                Text(_kes(cat.subtotal),
                  style: const TextStyle(color: _gold, fontWeight: FontWeight.bold, fontSize: 13)),
              ]),
            const SizedBox(width: 4),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: _white38, size: 18),
              color: const Color(0xFF0F162C),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: _border),
              ),
              onSelected: (v) {
                if (v == 'toggle') {
                  setState(() {
                    if (isCollapsed) {
                      _collapsedCategories.remove(cat.id);
                    } else {
                      _collapsedCategories.add(cat.id);
                    }
                  });
                }
                if (v == 'up' && catIdx > 0)             _moveCategory(catIdx, -1);
                if (v == 'down' && catIdx < _categories.length - 1) _moveCategory(catIdx, 1);
                if (v == 'dup')    _duplicateCategory(catIdx);
                if (v == 'del')    setState(() => _categories.removeAt(catIdx));
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'toggle',
                  child: Row(children: [
                    Icon(isCollapsed ? Icons.unfold_more : Icons.unfold_less, color: Colors.white70, size: 16),
                    const SizedBox(width: 8),
                    Text(isCollapsed ? 'Expand' : 'Collapse', style: const TextStyle(color: Colors.white)),
                  ]),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(value: 'up',  child: Text('Move Up',   style: TextStyle(color: Colors.white))),
                const PopupMenuItem(value: 'down',child: Text('Move Down', style: TextStyle(color: Colors.white))),
                const PopupMenuItem(value: 'dup', child: Text('Duplicate', style: TextStyle(color: Colors.white70))),
                const PopupMenuDivider(),
                const PopupMenuItem(value: 'del', child: Text('Delete Category', style: TextStyle(color: Colors.red))),
              ],
            ),
          ]),
        ),

        // Collapsible Content
        if (!isCollapsed) ...[
          // Tip for category name
          if (cat.name.trim().isEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(14, 8, 14, 2),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFF0F162C),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF2A3045)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lightbulb_outline_rounded, color: _gold, size: 15),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tip: A blank category name won\'t render the category title on the PDF, grouping items seamlessly.',
                      style: TextStyle(color: _white70, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),

          // Line Items label
          const Padding(
            padding: EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Text('Line Items',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
          ),

          // Items
          if (cat.items.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(14, 4, 14, 8),
              child: Text('No items yet — tap Add New Item below',
                style: TextStyle(color: _white38, fontSize: 12)),
            )
          else
            ...cat.items.asMap().entries.map((e) => _buildItemCard(catIdx, e.key, e.value)),

          // Add new item button
          GestureDetector(
            onTap: () => _showAddItemDialog(catIdx),
            child: Container(
              margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _gold.withValues(alpha: 0.35)),
                color: _gold.withValues(alpha: 0.04),
              ),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.add, color: _gold, size: 16),
                SizedBox(width: 6),
                Text('ADD NEW ITEM',
                  style: TextStyle(color: _gold, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
              ]),
            ),
          ),

          // Per-category labour row (responsive layout to prevent overflow)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1320),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _border),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 10,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.handyman_outlined, color: _white38, size: 16),
                    const SizedBox(width: 6),
                    const Text('CATEGORY LABOUR',
                      style: TextStyle(color: _white38, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
                    const SizedBox(width: 4),
                    Tooltip(
                      message: 'Enter % (e.g. 15%), flat ${widget.appState.currency} (e.g. 5000), or fraction (e.g. 1/3)',
                      child: const Icon(Icons.info_outline, color: _white38, size: 13),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 105,
                      child: _CategoryLabourField(
                        key: ValueKey('labour_${cat.id}'),
                        initial: cat.labourInput,
                        onChanged: (v) => setState(() => cat.labourInput = v),
                        border: _border,
                        gold: _gold,
                        white38: _white38,
                      ),
                    ),
                    if (cat.labourCost > 0) ...[
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('LABOUR COST',
                            style: TextStyle(color: _white38, fontSize: 9, letterSpacing: 0.5)),
                          Text(_kes(cat.labourCost),
                            style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ]),
    );
  }


  // ── Item card ────────────────────────────────────────────────────────────────
  Widget _buildItemCard(int catIdx, int itemIdx, QuoteItem item) {
    // Key must NOT include mutable fields (like item.name) — otherwise each
    // keystroke changes the key, Flutter disposes the stateful widget and
    // recreates it, resetting the controller to the single typed character.
    return _ItemCardWidget(
      key: ValueKey('item_${catIdx}_${itemIdx}_${item.productId}'),
      item: item,
      currency: widget.appState.currency,
      dec: _dec,
      onDelete: () => setState(() => _categories[catIdx].items.removeAt(itemIdx)),
      onChanged: () => setState(() {}),
    );
  }

  // ── Labour section ───────────────────────────────────────────────────────────
  Widget _buildLabourSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.people_outline, color: Colors.white70, size: 18),
          SizedBox(width: 8),
          Text('Labor & Adjustment',
            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _labelWrap('LABOR (%)',
            _PctField(initial: _labourInput, onChanged: (v) => setState(() => _labourInput = v), border: _border, gold: _gold, white38: _white38))),
          const SizedBox(width: 12),
          Expanded(child: _labelWrap('MARKUP (%)',
            _PctField(initial: _markupInput, onChanged: (v) => setState(() => _markupInput = v), border: _border, gold: _gold, white38: _white38))),
        ]),
        const SizedBox(height: 14),
        _labelWrap('LABOR NOTES',
          _LaborNotesField(
            key: const ValueKey('quote_labor_notes'),
            initialNotes: _notes,
            border: _border,
            gold: _gold,
            white38: _white38,
            onChanged: (v) => _notes = v,
          ),
        ),
      ]),
    );
  }

  // ── Summary panel ────────────────────────────────────────────────────────────
  Widget _buildSummary() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(children: [
        _summaryRow('SUBTOTAL',    _kes(_subtotal),    false),
        const SizedBox(height: 8),
        _summaryRow('LABOR & MARKUP', _kes(_catLabour + _globalLabour + _markup), false),
        const SizedBox(height: 8),
        _summaryRow('VAT (${_fmtPct(widget.appState.defaultVatPercent)})', _kes(_tax), false),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Divider(color: Colors.white.withValues(alpha: 0.08), thickness: 1)),
        _summaryRow('Grand Total', _kes(_grandTotal), true),
      ]),
    );
  }

  String _fmtPct(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  Widget _summaryRow(String label, String value, bool big) {
    return Row(children: [
      Text(label, style: TextStyle(
        color: big ? Colors.white : _white70,
        fontSize: big ? 15 : 13,
        fontWeight: big ? FontWeight.bold : FontWeight.normal,
      )),
      const Spacer(),
      Text(value, style: TextStyle(
        color: _gold,
        fontSize: big ? 20 : 13,
        fontWeight: FontWeight.bold,
      )),
    ]);
  }

  // ── Bottom bar ───────────────────────────────────────────────────────────────
  Widget _buildBottomBar(bool isEdit) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: BoxDecoration(
        color: _surface,
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      ),
      child: SafeArea(top: false, child: Row(children: [
        Expanded(child: OutlinedButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close, size: 18),
          label: const Text('Cancel'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white54,
            side: const BorderSide(color: Colors.white24),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        )),
        const SizedBox(width: 12),
        Expanded(flex: 2, child: ElevatedButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.check_circle_outline, size: 18),
          label: Text(isEdit ? 'Update' : 'Save Quote',
            style: const TextStyle(fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: _gold,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            elevation: 4,
          ),
        )),
      ])),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────
  InputDecoration _dec(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: _white38),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _gold)),
    filled: true, fillColor: Colors.white.withValues(alpha: 0.04),
    isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
  );

  Widget _labelWrap(String lbl, Widget child) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(lbl, style: const TextStyle(color: _white38, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
      const SizedBox(height: 6),
      child,
    ],
  );

  void _addCategory() {
    setState(() => _categories.add(QuoteCategory(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: 'Category ${_categories.length + 1}',
      items: [],
    )));
  }

  void _moveCategory(int idx, int dir) {
    if (idx + dir < 0 || idx + dir >= _categories.length) return;
    setState(() { final c = _categories.removeAt(idx); _categories.insert(idx + dir, c); });
  }

  void _duplicateCategory(int idx) {
    setState(() {
      final orig = _categories[idx];
      _categories.insert(idx + 1, QuoteCategory(
        id: 'cat_${DateTime.now().millisecondsSinceEpoch}',
        name: '${orig.name} (Copy)', labourInput: orig.labourInput,
        showSubtotals: orig.showSubtotals,
        items: orig.items.map((i) => QuoteItem(
          productId: 'custom_${DateTime.now().millisecondsSinceEpoch}',
          name: i.name, qty: i.qty, unitPrice: i.unitPrice, unit: i.unit,
        )).toList(),
      ));
    });
  }

  void _showAddItemDialog(int catIdx) {
    String itemName = '';
    final qtyCtrl   = TextEditingController(text: '1');
    final unitCtrl  = TextEditingController(text: 'Pcs');
    final priceCtrl = TextEditingController(text: '0');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: _surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Add Item', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _labelWrap('ITEM NAME',
                  Autocomplete<String>(
                    optionsBuilder: (v) {
                      if (v.text.isEmpty) return const Iterable<String>.empty();
                      final q = v.text.toLowerCase();
                      // Prefer the cloud-synced catalogue; fall back to the bundled itemlist.json
                      final src = widget.appState.products.isNotEmpty
                          ? widget.appState.productNames
                          : _autocompleteItems.keys.toList();
                      return src.where((o) => o.toLowerCase().contains(q));
                    },
                    onSelected: (sel) {
                      setDlg(() {
                        itemName = sel;
                        final product = widget.appState.productByName(sel);
                        if (product != null) {
                          unitCtrl.text = product.unit;
                          priceCtrl.text = product.unitPrice == product.unitPrice.truncateToDouble()
                              ? product.unitPrice.toInt().toString()
                              : product.unitPrice.toStringAsFixed(2);
                        } else {
                          final info = _autocompleteItems[sel];
                          if (info is List && info.length >= 2) {
                            unitCtrl.text = info[0].toString();
                            priceCtrl.text = info[1].toString();
                          }
                        }
                      });
                    },
                    fieldViewBuilder: (_, ctrl, fn, _) => TextField(
                      controller: ctrl, focusNode: fn,
                      style: const TextStyle(color: Colors.white),
                      decoration: _dec('Type or select item...'),
                      onChanged: (v) => itemName = v,
                    ),
                    optionsViewBuilder: (_, onSel, opts) => Align(
                      alignment: Alignment.topLeft,
                      child: Material(color: const Color(0xFF0F162C), elevation: 4, borderRadius: BorderRadius.circular(8),
                        child: SizedBox(width: 360, height: 180,
                          child: ListView.builder(
                            padding: EdgeInsets.zero, itemCount: opts.length,
                            itemBuilder: (_, i) {
                              final opt = opts.elementAt(i);
                              return ListTile(
                                title: Text(opt, style: const TextStyle(color: Colors.white)),
                                onTap: () => onSel(opt),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: _labelWrap('QUANTITY',
                    TextField(controller: qtyCtrl, style: const TextStyle(color: Colors.white),
                      decoration: _dec('1'), keyboardType: TextInputType.number))),
                  const SizedBox(width: 12),
                  Expanded(child: _labelWrap('UNIT',
                    TextField(controller: unitCtrl, style: const TextStyle(color: Colors.white),
                      decoration: _dec('Pcs')))),
                ]),
                const SizedBox(height: 14),
                _labelWrap('UNIT PRICE (${widget.appState.currency})',
                  TextField(controller: priceCtrl, style: const TextStyle(color: Colors.white),
                    decoration: _dec('0'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: moneyInputFormatters(decimalDigits: 2))),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _gold, foregroundColor: Colors.black),
              onPressed: () {
                if (itemName.trim().isNotEmpty) {
                  setState(() {
                    _categories[catIdx].items.add(QuoteItem(
                      productId: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                      name: itemName.trim(),
                      qty: parseMoneyOr(qtyCtrl.text, 1.0),
                      unitPrice: parseMoneyOr(priceCtrl.text),
                      unit: unitCtrl.text.trim().isEmpty ? 'Pcs' : unitCtrl.text.trim(),
                    ));
                  });
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Add Item'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Fill from Text Dialog ─────────────────────────────────────────────────────
  void _showFillFromTextDialog() {
    final textCtrl = TextEditingController();
    final catNameCtrl = TextEditingController(text: 'Imported Items');
    
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: _surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: _border),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _gold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.text_fields, color: _gold, size: 18),
              ),
              const SizedBox(width: 12),
              const Text('Fill from Text', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Scan buttons section with background
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D1220),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'SCAN IMAGE FOR ITEMS',
                        style: TextStyle(color: _gold, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _isScanning ? null : () => _pickAndScanImage(setDlg, textCtrl),
                              icon: _isScanning
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                                  : const Icon(Icons.camera_alt, size: 16),
                              label: Text(_isScanning ? 'Scanning...' : 'Camera', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              style: FilledButton.styleFrom(
                                backgroundColor: _gold,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isScanning ? null : () => _pickAndScanImage(setDlg, textCtrl, fromGallery: true),
                              icon: _isScanning
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: _gold))
                                  : const Icon(Icons.photo_library, size: 16),
                              label: Text(_isScanning ? 'Scanning...' : 'Gallery', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: _border),
                                backgroundColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Paste your items below or scan an image. Supports formats like:',
                  style: TextStyle(color: _white70, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D1220),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _border),
                  ),
                  child: Text(
                    '• Item name, qty, price\n• Item name - qty x price\n• Item name\tqty\tprice\n• Item name ${widget.appState.currency} 5000 x 2',
                    style: const TextStyle(color: _white38, fontSize: 11, fontFamily: 'monospace'),
                  ),
                ),
                const SizedBox(height: 14),
                _labelWrap('CATEGORY NAME',
                  TextField(
                    controller: catNameCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: _dec('Imported Items'),
                  ),
                ),
                const SizedBox(height: 14),
                _labelWrap('ITEMS TEXT',
                  TextField(
                    controller: textCtrl,
                    style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 12),
                    decoration: _dec('Paste items here or scan image...').copyWith(
                      hintStyle: const TextStyle(fontFamily: 'monospace'),
                    ),
                    maxLines: 8,
                    keyboardType: TextInputType.multiline,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                final text = textCtrl.text.trim();
                if (text.isEmpty) return;
                
                setDlg(() => _isScanning = true);
                final formatted = await GroqService().formatQuoteText(text);
                setDlg(() {
                  textCtrl.text = formatted;
                  _isScanning = false;
                });
              },
              icon: const Icon(Icons.auto_awesome, size: 16),
              label: const Text('AI Format', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: _gold,
                side: const BorderSide(color: _gold),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _gold, foregroundColor: Colors.black),
              onPressed: () {
                final text = textCtrl.text.trim();
                if (text.isNotEmpty) {
                  _parseAndAddItems(text, catNameCtrl.text.trim());
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Import Items'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndScanImage(StateSetter setDlg, TextEditingController textCtrl, {bool fromGallery = false}) async {
    final picker = ImagePicker();
    final source = fromGallery ? ImageSource.gallery : ImageSource.camera;
    
    try {
      final XFile? image = await picker.pickImage(source: source);
      if (image == null) return;

      setState(() => _isScanning = true);
      setDlg(() => _isScanning = true);
      
      final recognizedText = await _scanImage(image.path);
      
      if (recognizedText.isNotEmpty) {
        setState(() => _isScanning = false);
        setDlg(() {
          textCtrl.text = recognizedText;
          _isScanning = false;
        });
      } else {
        setState(() => _isScanning = false);
        setDlg(() => _isScanning = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not extract text from image. Try a clearer image.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isScanning = false);
      setDlg(() => _isScanning = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error scanning image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String> _scanImage(String imagePath) async {
    final textRecognizer = TextRecognizer();
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();
      return recognizedText.text;
    } catch (e) {
      await textRecognizer.close();
      debugPrint('OCR Error: $e');
      return '';
    }
  }

  void _parseAndAddItems(String text, String categoryName) {
    final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return;

    final items = <QuoteItem>[];
    final unmatchedItems = <(QuoteItem, String)>[]; // (item, original line)
    final appState = AppStateProvider.of(context);
    final products = appState.products;
    
    for (final line in lines) {
      final result = _parseItemLine(line, products);
      if (result != null) {
        final (item, wasMatched) = result;
        items.add(item);
        if (!wasMatched) {
          unmatchedItems.add((item, line));
        }
      }
    }

    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not parse any items. Check the format.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      if (_categories.isEmpty) {
        _categories.add(QuoteCategory(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: categoryName.isEmpty ? 'Imported Items' : categoryName,
          items: items,
        ));
      } else {
        // Add to first category or create new one
        _categories[0].items.addAll(items);
      }
    });

    // Show report and handle unmatched items
    final message = 'Imported ${items.length} item${items.length == 1 ? '' : 's'}';
    
    if (unmatchedItems.isNotEmpty) {
      _showUnmatchedItemsDialog(unmatchedItems, categoryName);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$message (all matched to catalogue)'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  (QuoteItem, bool)? _parseItemLine(String line, List<Product> products) {
    // Try multiple patterns to extract item name, quantity, unit, and price
    
    // Common unit keywords to detect
    final unitKeywords = ['pcs', 'pc', 'pieces', 'piece', 'bundles', 'bundle', 'pkts', 'pkt', 'packets', 'packet', 
                          'rolls', 'roll', 'sq ft', 'sqft', 'square feet', 'meters', 'meter', 'm', 'kg', 'kilograms',
                          'liters', 'liter', 'l', 'gallons', 'gallon', 'boxes', 'box', 'cartons', 'carton'];
    
    // Pattern 0: AI format "Item Name, Quantity, Unit, Price"
    final pattern0 = RegExp(r'^(.+?)\s*,\s*(\d+(?:\.\d+)?)\s*,\s*(.+?)\s*,\s*(\d+(?:,\d+)*(?:\.\d+)?)\s*$');
    final match0 = pattern0.firstMatch(line);
    if (match0 != null) {
      final itemName = match0.group(1)!.trim();
      final unit = match0.group(3)!.trim();
      final qty = double.tryParse(match0.group(2)!) ?? 1.0;
      final price = double.tryParse(match0.group(4)!.replaceAll(',', '')) ?? 0.0;
      
      // Find closest matching product
      final matchedProduct = _findClosestProduct(itemName, products);
      
      return (QuoteItem(
        productId: matchedProduct?.id ?? 'custom_${DateTime.now().millisecondsSinceEpoch}',
        name: matchedProduct?.name ?? itemName,
        qty: qty,
        unitPrice: matchedProduct?.unitPrice ?? price,
        unit: matchedProduct?.unit ?? (unit.isEmpty ? 'Pcs' : unit),
      ), matchedProduct != null);
    }

    // Pattern 1: "Item name, qty, price" or "Item name, qty x price"
    final pattern1 = RegExp(r'^(.+?)\s*[,\t]\s*(\d+(?:\.\d+)?)\s*(?:x|X|\*)?\s*(\d+(?:,\d+)*(?:\.\d+)?)\s*$');
    final match1 = pattern1.firstMatch(line);
    if (match1 != null) {
      // Try to detect unit from item name
      final itemName = match1.group(1)!.trim().toLowerCase();
      String detectedUnit = 'Pcs';
      for (final keyword in unitKeywords) {
        if (itemName.contains(keyword)) {
          detectedUnit = keyword;
          break;
        }
      }
      final matchedProduct = _findClosestProduct(match1.group(1)!.trim(), products);
      return (QuoteItem(
        productId: matchedProduct?.id ?? 'custom_${DateTime.now().millisecondsSinceEpoch}',
        name: matchedProduct?.name ?? match1.group(1)!.trim(),
        qty: double.tryParse(match1.group(2)!) ?? 1.0,
        unitPrice: matchedProduct?.unitPrice ?? double.tryParse(match1.group(3)!.replaceAll(',', '')) ?? 0.0,
        unit: matchedProduct?.unit ?? detectedUnit,
      ), matchedProduct != null);
    }

    // Pattern 2: "Item name - qty x price"
    final pattern2 = RegExp(r'^(.+?)\s*-\s*(\d+(?:\.\d+)?)\s*(?:x|X|\*)\s*(\d+(?:,\d+)*(?:\.\d+)?)\s*$');
    final match2 = pattern2.firstMatch(line);
    if (match2 != null) {
      final itemName = match2.group(1)!.trim().toLowerCase();
      String detectedUnit = 'Pcs';
      for (final keyword in unitKeywords) {
        if (itemName.contains(keyword)) {
          detectedUnit = keyword;
          break;
        }
      }
      final matchedProduct = _findClosestProduct(match2.group(1)!.trim(), products);
      return (QuoteItem(
        productId: matchedProduct?.id ?? 'custom_${DateTime.now().millisecondsSinceEpoch}',
        name: matchedProduct?.name ?? match2.group(1)!.trim(),
        qty: double.tryParse(match2.group(2)!) ?? 1.0,
        unitPrice: matchedProduct?.unitPrice ?? double.tryParse(match2.group(3)!.replaceAll(',', '')) ?? 0.0,
        unit: matchedProduct?.unit ?? detectedUnit,
      ), matchedProduct != null);
    }

    // Pattern 3: "Item name KES 5000 x 2" (price first, then quantity)
    final pattern3 = RegExp(r'^(.+?)\s*(?:KES|Ksh|KES\.|Ksh\.)?\s*(\d+(?:,\d+)*(?:\.\d+)?)\s*(?:x|X|\*)\s*(\d+(?:\.\d+)?)\s*$');
    final match3 = pattern3.firstMatch(line);
    if (match3 != null) {
      final itemName = match3.group(1)!.trim().toLowerCase();
      String detectedUnit = 'Pcs';
      for (final keyword in unitKeywords) {
        if (itemName.contains(keyword)) {
          detectedUnit = keyword;
          break;
        }
      }
      final matchedProduct = _findClosestProduct(match3.group(1)!.trim(), products);
      return (QuoteItem(
        productId: matchedProduct?.id ?? 'custom_${DateTime.now().millisecondsSinceEpoch}',
        name: matchedProduct?.name ?? match3.group(1)!.trim(),
        qty: double.tryParse(match3.group(4)!) ?? 1.0,
        unitPrice: matchedProduct?.unitPrice ?? double.tryParse(match3.group(2)!.replaceAll(',', '')) ?? 0.0,
        unit: matchedProduct?.unit ?? detectedUnit,
      ), matchedProduct != null);
    }

    // Pattern 4: Tab-separated "Item name\tqty\tunit\tprice" or "Item name\tqty\tprice"
    final parts = line.split('\t').map((p) => p.trim()).toList();
    if (parts.length >= 4) {
      final qty = double.tryParse(parts[1]);
      final price = double.tryParse(parts[3].replaceAll(',', ''));
      if (qty != null && price != null) {
        final matchedProduct = _findClosestProduct(parts[0], products);
        return (QuoteItem(
          productId: matchedProduct?.id ?? 'custom_${DateTime.now().millisecondsSinceEpoch}',
          name: matchedProduct?.name ?? parts[0],
          qty: qty,
          unitPrice: matchedProduct?.unitPrice ?? price,
          unit: matchedProduct?.unit ?? (parts[2].isEmpty ? 'Pcs' : parts[2]),
        ), matchedProduct != null);
      }
    }
    if (parts.length >= 3) {
      final qty = double.tryParse(parts[1]);
      final price = double.tryParse(parts[2].replaceAll(',', ''));
      if (qty != null && price != null) {
        final itemName = parts[0].toLowerCase();
        String detectedUnit = 'Pcs';
        for (final keyword in unitKeywords) {
          if (itemName.contains(keyword)) {
            detectedUnit = keyword;
            break;
          }
        }
        final matchedProduct = _findClosestProduct(parts[0], products);
        return (QuoteItem(
          productId: matchedProduct?.id ?? 'custom_${DateTime.now().millisecondsSinceEpoch}',
          name: matchedProduct?.name ?? parts[0],
          qty: qty,
          unitPrice: matchedProduct?.unitPrice ?? price,
          unit: matchedProduct?.unit ?? detectedUnit,
        ), matchedProduct != null);
      }
    }

    // Pattern 5: Just item name with price at end "Item name 5000"
    final pattern5 = RegExp(r'^(.+?)\s+(\d+(?:,\d+)*(?:\.\d+)?)\s*$');
    final match5 = pattern5.firstMatch(line);
    if (match5 != null) {
      final itemName = match5.group(1)!.trim().toLowerCase();
      String detectedUnit = 'Pcs';
      for (final keyword in unitKeywords) {
        if (itemName.contains(keyword)) {
          detectedUnit = keyword;
          break;
        }
      }
      final matchedProduct = _findClosestProduct(match5.group(1)!.trim(), products);
      return (QuoteItem(
        productId: matchedProduct?.id ?? 'custom_${DateTime.now().millisecondsSinceEpoch}',
        name: matchedProduct?.name ?? match5.group(1)!.trim(),
        qty: 1.0,
        unitPrice: matchedProduct?.unitPrice ?? double.tryParse(match5.group(2)!.replaceAll(',', '')) ?? 0.0,
        unit: matchedProduct?.unit ?? detectedUnit,
      ), matchedProduct != null);
    }

    return null;
  }

  void _showUnmatchedItemsDialog(List<(QuoteItem, String)> unmatchedItems, String categoryName) {
    int currentIndex = 0;
    final ScrollController scrollController = ScrollController();
    final GlobalKey itemKey = GlobalKey();
    final nameController = TextEditingController(text: unmatchedItems[0].$1.name);
    final qtyController = TextEditingController(text: unmatchedItems[0].$1.qty.toString());
    final priceController = TextEditingController(text: unmatchedItems[0].$1.unitPrice.toStringAsFixed(2));
    final appState = AppStateProvider.of(context);
    final products = appState.products;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: const Color(0xFF161B26),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF2A3045)),
          ),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFFFC107)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Unmatched Items', style: TextStyle(color: Colors.white, fontSize: 16)),
                    Text(
                      '${currentIndex + 1} of ${unmatchedItems.length} need review',
                      style: const TextStyle(color: Color(0xFF8A92A6), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 500,
            height: 400,
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    children: [
                      for (int i = 0; i < unmatchedItems.length; i++)
                        Container(
                          key: i == currentIndex ? itemKey : null,
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: i == currentIndex 
                                ? const Color(0xFFFFC107).withValues(alpha: 0.15)
                                : const Color(0xFF0F162C),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: i == currentIndex 
                                  ? const Color(0xFFFFC107)
                                  : const Color(0xFF2A3045),
                              width: i == currentIndex ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    '${i + 1}. ${unmatchedItems[i].$1.name}',
                                    style: TextStyle(
                                      color: i == currentIndex ? Colors.white : const Color(0xFFB0B8D0),
                                      fontWeight: i == currentIndex ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                  const Spacer(),
                                  if (i == currentIndex)
                                    const Icon(Icons.edit, color: Color(0xFFFFC107), size: 16),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Qty: ${unmatchedItems[i].$1.qty} ${unmatchedItems[i].$1.unit} • Price: ${formatAmount(unmatchedItems[i].$1.unitPrice, widget.appState.currency, decimalDigits: 2)}',
                                style: const TextStyle(color: Color(0xFF616C88), fontSize: 12),
                              ),
                              Text(
                                'Original: ${unmatchedItems[i].$2}',
                                style: const TextStyle(color: Color(0xFF616C88), fontSize: 11, fontStyle: FontStyle.italic),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (currentIndex < unmatchedItems.length)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F162C),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF2A3045)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Edit Item:', style: TextStyle(color: Color(0xFFB0B8D0), fontSize: 12)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Autocomplete<Product>(
                                optionsBuilder: (TextEditingValue textEditingValue) {
                                  if (textEditingValue.text.isEmpty) {
                                    return const Iterable<Product>.empty();
                                  }
                                  return products
                                      .where((product) => product.name.toLowerCase().contains(textEditingValue.text.toLowerCase()))
                                      .toList();
                                },
                                displayStringForOption: (Product option) => '${option.name} (${formatAmount(option.unitPrice, widget.appState.currency, decimalDigits: 2)})',
                                fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                                  textEditingController.text = nameController.text;
                                  textEditingController.selection = TextSelection.fromPosition(TextPosition(offset: textEditingController.text.length));
                                  textEditingController.addListener(() {
                                    nameController.text = textEditingController.text;
                                  });
                                  return TextField(
                                    controller: textEditingController,
                                    focusNode: focusNode,
                                    style: const TextStyle(color: Colors.white, fontSize: 13),
                                    decoration: InputDecoration(
                                      labelText: 'Name',
                                      labelStyle: const TextStyle(color: Color(0xFF616C88), fontSize: 11),
                                      filled: true,
                                      fillColor: const Color(0xFF0B0E17),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFF2A3045))),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      suffixIcon: products.isNotEmpty ? const Icon(Icons.arrow_drop_down, color: Color(0xFF616C88), size: 20) : null,
                                    ),
                                    onChanged: (val) {
                                      unmatchedItems[currentIndex].$1.name = val;
                                    },
                                  );
                                },
                                onSelected: (Product selection) {
                                  setDlgState(() {
                                    nameController.text = selection.name;
                                    qtyController.text = '1';
                                    priceController.text = selection.unitPrice.toStringAsFixed(2);
                                    unmatchedItems[currentIndex].$1.name = selection.name;
                                    unmatchedItems[currentIndex].$1.qty = 1.0;
                                    unmatchedItems[currentIndex].$1.unitPrice = selection.unitPrice;
                                    unmatchedItems[currentIndex].$1.unit = selection.unit;
                                    unmatchedItems[currentIndex].$1.productId = selection.id;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 70,
                              child: TextField(
                                controller: qtyController,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                decoration: InputDecoration(
                                  labelText: 'Qty',
                                  labelStyle: const TextStyle(color: Color(0xFF616C88), fontSize: 11),
                                  filled: true,
                                  fillColor: const Color(0xFF0B0E17),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFF2A3045))),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                ),
                                onChanged: (val) {
                                  unmatchedItems[currentIndex].$1.qty = double.tryParse(val) ?? 1.0;
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 80,
                              child: TextField(
                                controller: priceController,
                                keyboardType: TextInputType.numberWithOptions(decimal: true),
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                decoration: InputDecoration(
                                  labelText: 'Price',
                                  labelStyle: const TextStyle(color: Color(0xFF616C88), fontSize: 11),
                                  filled: true,
                                  fillColor: const Color(0xFF0B0E17),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFF2A3045))),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                ),
                                onChanged: (val) {
                                  unmatchedItems[currentIndex].$1.unitPrice = double.tryParse(val) ?? 0.0;
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            if (currentIndex > 0)
              TextButton(
                onPressed: () {
                  setDlgState(() {
                    currentIndex--;
                    nameController.text = unmatchedItems[currentIndex].$1.name;
                    qtyController.text = unmatchedItems[currentIndex].$1.qty.toString();
                    priceController.text = unmatchedItems[currentIndex].$1.unitPrice.toStringAsFixed(2);
                    _scrollToItem(scrollController, itemKey);
                  });
                },
                child: const Text('Previous', style: TextStyle(color: Color(0xFFB0B8D0))),
              ),
            const Spacer(),
            if (currentIndex < unmatchedItems.length - 1)
              ElevatedButton(
                onPressed: () {
                  setDlgState(() {
                    currentIndex++;
                    nameController.text = unmatchedItems[currentIndex].$1.name;
                    qtyController.text = unmatchedItems[currentIndex].$1.qty.toString();
                    priceController.text = unmatchedItems[currentIndex].$1.unitPrice.toStringAsFixed(2);
                    _scrollToItem(scrollController, itemKey);
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Next', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            if (currentIndex == unmatchedItems.length - 1)
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(dialogCtx);
                  _updateUnmatchedItems(unmatchedItems, categoryName);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ),
    );
  }

  void _scrollToItem(ScrollController controller, GlobalKey key) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final RenderObject? renderObject = key.currentContext?.findRenderObject();
      if (renderObject != null) {
        final RenderBox box = renderObject as RenderBox;
        final position = box.localToGlobal(Offset.zero);
        final size = box.size;
        final scrollOffset = controller.offset;
        final viewportHeight = controller.position.viewportDimension;
        
        // Calculate if item is visible
        final itemTop = position.dy;
        final itemBottom = position.dy + size.height;
        
        if (itemTop < scrollOffset || itemBottom > scrollOffset + viewportHeight) {
          // Item is not visible, scroll to it
          final targetOffset = itemTop - (viewportHeight / 2) + (size.height / 2);
          controller.animateTo(
            targetOffset.clamp(0.0, controller.position.maxScrollExtent),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      }
    });
  }

  void _updateUnmatchedItems(List<(QuoteItem, String)> unmatchedItems, String categoryName) {
    setState(() {
      // Update the items in the category
      for (final (item, _) in unmatchedItems) {
        for (final category in _categories) {
          final idx = category.items.indexWhere((i) => i.productId == item.productId);
          if (idx != -1) {
            category.items[idx] = item;
          }
        }
      }
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All items updated successfully'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Product? _findClosestProduct(String itemName, List<Product> products) {
    if (products.isEmpty) return null;
    
    final lowerItemName = itemName.toLowerCase();
    Product? bestMatch;
    int bestScore = 0;
    
    for (final product in products) {
      final lowerProductName = product.name.toLowerCase();
      int score = 0;
      
      // Exact match
      if (lowerItemName == lowerProductName) {
        return product;
      }
      
      // Contains match
      if (lowerItemName.contains(lowerProductName) || lowerProductName.contains(lowerItemName)) {
        score += 50;
      }
      
      // Word overlap
      final itemWords = lowerItemName.split(' ');
      final productWords = lowerProductName.split(' ');
      final commonWords = itemWords.where((w) => productWords.contains(w)).length;
      score += commonWords * 20;
      
      // Similarity score based on character overlap
      final similarity = _calculateSimilarity(lowerItemName, lowerProductName);
      score += (similarity * 30).toInt();
      
      if (score > bestScore) {
        bestScore = score;
        bestMatch = product;
      }
    }
    
    // Only return match if score is reasonably high (at least 70 for stricter matching)
    return bestScore >= 70 ? bestMatch : null;
  }

  double _calculateSimilarity(String s1, String s2) {
    if (s1 == s2) return 1.0;
    
    final longer = s1.length > s2.length ? s1 : s2;
    final shorter = s1.length > s2.length ? s2 : s1;
    
    if (longer.length == 0) return 1.0;
    
    final editDistance = _levenshteinDistance(longer, shorter);
    return 1.0 - (editDistance / longer.length);
  }

  int _levenshteinDistance(String s1, String s2) {
    final len1 = s1.length;
    final len2 = s2.length;
    
    if (len1 == 0) return len2;
    if (len2 == 0) return len1;
    
    final matrix = List.generate(len1 + 1, (i) => List.filled(len2 + 1, 0));
    
    for (int i = 0; i <= len1; i++) {
      matrix[i][0] = i;
    }
    for (int j = 0; j <= len2; j++) {
      matrix[0][j] = j;
    }
    
    for (int i = 1; i <= len1; i++) {
      for (int j = 1; j <= len2; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1,
          matrix[i][j - 1] + 1,
          matrix[i - 1][j - 1] + cost,
        ].reduce((a, b) => a < b ? a : b);
      }
    }
    
    return matrix[len1][len2];
  }

  Future<void> _save() async {
    final typedName = _clientNameCtrl.text.trim();

    if (typedName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a client name'), backgroundColor: Colors.red));
      return;
    }

    // Resolve or auto-create client
    Client client;
    if (_clientId != null) {
      final found = widget.appState.clients.where((c) => c.id == _clientId).firstOrNull;
      if (found != null) {
        client = found;
      } else {
        // ID no longer valid — fall through to name lookup
        _clientId = null;
        client = _resolveOrCreateClient(typedName);
      }
    } else {
      // Check if an existing client has exactly this name
      final existing = widget.appState.clients
          .where((c) => c.name.toLowerCase() == typedName.toLowerCase())
          .firstOrNull;
      if (existing != null) {
        client = existing;
        _clientId = existing.id;
      } else {
        // Auto-create a new client with the typed name
        client = _resolveOrCreateClient(typedName);
      }
    }

    if (widget.quote != null) {
      final q = widget.quote!;
      q.clientId = client.id; q.clientName = client.name;
      q.status = _status; q.notes = _notes;
      q.labourInput = _labourInput; q.categories = _categories;
      q.vatPercent = widget.appState.defaultVatPercent;
      widget.appState.updateQuote(q);
    } else {
      // Quotation numbers are issued by the cloud counter so they stay unique
      // and sequential across devices — this needs an active connection.
      final newId = await widget.appState.allocateQuoteNumber();
      if (newId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('You need to be online to generate a new quotation number.'),
            backgroundColor: Colors.orange,
          ));
        }
        return;
      }
      widget.appState.addQuote(Quote(
        id: newId, clientId: client.id, clientName: client.name,
        date: DateTime.now(),
        expiryDate: DateTime.now().add(Duration(days: widget.appState.defaultExpiryDays)),
        status: _status, notes: _notes, labourInput: _labourInput, categories: _categories,
        vatPercent: widget.appState.defaultVatPercent,
      ));
    }
    if (!mounted) return;

    // Always surface items that aren't in the catalogue yet so the list can grow.
    final newProducts = _collectNewProducts();
    if (newProducts.isNotEmpty) {
      await _promptCatalogueUpdate(newProducts.values.toList());
    }
    if (!mounted) return;

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(widget.quote != null ? 'Quote updated' : 'Quote saved'),
      backgroundColor: _surface,
    ));
  }

  /// Item names used in this quote that don't exist in the catalogue yet,
  /// keyed by lower-cased name so duplicates collapse.
  Map<String, QuoteItem> _collectNewProducts() {
    final result = <String, QuoteItem>{};
    for (final cat in _categories) {
      for (final item in cat.items) {
        final name = item.name.trim();
        if (name.isEmpty) continue;
        final key = name.toLowerCase();
        if (widget.appState.productByName(name) != null) continue;
        result.putIfAbsent(key, () => item);
      }
    }
    return result;
  }

  Future<void> _promptCatalogueUpdate(List<QuoteItem> newItems) async {
    final add = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _border),
        ),
        title: Row(
          children: [
            const Icon(Icons.playlist_add_check, color: _gold),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'New products detected',
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                newItems.length == 1
                    ? '1 item on this quote is not in your catalogue yet. Add it so future quotes autofill the price?'
                    : '${newItems.length} items on this quote are not in your catalogue yet. Add them so future quotes autofill the price?',
                style: const TextStyle(color: _white70, fontSize: 13),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final item in newItems)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.add_circle_outline, color: _gold, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item.name,
                                style: const TextStyle(color: Color(0xFFB0B8D0), fontSize: 13),
                              ),
                            ),
                            Text(
                              _kes(item.unitPrice),
                              style: const TextStyle(color: _white38, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not now', style: TextStyle(color: Color(0xFF8A92A6))),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _gold, foregroundColor: Colors.black),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Add to catalogue'),
          ),
        ],
      ),
    );

    if (add != true) return;

    final base = DateTime.now().millisecondsSinceEpoch;
    for (int i = 0; i < newItems.length; i++) {
      final item = newItems[i];
      widget.appState.addProduct(Product(
        id: 'P-${base + i}',
        name: item.name.trim(),
        description: item.description,
        unitPrice: item.unitPrice,
        unit: item.unit,
      ));
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(newItems.length == 1
            ? '1 product added to catalogue'
            : '${newItems.length} products added to catalogue'),
        backgroundColor: Colors.green,
      ));
    }
  }

  /// Returns an existing client by name (case-insensitive) or creates and persists a new one.
  Client _resolveOrCreateClient(String name) {
    final existing = widget.appState.clients
        .where((c) => c.name.toLowerCase() == name.toLowerCase())
        .firstOrNull;
    if (existing != null) return existing;

    final newClient = Client(
      id: widget.appState.nextClientId,
      name: name,
    );
    widget.appState.addClient(newClient);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('New client "$name" created'),
      backgroundColor: Colors.green,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
    return newClient;
  }

  void _previewPdf() {
    final clientName = widget.appState.clients
        .where((c) => c.id == _clientId)
        .firstOrNull
        ?.name ?? 'Customer';

    final tempQuote = Quote(
      id: widget.quote?.id ?? 'DRAFT',
      clientId: _clientId ?? '',
      clientName: clientName,
      categories: _categories,
      status: _status,
      date: widget.quote?.date ?? DateTime.now(),
      expiryDate: widget.quote?.expiryDate ??
          DateTime.now().add(Duration(days: widget.appState.defaultExpiryDays)),
      notes: _notes,
      labourInput: _labourInput,
      vatPercent: widget.appState.defaultVatPercent,
    );

    PdfViewerPage.openDocumentPdf(
      context: context,
      title: 'Quotation ${tempQuote.id}',
      filename: 'Quotation_${tempQuote.id}.pdf',
      buildPdf: (format) => PdfService.generateQuotePdf(tempQuote, widget.appState),
    );
  }
}

// ── Item card widget (stateful for stable controllers) ────────────────────────
class _ItemCardWidget extends StatefulWidget {
  final QuoteItem item;
  final String currency;
  final VoidCallback onDelete;
  final VoidCallback onChanged;
  final InputDecoration Function(String) dec;

  const _ItemCardWidget({super.key, required this.item, required this.currency,
    required this.onDelete, required this.onChanged, required this.dec});

  @override
  State<_ItemCardWidget> createState() => _ItemCardWidgetState();
}

class _ItemCardWidgetState extends State<_ItemCardWidget> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _priceCtrl;
  final FocusNode _nameFocus = FocusNode();

  static const _border  = Color(0xFF2A3660);
  static const _white38 = Color(0xFF616C88);

  String _compact(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  @override
  void initState() {
    super.initState();
    _nameCtrl  = TextEditingController(text: widget.item.name);
    _descCtrl  = TextEditingController(text: widget.item.description);
    _qtyCtrl   = TextEditingController(text: _compact(widget.item.qty));
    _priceCtrl = TextEditingController(text: _compact(widget.item.unitPrice));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('ITEM NAME', style: TextStyle(color: _white38, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
            onPressed: widget.onDelete, padding: EdgeInsets.zero, constraints: const BoxConstraints(),
          ),
        ]),
        const SizedBox(height: 6),
        RawAutocomplete<String>(
          textEditingController: _nameCtrl,
          focusNode: _nameFocus,
          optionsBuilder: (v) {
            if (v.text.isEmpty) return const Iterable<String>.empty();
            final q = v.text.toLowerCase();
            return AppStateProvider.of(context).productNames.where((o) => o.toLowerCase().contains(q));
          },
          onSelected: (sel) {
            final product = AppStateProvider.of(context).productByName(sel);
            setState(() {
              widget.item.name = sel;
              if (product != null) {
                widget.item.unit = product.unit;
                widget.item.unitPrice = product.unitPrice;
                _priceCtrl.text = _compact(product.unitPrice);
                if (widget.item.description.trim().isEmpty &&
                    product.description.trim().isNotEmpty) {
                  widget.item.description = product.description;
                  _descCtrl.text = product.description;
                }
              }
            });
            widget.onChanged();
          },
          fieldViewBuilder: (_, ctrl, fn, onFieldSubmitted) => TextField(
            controller: ctrl,
            focusNode: fn,
            style: const TextStyle(color: Colors.white),
            decoration: widget.dec('Item name'),
            onChanged: (v) { widget.item.name = v; widget.onChanged(); },
          ),
          optionsViewBuilder: (_, onSel, opts) => Align(
            alignment: Alignment.topLeft,
            child: Material(
              color: const Color(0xFF0F162C),
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 300,
                height: 180,
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: opts.length,
                  itemBuilder: (_, i) {
                    final opt = opts.elementAt(i);
                    return ListTile(
                      dense: true,
                      title: Text(opt, style: const TextStyle(color: Colors.white, fontSize: 13)),
                      onTap: () => onSel(opt),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('QUANTITY', style: TextStyle(color: _white38, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
            const SizedBox(height: 6),
            TextField(
              controller: _qtyCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: widget.dec('1'),
              keyboardType: TextInputType.number,
              onChanged: (v) { widget.item.qty = double.tryParse(v) ?? widget.item.qty; widget.onChanged(); },
            ),
          ])),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('UNIT PRICE (${widget.currency})', style: const TextStyle(color: _white38, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
            const SizedBox(height: 6),
            TextField(
              controller: _priceCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: widget.dec('0'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: moneyInputFormatters(decimalDigits: 2),
              onChanged: (v) { widget.item.unitPrice = parseMoneyOr(v, widget.item.unitPrice); widget.onChanged(); },
            ),
          ])),
        ]),
        const SizedBox(height: 10),
        const Text('DESCRIPTION (paint code / colour, spec)', style: TextStyle(color: _white38, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
        const SizedBox(height: 6),
        TextField(
          controller: _descCtrl,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: widget.dec('e.g. Paint code NCS S 1500-N, Matt finish'),
          onChanged: (v) { widget.item.description = v; widget.onChanged(); },
        ),
      ]),
    );
  }
}

// ── % field (stable controller for labour/markup) ─────────────────────────────
class _PctField extends StatefulWidget {
  final String initial;
  final ValueChanged<String> onChanged;
  final Color border, gold, white38;

  const _PctField({required this.initial, required this.onChanged,
    required this.border, required this.gold, required this.white38});

  @override
  State<_PctField> createState() => _PctFieldState();
}

class _PctFieldState extends State<_PctField> {
  late final TextEditingController _ctrl;

  static String _strip(String v) => v.endsWith('%') ? v.substring(0, v.length - 1) : v;

  @override
  void initState() { super.initState(); _ctrl = TextEditingController(text: _strip(widget.initial)); }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _ctrl,
    style: const TextStyle(color: Colors.white),
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(
      hintText: '0', hintStyle: TextStyle(color: widget.white38),
      suffixText: '%', suffixStyle: TextStyle(color: widget.white38),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: widget.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: widget.gold)),
      filled: true, fillColor: Colors.white.withValues(alpha: 0.04),
      isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    ),
    onChanged: (v) => widget.onChanged('$v%'),
  );
}

// ── Category name field (stable controller) ───────────────────────────────────
// Must be a separate StatefulWidget so its TextEditingController survives
// parent setState calls without being recreated every build.
class _CategoryNameField extends StatefulWidget {
  final String initialName;
  final ValueChanged<String> onChanged;

  const _CategoryNameField({super.key, required this.initialName, required this.onChanged});

  @override
  State<_CategoryNameField> createState() => _CategoryNameFieldState();
}

class _CategoryNameFieldState extends State<_CategoryNameField> {
  late final TextEditingController _ctrl;

  static const _white38 = Color(0xFF616C88);

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _ctrl,
    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
    decoration: const InputDecoration(
      hintText: 'Category name (leave blank to hide header on PDF)...',
      hintStyle: TextStyle(color: _white38, fontSize: 13, fontWeight: FontWeight.normal),
      isDense: true,
      border: InputBorder.none,
      contentPadding: EdgeInsets.zero,
    ),
    onChanged: widget.onChanged,
  );
}

// ── Category Labour field (stable controller, flexible format) ────────────────
// Accepts: 15% · 5000 (flat KES) · 1/3 (fraction of subtotal)
class _CategoryLabourField extends StatefulWidget {
  final String initial;
  final ValueChanged<String> onChanged;
  final Color border, gold, white38;

  const _CategoryLabourField({
    super.key,
    required this.initial,
    required this.onChanged,
    required this.border,
    required this.gold,
    required this.white38,
  });

  @override
  State<_CategoryLabourField> createState() => _CategoryLabourFieldState();
}

class _CategoryLabourFieldState extends State<_CategoryLabourField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _ctrl,
    style: const TextStyle(color: Colors.white, fontSize: 13),
    keyboardType: TextInputType.text,
    decoration: InputDecoration(
      hintText: '0% / 5000',
      hintStyle: TextStyle(color: widget.white38, fontSize: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: widget.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: widget.gold),
      ),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.04),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    ),
    onChanged: widget.onChanged,
  );
}

// ── Labor notes field (stable controller) ─────────────────────────────────────
class _LaborNotesField extends StatefulWidget {
  final String initialNotes;
  final ValueChanged<String> onChanged;
  final Color border, gold, white38;

  const _LaborNotesField({
    super.key,
    required this.initialNotes,
    required this.onChanged,
    required this.border,
    required this.gold,
    required this.white38,
  });

  @override
  State<_LaborNotesField> createState() => _LaborNotesFieldState();
}

class _LaborNotesFieldState extends State<_LaborNotesField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialNotes);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _ctrl,
    style: const TextStyle(color: Colors.white),
    decoration: InputDecoration(
      hintText: 'Additional details on site labor requirements...',
      hintStyle: TextStyle(color: widget.white38, fontSize: 13),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: widget.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: widget.gold),
      ),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.04),
      isDense: true,
      contentPadding: const EdgeInsets.all(14),
    ),
    maxLines: 4,
    onChanged: widget.onChanged,
  );
}
