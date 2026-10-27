import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import '../app_state.dart';
import '../models.dart';
import '../services/pdf_service.dart';
import '../widgets/money_text.dart';
import 'pdf_viewer_page.dart';

// ─── Entry point ──────────────────────────────────────────────────────────────
Future<void> openEnquiryInvoicePage(BuildContext context, AppState appState, {Invoice? invoice}) {
  return Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => EnquiryInvoicePage(appState: appState, invoice: invoice)),
  );
}

// ─── Page ─────────────────────────────────────────────────────────────────────
class EnquiryInvoicePage extends StatefulWidget {
  final AppState appState;
  final Invoice? invoice;
  const EnquiryInvoicePage({super.key, required this.appState, this.invoice});
  @override
  State<EnquiryInvoicePage> createState() => _EnquiryInvoicePageState();
}

class _EnquiryInvoicePageState extends State<EnquiryInvoicePage> {
  // ── Palette ────────────────────────────────────────────────────────────────
  static const _bg      = Color(0xFF0F162C);
  static const _surface = Color(0xFF161B26);
  static const _border  = Color(0xFF2A3045);
  static const _gold    = Color(0xFFFFC107);
  static const _white38 = Color(0xFF616C88);
  static const _white70 = Color(0xFFB0B8D0);

  // ── Form state ─────────────────────────────────────────────────────────────
  final _customerNameCtrl = TextEditingController();
  final _telephoneCtrl    = TextEditingController();
  final _kraPinCtrl       = TextEditingController();
  final FocusNode _kraPinFocus = FocusNode();
  final _quotationNoCtrl  = TextEditingController();
  DateTime _date = DateTime.now();

  // Items/Categories
  List<QuoteCategory> _categories = [];

  // Labour & Material section
  final _agreedTotalCtrl = TextEditingController();
  final _labourInputCtrl = TextEditingController();

  // Payment terms
  final _depositPctCtrl     = TextEditingController(text: '50');
  final _midPctCtrl         = TextEditingController(text: '25');
  final _completionPctCtrl  = TextEditingController(text: '25');

  // Amount Requested
  final _requestLabelCtrl  = TextEditingController(text: '100% Request');
  final _requestPctCtrl    = TextEditingController(text: '100');
  final _requestAmountCtrl = TextEditingController();

  // Notes & Terms
  final _nbCtrl       = TextEditingController();
  final _preparedByCtrl = TextEditingController();
  final _termsCtrl    = TextEditingController(
    text: '1. Terms Inclusive of VAT where applicable\n2. Quotation valid for 7 days'
  );

  NumberFormat get _fmt =>
      NumberFormat.currency(symbol: '${widget.appState.currency} ', decimalDigits: 2);

  double get _agreedTotal   => parseMoney(_agreedTotalCtrl.text) ?? 0;
  double get _requestAmount => parseMoney(_requestAmountCtrl.text) ?? 0;
  double get _grandTotal    => _requestAmount > 0 ? _requestAmount : _agreedTotal;
  double get _calculatedTotal => _categories.fold(0.0, (sum, cat) => sum + cat.subtotal + cat.labourCost);

  void _applyRequestPct(double pct, {String? label}) {
    final pctStr = pct.truncateToDouble() == pct ? pct.toInt().toString() : pct.toStringAsFixed(1);
    _requestPctCtrl.text = pctStr;
    _requestLabelCtrl.text = label ?? '$pctStr% Request';
    if (_agreedTotal > 0) {
      final amt = _agreedTotal * (pct / 100);
      _requestAmountCtrl.text = amt.toStringAsFixed(2);
    }
    setState(() {});
  }

  void _onAgreedTotalChanged(String v) {
    final pct = double.tryParse(_requestPctCtrl.text);
    if (pct != null && pct > 0) {
      final agreed = double.tryParse(v) ?? 0;
      final amt = agreed * (pct / 100);
      _requestAmountCtrl.text = amt.toStringAsFixed(2);
    }
    setState(() {});
  }

