// models.dart — QuotiMate shared data models

import 'package:flutter/material.dart';

// ── Enums ─────────────────────────────────────────────────────────────────────

enum QuoteStatus { draft, pending, approved, rejected, expired }

enum InvoiceStatus { draft, sent, paid, overdue }

extension QuoteStatusExt on QuoteStatus {
  String get label {
    switch (this) {
      case QuoteStatus.draft:     return 'Draft';
      case QuoteStatus.pending:   return 'Pending';
      case QuoteStatus.approved:  return 'Approved';
      case QuoteStatus.rejected:  return 'Rejected';
      case QuoteStatus.expired:   return 'Expired';
    }
  }

  Color get color {
    switch (this) {
      case QuoteStatus.draft:     return Colors.grey;
      case QuoteStatus.pending:   return Colors.orange;
      case QuoteStatus.approved:  return Colors.green;
      case QuoteStatus.rejected:  return Colors.red;
      case QuoteStatus.expired:   return Colors.purple;
    }
  }
}

extension InvoiceStatusExt on InvoiceStatus {
  String get label {
    switch (this) {
      case InvoiceStatus.draft:    return 'Draft';
      case InvoiceStatus.sent:     return 'Sent';
      case InvoiceStatus.paid:     return 'Paid';
      case InvoiceStatus.overdue:  return 'Overdue';
    }
  }

  Color get color {
    switch (this) {
      case InvoiceStatus.draft:    return Colors.grey;
      case InvoiceStatus.sent:     return Colors.blue;
      case InvoiceStatus.paid:     return Colors.green;
      case InvoiceStatus.overdue:  return Colors.red;
    }
  }
}

// ── Models ────────────────────────────────────────────────────────────────────

class Client {
  final String id;
  String name;
  String company;
  String email;
  String phone;
  String address;

  Client({
    required this.id,
    required this.name,
    this.company = '',
    this.email = '',
    this.phone = '',
    this.address = '',
  });

  factory Client.fromJson(Map<String, dynamic> j) => Client(
    id: j['id'] as String? ?? '',
    name: j['name'] as String? ?? '',
    company: j['company'] as String? ?? '',
    email: j['email'] as String? ?? '',
    phone: j['phone'] as String? ?? '',
    address: j['address'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'company': company,
    'email': email, 'phone': phone, 'address': address,
  };

  Client copyWith({
    String? name, String? company, String? email,
    String? phone, String? address,
  }) => Client(
    id: id,
    name: name ?? this.name,
    company: company ?? this.company,
    email: email ?? this.email,
    phone: phone ?? this.phone,
    address: address ?? this.address,
  );
}

class Product {
  final String id;
  String name;
  String description;
  double unitPrice;
  String unit;

  Product({
    required this.id,
    required this.name,
    this.description = '',
    required this.unitPrice,
    this.unit = 'pcs',
  });

  factory Product.fromJson(Map<String, dynamic> j) {
    try {
      return Product(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        description: j['description'] as String? ?? '',
        unitPrice: _parseDouble(j['unitPrice']),
        unit: j['unit'] as String? ?? 'pcs',
      );
    } catch (e) {
      print('Error parsing Product from JSON: $e, data: $j');
      return Product(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? 'Unknown Product',
        description: '',
        unitPrice: 0.0,
        unit: 'pcs',
      );
    }
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    if (value is num) return value.toDouble();
    return 0.0;
  }

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'description': description,
    'unitPrice': unitPrice, 'unit': unit,
  };

  Product copyWith({String? name, String? description, double? unitPrice, String? unit}) =>
    Product(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      unitPrice: unitPrice ?? this.unitPrice,
      unit: unit ?? this.unit,
    );
}

class QuoteItem {
  String productId;
  String name;
  double qty;
  double unitPrice;
  String unit;
  /// Internal project-management details (paint code, colour, finish, ...).
  /// Saved with the quote and shown in project PDFs, never in the quote PDF.
  String description;

  QuoteItem({
    required this.productId,
    required this.name,
    required this.qty,
    required this.unitPrice,
    this.unit = 'pcs',
    this.description = '',
  });

  double get total => qty * unitPrice;

  factory QuoteItem.fromJson(Map<String, dynamic> j) => QuoteItem(
    productId: j['productId'] as String? ?? '',
    name: j['name'] as String? ?? '',
    qty: (j['qty'] as num?)?.toDouble() ?? 1.0,
    unitPrice: (j['unitPrice'] as num?)?.toDouble() ?? 0.0,
    unit: j['unit'] as String? ?? 'pcs',
    description: j['description'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'productId': productId, 'name': name,
    'qty': qty, 'unitPrice': unitPrice, 'unit': unit,
    if (description.isNotEmpty) 'description': description,
  };
}

class QuoteCategory {
  String id;
  String name;
  String labourInput;
  bool showSubtotals;
  List<QuoteItem> items;

