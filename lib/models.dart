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

// ── Signature Verification Metadata ───────────────────────────────────────────

/// Evidence captured at signing time: who signed, from which device/build and
/// where. Persisted with the document and printed on the signed PDF certificate.
class SignatureMetadata {
  final String? signerName;
  final String? signerPhone;
  final String? device;
  final String? appVersion;
  final String? location;

  const SignatureMetadata({
    this.signerName,
    this.signerPhone,
    this.device,
    this.appVersion,
    this.location,
  });

  /// Label/value rows for display, skipping anything that wasn't captured.
  List<MapEntry<String, String>> get rows => [
        if (signerName != null && signerName!.isNotEmpty)
          MapEntry('Signed by', signerName!),
        if (signerPhone != null && signerPhone!.isNotEmpty)
          MapEntry('WhatsApp Number', signerPhone!),
        if (device != null && device!.isNotEmpty) MapEntry('Device', device!),
        if (appVersion != null && appVersion!.isNotEmpty)
          MapEntry('App build', appVersion!),
        if (location != null && location!.isNotEmpty)
          MapEntry('Location', location!),
      ];
}

// ── Models ─────────────────────────────────────────────────────────────────────

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
  /// Internal working detail (e.g. paint code / colour, spec notes). Saved with
  /// the document and printed on the project PDF, but never on the client quote.
  String description;
  double qty;
  double unitPrice;
  String unit;

  QuoteItem({
    required this.productId,
    required this.name,
    this.description = '',
    required this.qty,
    required this.unitPrice,
    this.unit = 'pcs',
  });

  double get total => qty * unitPrice;

  factory QuoteItem.fromJson(Map<String, dynamic> j) => QuoteItem(
    productId: j['productId'] as String? ?? '',
    name: j['name'] as String? ?? '',
    description: j['description'] as String? ?? '',
    qty: (j['qty'] as num?)?.toDouble() ?? 1.0,
    unitPrice: (j['unitPrice'] as num?)?.toDouble() ?? 0.0,
    unit: j['unit'] as String? ?? 'pcs',
  );

  Map<String, dynamic> toJson() => {
    'productId': productId, 'name': name, 'description': description,
    'qty': qty, 'unitPrice': unitPrice, 'unit': unit,
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
  String? signerName;
  String? signerDevice;
  String? signerAppVersion;
  String? signerLocation;
  String? signerPhone;
  String? shareToken;     // unique share UUID

  SignatureMetadata get signerMetadata => SignatureMetadata(
        signerName: signerName,
        signerPhone: signerPhone,
        device: signerDevice,
        appVersion: signerAppVersion,
        location: signerLocation,
      );

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
    this.signerName,
    this.signerDevice,
    this.signerAppVersion,
    this.signerLocation,
    this.signerPhone,
    this.shareToken,
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
    signerName: j['signerName'] as String?,
    signerDevice: j['signerDevice'] as String?,
    signerAppVersion: j['signerAppVersion'] as String?,
    signerLocation: j['signerLocation'] as String?,
    signerPhone: j['signerPhone'] as String?,
    shareToken: j['shareToken'] as String?,
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
    if (signerName != null) 'signerName': signerName,
    if (signerDevice != null) 'signerDevice': signerDevice,
    if (signerAppVersion != null) 'signerAppVersion': signerAppVersion,
    if (signerLocation != null) 'signerLocation': signerLocation,
    if (signerPhone != null) 'signerPhone': signerPhone,
    if (shareToken != null) 'shareToken': shareToken,
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
  String? signerName;
  String? signerDevice;
  String? signerAppVersion;
  String? signerLocation;
  String? signerPhone;
  String? shareToken;     // unique share UUID

  SignatureMetadata get signerMetadata => SignatureMetadata(
        signerName: signerName,
        signerPhone: signerPhone,
        device: signerDevice,
        appVersion: signerAppVersion,
        location: signerLocation,
      );

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
    this.signerName,
    this.signerDevice,
    this.signerAppVersion,
    this.signerLocation,
    this.signerPhone,
    this.shareToken,
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
        signerName: j['signerName'] as String?,
    signerDevice: j['signerDevice'] as String?,
        signerAppVersion: j['signerAppVersion'] as String?,
        signerLocation: j['signerLocation'] as String?,
        signerPhone: j['signerPhone'] as String?,
        shareToken: j['shareToken'] as String?,
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
    if (signerName != null) 'signerName': signerName,
    if (signerDevice != null) 'signerDevice': signerDevice,
    if (signerAppVersion != null) 'signerAppVersion': signerAppVersion,
    if (signerLocation != null) 'signerLocation': signerLocation,
    if (signerPhone != null) 'signerPhone': signerPhone,
    if (shareToken != null) 'shareToken': shareToken,
    'categories': categories.map((c) => c.toJson()).toList(),
  };
}