  void _onRequestPctChanged(String v) {
    final pct = double.tryParse(v);
    if (pct != null) {
      _requestLabelCtrl.text = '$v% Request';
      if (_agreedTotal > 0) {
        final amt = _agreedTotal * (pct / 100);
        _requestAmountCtrl.text = amt.toStringAsFixed(2);
      }
    }
    setState(() {});
  }

  void _onRequestAmountChanged(String v) {
    final amt = double.tryParse(v);
    if (amt != null && _agreedTotal > 0) {
      final pct = (amt / _agreedTotal) * 100;
      final pctStr = pct.truncateToDouble() == pct ? pct.toInt().toString() : pct.toStringAsFixed(1);
      _requestPctCtrl.text = pctStr;
    }
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    if (widget.invoice != null) {
      final inv = widget.invoice!;
      _quotationNoCtrl.text = inv.id;
      _customerNameCtrl.text = inv.clientName;
      _date = inv.date;
      // Deep-copy categories AND items: QuoteCategory/QuoteItem fields are
      // mutable and the editor edits them in place, so sharing objects with
      // the original invoice would leak changes even when the user cancels.
      _categories = inv.categories.map((c) => QuoteCategory(
        id: c.id, name: c.name, labourInput: c.labourInput,
        showSubtotals: c.showSubtotals,
        items: c.items.map((i) => QuoteItem(
          productId: i.productId, name: i.name, qty: i.qty,
          unitPrice: i.unitPrice, unit: i.unit,
        )).toList(),
      )).toList();
      _labourInputCtrl.text = inv.labourInput;
      _kraPinCtrl.text = inv.kraPin.isNotEmpty ? inv.kraPin : widget.appState.companyKraPin;
      
      // Calculate total from categories if available
      final calculatedTotal = _categories.fold(0.0, (sum, cat) => sum + cat.subtotal + cat.labourCost);
      if (calculatedTotal > 0) {
        _agreedTotalCtrl.text = calculatedTotal.toStringAsFixed(2);
      } else if (inv.amount > 0) {
        _agreedTotalCtrl.text = inv.amount.toStringAsFixed(2);
      }
      
      _requestAmountCtrl.text = inv.amount.toStringAsFixed(2);
      _requestPctCtrl.text = '100';
      _requestLabelCtrl.text = '100% Request';
      
      final client = widget.appState.clients.where((c) => c.name.toLowerCase() == inv.clientName.toLowerCase() || c.id == inv.clientId).firstOrNull;
      if (client != null && client.phone.isNotEmpty) {
        _telephoneCtrl.text = client.phone;
      }
    } else {
      // Pre-fill quotation number
      _quotationNoCtrl.text = 'ME-${widget.appState.nextQuoteNumber.toString().padLeft(3, '0')}';
      _kraPinCtrl.text = widget.appState.companyKraPin;
      if (widget.appState.clients.isNotEmpty) {
        _customerNameCtrl.text = widget.appState.clients.first.name;
        _telephoneCtrl.text = widget.appState.clients.first.phone;
      }
    }
  }

  @override
  void dispose() {
    for (final c in [_customerNameCtrl, _telephoneCtrl, _kraPinCtrl, _quotationNoCtrl,
      _agreedTotalCtrl, _labourInputCtrl, _depositPctCtrl, _midPctCtrl, _completionPctCtrl,
      _requestLabelCtrl, _requestPctCtrl, _requestAmountCtrl, _nbCtrl, _preparedByCtrl, _termsCtrl]) {
      c.dispose();
    }
    _kraPinFocus.dispose();
    super.dispose();
  }

  // ── Category & Item Management ─────────────────────────────────────────────
  void _addCategory() {
    setState(() {
      _categories.add(QuoteCategory(
        id: 'cat_${DateTime.now().millisecondsSinceEpoch}',
        name: 'New Category',
        items: [],
      ));
    });
  }

  void _addItemToCategory(int categoryIndex) {
    showDialog(
      context: context,
      builder: (context) => _AddItemDialog(
        appState: widget.appState,
        onAdd: (item) {
          setState(() {
            _categories[categoryIndex].items.add(item);
            _updateAgreedTotal();
          });
        },
      ),
    );
  }

