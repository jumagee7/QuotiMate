// services/review_server_service.dart — Embedded HTTP Review Server for QuotiMate
// Allows clients on the local network (Wi-Fi / Hotspot) to open review links and submit signatures directly back to the app in real time.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../app_state.dart';
import 'signer_info_service.dart';
import '../models.dart';
import 'html_review_service.dart';
import 'notification_service.dart';

class ReviewServerService {
  static final ReviewServerService _instance = ReviewServerService._internal();
  factory ReviewServerService() => _instance;
  ReviewServerService._internal();

  HttpServer? _server;
  int? _port;
  String? _localIp;
  AppState? _appState;

  bool get isRunning => _server != null;
  int? get port => _port;
  String? get localIp => _localIp;

  Future<void> start({required AppState appState}) async {
    _appState = appState;
    if (_server != null) return;

    try {
      _localIp = await _findLocalIp();

      // Attempt standard port 8080, fallback to system-assigned available port
      try {
        _server = await HttpServer.bind(InternetAddress.anyIPv4, 8080);
      } catch (_) {
        _server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
      }

      _port = _server!.port;
      debugPrint('QuotiMate Review Server listening on http://$_localIp:$_port');

      _server!.listen(_handleRequest, onError: (e) {
        debugPrint('Review Server error: $e');
      });
    } catch (e) {
      debugPrint('Could not start Review Server: $e');
    }
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _port = null;
  }

  String getReviewUrl({required String type, required String id}) {
    final ip = _localIp ?? 'localhost';
    final p = _port ?? 8080;
    return 'http://$ip:$p/review?type=$type&id=${Uri.encodeComponent(id)}';
  }