// ── Notification Model ────────────────────────────────────────────────────────

/// Icons the in-app notification centre can persist. Flutter requires icon code
/// points to be compile-time constants, so entries are stored by key.
const Map<String, IconData> kNotificationIcons = {
  'alarm': Icons.alarm,
  'alarm_on': Icons.alarm_on,
  'bell': Icons.notifications_active,
  'bell_off': Icons.notifications_off,
  'task': Icons.task_alt,
  'start': Icons.play_circle_outline,
  'end': Icons.stop_circle_outlined,
  'box': Icons.inventory_2_outlined,
  'sign': Icons.draw,
};

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

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
    id: j['id'] as String? ?? '',
    title: j['title'] as String? ?? '',
    body: j['body'] as String? ?? '',
    timestamp: DateTime.tryParse(j['timestamp'] as String? ?? '') ?? DateTime.now(),
    isRead: j['isRead'] as bool? ?? false,
    icon: kNotificationIcons[j['icon'] as String? ?? 'bell'] ?? Icons.notifications_active,
    color: Color((j['color'] as num? ?? Colors.white.toARGB32()).toInt()),
  );

  static String _iconKey(IconData icon) {
    for (final entry in kNotificationIcons.entries) {
      if (entry.value.codePoint == icon.codePoint &&
          entry.value.fontFamily == icon.fontFamily) {
        return entry.key;
      }
    }
    return 'bell';
  }

  Map<String, dynamic> toJson() => {
    'id': id, 'title': title, 'body': body,
    'timestamp': timestamp.toIso8601String(),
    'isRead': isRead,
    'icon': _iconKey(icon),
    'color': color.toARGB32(),
  };
}

/// A single entry in the dashboard activity feed, derived from real app data.
class AppActivity {
  final String title;
  final DateTime time;
  final IconData icon;
  final Color color;

  AppActivity({
    required this.title,
    required this.time,
    required this.icon,
    required this.color,
  });
}

// ── Task Models ───────────────────────────────────────────────────────────────