  QuoteCategory({
    required this.id,
    required this.name,
    this.labourInput = '',
    this.showSubtotals = true,
    required this.items,
  });

  double get subtotal => items.fold(0, (sum, i) => sum + i.total);

  double get labourCost {
    final str = labourInput.trim();
    if (str.isEmpty) return 0.0;
    if (str.endsWith('%')) {
      final val = double.tryParse(str.substring(0, str.length - 1));
      if (val != null) return subtotal * (val / 100);
    }
    if (str.contains('/')) {
      final parts = str.split('/');
      if (parts.length == 2) {
        final num = double.tryParse(parts[0]);
        final den = double.tryParse(parts[1]);
        if (num != null && den != null && den != 0) return subtotal * (num / den);
      }
    }
    final val = double.tryParse(str);
    if (val != null) {
      if (val > 0 && val < 1.0) return subtotal * val;
      return val;
    }
    return 0.0;
  }

  factory QuoteCategory.fromJson(Map<String, dynamic> j) => QuoteCategory(
    id: j['id'] as String? ?? '',
    name: j['name'] as String? ?? '',
    labourInput: j['labourInput'] as String? ?? '',
    showSubtotals: j['showSubtotals'] as bool? ?? true,
    items: (j['items'] as List<dynamic>? ?? [])
        .map((e) => QuoteItem.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'labourInput': labourInput,
    'showSubtotals': showSubtotals,
    'items': items.map((i) => i.toJson()).toList(),
  };
}

class Quote {
  final String id;
  String clientId;
  String clientName;
  List<QuoteCategory> categories;
  QuoteStatus status;
  DateTime date;
  DateTime expiryDate;
  String notes;
  bool isPinned;
  String labourInput;
  double vatPercent;
  String? projectId;
  String? projectName;
  // Signature / sharing
  String? signatureData;  // base64 PNG
  DateTime? signedAt;
  String? shareToken;     // unique share UUID
  SignerInfo? signerInfo; // signer identity + device evidence

  Quote({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.categories,
    this.status = QuoteStatus.draft,
    required this.date,
    required this.expiryDate,
    this.notes = '',
    this.isPinned = false,
    this.labourInput = '',
    this.vatPercent = 0.0,
    this.projectId,
    this.projectName,
    this.signatureData,
    this.signedAt,
    this.shareToken,
    this.signerInfo,
  });

  double get subtotal => categories.fold(0, (sum, cat) => sum + cat.subtotal);
  double get categoryLabourCost => categories.fold(0, (sum, cat) => sum + cat.labourCost);

  double get labourCost {
    final str = labourInput.trim();
    if (str.isEmpty) return 0.0;
    if (str.endsWith('%')) {
      final val = double.tryParse(str.substring(0, str.length - 1));
      if (val != null) return subtotal * (val / 100);
    }
    if (str.contains('/')) {
      final parts = str.split('/');
      if (parts.length == 2) {
        final num = double.tryParse(parts[0]);
        final den = double.tryParse(parts[1]);
        if (num != null && den != null && den != 0) return subtotal * (num / den);
      }
    }
    final val = double.tryParse(str);
    if (val != null) {
      if (val > 0 && val < 1.0) return (subtotal + categoryLabourCost) * val;
      return val;
    }
    return 0.0;
  }

  double get tax => (subtotal + categoryLabourCost + labourCost) * vatPercent / 100;
  double get total => subtotal + categoryLabourCost + labourCost + tax;

  factory Quote.fromJson(Map<String, dynamic> j) => Quote(
    id: j['id'] as String? ?? '',
    clientId: j['clientId'] as String? ?? '',
    clientName: j['clientName'] as String? ?? '',
    status: QuoteStatus.values.firstWhere(
      (s) => s.name == j['status'],
      orElse: () => QuoteStatus.draft,
    ),
    date: DateTime.tryParse(j['date'] as String? ?? '') ?? DateTime.now(),
    expiryDate: DateTime.tryParse(j['expiryDate'] as String? ?? '') ?? DateTime.now(),
    notes: j['notes'] as String? ?? '',
    isPinned: j['isPinned'] as bool? ?? false,
    labourInput: j['labourInput'] as String? ?? '',
    vatPercent: (j['vatPercent'] as num?)?.toDouble() ?? 0.0,
    projectId: j['projectId'] as String?,
    projectName: j['projectName'] as String?,
    signatureData: j['signatureData'] as String?,
    signedAt: j['signedAt'] != null ? DateTime.tryParse(j['signedAt'] as String) : null,
    shareToken: j['shareToken'] as String?,
    signerInfo: j['signerInfo'] is Map ? SignerInfo.fromJson(Map<String, dynamic>.from(j['signerInfo'] as Map)) : null,
    categories: (j['categories'] as List<dynamic>? ?? [])
        .map((e) => QuoteCategory.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'clientId': clientId, 'clientName': clientName,
    'status': status.name,
    'date': date.toIso8601String(),
    'expiryDate': expiryDate.toIso8601String(),
    'notes': notes, 'isPinned': isPinned, 'labourInput': labourInput,
    'vatPercent': vatPercent,
    if (projectId != null) 'projectId': projectId,
    if (projectName != null) 'projectName': projectName,
    if (signatureData != null) 'signatureData': signatureData,
    if (signedAt != null) 'signedAt': signedAt!.toIso8601String(),
    if (shareToken != null) 'shareToken': shareToken,
    if (signerInfo != null) 'signerInfo': signerInfo!.toJson(),
    'categories': categories.map((c) => c.toJson()).toList(),
  };
}

class Invoice {
  final String id;
  String quoteId;
  String clientId;
  String clientName;
  List<QuoteCategory> categories;
  double amount;
  InvoiceStatus status;
  DateTime date;
  DateTime dueDate;
  String notes;
  String labourInput;
  String kraPin;
  String? projectId;
  String? projectName;
  // Signature / sharing
  String? signatureData;  // base64 PNG
  DateTime? signedAt;
  String? shareToken;     // unique share UUID
  SignerInfo? signerInfo; // signer identity + device evidence

