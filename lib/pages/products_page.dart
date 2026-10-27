// pages/products_page.dart — QuotiMate Products & Services Page
// Backed by AppState with cloud sync support.
// Styled with the unified dark-blue table design system matching Clients & Invoices.

import 'package:flutter/material.dart';
import '../app_state.dart';
import '../models.dart';
import '../widgets/money_text.dart';

// ─── Design Tokens (Dark-Blue Theme) ──────────────────────────────────────────
const _bg      = Color(0xFF0F162C);
const _surface = Color(0xFF161B26);
const _border  = Color(0xFF2A3045);
const _gold    = Color(0xFFFFC107);
const _white38 = Color(0xFF616C88);
const _white54 = Colors.white54;
const _white70 = Color(0xFFB0B8D0);

// ─── Page ─────────────────────────────────────────────────────────────────────
class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final appState = AppStateProvider.of(context);
    final products = appState.products;
    
    final filtered = products
        .where((p) =>
            _search.isEmpty ||
            p.name.toLowerCase().contains(_search.toLowerCase()) ||
            p.unit.toLowerCase().contains(_search.toLowerCase()))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return Container(
      color: _bg,
      child: ClipRRect(
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Toolbar ─────────────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: TextField(
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search items or services...',
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
                    onChanged: (v) => setState(() => _search = v),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () => _showProductDialog(context, appState, null),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New Item', style: TextStyle(fontWeight: FontWeight.bold)),
                style: FilledButton.styleFrom(
                  backgroundColor: _gold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Summary pill ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(bottom: 12, left: 4),
            child: Row(
              children: [
                Text(
                  '${filtered.length} item${filtered.length == 1 ? '' : 's'} in catalogue',
                  style: const TextStyle(color: _white54, fontSize: 12, fontWeight: FontWeight.w500),
                ),
                if (_search.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _gold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'filtered by "$_search"',
                      style: const TextStyle(color: _gold, fontSize: 11),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Main Table Card ─────────────────────────────────────────────────
          Expanded(
            child: Card(
              color: _surface,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: _border),
              ),
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inventory_2_outlined, color: _gold.withValues(alpha: 0.3), size: 48),
                          const SizedBox(height: 12),
                          const Text('No catalogue items found.', style: TextStyle(color: _white70, fontSize: 14)),
                          if (_search.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            const Text('Try a different keyword or add a new item.', style: TextStyle(color: _white38, fontSize: 12)),
                          ],
                        ],
                      ),
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Column(
                        children: [
                          // Table Header
                          _ProductTableHeader(currency: appState.currency),
                          const Divider(color: _border, height: 1),

                          // Table Rows
                          Expanded(
                            child: Scrollbar(
                              child: ListView.builder(
                                itemCount: filtered.length,
                                itemBuilder: (context, idx) {
                                  final product = filtered[idx];
                                  return _ProductTableRow(
                                    product: product,
                                    formattedPrice: formatAmount(product.unitPrice, appState.currency, decimalDigits: 2),
                                    onEdit: () => _showProductDialog(context, appState, product),
                                    onDelete: () => _confirmDelete(context, appState, product),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  void _showProductDialog(BuildContext context, AppState appState, Product? existing) {
    showDialog(
      context: context,
      builder: (_) => _ProductFormDialog(
        appState: appState,
        existing: existing,
      ),
    );
  }

  void _confirmDelete(BuildContext context, AppState appState, Product product) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: _border),
        ),
        title: const Text('Delete Item?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to remove "${product.name}" from the catalogue? It will no longer appear in autocomplete suggestions.',
          style: const TextStyle(color: _white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: _white38)),
          ),
          FilledButton(
            onPressed: () {
              appState.deleteProduct(product.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Removed "${product.name}"'),
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

// ─── Table Header ─────────────────────────────────────────────────────────────
class _ProductTableHeader extends StatelessWidget {
  final String currency;
  const _ProductTableHeader({required this.currency});

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(color: _white54, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5);

    return Container(
      color: const Color(0xFF131722),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Expanded(flex: 4, child: Text('ITEM / SERVICE NAME', style: style)),
          const Expanded(flex: 2, child: Text('UNIT', style: style)),
          Expanded(flex: 2, child: Text('UNIT PRICE ($currency)', style: style, textAlign: TextAlign.right)),
          const SizedBox(width: 90, child: Text('ACTIONS', style: style, textAlign: TextAlign.center)),
        ],
      ),
    );
  }
}

// ─── Table Row ────────────────────────────────────────────────────────────────
class _ProductTableRow extends StatelessWidget {
  final Product product;
  final String formattedPrice;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProductTableRow({
    required this.product,
    required this.formattedPrice,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(
            children: [
              // Item Name + Icon
              Expanded(
                flex: 4,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 15,
                      backgroundColor: _gold.withValues(alpha: 0.12),
                      child: const Icon(Icons.inventory_2_outlined, color: _gold, size: 15),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        product.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              // Unit Badge
              Expanded(
                flex: 2,
                child: product.unit.isNotEmpty
                    ? Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF334155)),
                          ),
                          child: Text(
                            product.unit,
                            style: const TextStyle(
                              color: Color(0xFF93C5FD),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      )
                    : const Text('—', style: TextStyle(color: _white38, fontSize: 12)),
              ),

              // Unit Price
              Expanded(
                flex: 2,
                child: Text(
                  formattedPrice,
                  style: const TextStyle(
                    color: _gold,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),

              // Action Buttons
              SizedBox(
                width: 90,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: Colors.white54, size: 17),
                      tooltip: 'Edit Item',
                      splashRadius: 18,
                      onPressed: onEdit,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 17),
                      tooltip: 'Delete Item',
                      splashRadius: 18,
                      onPressed: onDelete,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(color: _border, height: 1),
      ],
    );
  }
}

// ─── Product Form Dialog ─────────────────────────────────────────────────────────
class _ProductFormDialog extends StatefulWidget {
  final AppState appState;
  final Product? existing;
  const _ProductFormDialog({required this.appState, this.existing});

  @override
  State<_ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<_ProductFormDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _unitCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _descCtrl;
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl  = TextEditingController(text: e?.name ?? '');
    _unitCtrl  = TextEditingController(text: e?.unit ?? '');
    _priceCtrl = TextEditingController(
      text: e != null ? formatMoney(e.unitPrice, decimalDigits: 2) : '',
    );
    _descCtrl  = TextEditingController(text: e?.description ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _unitCtrl.dispose();
    _priceCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Dialog(
      backgroundColor: _surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: _border),
      ),
      child: SizedBox(
        width: 480,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _gold.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.inventory_2_outlined, color: _gold, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isEdit ? 'Edit Item' : 'New Catalogue Item',
                      style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: _white38, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Item Name Field
                const Text('ITEM / SERVICE NAME', style: TextStyle(color: _white38, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Item name is required' : null,
                  decoration: _dec('e.g. Gypsy Board, Wallpaper Installation, Paint'),
                ),
                const SizedBox(height: 14),

                // Description Field
                const Text('DESCRIPTION (OPTIONAL)', style: TextStyle(color: _white38, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _descCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: _dec('e.g. High-quality gypsum board'),
                  maxLines: 2,
                ),
                const SizedBox(height: 14),

                // Unit & Price Row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('UNIT', style: TextStyle(color: _white38, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _unitCtrl,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: _dec('e.g. Pcs, Rolls, Sq Ft'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('UNIT PRICE (${widget.appState.currency})', style: const TextStyle(color: _white38, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _priceCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: moneyInputFormatters(decimalDigits: 2),
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Price required';
                              if (parseMoney(v) == null) return 'Enter a valid number';
                              return null;
                            },
                            decoration: _dec('0'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel', style: TextStyle(color: _white38)),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: _gold,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _saving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                          : Text(isEdit ? 'Save Changes' : 'Add Item', style: const TextStyle(fontWeight: FontWeight.bold)),
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

  InputDecoration _dec(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: _white38, fontSize: 13),
    filled: true,
    fillColor: _bg,
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _gold)),
    errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.red)),
    focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.red)),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    errorStyle: const TextStyle(color: Colors.red, fontSize: 11),
  );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final name = _nameCtrl.text.trim();
      final unit = _unitCtrl.text.trim();
      final description = _descCtrl.text.trim();
      final price = parseMoney(_priceCtrl.text) ?? 0;
      
      if (widget.existing != null) {
        widget.appState.updateProduct(widget.existing!.copyWith(
          name: name,
          unit: unit,
          description: description,
          unitPrice: price,
        ));
      } else {
        widget.appState.addProduct(Product(
          id: widget.appState.nextProductId,
          name: name,
          unit: unit.isEmpty ? 'pcs' : unit,
          description: description,
          unitPrice: price,
        ));
      }
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.existing != null ? 'Item updated!' : 'Item added to catalogue!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
