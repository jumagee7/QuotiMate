// verify_features_test.dart — runtime verification of the feature set.
// Exercises AppState logic and PDF generation on the Dart VM (no device needed).

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:quotimate/app_state.dart';
import 'package:quotimate/models.dart';
import 'package:quotimate/services/pdf_service.dart';

Future<AppState> _newState() async {
  SharedPreferences.setMockInitialValues({});
  late AppState state;
  await runZonedGuarded(() async {
    state = AppState();
    await Future<void>.delayed(const Duration(milliseconds: 400));
  }, (_, __) {});
  return state;
}

Quote _quote(String id, {String client = 'Acme Ltd'}) => Quote(
      id: id,
      clientId: 'c1',
      clientName: client,
      date: DateTime(2026, 10, 1),
      expiryDate: DateTime(2026, 10, 31),
      categories: [
        QuoteCategory(
          id: 'cat1',
          name: 'Painting',
          items: [
            QuoteItem(
              productId: 'p1',
              name: 'Silk Paint',
              description: 'Code: SILK-204 / Colour: Ivory',
              qty: 2,
              unitPrice: 1000,
            ),
          ],
        ),
      ],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Quotation numbering', () {
    test('allocateQuoteNumber refuses to issue a number while offline', () async {
      final state = await _newState();
      final id = await state.allocateQuoteNumber();
      expect(id, isNull, reason: 'offline devices must not mint quote numbers');
    });

    test('deleting the last-issued quote rolls the counter back', () async {
      final state = await _newState();
      state.nextQuoteNumber = 1043; // pretend 1042 was just issued
      state.addQuote(_quote('Q-1042'));
      state.deleteQuote('Q-1042');
      expect(state.nextQuoteNumber, 1042,
          reason: 'tail number must be reusable after deleting the newest quote');
    });

    test('deleting an older quote leaves the counter untouched', () async {
      final state = await _newState();
      state.nextQuoteNumber = 1043;
      state.addQuote(_quote('Q-1040'));
      state.addQuote(_quote('Q-1042'));
      state.deleteQuote('Q-1040');
      expect(state.nextQuoteNumber, 1043,
          reason: 'only the tail number may be reclaimed');
    });
  });

  group('Activity feed', () {
    test('derives entries from real documents, not mocks', () async {
      final state = await _newState();
      state.addQuote(_quote('Q-2001'));
      state.addInvoice(Invoice(
        id: 'INV-1',
        quoteId: 'Q-2001',
        clientId: 'c1',
        clientName: 'Acme Ltd',
        categories: const [],
        amount: 5000,
        status: InvoiceStatus.paid,
        date: DateTime(2026, 10, 2),
        dueDate: DateTime(2026, 10, 30),
      ));
      final titles = state.activities.map((a) => a.title).toList();
      expect(titles.any((t) => t.contains('Q-2001')), isTrue);
      expect(titles.any((t) => t.contains('INV-1') && t.contains('paid')), isTrue);
      expect(titles.any((t) => t.contains('Quotation #Q-1021 approved')), isFalse,
          reason: 'old hard-coded mock rows must be gone');
    });
  });

  group('Project tasks', () {
    test('tasksForProject scopes tasks to their project', () async {
      final state = await _newState();
      state.addTask(AppTask(
        id: 't1',
        title: 'Prime walls',
        dueDate: DateTime(2026, 10, 5),
        projectId: 'projA',
      ));
      state.addTask(AppTask(
        id: 't2',
        title: 'Unrelated chore',
        dueDate: DateTime(2026, 10, 5),
        projectId: 'projB',
      ));
      final forA = state.tasksForProject('projA');
      expect(forA.length, 1);
      expect(forA.single.title, 'Prime walls');
    });
  });

  group('Project numbering', () {
    test('new projects get the next sequential number', () async {
      final state = await _newState();
      final first = Project(
        id: 'PRJ-a',
        number: state.nextProjectNumber,
        name: 'First',
        clientId: 'c1',
        clientName: 'Acme Ltd',
        startDate: DateTime(2026, 10, 1),
      );
      state.addProject(first);
      expect(first.numberLabel, 'PRJ-001');
      expect(state.nextProjectNumber, 2);

      final second = Project(
        id: 'PRJ-b',
        number: state.nextProjectNumber,
        name: 'Second',
        clientId: 'c1',
        clientName: 'Acme Ltd',
        startDate: DateTime(2026, 10, 2),
      );
      state.addProject(second);
      expect(second.numberLabel, 'PRJ-002');
    });

    test('legacy projects without a number are backfilled oldest first', () async {
      SharedPreferences.setMockInitialValues({
        'qm_seeded': true,
        'qm_projects': jsonEncode([
          {
            'id': 'PRJ-1755000000001',
            'name': 'Newer',
            'clientId': 'c1',
            'clientName': 'Acme Ltd',
            'startDate': '2026-03-01T00:00:00.000',
            'createdAt': '2026-03-01T00:00:00.000',
          },
          {
            'id': 'PRJ-1755000000000',
            'name': 'Older',
            'clientId': 'c1',
            'clientName': 'Acme Ltd',
            'startDate': '2026-01-01T00:00:00.000',
            'createdAt': '2026-01-01T00:00:00.000',
          },
        ]),
      });
      AppState? state;
      await runZonedGuarded(() async {
        state = AppState();
        await Future<void>.delayed(const Duration(milliseconds: 400));
      }, (_, __) {});

      expect(state!.getProject('PRJ-1755000000000')!.number, 1);
      expect(state!.getProject('PRJ-1755000000001')!.number, 2);
      expect(state!.nextProjectNumber, 3);
    });
  });

  group('Item descriptions', () {
    test('description survives a JSON round-trip', () {
      final item = QuoteItem(
        productId: 'p1',
        name: 'Silk Paint',
        description: 'Code: SILK-204',
        qty: 1,
        unitPrice: 10,
      );
      final restored = QuoteItem.fromJson(item.toJson());
      expect(restored.description, 'Code: SILK-204');
    });
  });

  group('PDF generation', () {
    test('quote, signed-quote and full-project PDFs all generate', () async {
      final state = await _newState();
      final quote = _quote('Q-3001');
      state.addQuote(quote);
      final project = Project(
        id: 'projP',
        name: 'Office Repaint',
        clientId: 'c1',
        clientName: 'Acme Ltd',
        startDate: DateTime(2026, 10, 1),
        quoteIds: ['Q-3001'],
      );
      state.addProject(project);

      final quotePdf = await PdfService.generateQuotePdf(quote, state);
      expect(quotePdf.length, greaterThan(1000));

      final signedPdf = await PdfService.generateSignedQuotePdf(
        quote, state, await _signaturePng());
      expect(signedPdf.length, greaterThan(1000));

      final projectPdf = await PdfService.generateFullProjectPdf(
        appState: state,
        project: project,
        quotes: state.quotes,
        invoices: state.invoices,
      );
      expect(projectPdf.length, greaterThan(1000));
    });

    test('full-project dossier prints notes, photos, tasks and completion',
        () async {
      final state = await _newState();
      state.currency = 'TSh';
      final png = await _signaturePng();
      final bogus = base64Encode(utf8.encode('not a real image'));

      final project = Project(
        id: 'projDossier',
        number: 7,
        name: 'Riverside Fit-out',
        clientId: 'c1',
        clientName: 'Acme Ltd',
        status: ProjectStatus.completed,
        startDate: DateTime(2026, 9, 1),
        deadline: DateTime(2026, 10, 15),
        completedAt: DateTime(2026, 10, 12),
        budget: 450000,
        description: 'Ground floor refurbishment.',
        location: 'Westlands',
        summaryImages: [base64Encode(png), bogus],
        workflowNotes: [
          ProjectNote(
            id: 'n1',
            text: 'First floor skimming almost done',
            images: [base64Encode(png)],
            createdAt: DateTime(2026, 9, 20),
          ),
        ],
        expenses: [
          ProjectExpense(
            id: 'e1',
            projectId: 'projDossier',
            title: 'Skimming plaster',
            quantity: 4,
            unit: 'bags',
            unitPrice: 1250,
            amount: 5000,
            supplier: 'BuildMart',
            receiptNo: 'RC-77',
            notes: 'Delivered on site',
            date: DateTime(2026, 9, 10),
          ),
        ],
        payments: [
          ProjectPayment(
            id: 'pay1',
            projectId: 'projDossier',
            amount: 200000,
            date: DateTime(2026, 9, 15),
            paymentMethod: 'M-Pesa',
            reference: 'QK12',
            notes: 'Deposit',
          ),
        ],
      );
      state.addProject(project);
      state.addTask(AppTask(
        id: 'td1',
        title: 'Snag list walkthrough',
        dueDate: DateTime(2026, 10, 10),
        projectId: 'projDossier',
        status: TaskStatus.done,
      ));

      for (final template in ['modern_edge', 'minimalist']) {
        state.pdfTemplate = template;
        final bytes = await PdfService.generateFullProjectPdf(
          appState: state,
          project: project,
          quotes: state.quotes,
          invoices: state.invoices,
        );
        expect(bytes.length, greaterThan(5000),
            reason: '$template dossier should embed notes and photos');
      }
    });
  });

  group('Project completion', () {
    test('completedAt survives JSON round-trip and can be cleared', () {
      final done = DateTime(2026, 10, 12, 9, 30);
      final project = Project(
        id: 'p1',
        name: 'Done job',
        clientId: 'c1',
        clientName: 'Acme Ltd',
        status: ProjectStatus.completed,
        startDate: DateTime(2026, 9, 1),
        completedAt: done,
      );
      final restored = Project.fromJson(
          jsonDecode(jsonEncode(project.toJson())) as Map<String, dynamic>);
      expect(restored.completedAt, done);
      expect(restored.status, ProjectStatus.completed);

      final reopened = restored.copyWith(
        status: ProjectStatus.inProgress,
        clearCompletedAt: true,
      );
      expect(reopened.completedAt, isNull);
    });

    test('workflow cards own the note text and photos', () {
      final project = Project(
        id: 'p2',
        name: 'Notes job',
        clientId: 'c1',
        clientName: 'Acme Ltd',
        startDate: DateTime(2026, 9, 1),
        notes: 'Old blob',
        noteImages: ['old-image'],
      );
      final cards = [
        ProjectNote(id: 'n1', text: 'Ceiling primed', images: ['img1']),
        ProjectNote(id: 'n2', text: 'Doors hung', images: ['img2']),
      ];
      final updated = project.withWorkflowNotes(cards);
      expect(updated.workflowNotes.length, 2);
      expect(updated.notes, 'Ceiling primed\n\nDoors hung');
      expect(updated.noteImages, isEmpty,
          reason: 'photos must live on the cards only, not stored twice');
    });
  });
}

/// Renders a tiny raster and encodes it as a valid PNG, standing in for a
/// captured signature so the signed-PDF path is exercised for real.
Future<Uint8List> _signaturePng() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(const Rect.fromLTWH(0, 0, 60, 24),
      Paint()..color = const Color(0xFF1A1A2E));
  final picture = recorder.endRecording();
  final image = await picture.toImage(60, 24);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}
