// pages/signature_page.dart — QuotiMate Signature Capture

import "dart:convert";
import "dart:ui" as ui;
import "package:flutter/material.dart";
import "package:flutter/rendering.dart";
import "../models.dart";
import "../app_state.dart";
import "../services/pdf_service.dart";
import "../services/signer_capture_service.dart";
import "pdf_viewer_page.dart";

const _cBg      = Color(0xFF0B0E17);
const _cBorder  = Color(0xFF2A3045);
const _cGold    = Color(0xFFFFC107);

class SignaturePage extends StatefulWidget {
  final Quote? quote;
  final Invoice? invoice;

  const SignaturePage({super.key, this.quote, this.invoice})
      : assert(quote != null || invoice != null,
            "Either quote or invoice must be provided");

  @override
  State<SignaturePage> createState() => _SignaturePageState();
}

class _SignaturePageState extends State<SignaturePage> {
  final List<Offset?> _points = [];
  final GlobalKey _canvasKey = GlobalKey();
  bool _saving = false;
  late final TextEditingController _signerNameCtrl;
  late final TextEditingController _signerPhoneCtrl;

  @override
  void initState() {
    super.initState();
    _signerNameCtrl = TextEditingController(text: _clientName);
    _signerPhoneCtrl = TextEditingController(text: _clientPhone);
  }

  @override
  void dispose() {
    _signerNameCtrl.dispose();
    _signerPhoneCtrl.dispose();
    super.dispose();
  }

  String get _clientPhone {
    final clientId = widget.quote?.clientId ?? widget.invoice?.clientId ?? '';
    try {
      final clients = AppStateProvider.of(context).clients;
      final match = clients.where((c) => c.id == clientId);
      return match.isNotEmpty ? match.first.phone : '';
    } catch (_) {
      return '';
    }
  }

  String get _docTitle => widget.quote != null
      ? "Quotation ${widget.quote!.id}"
      : "Invoice ${widget.invoice!.id}";

  String get _clientName =>
      widget.quote?.clientName ?? widget.invoice!.clientName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F162C),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_docTitle,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text("Signature for $_clientName",
                style: const TextStyle(fontSize: 12, color: Colors.white54)),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed:
                _points.isEmpty ? null : () => setState(() => _points.clear()),
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text("Clear"),
            style: TextButton.styleFrom(foregroundColor: Colors.white70),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: (_points.isEmpty || _saving) ? null : _confirmSignature,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.black),
                  )
                : const Icon(Icons.check, size: 18),
            label: const Text("Confirm Signature"),
            style: FilledButton.styleFrom(
              backgroundColor: _cGold,
              foregroundColor: Colors.black,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _cGold.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: _cGold.withValues(alpha: 0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.edit_outlined, color: _cGold, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Sign in the box below using mouse, stylus, or finger. "
                      "Tap Clear to redo, or Confirm Signature when done.",
                      style:
                          TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _signerField(
                    'Signed by',
                    _signerNameCtrl,
                    Icons.person_outline,
                    'Full name of the signer',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _signerField(
                    'WhatsApp Number',
                    _signerPhoneCtrl,
                    Icons.chat_outlined,
                    'e.g. +254 712 345 678',
                    keyboardType: TextInputType.phone,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: RepaintBoundary(
                key: _canvasKey,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _cBorder, width: 2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Stack(
                      children: [
                        if (_points.isEmpty)
                          Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.draw_outlined,
                                    size: 48,
                                    color: Colors.grey.shade300),
                                const SizedBox(height: 12),
                                Text("Sign here",
                                    style: TextStyle(
                                        color: Colors.grey.shade400,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w300)),
                              ],
                            ),
                          ),
                        GestureDetector(
                          onPanUpdate: (details) {
                            final RenderBox box = _canvasKey.currentContext!
                                .findRenderObject() as RenderBox;
                            final localPos =
                                box.globalToLocal(details.globalPosition);
                            setState(() => _points.add(localPos));
                          },
                          onPanEnd: (_) =>
                              setState(() => _points.add(null)),
                          child: CustomPaint(
                            painter: _SignaturePainter(_points),
                            size: Size.infinite,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Icon(Icons.lock_outline, color: Colors.white38, size: 16),
                SizedBox(width: 6),
                Text(
                  "This signature will be embedded into the final signed PDF.",
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _signerField(String label, TextEditingController ctrl, IconData icon,
      String hint,
      {TextInputType keyboardType = TextInputType.text}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: Colors.white54,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: keyboardType,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
            prefixIcon: Icon(icon, size: 18, color: _cGold.withValues(alpha: 0.7)),
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            filled: true,
            fillColor: const Color(0xFF141A26),
            enabledBorder:
                OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _cBorder)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _cGold)),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmSignature() async {
    setState(() => _saving = true);
    try {
      final boundary = _canvasKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        _showError("Could not capture signature canvas");
        return;
      }
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        _showError("Failed to encode signature image");
        return;
      }
      final pngBytes = byteData.buffer.asUint8List();
      final base64Sig = base64Encode(pngBytes);

      if (!mounted) return;
      final appState = AppStateProvider.of(context);
      final signedAt = DateTime.now();
      final meta = await SignerCaptureService().collect(
        signerName: _signerNameCtrl.text.trim(),
        signerPhone: _signerPhoneCtrl.text.trim(),
      );

      if (widget.quote != null) {
        final q = widget.quote!;
        appState.markQuoteSigned(q.id, base64Sig, signedAt, meta);
        q.signatureData = base64Sig;
        q.signedAt = signedAt;
        if (!mounted) return;
        await PdfViewerPage.openDocumentPdf(
          context: context,
          title: "Signed — ${q.id}",
          filename: "Signed_${q.id}.pdf",
          buildPdf: (_) => PdfService.generateSignedQuotePdf(q, appState, pngBytes),
        );
      } else if (widget.invoice != null) {
        final inv = widget.invoice!;
        appState.markInvoiceSigned(inv.id, base64Sig, signedAt, meta);
        inv.signatureData = base64Sig;
        inv.signedAt = signedAt;
        if (!mounted) return;
        await PdfViewerPage.openDocumentPdf(
          context: context,
          title: "Signed — ${inv.id}",
          filename: "Signed_${inv.id}.pdf",
          buildPdf: (_) =>
              PdfService.generateSignedInvoicePdf(inv, appState, pngBytes),
        );
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showError("Error: $e");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }
}

class _SignaturePainter extends CustomPainter {
  final List<Offset?> points;
  _SignaturePainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1A1A2E)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_SignaturePainter old) => old.points != points;
}