  Future<String> _findLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback) {
            return addr.address;
          }
        }
      }
    } catch (e) {
      debugPrint('Error finding local IP: $e');
    }
    return 'localhost';
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final res = request.response;

    // Apply CORS headers to all responses
    res.headers.set('Access-Control-Allow-Origin', '*');
    res.headers.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.headers.set('Access-Control-Allow-Headers', 'Content-Type');

    if (request.method == 'OPTIONS') {
      res.statusCode = HttpStatus.noContent;
      await res.close();
      return;
    }

    final path = request.uri.path;

    if (request.method == 'GET' && path == '/review') {
      await _handleReviewPage(request, res);
    } else if (request.method == 'POST' && path == '/api/sign') {
      await _handleSignApi(request, res);
    } else if (request.method == 'GET' && path == '/health') {
      res.statusCode = HttpStatus.ok;
      res.headers.contentType = ContentType.json;
      res.write(jsonEncode({'status': 'ok', 'app': 'QuotiMate', 'time': DateTime.now().toIso8601String()}));
      await res.close();
    } else {
      res.statusCode = HttpStatus.notFound;
      res.write('Not Found');
      await res.close();
    }
  }

  Future<void> _handleReviewPage(HttpRequest request, HttpResponse res) async {
    if (_appState == null) {
      res.statusCode = HttpStatus.internalServerError;
      res.write('App state not available');
      await res.close();
      return;
    }

    final type = request.uri.queryParameters['type'] ?? 'quote';
    final id = request.uri.queryParameters['id'] ?? '';
    final serverUrl = 'http://$_localIp:$_port';

    if (type == 'invoice') {
      final invoice = _appState!.invoices.where((i) => i.id == id).firstOrNull;
      if (invoice == null) {
        res.statusCode = HttpStatus.notFound;
        res.write('Invoice #$id not found in QuotiMate.');
        await res.close();
        return;
      }
      final html = HtmlReviewService.generateInvoiceHtml(invoice, _appState!, serverUrl: serverUrl);
      res.statusCode = HttpStatus.ok;
      res.headers.contentType = ContentType('text', 'html', charset: 'utf-8');
      res.write(html);
      await res.close();
      return;
    }

    // Default: Quotation
    final quote = _appState!.quotes.where((q) => q.id == id).firstOrNull;
    if (quote == null) {
      res.statusCode = HttpStatus.notFound;
      res.write('Quotation #$id not found in QuotiMate.');
      await res.close();
      return;
    }

    final html = HtmlReviewService.generateQuoteHtml(quote, _appState!, serverUrl: serverUrl);
    res.statusCode = HttpStatus.ok;
    res.headers.contentType = ContentType('text', 'html', charset: 'utf-8');
    res.write(html);
    await res.close();
  }

  Future<void> _handleSignApi(HttpRequest request, HttpResponse res) async {
    if (_appState == null) {
      res.statusCode = HttpStatus.internalServerError;
      res.write(jsonEncode({'error': 'App state not available'}));
      await res.close();
      return;
    }

    try {
      final bodyStr = await utf8.decoder.bind(request).join();
      final data = jsonDecode(bodyStr) as Map<String, dynamic>;

      final docId = data['docId'] as String? ?? '';
      final docType = data['docType'] as String? ?? 'Quotation';
      final sigBase64 = data['signatureData'] as String? ?? '';
      final signedAtStr = data['signedAt'] as String?;
      final signedAt = signedAtStr != null ? DateTime.tryParse(signedAtStr) : DateTime.now();

      if (docId.isEmpty || sigBase64.isEmpty) {
        res.statusCode = HttpStatus.badRequest;
        res.write(jsonEncode({'error': 'Missing docId or signatureData'}));
        await res.close();
        return;
      }

      final isInvoice = docType.toLowerCase() == 'invoice';
      final quoteDoc = isInvoice ? null : _appState!.quotes.where((q) => q.id == docId).firstOrNull;
      final invoiceDoc = isInvoice ? _appState!.invoices.where((i) => i.id == docId).firstOrNull : null;
      if (quoteDoc == null && invoiceDoc == null) {
        res.statusCode = HttpStatus.notFound;
        res.write(jsonEncode({'error': 'Document not found'}));
        await res.close();
        return;
      }
      final expectedToken = quoteDoc?.shareToken ?? invoiceDoc?.shareToken;
      if (expectedToken != null && expectedToken.isNotEmpty && data['token'] != expectedToken) {
        res.statusCode = HttpStatus.forbidden;
        res.write(jsonEncode({'error': 'Invalid or expired signing link'}));
        await res.close();
        return;
      }

      final rawSigner = data['signerInfo'] is Map ? Map<String, dynamic>.from(data['signerInfo'] as Map) : <String, dynamic>{};
      final signer = SignerInfo.fromJson(rawSigner)
        ..method = 'Web link'
        ..ipAddress = request.connectionInfo?.remoteAddress.address ?? ''
        ..userAgent = request.headers.value(HttpHeaders.userAgentHeader) ?? (rawSigner['userAgent']?.toString() ?? '')
        ..docHash = SignerInfoService.hashDocument(quoteDoc?.toJson() ?? invoiceDoc!.toJson());
      if (signer.name.trim().isEmpty || signer.phone.trim().isEmpty) {
        res.statusCode = HttpStatus.badRequest;
        res.write(jsonEncode({'error': 'Signer name and phone number are required'}));
        await res.close();
        return;
      }

      if (docType.toLowerCase() == 'invoice') {
        _appState!.markInvoiceSigned(docId, sigBase64, signedAt, signer);
        final inv = _appState!.invoices.where((i) => i.id == docId).firstOrNull;
        if (inv != null && signedAt != null) {
          inv.signedAt = signedAt;
        }
      } else {
        _appState!.markQuoteSigned(docId, sigBase64, signedAt, signer);
        final q = _appState!.quotes.where((i) => i.id == docId).firstOrNull;
        if (q != null) {
          if (signedAt != null) q.signedAt = signedAt;
          q.status = QuoteStatus.approved;
        }
      }

      try {
        await NotificationService().showInstantNotification(
          id: docId.hashCode,
          title: '$docType Approved & Signed! ✍️',
          body: 'Client signed $docType #$docId. PDF updated in QuotiMate.',
        );
      } catch (e) {
        debugPrint('Notification notice: $e');
      }

      res.statusCode = HttpStatus.ok;
      res.headers.contentType = ContentType.json;
      res.write(jsonEncode({
        'success': true,
        'docId': docId,
        'docType': docType,
        'message': 'Signature recorded and applied in QuotiMate app.',
      }));
      await res.close();
    } catch (e) {
      debugPrint('Error handling sign API: $e');
      res.statusCode = HttpStatus.internalServerError;
      res.headers.contentType = ContentType.json;
      res.write(jsonEncode({'error': e.toString()}));
      await res.close();
    }
  }
}