/// Lead-time choices shared by every alarm dialog (minutes before the event).
const Map<int, String> kLeadOptions = {
  0: 'At the time',
  5: '5 minutes before',
  10: '10 minutes before',
  15: '15 minutes before',
  30: '30 minutes before',
  60: '1 hour before',
};

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
  /// Project this task belongs to, if any. Populated from the project page so
  /// project work can be tracked separately from general tasks.
  String? projectId;
  bool alarmEnabled;
  /// Minutes before [dueDate] that the reminder/alarm should also fire.
  /// 0 means "right at the due time".
  int reminderLeadMinutes;

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
    this.reminderLeadMinutes = 0,
  });

  /// When the device alarm/reminder actually fires.
  DateTime get alarmAt => dueDate.subtract(Duration(minutes: reminderLeadMinutes));

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
    reminderLeadMinutes: (j['reminderLeadMinutes'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'title': title, 'description': description,
    'priority': priority.name, 'status': status.name,
    'dueDate': dueDate.toIso8601String(),
    'alarmEnabled': alarmEnabled,
    'reminderLeadMinutes': reminderLeadMinutes,
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
  /// Minutes before [startTime] that the "starting soon" reminder fires.
  int reminderLeadMinutes;

  AppEvent({
    required this.id,
    required this.title,
    this.description = '',
    required this.startTime,
    required this.endTime,
    this.color = Colors.blue,
    this.alarmEnabled = false,
    this.reminderLeadMinutes = 15,
  });

  /// When the "starting soon" reminder fires.
  DateTime get alarmAt => startTime.subtract(Duration(minutes: reminderLeadMinutes));

  factory AppEvent.fromJson(Map<String, dynamic> j) => AppEvent(
    id: j['id'] as String? ?? '',
    title: j['title'] as String? ?? '',
    description: j['description'] as String? ?? '',
    startTime: DateTime.tryParse(j['startTime'] as String? ?? '') ?? DateTime.now(),
    endTime: DateTime.tryParse(j['endTime'] as String? ?? '') ?? DateTime.now(),
    color: Color(j['color'] as int? ?? Colors.blue.toARGB32()),
    alarmEnabled: j['alarmEnabled'] as bool? ?? false,
    reminderLeadMinutes: (j['reminderLeadMinutes'] as num?)?.toInt() ?? 15,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'title': title, 'description': description,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime.toIso8601String(),
    'color': color.toARGB32(),
    'alarmEnabled': alarmEnabled,
    'reminderLeadMinutes': reminderLeadMinutes,
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

/// One workflow card: a site note plus the photos stuck to it.
class ProjectNote {
  final String id;
  String text;
  List<String> images;
  DateTime createdAt;
  DateTime updatedAt;

  ProjectNote({
    required this.id,
    this.text = '',
    List<String>? images,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : images = images ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory ProjectNote.fromJson(Map<String, dynamic> j) => ProjectNote(
        id: j['id'] as String? ?? '',
        text: j['text'] as String? ?? '',
        images: (j['images'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
        updatedAt: DateTime.tryParse(j['updatedAt'] as String? ?? '') ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'images': images,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  ProjectNote copyWith({
    String? text,
    List<String>? images,
  }) =>
      ProjectNote(
        id: id,
        text: text ?? this.text,
        images: images ?? List.from(this.images),
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );
}

class Project {
  final String id;
  /// Sequential project number shown to the user (PRJ-001, PRJ-002, ...).
  /// 0 means a legacy record that has not been backfilled yet.
  int number;
  String name;
  String clientId;
  String clientName;
  ProjectStatus status;
  DateTime startDate;
  DateTime? deadline;
  double budget;
  String description;
  String notes;
  String location;
  List<String> quoteIds;
  List<String> invoiceIds;
  List<ProjectExpense> expenses;
  List<ProjectPayment> payments;
  List<String> summaryImages;
  List<String> noteImages;
  List<ProjectNote> workflowNotes;
  DateTime createdAt;
  DateTime updatedAt;
  DateTime? completedAt;

  Project({
    required this.id,
    this.number = 0,
    required this.name,
    required this.clientId,
    required this.clientName,
    this.status = ProjectStatus.planning,
    required this.startDate,
    this.deadline,
    this.budget = 0.0,
    this.description = '',
    this.notes = '',
    this.location = '',
    List<String>? quoteIds,
    List<String>? invoiceIds,
    List<ProjectExpense>? expenses,
    List<ProjectPayment>? payments,
    List<String>? summaryImages,
    List<String>? noteImages,
    List<ProjectNote>? workflowNotes,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.completedAt,
  })  : quoteIds = quoteIds ?? [],
        invoiceIds = invoiceIds ?? [],
        expenses = expenses ?? [],
        payments = payments ?? [],
        summaryImages = summaryImages ?? [],
        noteImages = noteImages ?? [],
        workflowNotes = workflowNotes ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  // Financial calculations
  double get totalExpenses => expenses.fold(0.0, (s, e) => s + e.amount);
  double get totalPaymentsReceived => payments.fold(0.0, (s, p) => s + p.amount);

  /// User-facing project number, e.g. "PRJ-004". Falls back to the raw id for
  /// legacy records until AppState backfills [number].
  String get numberLabel =>
      number > 0 ? 'PRJ-${number.toString().padLeft(3, '0')}' : id;

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

  factory Project.fromJson(Map<String, dynamic> j) {
    final noteImages = (j['noteImages'] as List<dynamic>? ?? []).map((e) => e.toString()).toList();
    final notes = j['notes'] as String? ?? '';
    var workflowNotes = (j['workflowNotes'] as List<dynamic>? ?? [])
        .map((e) => ProjectNote.fromJson(e as Map<String, dynamic>))
        .toList();
    // Older projects stored one notes blob + a photo strip. Fold them into a
    // single card so nothing is lost when opening the new workflow.
    if (workflowNotes.isEmpty && (notes.trim().isNotEmpty || noteImages.isNotEmpty)) {
      workflowNotes = [
        ProjectNote(
          id: 'legacy-${j['id'] ?? 'note'}',
          text: notes,
          images: List<String>.from(noteImages),
          createdAt: DateTime.tryParse(j['updatedAt'] as String? ?? '') ?? DateTime.now(),
        ),
      ];
    }
    return Project(
      id: j['id'] as String? ?? '',
      number: (j['number'] as num?)?.toInt() ?? 0,
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
      notes: notes,
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
      noteImages: noteImages,
      workflowNotes: workflowNotes,
      createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(j['updatedAt'] as String? ?? '') ?? DateTime.now(),
      completedAt: j['completedAt'] != null
          ? DateTime.tryParse(j['completedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'number': number,
    'name': name,
    'clientId': clientId,
    'clientName': clientName,
    'status': status.name,
    'startDate': startDate.toIso8601String(),
    if (deadline != null) 'deadline': deadline!.toIso8601String(),
    'budget': budget,
    'description': description,
    'notes': notes,
    'location': location,
    'quoteIds': quoteIds,
    'invoiceIds': invoiceIds,
    'expenses': expenses.map((e) => e.toJson()).toList(),
    'payments': payments.map((p) => p.toJson()).toList(),
    'summaryImages': summaryImages,
    'noteImages': noteImages,
    'workflowNotes': workflowNotes.map((n) => n.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
  };

  /// Keeps the legacy notes blob in sync with card-based workflow. Photos stay
  /// only inside [workflowNotes]; copying them into `noteImages` as well doubled
  /// the payload of every synced project.
  Project withWorkflowNotes(List<ProjectNote> cards) => copyWith(
        workflowNotes: cards,
        notes: cards.map((c) => c.text.trim()).where((t) => t.isNotEmpty).join('\n\n'),
        noteImages: const [],
      );

  Project copyWith({
    int? number,
    String? name,
    String? clientId,
    String? clientName,
    ProjectStatus? status,
    DateTime? startDate,
    DateTime? deadline,
    double? budget,
    String? description,
    String? notes,
    String? location,
    List<String>? quoteIds,
    List<String>? invoiceIds,
    List<ProjectExpense>? expenses,
    List<ProjectPayment>? payments,
    List<String>? summaryImages,
    List<String>? noteImages,
    List<ProjectNote>? workflowNotes,
    DateTime? completedAt,
    bool clearCompletedAt = false,
  }) => Project(
    id: id,
    number: number ?? this.number,
    name: name ?? this.name,
    clientId: clientId ?? this.clientId,
    clientName: clientName ?? this.clientName,
    status: status ?? this.status,
    startDate: startDate ?? this.startDate,
    deadline: deadline ?? this.deadline,
    budget: budget ?? this.budget,
    description: description ?? this.description,
    notes: notes ?? this.notes,
    location: location ?? this.location,
    quoteIds: quoteIds ?? List.from(this.quoteIds),
    invoiceIds: invoiceIds ?? List.from(this.invoiceIds),
    expenses: expenses ?? List.from(this.expenses),
    payments: payments ?? List.from(this.payments),
    summaryImages: summaryImages ?? List.from(this.summaryImages),
    noteImages: noteImages ?? List.from(this.noteImages),
    workflowNotes: workflowNotes ?? List.from(this.workflowNotes),
    completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
    createdAt: createdAt,
    updatedAt: DateTime.now(),
  );
}