  Invoice({
    required this.id,
    required this.quoteId,
    required this.clientId,
    required this.clientName,
    required this.categories,
    required this.amount,
    this.status = InvoiceStatus.draft,
    required this.date,
    required this.dueDate,
    this.notes = '',
    this.labourInput = '',
    this.kraPin = '',
    this.projectId,
    this.projectName,
    this.signatureData,
    this.signedAt,
    this.shareToken,
    this.signerInfo,
  });

  double get subtotal => categories.fold(0, (sum, cat) => sum + cat.subtotal);
  double get categoryLabourCost => categories.fold(0, (sum, cat) => sum + cat.labourCost);

  double get labourCost {
    final str = labourInput.trim();
    if (str.isEmpty) return 0.0;
    if (str.endsWith('%')) {
      final val = double.tryParse(str.substring(0, str.length - 1));
      if (val != null) return subtotal * (val / 100);
    }
    if (str.contains('/')) {
      final parts = str.split('/');
      if (parts.length == 2) {
        final num = double.tryParse(parts[0]);
        final den = double.tryParse(parts[1]);
        if (num != null && den != null && den != 0) return subtotal * (num / den);
      }
    }
    final val = double.tryParse(str);
    if (val != null) {
      if (val > 0 && val < 1.0) return (subtotal + categoryLabourCost) * val;
      return val;
    }
    return 0.0;
  }

  double get tax => (subtotal + categoryLabourCost + labourCost) * 0.16;
  double get total => subtotal + categoryLabourCost + labourCost + tax;

  factory Invoice.fromJson(Map<String, dynamic> j) {
    try {
      return Invoice(
        id: j['id'] as String? ?? '',
        quoteId: j['quoteId'] as String? ?? '',
        clientId: j['clientId'] as String? ?? '',
        clientName: j['clientName'] as String? ?? '',
        amount: _parseDouble(j['amount']),
        status: InvoiceStatus.values.firstWhere(
          (s) => s.name == j['status'],
          orElse: () => InvoiceStatus.draft,
        ),
        date: DateTime.tryParse(j['date'] as String? ?? '') ?? DateTime.now(),
        dueDate: DateTime.tryParse(j['dueDate'] as String? ?? '') ?? DateTime.now(),
        notes: j['notes'] as String? ?? '',
        labourInput: j['labourInput'] as String? ?? '',
        kraPin: j['kraPin'] as String? ?? '',
        projectId: j['projectId'] as String?,
        projectName: j['projectName'] as String?,
        signatureData: j['signatureData'] as String?,
        signedAt: j['signedAt'] != null ? DateTime.tryParse(j['signedAt'] as String) : null,
        shareToken: j['shareToken'] as String?,
    signerInfo: j['signerInfo'] is Map ? SignerInfo.fromJson(Map<String, dynamic>.from(j['signerInfo'] as Map)) : null,
        categories: (j['categories'] as List<dynamic>? ?? [])
            .map((e) => QuoteCategory.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    } catch (e) {
      print('Error parsing Invoice from JSON: $e, data: $j');
      // Fallback for old invoices without categories
      return Invoice(
        id: j['id'] as String? ?? '',
        quoteId: j['quoteId'] as String? ?? '',
        clientId: j['clientId'] as String? ?? '',
        clientName: j['clientName'] as String? ?? '',
        amount: _parseDouble(j['amount']),
        status: InvoiceStatus.values.firstWhere(
          (s) => s.name == j['status'],
          orElse: () => InvoiceStatus.draft,
        ),
        date: DateTime.tryParse(j['date'] as String? ?? '') ?? DateTime.now(),
        dueDate: DateTime.tryParse(j['dueDate'] as String? ?? '') ?? DateTime.now(),
        notes: j['notes'] as String? ?? '',
        labourInput: j['labourInput'] as String? ?? '',
        kraPin: j['kraPin'] as String? ?? '',
        projectId: j['projectId'] as String?,
        projectName: j['projectName'] as String?,
        categories: [],
      );
    }
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    if (value is num) return value.toDouble();
    return 0.0;
  }

  Map<String, dynamic> toJson() => {
    'id': id, 'quoteId': quoteId, 'clientId': clientId,
    'clientName': clientName, 'amount': amount,
    'status': status.name,
    'date': date.toIso8601String(),
    'dueDate': dueDate.toIso8601String(),
    'notes': notes, 'labourInput': labourInput,
    'kraPin': kraPin,
    if (projectId != null) 'projectId': projectId,
    if (projectName != null) 'projectName': projectName,
    if (signatureData != null) 'signatureData': signatureData,
    if (signedAt != null) 'signedAt': signedAt!.toIso8601String(),
    if (shareToken != null) 'shareToken': shareToken,
    if (signerInfo != null) 'signerInfo': signerInfo!.toJson(),
    'categories': categories.map((c) => c.toJson()).toList(),
  };
}

// ── Notification Model ────────────────────────────────────────────────────────

class AppNotification {
  final String id;
  final String title;
  final String body;
  final DateTime timestamp;
  bool isRead;
  final IconData icon;
  final Color color;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    this.isRead = false,
    required this.icon,
    required this.color,
  });
}

// ── Signer evidence ───────────────────────────────────────────────────────────

class SignerInfo {
  String name;
  String phone;
  String email;
  String method;      // 'In-app' or 'Web link'
  String deviceModel;
  String platform;
  String osVersion;
  String userAgent;
  String ipAddress;
  String appVersion;
  String timezone;
  String docHash;     // SHA-256 of the document content at signing time
  DateTime capturedAt;

