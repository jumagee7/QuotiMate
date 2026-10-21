// services/project_pdf_service.dart — Internal project report PDF
// Includes item project notes (paint codes, colours), tasks, notes and photos
// that are intentionally left out of client-facing quote PDFs.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart' show debugPrint;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../app_state.dart';
import '../models.dart';

class ProjectPdfService {
  static final _money = NumberFormat.currency(symbol: 'KES ', decimalDigits: 2);
  static final _date = DateFormat('dd MMM yyyy');
  static final _dateTime = DateFormat('dd MMM yyyy, HH:mm');
  static final _dark = PdfColor.fromHex('#1E2733');
  static final _gold = PdfColor.fromHex('#C9A227');

  static pw.MemoryImage? _image(String b64) {
    try {
      return pw.MemoryImage(base64Decode(b64));
    } catch (_) {
      return null;
    }
  }

  static pw.Widget _section(String title) => pw.Container(
        margin: const pw.EdgeInsets.only(top: 16, bottom: 6),
        padding: const pw.EdgeInsets.only(bottom: 3),
        decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _gold, width: 1.2))),
        child: pw.Text(title.toUpperCase(),
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _dark, letterSpacing: 1)),
      );

  static pw.Widget _kv(String k, String v) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
        child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.SizedBox(width: 90, child: pw.Text(k, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700))),
          pw.Expanded(child: pw.Text(v, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
        ]),
      );

  static pw.Widget _photos(List<String> images, {double size = 120}) {
    final decoded = images.map(_image).whereType<pw.MemoryImage>().toList();
    if (decoded.isEmpty) return pw.SizedBox();
    return pw.Wrap(spacing: 6, runSpacing: 6, children: [
      for (final img in decoded)
        pw.Container(
          width: size, height: size,
          decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300)),
          child: pw.Image(img, fit: pw.BoxFit.cover),
        ),
    ]);
  }

  static pw.Widget _table(List<String> headers, List<List<String>> rows, {Map<int, pw.TableColumnWidth>? widths}) {
    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      columnWidths: widths,
      headerStyle: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: pw.BoxDecoration(color: _dark),
      cellStyle: const pw.TextStyle(fontSize: 8.5),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
    );
  }

  static Future<Uint8List> generate(
    Project project,
    AppState state, {
    required List<Quote> quotes,
    required List<Invoice> invoices,
  }) async {
    pw.MemoryImage? logo;
    try {
      final bytes = await rootBundle.load('assets/modernedge_logo.png');
      logo = pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (e) {
      debugPrint('Project PDF logo load error: $e');
    }

    final tasks = state.tasksForProject(project.id)..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    final doneTasks = tasks.where((t) => t.status == TaskStatus.done).length;
    final pdf = pw.Document();

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      footer: (ctx) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text('Internal project report — not a client document',
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
        pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
      ]),
      build: (ctx) => [
        pw.Container(
          color: _dark,
          padding: const pw.EdgeInsets.all(12),
          child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
            if (logo != null) pw.SizedBox(height: 60, width: 122, child: pw.Image(logo, fit: pw.BoxFit.contain)),
            pw.SizedBox(width: 14),
            pw.Expanded(
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('PROJECT REPORT', style: pw.TextStyle(color: _gold, fontSize: 10, letterSpacing: 2)),
                pw.Text(project.name,
                    style: pw.TextStyle(color: PdfColors.white, fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.Text('Generated ${_dateTime.format(DateTime.now())}',
                    style: const pw.TextStyle(color: PdfColors.grey400, fontSize: 8)),
              ]),
            ),
          ]),
        ),
        _section('Summary'),
        _kv('Client', project.clientName),
        if (project.location.isNotEmpty) _kv('Location', project.location),
        _kv('Status', project.status.label),
        _kv('Start date', _date.format(project.startDate)),
        if (project.deadline != null) _kv('Deadline', _date.format(project.deadline!)),
        _kv('Budget', _money.format(project.budget)),
        _kv('Tasks', '$doneTasks of ${tasks.length} completed'),
        if (project.description.isNotEmpty) ...[
          pw.SizedBox(height: 6),
          pw.Text(project.description, style: const pw.TextStyle(fontSize: 9.5)),
        ],
        if (project.summaryImages.isNotEmpty) ...[
          pw.SizedBox(height: 8),
          _photos(project.summaryImages),
        ],
        _section('Financials'),
        _kv('Quoted', _money.format(project.totalQuoted(state.quotes))),
        _kv('Invoiced', _money.format(project.totalInvoiced(state.invoices))),
        _kv('Received', _money.format(project.totalPaymentsReceived)),
        _kv('Expenses', _money.format(project.totalExpenses)),
        _kv('Net profit', _money.format(project.netProfitRealized())),
        _kv('Outstanding', _money.format(project.outstandingBalance(state.invoices, state.quotes))),
        for (final q in quotes) ...[
          _section('Quotation #${q.id} — ${q.status.name}'),
          for (final cat in q.categories) ...[
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 4, bottom: 3),
              child: pw.Text(cat.name, style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
            ),
            _table(
              ['Item', 'Project notes (paint code / colour)', 'Qty', 'Unit price', 'Total'],
              [
                for (final i in cat.items)
                  [
                    i.name,
                    i.description.isEmpty ? '-' : i.description,
                    '${i.qty % 1 == 0 ? i.qty.toInt() : i.qty} ${i.unit}',
                    _money.format(i.unitPrice),
                    _money.format(i.total),
                  ],
              ],
              widths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(3),
                2: const pw.FlexColumnWidth(1.2),
                3: const pw.FlexColumnWidth(1.6),
                4: const pw.FlexColumnWidth(1.6),
              },
            ),
          ],
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Padding(
              padding: const pw.EdgeInsets.only(top: 4),
              child: pw.Text('Quote total: ${_money.format(q.total)}',
                  style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
            ),
          ),
        ],
        if (invoices.isNotEmpty) ...[
          _section('Invoices'),
          _table(['Invoice', 'Date', 'Status', 'Amount'], [
            for (final inv in invoices) [inv.id, _date.format(inv.date), inv.status.name, _money.format(inv.amount)],
          ]),
        ],
        if (tasks.isNotEmpty) ...[
          _section('Tasks'),
          _table(['Task', 'Due', 'Priority', 'Status'], [
            for (final t in tasks)
              [
                t.description.isEmpty ? t.title : '${t.title}\n${t.description}',
                _dateTime.format(t.dueDate),
                t.priority.name,
                t.status == TaskStatus.done ? 'Done' : (t.status == TaskStatus.inProgress ? 'In progress' : 'To do'),
              ],
          ], widths: {
            0: const pw.FlexColumnWidth(4),
            1: const pw.FlexColumnWidth(2),
            2: const pw.FlexColumnWidth(1),
            3: const pw.FlexColumnWidth(1.2),
          }),
        ],
        if (project.expenses.isNotEmpty) ...[
          _section('Bought products & expenses'),
          _table(['Date', 'Item', 'Category', 'Supplier', 'Amount'], [
            for (final e in project.expenses)
              [_date.format(e.date), e.title, e.category, e.supplier, _money.format(e.amount)],
          ]),
        ],
        if (project.payments.isNotEmpty) ...[
          _section('Payments received'),
          _table(['Date', 'Method', 'Reference', 'Amount'], [
            for (final p in project.payments)
              [_date.format(p.date), p.paymentMethod, p.reference, _money.format(p.amount)],
          ]),
        ],
        if (project.notes.isNotEmpty) ...[
          _section('Notes'),
          for (final n in project.notes)
            pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 8),
              padding: const pw.EdgeInsets.all(6),
              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300)),
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text(_dateTime.format(n.createdAt), style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
                if (n.text.isNotEmpty) pw.Text(n.text, style: const pw.TextStyle(fontSize: 9.5)),
                if (n.images.isNotEmpty) ...[pw.SizedBox(height: 4), _photos(n.images, size: 100)],
              ]),
            ),
        ],
      ],
    ));
    return pdf.save();
  }
}