  void _removeCategory(int index) {
    setState(() {
      _categories.removeAt(index);
      _updateAgreedTotal();
    });
  }

  void _removeItem(int categoryIndex, int itemIndex) {
    setState(() {
      _categories[categoryIndex].items.removeAt(itemIndex);
      _updateAgreedTotal();
    });
  }

  void _updateAgreedTotal() {
    final total = _categories.fold(0.0, (sum, cat) => sum + cat.subtotal + cat.labourCost);
    _agreedTotalCtrl.text = total.toStringAsFixed(2);
    _onAgreedTotalChanged(_agreedTotalCtrl.text);
  }

  // ─── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isEdit = widget.invoice != null;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(isEdit ? 'Edit Invoice ${widget.invoice!.id}' : 'Enquiry Invoice',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(color: _gold.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
            child: Text(_grandTotal > 0 ? 'Total: ${_fmt.format(_grandTotal)}' : 'Fill in amounts',
              style: const TextStyle(color: _gold, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // ── Customer Info ───────────────────────────────────────────────
              _sectionCard('Customer Details', Icons.person_outline, [
                Row(children: [
                  Expanded(child: _labelField('CUSTOMER NAME', _customerNameCtrl, 'Full name')),
                  const SizedBox(width: 12),
                  Expanded(child: _labelField('TELEPHONE', _telephoneCtrl, 'Phone number', type: TextInputType.phone)),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _dateTile()),
                  const SizedBox(width: 12),
                  Expanded(child: _labelField('QUOTATION NO.', _quotationNoCtrl, 'e.g. ME-001')),
                ]),
                const SizedBox(height: 12),
                _kraPinField(),
              ]),

              const SizedBox(height: 16),

              // ── Items/Categories ───────────────────────────────────────────────
              _sectionCard('Invoice Items', Icons.list_alt, [
                if (_categories.isEmpty)
                  Center(
                    child: Column(
                      children: [
                        Icon(Icons.inventory_2_outlined, color: _white38, size: 48),
                        const SizedBox(height: 12),
                        const Text('No items added yet', style: TextStyle(color: _white70, fontSize: 14)),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: _addCategory,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add Category'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _gold,
                            foregroundColor: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Column(
                    children: [
                      for (int catIdx = 0; catIdx < _categories.length; catIdx++)
                        _CategoryCard(
                          category: _categories[catIdx],
                          index: catIdx,
                          onEditName: (name) {
                            setState(() => _categories[catIdx].name = name);
                          },
                          onAddItem: () => _addItemToCategory(catIdx),
                          onRemoveItem: (itemIdx) => _removeItem(catIdx, itemIdx),
                          onRemove: () => _removeCategory(catIdx),
                          onItemChanged: () => _updateAgreedTotal(),
                        ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _addCategory,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Category'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _gold,
                          foregroundColor: Colors.black,
                        ),
                      ),
                    ],
                  ),
              ]),

              const SizedBox(height: 16),

              // ── Labour & Material ───────────────────────────────────────────
              _sectionCard('Labour and Material Per Agreement', Icons.handyman_outlined, [
                Row(children: [
                  Expanded(child: _labelField('LABOUR INPUT', _labourInputCtrl, 'e.g. 10% or 1/10')),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('AGREED TOTAL (${widget.appState.currency})', style: TextStyle(color: _white38, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _agreedTotalCtrl,
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: moneyInputFormatters(decimalDigits: 2),
                        decoration: _dec('0.00'),
                        onChanged: _onAgreedTotalChanged,
                      ),
                    ]),
                  ),
                ]),
                const SizedBox(height: 8),
                Text('Calculated from items: ${_fmt.format(_calculatedTotal)}', style: const TextStyle(color: _white70, fontSize: 12)),
              ]),

              const SizedBox(height: 16),

              // ── Payment Terms ───────────────────────────────────────────────
              _sectionCard('Payment Terms Schedule', Icons.schedule_outlined, [
                Row(children: [
                  Expanded(child: _pctField('DEPOSIT (%)', _depositPctCtrl, 'e.g. 50')),
                  const SizedBox(width: 12),
                  Expanded(child: _pctField('MID-WORK (%)', _midPctCtrl, 'e.g. 25')),
                  const SizedBox(width: 12),
                  Expanded(child: _pctField('COMPLETION (%)', _completionPctCtrl, 'e.g. 25')),
                ]),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: _gold.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(8), border: Border.all(color: _gold.withValues(alpha: 0.2))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _termLine('${_depositPctCtrl.text}% Deposit to commence work'),
                    _termLine('${_midPctCtrl.text}% upon ${_midPctCtrl.text}% work done'),
                    _termLine('${_completionPctCtrl.text}% upon Completion of work'),
                  ]),
                ),
              ]),

              const SizedBox(height: 16),

              // ── Amount Requested ────────────────────────────────────────────
              _sectionCard('Amount Requested', Icons.payments_outlined, [
                // Quick Milestone Presets
                const Text('QUICK PRESET PERCENTAGES', style: TextStyle(color: _white38, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _presetChip('Deposit (${_depositPctCtrl.text}%)', () {
                      final p = double.tryParse(_depositPctCtrl.text) ?? 50;
                      _applyRequestPct(p, label: '${p.toInt()}% Deposit Request');
                    }),
                    _presetChip('Mid-work (${_midPctCtrl.text}%)', () {
                      final p = double.tryParse(_midPctCtrl.text) ?? 25;
                      _applyRequestPct(p, label: '${p.toInt()}% Mid-work Request');
                    }),
                    _presetChip('Completion (${_completionPctCtrl.text}%)', () {
                      final p = double.tryParse(_completionPctCtrl.text) ?? 25;
                      _applyRequestPct(p, label: '${p.toInt()}% Completion Request');
                    }),
                    _presetChip('100% Full', () => _applyRequestPct(100, label: '100% Full Request')),
                  ],
                ),
                const SizedBox(height: 16),

                // Request Inputs
                Row(children: [
                  Expanded(
                    flex: 2,
                    child: _labelField(
                      'REQUEST PERCENT (%)',
                      _requestPctCtrl,
                      '100',
                      type: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: _onRequestPctChanged,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: _labelField('REQUEST LABEL', _requestLabelCtrl, 'e.g. 50% Deposit Request'),
                  ),
                ]),
                const SizedBox(height: 12),
                _labelField(
                  'REQUEST AMOUNT (${widget.appState.currency})',
                  _requestAmountCtrl,
                  '0.00',
                  type: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: moneyInputFormatters(decimalDigits: 2),
                  onChanged: _onRequestAmountChanged,
                ),

                if (_grandTotal > 0) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: _gold.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _gold.withValues(alpha: 0.3)),
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Invoice Total Requested', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          if (_agreedTotal > 0 && _requestAmount > 0)
                            Text(
                              '${((_requestAmount / _agreedTotal) * 100).toStringAsFixed(1)}% of agreed ${_fmt.format(_agreedTotal)}',
                              style: const TextStyle(color: _white70, fontSize: 11),
                            ),
                        ],
                      ),
                      Text(_fmt.format(_grandTotal), style: const TextStyle(color: _gold, fontWeight: FontWeight.bold, fontSize: 20)),
                    ]),
                  ),
                ],
              ]),

              const SizedBox(height: 16),

              // ── Notes & Terms ───────────────────────────────────────────────
              _sectionCard('Notes & Terms', Icons.note_outlined, [
                _labelField('NB / NOTES', _nbCtrl, 'e.g. All sockets will be counted once...', maxLines: 3),
                const SizedBox(height: 12),
                _labelField('PREPARED BY', _preparedByCtrl, 'e.g. George Juma'),
                const SizedBox(height: 12),
                _labelField('TERMS', _termsCtrl, 'Terms...', maxLines: 4),
              ]),

              const SizedBox(height: 24),
            ]),
          ),
        ),

        // ── Bottom Bar ──────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          decoration: BoxDecoration(
            color: _surface,
            border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
          ),
          child: SafeArea(top: false, child: Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: () => _saveInvoice(closeAfter: true),
              icon: const Icon(Icons.save_outlined, size: 18),
              label: const Text('Save Invoice'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _gold,
                side: const BorderSide(color: _border),
                backgroundColor: const Color(0xFF1E293B),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            )),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: ElevatedButton.icon(
              onPressed: _openPdfViewer,
              icon: const Icon(Icons.picture_as_pdf, size: 18),
              label: const Text('Save & View PDF', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 4,
              ),
            )),
          ])),
        ),
      ]),
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────
  Widget _sectionCard(String title, IconData icon, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: _gold.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: _gold, size: 16)),
          const SizedBox(width: 10),
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        ]),
        const SizedBox(height: 16),
        const Divider(color: Color(0xFF2A3045), height: 1),
        const SizedBox(height: 14),
        ...children,
      ]),
    );
  }

  Widget _labelField(String label, TextEditingController ctrl, String hint, {TextInputType? type, int maxLines = 1, ValueChanged<String>? onChanged, List<TextInputFormatter>? inputFormatters}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: _white38, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
      const SizedBox(height: 6),
      TextField(
        controller: ctrl,
        style: const TextStyle(color: Colors.white),
        keyboardType: type,
        maxLines: maxLines,
        inputFormatters: inputFormatters,
        decoration: _dec(hint),
        onChanged: onChanged,
      ),
    ]);
  }

  // KRA PIN (company) with suggestions from the company setting and past invoices
  Widget _kraPinField() {
    return RawAutocomplete<String>(
      textEditingController: _kraPinCtrl,
      focusNode: _kraPinFocus,
      displayStringForOption: (pin) => pin,
      optionsBuilder: (TextEditingValue value) {
        final query = value.text.trim().toLowerCase();
        final pins = <String>{
          widget.appState.companyKraPin,
          ...widget.appState.invoices.map((i) => i.kraPin),
        }.where((p) => p.trim().isNotEmpty).toList()
          ..sort();
        if (query.isEmpty) return pins;
        return pins.where((p) => p.toLowerCase().contains(query));
      },
      fieldViewBuilder: (context, ctrl, focusNode, onFieldSubmitted) {
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('KRA PIN (COMPANY)', style: TextStyle(color: _white38, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
          const SizedBox(height: 6),
          TextField(
            controller: ctrl,
            focusNode: focusNode,
            style: const TextStyle(color: Colors.white),
            decoration: _dec('e.g. P051234567X'),
          ),
        ]);
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            color: const Color(0xFF19233E),
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 160, maxWidth: 320),
              child: ListView(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                children: options.map((pin) => ListTile(
                  dense: true,
                  leading: const Icon(Icons.badge_outlined, size: 16, color: _gold),
                  title: Text(pin, style: const TextStyle(color: Colors.white, fontSize: 13)),
                  onTap: () => onSelected(pin),
                )).toList(),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _pctField(String label, TextEditingController ctrl, String hint) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: _white38, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
      const SizedBox(height: 6),
      TextField(
        controller: ctrl,
        style: const TextStyle(color: Colors.white),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: _dec(hint).copyWith(suffixText: '%', suffixStyle: const TextStyle(color: _white38)),
        onChanged: (_) => setState(() {}),
      ),
    ]);
  }

  Widget _dateTile() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('DATE', style: TextStyle(color: _white38, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
      const SizedBox(height: 6),
      GestureDetector(
        onTap: () async {
          final picked = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime(2035));
          if (picked != null) setState(() => _date = picked);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            border: Border.all(color: _border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            const Icon(Icons.calendar_today, color: _white38, size: 16),
            const SizedBox(width: 8),
            Text(DateFormat('dd/MM/yyyy').format(_date), style: const TextStyle(color: Colors.white)),
          ]),
        ),
      ),
    ]);
  }

  Widget _termLine(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(children: [
      const Icon(Icons.check_circle_outline, color: _gold, size: 14),
      const SizedBox(width: 6),
      Text(text, style: const TextStyle(color: _white70, fontSize: 13)),
    ]),
  );

  Widget _presetChip(String label, VoidCallback onTap) {
    return ActionChip(
      label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
      backgroundColor: const Color(0xFF1E293B),
      side: const BorderSide(color: Color(0xFF334155)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      onPressed: onTap,
    );
  }

  InputDecoration _dec(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: _white38),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _gold)),
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.04),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
  );

  // ── Category Card Widget ─────────────────────────────────────────────────────
  Widget _CategoryCard({
    required QuoteCategory category,
    required int index,
    required Function(String) onEditName,
    required VoidCallback onAddItem,
    required Function(int) onRemoveItem,
    required VoidCallback onRemove,
    required VoidCallback onItemChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    hintText: 'Category Name (leave blank to hide on PDF)',
                    hintStyle: TextStyle(color: _white38, fontSize: 13, fontWeight: FontWeight.normal),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  controller: TextEditingController(text: category.name)
                    ..selection = TextSelection.fromPosition(TextPosition(offset: category.name.length)),
                  onChanged: onEditName,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                onPressed: onRemove,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          if (category.name.trim().isEmpty) ...[
            const SizedBox(height: 4),
            const Row(
              children: [
                Icon(Icons.lightbulb_outline_rounded, color: _gold, size: 13),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Tip: A blank category name won\'t render a category heading on the PDF.',
                    style: TextStyle(color: _white70, fontSize: 10),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  style: const TextStyle(color: _white70, fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Labour (e.g., 10%)',
                    hintStyle: const TextStyle(color: _white38, fontSize: 11),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: _border)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    isDense: true,
                  ),
                  controller: TextEditingController(text: category.labourInput)
                    ..selection = TextSelection.fromPosition(TextPosition(offset: category.labourInput.length)),
                  onChanged: (val) {
                    category.labourInput = val;
                    onItemChanged();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Text('Subtotal: ${_fmt.format(category.subtotal)}', style: const TextStyle(color: _gold, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          if (category.items.isEmpty)
            const Text('No items', style: TextStyle(color: _white38, fontSize: 12))
          else
            Column(
              children: [
                for (int itemIdx = 0; itemIdx < category.items.length; itemIdx++)
                  _ItemRow(
                    item: category.items[itemIdx],
                    onRemove: () => onRemoveItem(itemIdx),
                    onChanged: (updatedItem) {
                      category.items[itemIdx] = updatedItem;
                      onItemChanged();
                    },
                  ),
              ],
            ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: onAddItem,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add Item'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _gold.withValues(alpha: 0.15),
              foregroundColor: _gold,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: const Size(0, 32),
            ),
          ),
        ],
      ),
    );
  }

  // ── Item Row Widget ─────────────────────────────────────────────────────────
  Widget _ItemRow({
    required QuoteItem item,
    required VoidCallback onRemove,
    required Function(QuoteItem) onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: RawAutocomplete<String>(
              initialValue: TextEditingValue(text: item.name),
              optionsBuilder: (v) {
                if (v.text.isEmpty) return const Iterable<String>.empty();
                final q = v.text.toLowerCase();
                return widget.appState.productNames.where((o) => o.toLowerCase().contains(q));
              },
              onSelected: (sel) {
                final product = widget.appState.productByName(sel);
                item.name = sel;
                if (product != null) {
                  item.unit = product.unit;
                  item.unitPrice = product.unitPrice;
                }
                onChanged(item);
              },
              fieldViewBuilder: (_, ctrl, fn, onFieldSubmitted) => TextField(
                controller: ctrl,
                focusNode: fn,
                style: const TextStyle(color: Colors.white, fontSize: 12),
                decoration: const InputDecoration(
                  hintText: 'Item name',
                  hintStyle: TextStyle(color: _white38, fontSize: 11),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (val) {
                  item.name = val;
                  onChanged(item);
                },
              ),
              optionsViewBuilder: (_, onSel, opts) => Align(
                alignment: Alignment.topLeft,
                child: Material(
                  color: const Color(0xFF0F162C),
                  elevation: 4,
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 280,
                    height: 180,
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: opts.length,
                      itemBuilder: (_, i) {
                        final opt = opts.elementAt(i);
                        return ListTile(
                          dense: true,
                          title: Text(opt, style: const TextStyle(color: Colors.white, fontSize: 12)),
                          onTap: () => onSel(opt),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 50,
            child: TextField(
              style: const TextStyle(color: Colors.white, fontSize: 12),
              decoration: const InputDecoration(
                hintText: 'Qty',
                hintStyle: TextStyle(color: _white38, fontSize: 11),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              controller: TextEditingController(text: item.qty.toString())
                ..selection = TextSelection.fromPosition(TextPosition(offset: item.qty.toString().length)),
              onChanged: (val) {
                item.qty = double.tryParse(val) ?? 1;
                onChanged(item);
              },
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 60,
            child: TextField(
              style: const TextStyle(color: Colors.white, fontSize: 12),
              decoration: const InputDecoration(
                hintText: 'Price',
                hintStyle: TextStyle(color: _white38, fontSize: 11),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              controller: TextEditingController(text: item.unitPrice.toString())
                ..selection = TextSelection.fromPosition(TextPosition(offset: item.unitPrice.toString().length)),
              onChanged: (val) {
                item.unitPrice = double.tryParse(val) ?? 0;
                onChanged(item);
              },
            ),
          ),
          const SizedBox(width: 8),
          Text('${_fmt.format(item.total)}', style: const TextStyle(color: _gold, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.red, size: 16),
            onPressed: onRemove,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  // ─── PDF Generation ────────────────────────────────────────────────────────
  Future<Uint8List> _buildPdfBytes(PdfPageFormat pageFormat) async {
    final depositPct = double.tryParse(_depositPctCtrl.text) ?? 50;
    final midPct = double.tryParse(_midPctCtrl.text) ?? 25;
    final compPct = double.tryParse(_completionPctCtrl.text) ?? 25;

    return PdfService.generateEnquiryInvoicePdf(
      state: widget.appState,
      customerName: _customerNameCtrl.text.trim().isEmpty ? 'Valued Customer' : _customerNameCtrl.text.trim(),
      telephone: _telephoneCtrl.text.trim(),
      kraPin: _kraPinCtrl.text.trim(),
      quotationNo: _quotationNoCtrl.text.trim().isEmpty ? 'INV-001' : _quotationNoCtrl.text.trim(),
      date: _date,
      agreedTotal: _agreedTotal,
      depositPct: depositPct,
      midPct: midPct,
      completionPct: compPct,
      requestLabel: _requestLabelCtrl.text.trim(),
      requestAmount: _requestAmount,
      nb: _nbCtrl.text.trim(),
      preparedBy: _preparedByCtrl.text.trim(),
      terms: _termsCtrl.text.trim(),
      categories: _categories,
    );
  }

  void _saveInvoice({bool closeAfter = false}) {
    final isEdit = widget.invoice != null;
    final rawNo = _quotationNoCtrl.text.trim().isEmpty
        ? (widget.invoice?.id ?? 'INV-${DateTime.now().millisecondsSinceEpoch % 10000}')
        : _quotationNoCtrl.text.trim();
    final clientName = _customerNameCtrl.text.trim().isEmpty
        ? 'Valued Customer'
        : _customerNameCtrl.text.trim();

    // Find or create client ID
    String clientId = widget.invoice?.clientId ?? '';
    if (clientId.isEmpty) {
      final existingClient = widget.appState.clients.firstWhere(
        (c) => c.name.toLowerCase() == clientName.toLowerCase(),
        orElse: () => Client(id: widget.appState.nextClientId, name: clientName),
      );
      clientId = existingClient.id;
      if (!widget.appState.clients.any((c) => c.id == clientId)) {
        widget.appState.addClient(existingClient);
      }
    }

    final invoice = Invoice(
      id: rawNo,
      quoteId: widget.invoice?.quoteId.isNotEmpty == true ? widget.invoice!.quoteId : rawNo,
      clientId: clientId,
      clientName: clientName,
      categories: _categories,
      amount: _grandTotal,
      status: widget.invoice?.status ?? InvoiceStatus.sent,
      date: _date,
      dueDate: widget.invoice?.dueDate ?? _date.add(const Duration(days: 14)),
      notes: _nbCtrl.text.trim(),
      labourInput: _labourInputCtrl.text.trim(),
      kraPin: _kraPinCtrl.text.trim(),
    );

    widget.appState.addInvoice(invoice);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEdit ? 'Invoice $rawNo updated successfully!' : 'Invoice $rawNo saved successfully!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      if (closeAfter) {
        Navigator.pop(context);
      }
    }
  }

  void _openPdfViewer() {
    _saveInvoice(closeAfter: false);
    final rawNo = _quotationNoCtrl.text.trim().isEmpty ? 'INV-001' : _quotationNoCtrl.text.trim();
    final safeNo = rawNo.replaceAll(RegExp(r'[^\w\.-]'), '_');

    PdfViewerPage.openDocumentPdf(
      context: context,
      title: 'Enquiry Invoice $rawNo',
      filename: 'Enquiry_Invoice_$safeNo.pdf',
      buildPdf: _buildPdfBytes,
    );
  }
}

// ── Add Item Dialog ─────────────────────────────────────────────────────────────
class _AddItemDialog extends StatefulWidget {
  final AppState appState;
  final Function(QuoteItem) onAdd;

  const _AddItemDialog({required this.appState, required this.onAdd});

  @override
  State<_AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<_AddItemDialog> {
  final _nameCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  final _priceCtrl = TextEditingController();
  final _unitCtrl = TextEditingController(text: 'pcs');
  final FocusNode _nameFocus = FocusNode();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    _unitCtrl.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  void _add() {
    final item = QuoteItem(
      productId: '',
      name: _nameCtrl.text.trim(),
      qty: double.tryParse(_qtyCtrl.text) ?? 1,
      unitPrice: double.tryParse(_priceCtrl.text) ?? 0,
      unit: _unitCtrl.text.trim(),
    );
    widget.onAdd(item);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF161B26),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Text('Add Item', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RawAutocomplete<String>(
            textEditingController: _nameCtrl,
            focusNode: _nameFocus,
            optionsBuilder: (v) {
              if (v.text.isEmpty) return const Iterable<String>.empty();
              final q = v.text.toLowerCase();
              return widget.appState.productNames.where((o) => o.toLowerCase().contains(q));
            },
            onSelected: (sel) {
              final product = widget.appState.productByName(sel);
              setState(() {
                _nameCtrl.text = sel;
                if (product != null) {
                  _unitCtrl.text = product.unit;
                  _priceCtrl.text = product.unitPrice == product.unitPrice.truncateToDouble()
                      ? product.unitPrice.toInt().toString()
                      : product.unitPrice.toStringAsFixed(2);
                }
              });
            },
            fieldViewBuilder: (_, ctrl, fn, onFieldSubmitted) => TextField(
              controller: ctrl,
              focusNode: fn,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Item Name',
                labelStyle: TextStyle(color: Color(0xFF616C88)),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF2A3045))),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFFFC107))),
              ),
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
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _qtyCtrl,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Quantity',
                    labelStyle: TextStyle(color: Color(0xFF616C88)),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF2A3045))),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFFFC107))),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _unitCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Unit',
                    labelStyle: TextStyle(color: Color(0xFF616C88)),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF2A3045))),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFFFC107))),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _priceCtrl,
            style: const TextStyle(color: Colors.white),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Unit Price',
              labelStyle: TextStyle(color: Color(0xFF616C88)),
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF2A3045))),
              focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFFFC107))),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Color(0xFF616C88))),
        ),
        ElevatedButton(
          onPressed: _add,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFC107), foregroundColor: Colors.black),
          child: const Text('Add'),
        ),
      ],
    );
  }
}