  SignerInfo({
    required this.name,
    required this.phone,
    this.email = '',
    this.method = 'In-app',
    this.deviceModel = '',
    this.platform = '',
    this.osVersion = '',
    this.userAgent = '',
    this.ipAddress = '',
    this.appVersion = '',
    this.timezone = '',
    this.docHash = '',
    DateTime? capturedAt,
  }) : capturedAt = capturedAt ?? DateTime.now();

  factory SignerInfo.fromJson(Map<String, dynamic> j) => SignerInfo(
    name: j['name']?.toString() ?? '',
    phone: j['phone']?.toString() ?? '',
    email: j['email']?.toString() ?? '',
    method: j['method']?.toString() ?? 'In-app',
    deviceModel: j['deviceModel']?.toString() ?? '',
    platform: j['platform']?.toString() ?? '',
    osVersion: j['osVersion']?.toString() ?? '',
    userAgent: j['userAgent']?.toString() ?? '',
    ipAddress: j['ipAddress']?.toString() ?? '',
    appVersion: j['appVersion']?.toString() ?? '',
    timezone: j['timezone']?.toString() ?? '',
    docHash: j['docHash']?.toString() ?? '',
    capturedAt: DateTime.tryParse(j['capturedAt']?.toString() ?? ''),
  );

  Map<String, dynamic> toJson() => {
    'name': name, 'phone': phone, 'email': email, 'method': method,
    'deviceModel': deviceModel, 'platform': platform, 'osVersion': osVersion,
    'userAgent': userAgent, 'ipAddress': ipAddress, 'appVersion': appVersion,
    'timezone': timezone, 'docHash': docHash, 'capturedAt': capturedAt.toIso8601String(),
  };

  /// Label/value pairs for the signature certificate, skipping empty values.
  List<MapEntry<String, String>> get evidenceRows => [
    MapEntry('Signer name', name),
    MapEntry('Phone number', phone),
    MapEntry('Email', email),
    MapEntry('Signing method', method),
    MapEntry('Device', deviceModel),
    MapEntry('Platform / OS', [platform, osVersion].where((s) => s.isNotEmpty).join(' ')),
    MapEntry('Browser', userAgent),
    MapEntry('IP address', ipAddress),
    MapEntry('Time zone', timezone),
    MapEntry('App version', appVersion),
    MapEntry('Captured at (UTC)', capturedAt.toUtc().toIso8601String()),
    MapEntry('Document SHA-256', docHash),
  ].where((e) => e.value.trim().isNotEmpty).toList();
}

// ── Activity Log ──────────────────────────────────────────────────────────────

enum ActivityType { quote, invoice, client, product, project, task, event, signature, payment }

extension ActivityTypeX on ActivityType {
  Color get color => switch (this) {
    ActivityType.quote     => const Color(0xFF3B82F6),
    ActivityType.invoice   => const Color(0xFF8B5CF6),
    ActivityType.client    => const Color(0xFFFFC107),
    ActivityType.product   => const Color(0xFF10B981),
    ActivityType.project   => const Color(0xFFF97316),
    ActivityType.task      => const Color(0xFF06B6D4),
    ActivityType.event     => const Color(0xFFEC4899),
    ActivityType.signature => const Color(0xFF22C55E),
    ActivityType.payment   => const Color(0xFF14B8A6),
  };
  IconData get icon => switch (this) {
    ActivityType.quote     => Icons.request_quote_outlined,
    ActivityType.invoice   => Icons.receipt_long_outlined,
    ActivityType.client    => Icons.person_add_alt_1_outlined,
    ActivityType.product   => Icons.inventory_2_outlined,
    ActivityType.project   => Icons.work_outline_rounded,
    ActivityType.task      => Icons.task_alt_rounded,
    ActivityType.event     => Icons.event_outlined,
    ActivityType.signature => Icons.draw_outlined,
    ActivityType.payment   => Icons.payments_outlined,
  };
}

class ActivityEntry {
  final String id;
  final String title;
  final ActivityType type;
  final DateTime timestamp;

  ActivityEntry({required this.id, required this.title, required this.type, required this.timestamp});

  factory ActivityEntry.fromJson(Map<String, dynamic> j) => ActivityEntry(
    id: j['id'] as String? ?? '',
    title: j['title'] as String? ?? '',
    type: ActivityType.values.firstWhere((t) => t.name == j['type'], orElse: () => ActivityType.quote),
    timestamp: DateTime.tryParse(j['timestamp'] as String? ?? '') ?? DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'title': title, 'type': type.name, 'timestamp': timestamp.toIso8601String(),
  };
}

// ── Task Models ───────────────────────────────────────────────────────────────

enum TaskPriority { low, medium, high }

enum TaskStatus { todo, inProgress, done }

extension TaskPriorityExt on TaskPriority {
  String get label {
    switch (this) {
      case TaskPriority.low:    return 'Low';
      case TaskPriority.medium: return 'Medium';
      case TaskPriority.high:   return 'High';
    }
  }

  Color get color {
    switch (this) {
      case TaskPriority.low:    return Colors.teal;
      case TaskPriority.medium: return Colors.orange;
      case TaskPriority.high:   return Colors.redAccent;
    }
  }

  IconData get icon {
    switch (this) {
      case TaskPriority.low:    return Icons.arrow_downward;
      case TaskPriority.medium: return Icons.remove;
      case TaskPriority.high:   return Icons.arrow_upward;
    }
  }
}

extension TaskStatusExt on TaskStatus {
  String get label {
    switch (this) {
      case TaskStatus.todo:       return 'To Do';
      case TaskStatus.inProgress: return 'In Progress';
      case TaskStatus.done:       return 'Done';
    }
  }

  Color get color {
    switch (this) {
      case TaskStatus.todo:       return Colors.grey;
      case TaskStatus.inProgress: return Colors.blue;
      case TaskStatus.done:       return Colors.green;
    }
  }
}

class AppTask {
  final String id;
  String title;
  String description;
  TaskPriority priority;
  TaskStatus status;
  DateTime dueDate;
  String? linkedQuoteId;
  String? projectId;
  bool alarmEnabled;

  AppTask({
    required this.id,
    required this.title,
    this.description = '',
    this.priority = TaskPriority.medium,
    this.status = TaskStatus.todo,
    required this.dueDate,
    this.linkedQuoteId,
    this.projectId,
    this.alarmEnabled = false,
  });

  factory AppTask.fromJson(Map<String, dynamic> j) => AppTask(
    id: j['id'] as String? ?? '',
    title: j['title'] as String? ?? '',
    description: j['description'] as String? ?? '',
    priority: TaskPriority.values.firstWhere(
      (p) => p.name == j['priority'],
      orElse: () => TaskPriority.medium,
    ),
    status: TaskStatus.values.firstWhere(
      (s) => s.name == j['status'],
      orElse: () => TaskStatus.todo,
    ),
    dueDate: DateTime.tryParse(j['dueDate'] as String? ?? '') ?? DateTime.now(),
    linkedQuoteId: j['linkedQuoteId'] as String?,
    projectId: j['projectId'] as String?,
    alarmEnabled: j['alarmEnabled'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'title': title, 'description': description,
    'priority': priority.name, 'status': status.name,
    'dueDate': dueDate.toIso8601String(),
    'alarmEnabled': alarmEnabled,
    if (linkedQuoteId != null) 'linkedQuoteId': linkedQuoteId,
    if (projectId != null) 'projectId': projectId,
  };
}

// ── Event Model ───────────────────────────────────────────────────────────────

class AppEvent {
  final String id;
  String title;
  String description;
  DateTime startTime;
  DateTime endTime;
  Color color;
  bool alarmEnabled;

  AppEvent({
    required this.id,
    required this.title,
    this.description = '',
    required this.startTime,
    required this.endTime,
    this.color = Colors.blue,
    this.alarmEnabled = false,
  });

  factory AppEvent.fromJson(Map<String, dynamic> j) => AppEvent(
    id: j['id'] as String? ?? '',
    title: j['title'] as String? ?? '',
    description: j['description'] as String? ?? '',
    startTime: DateTime.tryParse(j['startTime'] as String? ?? '') ?? DateTime.now(),
    endTime: DateTime.tryParse(j['endTime'] as String? ?? '') ?? DateTime.now(),
    color: Color(j['color'] as int? ?? Colors.blue.toARGB32()),
    alarmEnabled: j['alarmEnabled'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'title': title, 'description': description,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime.toIso8601String(),
    'color': color.toARGB32(),
    'alarmEnabled': alarmEnabled,
  };
}

// ── Project & QuickBook Models ────────────────────────────────────────────────

enum ProjectStatus { planning, inProgress, onHold, completed, cancelled }

extension ProjectStatusExt on ProjectStatus {
  String get label {
    switch (this) {
      case ProjectStatus.planning:   return 'Planning';
      case ProjectStatus.inProgress: return 'In Progress';
      case ProjectStatus.onHold:     return 'On Hold';
      case ProjectStatus.completed:  return 'Completed';
      case ProjectStatus.cancelled:  return 'Cancelled';
    }
  }

  Color get color {
    switch (this) {
      case ProjectStatus.planning:   return const Color(0xFF818CF8); // Indigo / Violet
      case ProjectStatus.inProgress: return const Color(0xFF38BDF8); // Sky Blue
      case ProjectStatus.onHold:     return const Color(0xFFFBBF24); // Amber
      case ProjectStatus.completed:  return const Color(0xFF34D399); // Emerald Green
      case ProjectStatus.cancelled:  return const Color(0xFFF87171); // Rose Red
    }
  }

  IconData get icon {
    switch (this) {
      case ProjectStatus.planning:   return Icons.architecture_rounded;
      case ProjectStatus.inProgress: return Icons.construction_rounded;
      case ProjectStatus.onHold:     return Icons.pause_circle_outline_rounded;
      case ProjectStatus.completed:  return Icons.check_circle_rounded;
      case ProjectStatus.cancelled:  return Icons.cancel_outlined;
    }
  }
}

class ProjectNote {
  final String id;
  String text;
  /// Base64-encoded JPEG photos attached to the note.
  List<String> images;
  DateTime createdAt;

  ProjectNote({required this.id, this.text = '', List<String>? images, DateTime? createdAt})
      : images = images ?? [],
        createdAt = createdAt ?? DateTime.now();

  factory ProjectNote.fromJson(Map<String, dynamic> j) => ProjectNote(
    id: j['id'] as String? ?? '',
    text: j['text'] as String? ?? '',
    images: (j['images'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
    createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'text': text, 'images': images, 'createdAt': createdAt.toIso8601String(),
  };
}

class ProjectExpense {
  final String id;
  String projectId;
  String title;
  String category; // Materials, Labor, Transport, Tools, Subcontractor, Other
  double quantity;
  String unit;
  double unitPrice;
  double amount;
  String supplier;
  String receiptNo;
  DateTime date;
  String paymentMethod; // M-Pesa, Cash, Bank Transfer, Credit
  String notes;

  ProjectExpense({
    required this.id,
    required this.projectId,
    required this.title,
    this.category = 'Materials',
    this.quantity = 1.0,
    this.unit = 'pcs',
    this.unitPrice = 0.0,
    required this.amount,
    this.supplier = '',
    this.receiptNo = '',
    required this.date,
    this.paymentMethod = 'M-Pesa',
    this.notes = '',
  });

  factory ProjectExpense.fromJson(Map<String, dynamic> j) {
    final qty = (j['quantity'] as num?)?.toDouble() ?? 1.0;
    final up = (j['unitPrice'] as num?)?.toDouble() ?? 0.0;
    final parsedAmount = (j['amount'] as num?)?.toDouble() ?? (qty * up);

    return ProjectExpense(
      id: j['id'] as String? ?? '',
      projectId: j['projectId'] as String? ?? '',
      title: j['title'] as String? ?? '',
      category: j['category'] as String? ?? 'Materials',
      quantity: qty,
      unit: j['unit'] as String? ?? 'pcs',
      unitPrice: up,
      amount: parsedAmount,
      supplier: j['supplier'] as String? ?? '',
      receiptNo: j['receiptNo'] as String? ?? '',
      date: DateTime.tryParse(j['date'] as String? ?? '') ?? DateTime.now(),
      paymentMethod: j['paymentMethod'] as String? ?? 'M-Pesa',
      notes: j['notes'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'projectId': projectId,
    'title': title,
    'category': category,
    'quantity': quantity,
    'unit': unit,
    'unitPrice': unitPrice,
    'amount': amount,
    'supplier': supplier,
    'receiptNo': receiptNo,
    'date': date.toIso8601String(),
    'paymentMethod': paymentMethod,
    'notes': notes,
  };

  ProjectExpense copyWith({
    String? title,
    String? category,
    double? quantity,
    String? unit,
    double? unitPrice,
    double? amount,
    String? supplier,
    String? receiptNo,
    DateTime? date,
    String? paymentMethod,
    String? notes,
  }) => ProjectExpense(
    id: id,
    projectId: projectId,
    title: title ?? this.title,
    category: category ?? this.category,
    quantity: quantity ?? this.quantity,
    unit: unit ?? this.unit,
    unitPrice: unitPrice ?? this.unitPrice,
    amount: amount ?? this.amount,
    supplier: supplier ?? this.supplier,
    receiptNo: receiptNo ?? this.receiptNo,
    date: date ?? this.date,
    paymentMethod: paymentMethod ?? this.paymentMethod,
    notes: notes ?? this.notes,
  );
}

class ProjectPayment {
  final String id;
  String projectId;
  String? invoiceId;
  double amount;
  DateTime date;
  String paymentMethod; // M-Pesa, Cash, Bank Transfer, Cheque
  String reference;
  String notes;

  ProjectPayment({
    required this.id,
    required this.projectId,
    this.invoiceId,
    required this.amount,
    required this.date,
    this.paymentMethod = 'M-Pesa',
    this.reference = '',
    this.notes = '',
  });

  factory ProjectPayment.fromJson(Map<String, dynamic> j) => ProjectPayment(
    id: j['id'] as String? ?? '',
    projectId: j['projectId'] as String? ?? '',
    invoiceId: j['invoiceId'] as String?,
    amount: (j['amount'] as num?)?.toDouble() ?? 0.0,
    date: DateTime.tryParse(j['date'] as String? ?? '') ?? DateTime.now(),
    paymentMethod: j['paymentMethod'] as String? ?? 'M-Pesa',
    reference: j['reference'] as String? ?? '',
    notes: j['notes'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'projectId': projectId,
    if (invoiceId != null) 'invoiceId': invoiceId,
    'amount': amount,
    'date': date.toIso8601String(),
    'paymentMethod': paymentMethod,
    'reference': reference,
    'notes': notes,
  };
}

class Project {
  final String id;
  String name;
  String clientId;
  String clientName;
  ProjectStatus status;
  DateTime startDate;
  DateTime? deadline;
  double budget;
  String description;
  String location;
  List<String> quoteIds;
  List<String> invoiceIds;
  List<ProjectExpense> expenses;
  List<ProjectPayment> payments;
  /// Base64-encoded JPEG photos shown with the project summary.
  List<String> summaryImages;
  List<ProjectNote> notes;
  DateTime createdAt;
  DateTime updatedAt;

  Project({
    required this.id,
    required this.name,
    required this.clientId,
    required this.clientName,
    this.status = ProjectStatus.planning,
    required this.startDate,
    this.deadline,
    this.budget = 0.0,
    this.description = '',
    this.location = '',
    List<String>? quoteIds,
    List<String>? invoiceIds,
    List<ProjectExpense>? expenses,
    List<ProjectPayment>? payments,
    List<String>? summaryImages,
    List<ProjectNote>? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : quoteIds = quoteIds ?? [],
        invoiceIds = invoiceIds ?? [],
        expenses = expenses ?? [],
        payments = payments ?? [],
        summaryImages = summaryImages ?? [],
        notes = notes ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  // Financial calculations
  double get totalExpenses => expenses.fold(0.0, (s, e) => s + e.amount);
  double get totalPaymentsReceived => payments.fold(0.0, (s, p) => s + p.amount);

  double totalQuoted(List<Quote> allQuotes) {
    return allQuotes
        .where((q) => quoteIds.contains(q.id) || q.projectId == id)
        .fold(0.0, (s, q) => s + q.total);
  }

  double totalInvoiced(List<Invoice> allInvoices) {
    return allInvoices
        .where((i) => invoiceIds.contains(i.id) || i.projectId == id)
        .fold(0.0, (s, i) => s + i.total);
  }

  double totalInvoicedPaid(List<Invoice> allInvoices) {
    return allInvoices
        .where((i) => (invoiceIds.contains(i.id) || i.projectId == id) && i.status == InvoiceStatus.paid)
        .fold(0.0, (s, i) => s + i.total);
  }

  /// Outstanding balance due from client based on invoices (or quotations if un-invoiced)
  double outstandingBalance(List<Invoice> allInvoices, [List<Quote>? allQuotes]) {
    final invoiced = totalInvoiced(allInvoices);
    if (invoiced > 0) {
      return (invoiced - totalPaymentsReceived).clamp(0.0, double.infinity);
    }
    if (allQuotes != null) {
      final quoted = totalQuoted(allQuotes);
      return (quoted - totalPaymentsReceived).clamp(0.0, double.infinity);
    }
    return 0.0;
  }

  /// Realized net profit = Cash received - Total expenses
  double netProfitRealized() => totalPaymentsReceived - totalExpenses;

  /// Projected net profit = Total Invoiced (or Quoted) - Total expenses
  double netProfitProjected(List<Invoice> allInvoices, [List<Quote>? allQuotes]) {
    final revenue = totalInvoiced(allInvoices);
    if (revenue > 0) return revenue - totalExpenses;
    if (allQuotes != null) {
      final quoted = totalQuoted(allQuotes);
      if (quoted > 0) return quoted - totalExpenses;
    }
    return budget > 0 ? (budget - totalExpenses) : -totalExpenses;
  }

  /// Profit margin percentage based on payments received (or projected revenue)
  double profitMarginRealized() {
    if (totalPaymentsReceived <= 0) return 0.0;
    return (netProfitRealized() / totalPaymentsReceived) * 100;
  }

  double profitMarginProjected(List<Invoice> allInvoices, [List<Quote>? allQuotes]) {
    final rev = totalInvoiced(allInvoices);
    if (rev > 0) {
      return (netProfitProjected(allInvoices, allQuotes) / rev) * 100;
    }
    if (allQuotes != null) {
      final qRev = totalQuoted(allQuotes);
      if (qRev > 0) return (netProfitProjected(allInvoices, allQuotes) / qRev) * 100;
    }
    return 0.0;
  }

  factory Project.fromJson(Map<String, dynamic> j) => Project(
    id: j['id'] as String? ?? '',
    name: j['name'] as String? ?? '',
    clientId: j['clientId'] as String? ?? '',
    clientName: j['clientName'] as String? ?? '',
    status: ProjectStatus.values.firstWhere(
      (s) => s.name == j['status'],
      orElse: () => ProjectStatus.planning,
    ),
    startDate: DateTime.tryParse(j['startDate'] as String? ?? '') ?? DateTime.now(),
    deadline: j['deadline'] != null ? DateTime.tryParse(j['deadline'] as String) : null,
    budget: (j['budget'] as num?)?.toDouble() ?? 0.0,
    description: j['description'] as String? ?? '',
    location: j['location'] as String? ?? '',
    quoteIds: (j['quoteIds'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
    invoiceIds: (j['invoiceIds'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
    expenses: (j['expenses'] as List<dynamic>? ?? [])
        .map((e) => ProjectExpense.fromJson(e as Map<String, dynamic>))
        .toList(),
    payments: (j['payments'] as List<dynamic>? ?? [])
        .map((e) => ProjectPayment.fromJson(e as Map<String, dynamic>))
        .toList(),
    summaryImages: (j['summaryImages'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
    notes: (j['notes'] as List<dynamic>? ?? [])
        .map((e) => ProjectNote.fromJson(e as Map<String, dynamic>))
        .toList(),
    createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
    updatedAt: DateTime.tryParse(j['updatedAt'] as String? ?? '') ?? DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'clientId': clientId,
    'clientName': clientName,
    'status': status.name,
    'startDate': startDate.toIso8601String(),
    if (deadline != null) 'deadline': deadline!.toIso8601String(),
    'budget': budget,
    'description': description,
    'location': location,
    'quoteIds': quoteIds,
    'invoiceIds': invoiceIds,
    'expenses': expenses.map((e) => e.toJson()).toList(),
    'payments': payments.map((p) => p.toJson()).toList(),
    'summaryImages': summaryImages,
    'notes': notes.map((n) => n.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  Project copyWith({
    String? name,
    String? clientId,
    String? clientName,
    ProjectStatus? status,
    DateTime? startDate,
    DateTime? deadline,
    double? budget,
    String? description,
    String? location,
    List<String>? quoteIds,
    List<String>? invoiceIds,
    List<ProjectExpense>? expenses,
    List<ProjectPayment>? payments,
    List<String>? summaryImages,
    List<ProjectNote>? notes,
  }) => Project(
    id: id,
    name: name ?? this.name,
    clientId: clientId ?? this.clientId,
    clientName: clientName ?? this.clientName,
    status: status ?? this.status,
    startDate: startDate ?? this.startDate,
    deadline: deadline ?? this.deadline,
    budget: budget ?? this.budget,
    description: description ?? this.description,
    location: location ?? this.location,
    quoteIds: quoteIds ?? List.from(this.quoteIds),
    invoiceIds: invoiceIds ?? List.from(this.invoiceIds),
    expenses: expenses ?? List.from(this.expenses),
    payments: payments ?? List.from(this.payments),
    summaryImages: summaryImages ?? List.from(this.summaryImages),
    notes: notes ?? List.from(this.notes),
    createdAt: createdAt,
    updatedAt: DateTime.now(),
  );
}
