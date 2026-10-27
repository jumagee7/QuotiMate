// app_state.dart — QuotiMate state with SharedPreferences persistence

import 'dart:async';
import 'dart:convert';
import 'dart:math' as dartMath;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'services/notification_service.dart';
import 'services/cloud_sync_service.dart';
import 'services/auth_service.dart';
import 'services/review_server_service.dart';

// ── InheritedNotifier Provider ────────────────────────────────────────────────

class AppStateProvider extends InheritedNotifier<AppState> {
  const AppStateProvider({
    super.key,
    required AppState state,
    required super.child,
  }) : super(notifier: state);

  static AppState of(BuildContext context) {
    final provider = context.dependOnInheritedWidgetOfExactType<AppStateProvider>();
    if (provider == null) throw Exception('AppStateProvider not found in context');
    return provider.notifier!;
  }
}

// ── AppState ──────────────────────────────────────────────────────────────────

// ── Global root messenger (toast/snackbar from non-UI code) ─────────────────
final GlobalKey<ScaffoldMessengerState> rootMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// App-wide navigator handle — lets background services (e.g. the updater)
/// show dialogs after startup without holding a widget context.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void showToast(String message, {Color color = const Color(0xFF1E2538), Duration duration = const Duration(seconds: 3)}) {
  rootMessengerKey.currentState?.showSnackBar(
    SnackBar(
      content: Text(message, style: const TextStyle(color: Colors.white, fontSize: 13)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      duration: duration,
    ),
  );
}

class AppState extends ChangeNotifier with WidgetsBindingObserver {
  // ── Persistent lists ───────────────────────────────────────────────────────
  final List<Client> _clients = [];
  final List<Product> _products = [];
  final List<Quote> _quotes = [];
  final List<Invoice> _invoices = [];
  final List<AppTask> _tasks = [];
  final List<AppEvent> _events = [];
  final List<Project> _projects = [];

  // ── In-app notification centre (persisted, newest first) ───────────────────
  final List<AppNotification> _notifications = [];
  final Set<String> _seenScheduleStates = {};
  Timer? _scheduleTicker;

  // ── Settings ───────────────────────────────────────────────────────────────
  String companyName = 'MODERN EDGE';
  String companyEmail = 'jumaink20@gmail.com';
  String companyPhone = '+254 700 000000';
  String companyAddress = 'Nairobi, Kenya';
  String companyWebsite = 'www.modernedge.co.ke';
  String companyKraPin = 'A011821254M';
  String preparedBy = 'Admin';
  int defaultExpiryDays = 30;
  String currency = 'Ksh';

  String pdfTemplate = 'modern_edge';
  double defaultVatPercent = 0.0;
  String defaultPaymentTerms = '70% Advance, 30% on Completion';
  String defaultNotes = 'Validity: 30 days.';
  bool notificationsEnabled = true;
  /// When on, items marked as alarms ring full-screen and keep buzzing until
  /// stopped. Off makes them ordinary high-priority notifications.
  bool alarmBuzzEnabled = true;
  int nextQuoteNumber = 1001;

  // ── User Profile ───────────────────────────────────────────────────────────
  String userName = '';
  String userEmail = '';
  String userRole = 'Admin';
  String userPhotoUrl = '';

  // ── Init ───────────────────────────────────────────────────────────────────
  bool _loaded = false;
  bool _productsRetrievalToastShown = false;

  // ── Offline sync tracking ──────────────────────────────────────────────────
  int _pendingOfflineWrites = 0;
  bool get hasPendingOfflineWrites => _pendingOfflineWrites > 0;
  int get pendingOfflineWriteCount => _pendingOfflineWrites;

  void _trackWrite() {
    if (!CloudSyncService().isOnline) {
      _pendingOfflineWrites++;
      notifyListeners();
    }
  }

  void clearPendingOfflineWrites() {
    if (_pendingOfflineWrites > 0) {
      _pendingOfflineWrites = 0;
      notifyListeners();
    }
  }

  bool _reconnectToastShown = false;

  void _checkAndNotifyReconnect() {
    if (_pendingOfflineWrites > 0 && !_reconnectToastShown) {
      _reconnectToastShown = true;
      final count = _pendingOfflineWrites;
      // Small delay so the UI has time to mount
      Future.delayed(const Duration(milliseconds: 600), () {
        showToast(
          '☁ Back online! $count change${count == 1 ? '' : 's'} made offline are now syncing to cloud.',
          color: const Color(0xFF10B981),
          duration: const Duration(seconds: 5),
        );
        _pendingOfflineWrites = 0;
        _reconnectToastShown = false;
        notifyListeners();
      });
    }
  }

  AppState() {
    _init();
  }

  Future<void> _init() async {
    await _load();

    // Load products from itemlist.json if products list is empty (migration)
    if (_products.isEmpty) {
      await _loadProductsFromItemlist();
    }

    // Repair catalogues poisoned by the old demo products (p1/p2/p3) even on
    // already-loaded installs — _seedDefaults only runs on first launch.
    if (_isLegacyCatalogue()) {
      _products.clear();
      await _loadProductsFromItemlist();
    }

    if (!_loaded) {
      await _seedDefaults();
    }
    _seedNotifications();
    await _rescheduleAllNotifications();
    _startScheduleTicker();

    // Check user profile from AuthService
    final user = AuthService().currentUser;
    if (user != null) {
      userName = user.name;
      userEmail = user.email;
      userPhotoUrl = user.photoUrl;
    }

    _startCloudSyncListeners();
    // Backfill/purge the cloud catalogue if we're already signed in at startup
    _uploadProductsToCloud();
    ReviewServerService().start(appState: this);
    notifyListeners();
  }

  void _startCloudSyncListeners() {
    _productsRetrievalToastShown = false;
    CloudSyncService().startListening(
      onQuotesUpdated: (cloudQuotes) {
        _checkAndNotifyReconnect();
        if (cloudQuotes.isNotEmpty) {
          _quotes.clear();
          _quotes.addAll(cloudQuotes);
          _save();
          notifyListeners();
        }
      },
      onInvoicesUpdated: (cloudInvoices) {
        if (cloudInvoices.isNotEmpty) {
          _invoices.clear();
          _invoices.addAll(cloudInvoices);
          _save();
          notifyListeners();
        }
      },
      onClientsUpdated: (cloudClients) {
        if (cloudClients.isNotEmpty) {
          _clients.clear();
          _clients.addAll(cloudClients);
          _save();
          notifyListeners();
        }
      },
      onProductsUpdated: (cloudProducts) {
        if (cloudProducts.isNotEmpty) {
          _products.clear();
          _products.addAll(cloudProducts);
          _save();
          notifyListeners();
        }
        // Toast feedback on the first retrieval snapshot of this session
        if (!_productsRetrievalToastShown) {
          _productsRetrievalToastShown = true;
          showToast(
            cloudProducts.isNotEmpty
                ? 'Retrieved ${cloudProducts.length} catalogue item${cloudProducts.length == 1 ? '' : 's'} from cloud'
                : 'Cloud catalogue is empty - no items retrieved',
            color: cloudProducts.isNotEmpty ? const Color(0xFF1B5E20) : const Color(0xFF8A5A00),
          );
        }
      },
      onTasksUpdated: (cloudTasks) {
        if (cloudTasks.isNotEmpty) {
          _tasks.clear();
          _tasks.addAll(cloudTasks);
          _save();
          _rescheduleAllNotifications();
          notifyListeners();
        }
      },
      onEventsUpdated: (cloudEvents) {
        if (cloudEvents.isNotEmpty) {
          _events.clear();
          _events.addAll(cloudEvents);
          _save();
          _rescheduleAllNotifications();
          notifyListeners();
        }
      },
      onProjectsUpdated: (cloudProjects) {
        if (cloudProjects.isNotEmpty) {
          _projects.clear();
          _projects.addAll(cloudProjects);
          _backfillProjectNumbers();
          _save();
          notifyListeners();
        }
      },
      onSettingsUpdated: (cloudSettings) {
        if (cloudSettings.isNotEmpty) {
          companyName = cloudSettings['companyName'] as String? ?? companyName;
          companyPhone = cloudSettings['companyPhone'] as String? ?? companyPhone;
          companyEmail = cloudSettings['companyEmail'] as String? ?? companyEmail;
          companyAddress = cloudSettings['companyAddress'] as String? ?? companyAddress;
          companyKraPin = cloudSettings['companyKraPin'] as String? ?? companyKraPin;
          preparedBy = cloudSettings['preparedBy'] as String? ?? preparedBy;
          defaultExpiryDays = cloudSettings['defaultExpiryDays'] as int? ?? defaultExpiryDays;
          currency = cloudSettings['currency'] as String? ?? currency;
          pdfTemplate = cloudSettings['pdfTemplate'] as String? ?? pdfTemplate;
          defaultVatPercent = (cloudSettings['defaultVatPercent'] as num?)?.toDouble() ?? defaultVatPercent;
          defaultPaymentTerms = cloudSettings['defaultPaymentTerms'] as String? ?? defaultPaymentTerms;
          defaultNotes = cloudSettings['defaultNotes'] as String? ?? defaultNotes;
          nextQuoteNumber = cloudSettings['nextQuoteNumber'] as int? ?? nextQuoteNumber;
          _save();
          notifyListeners();
        }
      },
      onProductsError: (e) {
        showToast(
          'Cloud catalogue retrieval failed: $e',
          color: const Color(0xFFB71C1C),
          duration: const Duration(seconds: 5),
        );
      },
    );
  }

  /// Call this after a successful sign-in to immediately start cloud sync listeners
  /// and backfill any local products missing from the cloud.
  Future<void> restartCloudSync() async {
    CloudSyncService().stopListening();
    _startCloudSyncListeners();
    await _uploadProductsToCloud();
  }

  /// Uploads local products to the cloud if not already present there.
  Future<void> _uploadProductsToCloud() async {
    if (!AuthService().isAuthenticated) return;
    if (_products.isEmpty) return;
    try {
      await CloudSyncService().ensureProductsInCloud(_products);
    } catch (e) {
      debugPrint('Product cloud upload error: $e');
    }
  }

  Future<void> _rescheduleAllNotifications() async {
    final notifications = NotificationService();
    if (!notificationsEnabled) {
      await notifications.cancelAllReminders();
      return;
    }
    // Each schedule call tears down that item's own older alerts. A blanket
    // cancelAll() here would delete alerts for any item whose re-arm failed,
    // which silently removed working reminders at startup.
    for (final t in _tasks) {
      if (t.status != TaskStatus.done) {
        await notifications.scheduleTaskReminder(
          id: t.id,
          title: t.title,
          body: t.description,
          dueDate: t.dueDate,
          leadMinutes: t.reminderLeadMinutes,
          alarm: t.alarmEnabled,
          buzz: alarmBuzzEnabled,
        );
      }
    }
    for (final e in _events) {
      await notifications.scheduleEventReminders(
        id: e.id,
        title: e.title,
        description: e.description,
        startTime: e.startTime,
        leadMinutes: e.reminderLeadMinutes,
        alarm: e.alarmEnabled,
        buzz: alarmBuzzEnabled,
      );
    }
  }

  /// Re-arms every task/event alert. Called after the OS notification
  /// permissions change so alarms queued before the grant get a second chance.
  Future<void> refreshScheduledNotifications() => _rescheduleAllNotifications();

  // ── Load products from itemlist.json ──────────────────────────────────────────
  Future<void> _loadProductsFromItemlist() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/itemlist.json');
      final Map<String, dynamic> jsonData = jsonDecode(jsonString);
      
      _products.clear();
      int index = 0;
      jsonData.forEach((name, value) {
        if (value is List && value.length >= 2) {
          final unit = value[0] as String? ?? 'pcs';
          final price = double.tryParse(value[1].toString()) ?? 0.0;
          _products.add(Product(
            id: 'p${index++}',
            name: name,
            description: '',
            unitPrice: price,
            unit: unit,
          ));
        }
      });
      
      debugPrint('Loaded ${_products.length} products from itemlist.json');
      _save(); // Save to persist the loaded products
      // Add notification banner
      _notifications.add(AppNotification(
        id: 'n_products_loaded',
        title: 'Products Loaded',
        body: 'Successfully loaded ${_products.length} items from catalogue',
        timestamp: DateTime.now(),
        icon: Icons.inventory_2_outlined,
        color: Colors.green,
      ));
      
      // Sync to cloud if authenticated (uploads only products missing there)
      await _uploadProductsToCloud();
    } catch (e) {
      debugPrint('Error loading products from itemlist.json: $e');
      // Add error notification
      _notifications.add(AppNotification(
        id: 'n_products_error',
        title: 'Products Load Failed',
        body: 'Could not load catalogue items from itemlist.json.',
        timestamp: DateTime.now(),
        icon: Icons.error_outline,
        color: Colors.red,
      ));
    }
  }

  // ── Seed data (only on first run) ──────────────────────────────────────────
  static const _legacyFallbackProductIds = {'p1', 'p2', 'p3'};

  /// True when the local catalogue consists only of the old demo products
  /// (Website Design / Logo Design / SEO Package) that were seeded by mistake.
  bool _isLegacyCatalogue() {
    if (_products.isEmpty) return false;
    return _products.every((p) => _legacyFallbackProductIds.contains(p.id));
  }

  Future<void> _seedDefaults() async {
    // Load products from itemlist.json on first run, or when the catalogue
    // still only contains the old demo products.
    if (_products.isEmpty || _isLegacyCatalogue()) {
      if (_isLegacyCatalogue()) _products.clear();
      await _loadProductsFromItemlist();
    }

    // Also remove any legacy demo products individually present in a real catalogue
    _products.removeWhere((p) => _legacyFallbackProductIds.contains(p.id));

    _save(); // persist seeds immediately
  }

  void _seedNotifications() {
    // No demo notifications — real notifications are generated by app activity.
  }

  // ── Persistence ────────────────────────────────────────────────────────────

  static const _kClients   = 'qm_clients';
  static const _kProducts  = 'qm_products';
  static const _kQuotes    = 'qm_quotes';
  static const _kInvoices  = 'qm_invoices';
  static const _kTasks     = 'qm_tasks';
  static const _kEvents    = 'qm_events';
  static const _kProjects  = 'qm_projects';
  static const _kSettings  = 'qm_settings';
  static const _kProfile   = 'qm_profile';
  static const _kSeeded    = 'qm_seeded';
  static const _kNotifications = 'qm_notifications';
  static const int _maxNotifications = 60;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _loaded = prefs.getBool(_kSeeded) ?? false;
    if (!_loaded) return;

    // Clients
    final clientsRaw = prefs.getString(_kClients);
    if (clientsRaw != null) {
      final list = jsonDecode(clientsRaw) as List<dynamic>;
      _clients.addAll(list.map((e) => Client.fromJson(e as Map<String, dynamic>)));
    }
    // Products
    final productsRaw = prefs.getString(_kProducts);
    if (productsRaw != null) {
      final list = jsonDecode(productsRaw) as List<dynamic>;
      _products.addAll(list.map((e) => Product.fromJson(e as Map<String, dynamic>)));
    }
    // Quotes
    final quotesRaw = prefs.getString(_kQuotes);
    if (quotesRaw != null) {
      final list = jsonDecode(quotesRaw) as List<dynamic>;
      _quotes.addAll(list.map((e) => Quote.fromJson(e as Map<String, dynamic>)));
    }
    // Invoices
    final invoicesRaw = prefs.getString(_kInvoices);
    if (invoicesRaw != null) {
      final list = jsonDecode(invoicesRaw) as List<dynamic>;
      _invoices.addAll(list.map((e) => Invoice.fromJson(e as Map<String, dynamic>)));
    }
    // Tasks
    final tasksRaw = prefs.getString(_kTasks);
    if (tasksRaw != null) {
      final list = jsonDecode(tasksRaw) as List<dynamic>;
      _tasks.addAll(list.map((e) => AppTask.fromJson(e as Map<String, dynamic>)));
    }
    // Events
    final eventsRaw = prefs.getString(_kEvents);
    if (eventsRaw != null) {
      final list = jsonDecode(eventsRaw) as List<dynamic>;
      _events.addAll(list.map((e) => AppEvent.fromJson(e as Map<String, dynamic>)));
    }
    // Projects
    final projectsRaw = prefs.getString(_kProjects);
    if (projectsRaw != null) {
      final list = jsonDecode(projectsRaw) as List<dynamic>;
      _projects.addAll(list.map((e) => Project.fromJson(e as Map<String, dynamic>)));
    }
    // Settings
    final settingsRaw = prefs.getString(_kSettings);
    if (settingsRaw != null) {
      final s = jsonDecode(settingsRaw) as Map<String, dynamic>;
      companyName          = s['companyName']          as String? ?? companyName;
      companyPhone         = s['companyPhone']         as String? ?? companyPhone;
      companyEmail         = s['companyEmail']         as String? ?? companyEmail;
      companyAddress       = s['companyAddress']       as String? ?? companyAddress;
      companyKraPin        = s['companyKraPin']        as String? ?? companyKraPin;
      preparedBy           = s['preparedBy']           as String? ?? preparedBy;
      defaultExpiryDays    = s['defaultExpiryDays']    as int?    ?? defaultExpiryDays;
      currency             = s['currency']             as String? ?? currency;
      pdfTemplate          = s['pdfTemplate']          as String? ?? pdfTemplate;
      defaultVatPercent    = (s['defaultVatPercent']   as num?)?.toDouble() ?? defaultVatPercent;
      defaultPaymentTerms  = s['defaultPaymentTerms']  as String? ?? defaultPaymentTerms;
      defaultNotes         = s['defaultNotes']         as String? ?? defaultNotes;
      notificationsEnabled = s['notificationsEnabled'] as bool?   ?? notificationsEnabled;
      alarmBuzzEnabled     = s['alarmBuzzEnabled']     as bool?   ?? alarmBuzzEnabled;
      nextQuoteNumber      = s['nextQuoteNumber']      as int?    ?? nextQuoteNumber;
    }
    // Profile
    final profileRaw = prefs.getString(_kProfile);
    if (profileRaw != null) {
      final p = jsonDecode(profileRaw) as Map<String, dynamic>;
      userName  = p['userName']  as String? ?? userName;
      userEmail = p['userEmail'] as String? ?? userEmail;
      userRole  = p['userRole']  as String? ?? userRole;
    }
    // In-app notification centre
    final notificationsRaw = prefs.getString(_kNotifications);
    if (notificationsRaw != null) {
      final list = jsonDecode(notificationsRaw) as List<dynamic>;
      _notifications.addAll(list.map((e) => AppNotification.fromJson(e as Map<String, dynamic>)));
    }
    // Legacy projects stored before numbers existed get sequential numbers.
    if (_backfillProjectNumbers()) await _save();
  }

  /// Assigns sequential project numbers to records saved before [Project.number]
  /// existed, oldest first. Returns true when any project was changed.
  bool _backfillProjectNumbers() {
    final missing = _projects.where((p) => p.number <= 0).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    if (missing.isEmpty) return false;
    var next = _projects.fold<int>(0, (max, p) => p.number > max ? p.number : max);
    for (final p in missing) {
      p.number = ++next;
    }
    return true;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSeeded, true);
    await prefs.setString(_kClients,  jsonEncode(_clients.map((e)  => e.toJson()).toList()));
    await prefs.setString(_kProducts, jsonEncode(_products.map((e) => e.toJson()).toList()));
    await prefs.setString(_kQuotes,   jsonEncode(_quotes.map((e)   => e.toJson()).toList()));
    await prefs.setString(_kInvoices, jsonEncode(_invoices.map((e) => e.toJson()).toList()));
    await prefs.setString(_kTasks,    jsonEncode(_tasks.map((e)    => e.toJson()).toList()));
    await prefs.setString(_kEvents,   jsonEncode(_events.map((e)   => e.toJson()).toList()));
    await prefs.setString(_kProjects, jsonEncode(_projects.map((e) => e.toJson()).toList()));
    await prefs.setString(_kSettings, jsonEncode({
      'companyName': companyName, 'companyPhone': companyPhone,
      'companyEmail': companyEmail, 'companyAddress': companyAddress,
      'companyKraPin': companyKraPin,
      'preparedBy': preparedBy, 'defaultExpiryDays': defaultExpiryDays,
      'currency': currency, 'pdfTemplate': pdfTemplate,
      'defaultVatPercent': defaultVatPercent,
      'defaultPaymentTerms': defaultPaymentTerms,
      'defaultNotes': defaultNotes,
      'notificationsEnabled': notificationsEnabled,
      'alarmBuzzEnabled': alarmBuzzEnabled,
      'nextQuoteNumber': nextQuoteNumber,
    }));
    await prefs.setString(_kProfile, jsonEncode({
      'userName': userName, 'userEmail': userEmail, 'userRole': userRole,
    }));
    await _saveNotifications();
  }

  Future<void> _saveNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kNotifications,
      jsonEncode(_notifications.take(_maxNotifications).map((e) => e.toJson()).toList()),
    );
  }

  // ── Getters ────────────────────────────────────────────────────────────────
  List<Client>          get clients       => List.unmodifiable(_clients);
  List<Product>         get products      => List.unmodifiable(_products);
  List<Quote>           get quotes        => List.unmodifiable(_quotes);
  List<Invoice>         get invoices      => List.unmodifiable(_invoices);
  List<AppNotification> get notifications => List.unmodifiable(_notifications);
  List<AppTask>         get tasks         => List.unmodifiable(_tasks);
  List<AppEvent>        get events        => List.unmodifiable(_events);
  List<Project>         get projects      => List.unmodifiable(_projects);

  List<Project> get activeProjects => _projects
      .where((p) => p.status == ProjectStatus.inProgress || p.status == ProjectStatus.planning)
      .toList();
  List<Project> get completedProjects => _projects
      .where((p) => p.status == ProjectStatus.completed)
      .toList();

  Project? getProject(String id) {
    final idx = _projects.indexWhere((p) => p.id == id);
    return idx == -1 ? null : _projects[idx];
  }

  /// Tasks linked to a specific project, newest due date last.
  List<AppTask> tasksForProject(String projectId) =>
      _tasks.where((t) => t.projectId == projectId).toList();

  int    get unreadCount         => _notifications.where((n) => !n.isRead).length;
  int    quoteCountForClient(String clientId) => _quotes.where((q) => q.clientId == clientId).length;
  String get nextClientId        => 'C-${DateTime.now().millisecondsSinceEpoch}';
  String get nextProductId       => 'P-${DateTime.now().millisecondsSinceEpoch}';
  String get nextTaskId          => 'T-${DateTime.now().millisecondsSinceEpoch}';
  String get nextEventId         => 'EV-${DateTime.now().millisecondsSinceEpoch}';
  String get nextProjectId       => 'PRJ-${DateTime.now().millisecondsSinceEpoch}';
  /// Next user-facing project number (PRJ-001, PRJ-002, ...).
  int get nextProjectNumber =>
      _projects.fold<int>(0, (max, p) => p.number > max ? p.number : max) + 1;
  String get nextExpenseId       => 'EXP-${DateTime.now().millisecondsSinceEpoch}';
  String get nextPaymentId       => 'PAY-${DateTime.now().millisecondsSinceEpoch}';

  // ── Product catalogue lookups (for item suggestions) ──────────────────────
  List<String> get productNames => _products.map((p) => p.name).toList();
  Product? productByName(String name) {
    final idx = _products.indexWhere((p) => p.name.toLowerCase() == name.toLowerCase());
    return idx == -1 ? null : _products[idx];
  }

  List<Quote>  get pinnedQuotes  => _quotes.where((q) => q.isPinned).toList();

  /// Live activity feed for the dashboard, built from real documents rather
  /// than the (session-only) notification list.
  List<AppActivity> get activities {
    final items = <AppActivity>[];

    for (final q in _quotes) {
      final signed = q.signatureData != null && q.signatureData!.isNotEmpty;
      items.add(AppActivity(
        title: signed
            ? 'Quotation ${q.id} signed by ${q.clientName}'
            : 'Quotation ${q.id} created for ${q.clientName}',
        time: signed ? (q.signedAt ?? q.date) : q.date,
        icon: signed ? Icons.verified_rounded : Icons.description_outlined,
        color: signed ? const Color(0xFF10B981) : const Color(0xFFFFC107),
      ));
    }

    for (final inv in _invoices) {
      final paid = inv.status == InvoiceStatus.paid;
      items.add(AppActivity(
        title: paid
            ? 'Invoice ${inv.id} paid by ${inv.clientName}'
            : 'Invoice ${inv.id} issued to ${inv.clientName}',
        time: inv.date,
        icon: paid ? Icons.paid_rounded : Icons.receipt_long_outlined,
        color: paid ? const Color(0xFF10B981) : const Color(0xFF3B82F6),
      ));
    }

    for (final p in _projects) {
      items.add(AppActivity(
        title: 'Project "${p.name}" created',
        time: p.createdAt,
        icon: Icons.business_center_outlined,
        color: const Color(0xFF38BDF8),
      ));
      for (final pay in p.payments) {
        items.add(AppActivity(
          title: 'Payment of $currency ${pay.amount.toStringAsFixed(0)} received on "${p.name}"',
          time: pay.date,
          icon: Icons.payments_outlined,
          color: const Color(0xFF10B981),
        ));
      }
      for (final e in p.expenses) {
        items.add(AppActivity(
          title: 'Expense "${e.title}" recorded on "${p.name}"',
          time: e.date,
          icon: Icons.shopping_bag_outlined,
          color: const Color(0xFFE2A45C),
        ));
      }
    }

    items.sort((a, b) => b.time.compareTo(a.time));
    return items.take(8).toList();
  }

  int    get totalQuotes         => _quotes.length;
  int    get approvedCount       => _quotes.where((q) => q.status == QuoteStatus.approved).length;
  double get conversionRate      => totalQuotes == 0 ? 0 : approvedCount / totalQuotes * 100;
  double get totalRevenue        => _quotes.where((q) => q.status == QuoteStatus.approved).fold(0, (s, q) => s + q.total);
  double get paidRevenue         => _invoices.where((i) => i.status == InvoiceStatus.paid).fold(0, (s, i) => s + i.amount);

  // ── User Profile ───────────────────────────────────────────────────────────
  void updateUserProfile({String? name, String? email, String? role}) {
    if (name  != null) userName  = name;
    if (email != null) userEmail = email;
    if (role  != null) userRole  = role;
    _save();
    notifyListeners();
  }

  // ── Notifications ──────────────────────────────────────────────────────────
  void markAllNotificationsRead() {
    for (final n in _notifications) { n.isRead = true; }
    _saveNotifications();
    notifyListeners();
  }

  void markNotificationRead(String id) {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx != -1) {
      _notifications[idx].isRead = true;
      _saveNotifications();
      notifyListeners();
    }
  }

  void addNotification(AppNotification notification) {
    _notifications.insert(0, notification);
    if (_notifications.length > _maxNotifications) {
      _notifications.removeRange(_maxNotifications, _notifications.length);
    }
    _saveNotifications();
    notifyListeners();
  }

  /// Adds (or refreshes, when [key] already exists) an entry in the in-app
  /// notification centre. Re-arming an alarm updates its own row instead of
  /// stacking a new one per edit.
  void pushNotification({
    required String key,
    required String title,
    required String body,
    required IconData icon,
    required Color color,
  }) {
    final now = DateTime.now();
    final idx = _notifications.indexWhere((n) => n.id == key);
    if (idx != -1) {
      _notifications.removeAt(idx);
    }
    _notifications.insert(0, AppNotification(
      id: key,
      title: title,
      body: body,
      timestamp: now,
      isRead: false,
      icon: icon,
      color: color,
    ));
    if (_notifications.length > _maxNotifications) {
      _notifications.removeRange(_maxNotifications, _notifications.length);
    }
    _saveNotifications();
    notifyListeners();
  }

  void clearNotifications() {
    _notifications.clear();
    _saveNotifications();
    notifyListeners();
  }

  void _dropNotificationsFor(String kind, String itemId) {
    final before = _notifications.length;
    _notifications.removeWhere(
      (n) => n.id.startsWith('n_${kind}_') && n.id.endsWith('_$itemId'),
    );
    if (_notifications.length != before) _saveNotifications();
  }

  /// Watches tasks/events cross their due/start/end times so the app shows
  /// something even when the device alarm was handled by Android.
  void _startScheduleTicker() {
    _baselineScheduleStates();
    _scheduleTicker?.cancel();
    _scheduleTicker = Timer.periodic(
      const Duration(seconds: 30),
      (_) {
        _checkScheduleStates();
        syncAwaitingSignatures();
      },
    );
    // The ticker only runs while the process lives, so returning to the
    // foreground is the moment to heal anything the OS dropped meanwhile.
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Do not cancel/re-arm on pause: AlarmManager already holds the alerts, and
    // a background re-arm can fail on OEM battery savers, wiping working alarms.
    if (state != AppLifecycleState.resumed) return;
    _checkScheduleStates();
    syncAwaitingSignatures();
    _rescheduleAllNotifications();
  }

  void _baselineScheduleStates() {
    _seenScheduleStates.clear();
    final now = DateTime.now();
    for (final t in _tasks) {
      if (t.status != TaskStatus.done && !t.dueDate.isAfter(now)) {
        _seenScheduleStates.add('task_due:${t.id}');
      }
    }
    for (final e in _events) {
      if (now.isAfter(e.startTime)) _seenScheduleStates.add('event_start:${e.id}');
      if (now.isAfter(e.endTime)) _seenScheduleStates.add('event_end:${e.id}');
    }
  }

  void _checkScheduleStates() {
    final now = DateTime.now();
    var fired = false;
    // The live status pills must refresh even with the feed muted, so a
    // transition always rebuilds while only an enabled feed records it.
    void transition(String key, String title, String body, IconData icon, Color color) {
      fired = true;
      if (notificationsEnabled) {
        pushNotification(key: key, title: title, body: body, icon: icon, color: color);
      }
    }

    for (final t in _tasks) {
      if (t.status == TaskStatus.done) continue;
      if (t.dueDate.isAfter(now)) continue;
      if (!_seenScheduleStates.add('task_due:${t.id}')) continue;
      transition(
        'n_task_due_${t.id}',
        t.alarmEnabled ? 'Task alarm' : 'Task due',
        t.title,
        t.alarmEnabled ? Icons.alarm : Icons.task_alt,
        const Color(0xFFFFC107),
      );
    }

    for (final e in _events) {
      if (now.isAfter(e.startTime) && _seenScheduleStates.add('event_start:${e.id}')) {
        transition(
          'n_event_start_${e.id}',
          'Event started',
          '${e.title} · ${_clockTime(e.startTime)}',
          Icons.play_circle_outline,
          e.color,
        );
      }
      if (now.isAfter(e.endTime) && _seenScheduleStates.add('event_end:${e.id}')) {
        transition(
          'n_event_end_${e.id}',
          'Event ended',
          '${e.title} · ${_clockTime(e.endTime)}',
          Icons.stop_circle_outlined,
          Colors.white70,
        );
      }
    }

    if (fired) {
      if (notificationsEnabled && _notifications.isNotEmpty) {
        showToast('🔔 ${_notifications.first.title}: ${_notifications.first.body}');
      }
      notifyListeners();
    }
  }

  static String _clockTime(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    return '$h:${dt.minute.toString().padLeft(2, '0')} ${dt.hour >= 12 ? 'PM' : 'AM'}';
  }

  /// Timestamp shown when a saved time conflicts with the device clock, so the
  /// user can see which of the two the scheduler actually compared.
  static String _stamp(DateTime dt) {
    final m = dt.month.toString().padLeft(2, '0');
    return '${dt.day}/$m ${_clockTime(dt)}';
  }

  /// Human phrase for when a reminder will ring.
  static String whenPhrase(DateTime dt) {    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(dt.year, dt.month, dt.day);
    final dayWord = target == today
        ? 'today'
        : target == today.add(const Duration(days: 1))
            ? 'tomorrow'
            : '${dt.day}/${dt.month}/${dt.year}';
    return '$dayWord at ${_clockTime(dt)}';
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scheduleTicker?.cancel();
    super.dispose();
  }

  // ── Settings ───────────────────────────────────────────────────────────────
  void updateSettings({
    String? companyName, String? companyPhone, String? companyEmail,
    String? companyAddress, String? companyKraPin, String? preparedBy,
    int? defaultExpiryDays,
    String? currency, String? pdfTemplate, double? defaultVatPercent,
    String? defaultPaymentTerms, String? defaultNotes, bool? notificationsEnabled,
    bool? alarmBuzzEnabled, int? nextQuoteNumber,
  }) {
    if (companyName         != null) this.companyName         = companyName;
    if (companyPhone        != null) this.companyPhone        = companyPhone;
    if (companyEmail        != null) this.companyEmail        = companyEmail;
    if (companyAddress      != null) this.companyAddress      = companyAddress;
    if (companyKraPin       != null) this.companyKraPin       = companyKraPin;
    if (preparedBy          != null) this.preparedBy          = preparedBy;
    if (defaultExpiryDays   != null) this.defaultExpiryDays   = defaultExpiryDays;
    if (currency            != null) this.currency            = currency;
    if (pdfTemplate         != null) this.pdfTemplate         = pdfTemplate;
    if (defaultVatPercent   != null) this.defaultVatPercent   = defaultVatPercent;
    if (defaultPaymentTerms != null) this.defaultPaymentTerms = defaultPaymentTerms;
    if (defaultNotes        != null) this.defaultNotes        = defaultNotes;
    if (notificationsEnabled!= null) {
      this.notificationsEnabled = notificationsEnabled;
      // Flipping the master switch must arm or tear down every pending alarm.
      _rescheduleAllNotifications();
    }
    if (alarmBuzzEnabled    != null) {
      this.alarmBuzzEnabled   = alarmBuzzEnabled;
      // Existing alarms were queued with the old ring behaviour.
      _rescheduleAllNotifications();
    }
    if (nextQuoteNumber     != null) this.nextQuoteNumber     = nextQuoteNumber;
    _save();
    CloudSyncService().saveSettings({
      'companyName': this.companyName,
      'companyPhone': this.companyPhone,
      'companyEmail': this.companyEmail,
      'companyAddress': this.companyAddress,
      'companyKraPin': this.companyKraPin,
      'preparedBy': this.preparedBy,
      'defaultExpiryDays': this.defaultExpiryDays,
      'currency': this.currency,
      'pdfTemplate': this.pdfTemplate,
      'defaultVatPercent': this.defaultVatPercent,
      'defaultPaymentTerms': this.defaultPaymentTerms,
      'defaultNotes': this.defaultNotes,
      'notificationsEnabled': this.notificationsEnabled,
      'alarmBuzzEnabled': this.alarmBuzzEnabled,
      'nextQuoteNumber': this.nextQuoteNumber,
    });
    notifyListeners();
  }

  void resetSettings() {
    companyName = 'MODERN EDGE';
    companyEmail = 'jumaink20@gmail.com';
    companyPhone = '+254 700 000000';
    companyAddress = 'Nairobi, Kenya';
    companyWebsite = 'www.modernedge.co.ke';
    companyKraPin = 'A011821254M';
    preparedBy = 'Admin';
    defaultExpiryDays = 30;
    currency = 'Ksh';
    pdfTemplate = 'modern_edge';
    defaultVatPercent = 0.0;
    defaultPaymentTerms = '70% Advance, 30% on Completion';
    defaultNotes = 'Thank you for your business!';
    nextQuoteNumber = 1001;
    _save();
    CloudSyncService().saveSettings({
      'companyName': companyName,
      'companyPhone': companyPhone,
      'companyEmail': companyEmail,
      'companyAddress': companyAddress,
      'companyKraPin': companyKraPin,
      'preparedBy': preparedBy,
      'defaultExpiryDays': defaultExpiryDays,
      'currency': currency,
      'pdfTemplate': pdfTemplate,
      'defaultVatPercent': defaultVatPercent,
      'defaultPaymentTerms': defaultPaymentTerms,
      'defaultNotes': defaultNotes,
      'nextQuoteNumber': nextQuoteNumber,
    });
    notifyListeners();
  }

  // ── Clients ────────────────────────────────────────────────────────────────
  void addClient(Client client) {
    _clients.add(client);
    _save();
    CloudSyncService().saveClient(client);
    notifyListeners();
  }
  void updateClient(Client client) {
    final idx = _clients.indexWhere((c) => c.id == client.id);
    if (idx != -1) {
      _clients[idx] = client;
      _save();
      CloudSyncService().saveClient(client);
      notifyListeners();
    }
  }
  void deleteClient(String id) {
    _clients.removeWhere((c) => c.id == id);
    _save();
    CloudSyncService().deleteClient(id);
    notifyListeners();
  }

  // ── Products ───────────────────────────────────────────────────────────────
  void addProduct(Product product) {
    _products.add(product);
    _save();
    CloudSyncService().saveProduct(product);
    notifyListeners();
  }
  void updateProduct(Product product) {
    final idx = _products.indexWhere((p) => p.id == product.id);
    if (idx != -1) {
      _products[idx] = product;
      _save();
      CloudSyncService().saveProduct(product);
      notifyListeners();
    }
  }
  void deleteProduct(String id) {
    _products.removeWhere((p) => p.id == id);
    _save();
    CloudSyncService().deleteProduct(id);
    notifyListeners();
  }

  // ── Quotes ─────────────────────────────────────────────────────────────────
  void addQuote(Quote quote) {
    _quotes.add(quote);
    _save();
    _trackWrite();
    CloudSyncService().saveQuote(quote);
    notifyListeners();
  }
  void updateQuote(Quote quote) {
    final idx = _quotes.indexWhere((q) => q.id == quote.id);
    if (idx != -1) {
      _quotes[idx] = quote;
      _save();
      _trackWrite();
      CloudSyncService().saveQuote(quote);
      notifyListeners();
    }
  }
  void deleteQuote(String id) {
    _quotes.removeWhere((q) => q.id == id);
    // If the deleted quotation carried the most recently allocated number,
    // roll the counter back so the next quotation reuses it (no tail gaps).
    final num = quoteNumberFromId(id);
    if (num != null && num == nextQuoteNumber - 1) {
      final stillUsed = _quotes.any((q) => quoteNumberFromId(q.id) == num);
      if (!stillUsed) {
        nextQuoteNumber = num;
        CloudSyncService().saveSettings({'nextQuoteNumber': nextQuoteNumber});
      }
    }
    _save();
    CloudSyncService().deleteQuote(id);
    notifyListeners();
  }

  /// Extracts the trailing numeric portion of a document id ("Q-1042" -> 1042).
  static int? quoteNumberFromId(String id) {
    final match = RegExp(r'(\d+)\s*$').firstMatch(id);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  /// Allocates the next quotation number. Requires an active cloud connection so
  /// numbers stay unique and sequential across synced devices.
  ///
  /// Returns the new id (e.g. "Q-1042"), or null when the device is offline.
  Future<String?> allocateQuoteNumber() async {
    final cloud = CloudSyncService();
    if (!cloud.isOnline) return null;

    final num = await cloud.getAndIncrementNextQuoteNumber(nextQuoteNumber);
    // getAndIncrementNextQuoteNumber persists the incremented value in the cloud;
    // mirror it locally so the settings UI and offline fallback stay in step.
    nextQuoteNumber = num + 1;
    await _save();
    notifyListeners();
    return 'Q-$num';
  }

  void markQuoteSigned(String quoteId, String signatureBase64,
      [DateTime? signedAt, SignatureMetadata? meta]) {
    final idx = _quotes.indexWhere((q) => q.id == quoteId);
    if (idx != -1) {
      _quotes[idx].signatureData = signatureBase64;
      _quotes[idx].signedAt = signedAt ?? DateTime.now();
      _quotes[idx].status = QuoteStatus.approved;
      if (meta != null) {
        _quotes[idx].signerName = meta.signerName ?? _quotes[idx].signerName;
        _quotes[idx].signerPhone = meta.signerPhone ?? _quotes[idx].signerPhone;
        _quotes[idx].signerDevice = meta.device ?? _quotes[idx].signerDevice;
        _quotes[idx].signerAppVersion = meta.appVersion ?? _quotes[idx].signerAppVersion;
        _quotes[idx].signerLocation = meta.location ?? _quotes[idx].signerLocation;
      }
      _save();
      CloudSyncService().saveQuote(_quotes[idx]);
      notifyListeners();
    }
  }

  void markInvoiceSigned(String invoiceId, String signatureBase64,
      [DateTime? signedAt, SignatureMetadata? meta]) {
    final idx = _invoices.indexWhere((i) => i.id == invoiceId);
    if (idx != -1) {
      _invoices[idx].signatureData = signatureBase64;
      _invoices[idx].signedAt = signedAt ?? DateTime.now();
      if (meta != null) {
        _invoices[idx].signerName = meta.signerName ?? _invoices[idx].signerName;
        _invoices[idx].signerPhone = meta.signerPhone ?? _invoices[idx].signerPhone;
        _invoices[idx].signerDevice = meta.device ?? _invoices[idx].signerDevice;
        _invoices[idx].signerAppVersion = meta.appVersion ?? _invoices[idx].signerAppVersion;
        _invoices[idx].signerLocation = meta.location ?? _invoices[idx].signerLocation;
      }
      _save();
      CloudSyncService().saveInvoice(_invoices[idx]);
      notifyListeners();
    }
  }

  Future<bool> checkCloudSignatureForQuote(String quoteId) async {
    final remote = await _fetchCloudSignature(quoteId, invoice: false);
    if (remote == null) return false;
    markQuoteSigned(quoteId, remote.signatureData, remote.signedAt, remote.meta);
    return true;
  }

  Future<bool> checkCloudSignatureForInvoice(String invoiceId) async {
    final remote = await _fetchCloudSignature(invoiceId, invoice: true);
    if (remote == null) return false;
    markInvoiceSigned(invoiceId, remote.signatureData, remote.signedAt, remote.meta);
    return true;
  }

  /// The browser review page writes `signatureData` straight into Firestore, and
  /// the realtime listener only exists when Firebase was up at startup — so a
  /// client signing on their own phone can go unnoticed indefinitely. Anything
  /// shared but still unsigned is therefore re-read here, which is the automatic
  /// version of the "Check / Sync Signature from Cloud" action.
  Future<void> syncAwaitingSignatures() async {
    if (_pullingSignatures) return;
    _pullingSignatures = true;
    try {
      final quotes = _quotes
          .where((q) =>
              q.shareToken != null && (q.signatureData ?? '').isEmpty)
          .take(8)
          .toList();
      final invoices = _invoices
          .where((i) =>
              i.shareToken != null && (i.signatureData ?? '').isEmpty)
          .take(8)
          .toList();

      for (final q in quotes) {
        if (await checkCloudSignatureForQuote(q.id)) {
          final signed = _quotes.firstWhere((e) => e.id == q.id);
          announceSignatureApplied(
              signed.clientName, signed.id, signed.signerMetadata);
        }
      }
      for (final i in invoices) {
        if (await checkCloudSignatureForInvoice(i.id)) {
          final signed = _invoices.firstWhere((e) => e.id == i.id);
          announceSignatureApplied(
              signed.clientName, signed.id, signed.signerMetadata);
        }
      }
    } finally {
      _pullingSignatures = false;
    }
  }

  bool _pullingSignatures = false;

  void announceSignatureApplied(
      String clientName, String docId, SignatureMetadata meta) {
    final signer = meta.signerName;
    final who = (signer == null || signer.isEmpty) ? clientName : signer;
    final details = <String>[
      if (meta.signerPhone != null && meta.signerPhone!.isNotEmpty)
        'WhatsApp ${meta.signerPhone}'
      else if (meta.location != null && meta.location!.isNotEmpty)
        'Location ${meta.location}',
      if (meta.device != null && meta.device!.isNotEmpty) meta.device!,
    ];
    pushNotification(
      key: 'n_signed_$docId',
      title: '$docId signed by $who',
      body: '$who approved and signed it in the review link. '
          '${details.isEmpty ? 'The signed PDF is ready.' : '${details.join(' · ')}. The signed PDF carries the full evidence.'}',
      icon: kNotificationIcons['sign']!,
      color: const Color(0xFF10B981),
    );
    showToast('✍️ $who signed $docId', color: const Color(0xFF1B5E20));
    notifyListeners();
  }

  Future<_CloudSignature?> _fetchCloudSignature(String docId,
      {required bool invoice}) async {
    final data = invoice
        ? await CloudSyncService().fetchInvoiceFromCloud(docId)
        : await CloudSyncService().fetchQuoteFromCloud(docId);
    final sig = data?['signatureData'] as String?;
    if (sig == null || sig.isEmpty) return null;
    String? text(String key) {
      final v = data?[key];
      return v is String && v.isNotEmpty ? v : null;
    }

    return _CloudSignature(
      sig,
      DateTime.tryParse(data?['signedAt']?.toString() ?? '') ?? DateTime.now(),
      SignatureMetadata(
        signerName: text('signerName'),
        signerPhone: text('signerPhone'),
        device: text('signerDevice'),
        appVersion: text('signerAppVersion'),
        location: text('signerLocation'),
      ),
    );
  }

  String generateShareToken() {
    final rand = dartMath.Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  // ── Invoices ───────────────────────────────────────────────────────────────
  void addInvoice(Invoice invoice) {
    final idx = _invoices.indexWhere((i) => i.id == invoice.id);
    if (idx != -1) {
      _invoices[idx] = invoice;
    } else {
      _invoices.insert(0, invoice);
    }
    _save();
    _trackWrite();
    CloudSyncService().saveInvoice(invoice);
    notifyListeners();
  }

  void updateInvoice(Invoice invoice) {
    final idx = _invoices.indexWhere((i) => i.id == invoice.id);
    if (idx != -1) {
      _invoices[idx] = invoice;
      _save();
      _trackWrite();
      CloudSyncService().saveInvoice(invoice);
      notifyListeners();
    }
  }

  void deleteInvoice(String invoiceId) {
    _invoices.removeWhere((i) => i.id == invoiceId);
    _save();
    CloudSyncService().deleteInvoice(invoiceId);
    notifyListeners();
  }

  void updateInvoiceStatus(String invoiceId, InvoiceStatus newStatus) {
    final idx = _invoices.indexWhere((i) => i.id == invoiceId);
    if (idx != -1) {
      _invoices[idx].status = newStatus;
      _save();
      CloudSyncService().saveInvoice(_invoices[idx]);
      notifyListeners();
    }
  }

  // ── Tasks ──────────────────────────────────────────────────────────────────
  /// Adds a new task, or replaces and re-arms an existing one.
  void upsertTask(AppTask task) {
    if (_tasks.any((t) => t.id == task.id)) {
      updateTask(task);
    } else {
      addTask(task);
    }
  }

  void upsertEvent(AppEvent event) {
    if (_events.any((e) => e.id == event.id)) {
      updateEvent(event);
    } else {
      addEvent(event);
    }
  }

  void addTask(AppTask task) {
    _tasks.add(task);
    _save();
    CloudSyncService().saveTask(task);
    if (task.status != TaskStatus.done) {
      _armTaskReminder(task);
    } else {
      NotificationService().cancelReminder(task.id);
    }
    notifyListeners();
  }
  void updateTask(AppTask task) {
    final idx = _tasks.indexWhere((t) => t.id == task.id);
    if (idx != -1) {
      _tasks[idx] = task;
      _save();
      CloudSyncService().saveTask(task);
      if (task.status == TaskStatus.done) {
        NotificationService().cancelReminder(task.id);
      } else {
        _armTaskReminder(task);
      }
      notifyListeners();
    }
  }
  void _armTaskReminder(AppTask task) {
    if (!notificationsEnabled) return;
    // Moving a task to a future time must let its due transition fire again.
    if (task.dueDate.isAfter(DateTime.now())) {
      _seenScheduleStates.remove('task_due:${task.id}');
    }
    NotificationService().scheduleTaskReminder(
      id: task.id,
      title: task.title,
      body: task.description,
      dueDate: task.dueDate,
      leadMinutes: task.reminderLeadMinutes,
      alarm: task.alarmEnabled,
      buzz: alarmBuzzEnabled,
    ).then((result) {
      final armed = result.armed;
      if (!armed) _seenScheduleStates.add('task_due:${task.id}');
      // A lead that has already slipped by cannot arm, so report the time that
      // actually rings instead of promising a skipped heads-up.
      final leadSkipped = task.reminderLeadMinutes > 0 &&
          !task.alarmAt.isAfter(DateTime.now());
      final ringAt = leadSkipped ? task.dueDate : task.alarmAt;
      pushNotification(
        key: 'n_task_arm_${task.id}',
        title: armed
            ? (task.alarmEnabled ? 'Alarm set' : 'Reminder set')
            : (task.alarmEnabled ? 'Alarm not set' : 'Reminder not set'),
        body: switch (result.status) {
          ArmStatus.armed =>
            '${task.title} — ${whenPhrase(ringAt)}'
                '${leadSkipped ? ' (heads-up window already passed)' : ''}'
                '${result.detail == 'inexact' ? ' · queued inexact: Android denies exact alarms, so it can ring late' : ''}',
          ArmStatus.past =>
            '${task.title} — due ${_stamp(task.dueDate)}, already behind your clock '
                '(${_stamp(DateTime.now())}), so nothing could ring.',
          ArmStatus.rejected =>
            '${task.title} — Android refused the alarm: ${result.detail}',
          ArmStatus.unsupported =>
            '${task.title} — this device reports no local notification support.',
        },
        icon: armed ? (task.alarmEnabled ? Icons.alarm_on : Icons.notifications_active) : Icons.notifications_off,
        color: armed ? const Color(0xFFFFC107) : Colors.redAccent,
      );
      notifyListeners();
    });
  }
  void deleteTask(String id) {
    _tasks.removeWhere((t) => t.id == id);
    _save(); 
    CloudSyncService().deleteTask(id);
    NotificationService().cancelReminder(id);
    _seenScheduleStates.removeWhere((k) => k.endsWith(':$id'));
    _dropNotificationsFor('task', id);
    notifyListeners();
  }

  // ── Events ────────────────────────────────────────────────────────────────
  void addEvent(AppEvent event) {
    _events.add(event);
    _save();
    CloudSyncService().saveEvent(event);
    _armEventReminders(event);
    notifyListeners();
  }
  void updateEvent(AppEvent event) {
    final idx = _events.indexWhere((e) => e.id == event.id);
    if (idx != -1) {
      _events[idx] = event;
      _save();
      CloudSyncService().saveEvent(event);
      _armEventReminders(event);
      notifyListeners();
    }
  }
  void _armEventReminders(AppEvent event) {
    if (!notificationsEnabled) return;
    // Rescheduling into the future must let the start/end transitions fire again.
    if (event.startTime.isAfter(DateTime.now())) {
      _seenScheduleStates.remove('event_start:${event.id}');
      _seenScheduleStates.remove('event_end:${event.id}');
    }
    NotificationService().scheduleEventReminders(
      id: event.id,
      title: event.title,
      description: event.description,
      startTime: event.startTime,
      leadMinutes: event.reminderLeadMinutes,
      alarm: event.alarmEnabled,
      buzz: alarmBuzzEnabled,
    ).then((result) {
      final armed = result.armed;
      if (!armed) {
        _seenScheduleStates.add('event_start:${event.id}');
        _seenScheduleStates.add('event_end:${event.id}');
      }
      final leadSkipped = !event.alarmAt.isAfter(DateTime.now());
      final ringAt = leadSkipped ? event.startTime : event.alarmAt;
      pushNotification(
        key: 'n_event_arm_${event.id}',
        title: armed
            ? (event.alarmEnabled ? 'Alarm set' : 'Reminder set')
            : (event.alarmEnabled ? 'Alarm not set' : 'Reminder not set'),
        body: switch (result.status) {
          ArmStatus.armed =>
            '${event.title} — ${whenPhrase(ringAt)}'
                '${leadSkipped ? ' (heads-up window already passed)' : ''}'
                '${result.detail == 'inexact' ? ' · queued inexact: Android denies exact alarms, so it can ring late' : ''}',
          ArmStatus.past =>
            '${event.title} — starts ${_stamp(event.startTime)}, already behind your clock '
                '(${_stamp(DateTime.now())}), so nothing could ring.',
          ArmStatus.rejected =>
            '${event.title} — Android refused the alarm: ${result.detail}',
          ArmStatus.unsupported =>
            '${event.title} — this device reports no local notification support.',
        },
        icon: armed ? (event.alarmEnabled ? Icons.alarm_on : Icons.notifications_active) : Icons.notifications_off,
        color: armed ? event.color : Colors.redAccent,
      );
      notifyListeners();
    });
  }
  void deleteEvent(String id) {
    _events.removeWhere((e) => e.id == id);
    _save(); 
    CloudSyncService().deleteEvent(id);
    NotificationService().cancelReminder(id);
    _seenScheduleStates.removeWhere((k) => k.endsWith(':$id'));
    _dropNotificationsFor('event', id);
    notifyListeners();
  }

  // ── Projects ───────────────────────────────────────────────────────────────
  void addProject(Project project) {
    _projects.insert(0, project);
    _save();
    _trackWrite();
    CloudSyncService().saveProject(project);
    notifyListeners();
  }

  void updateProject(Project project) {
    final idx = _projects.indexWhere((p) => p.id == project.id);
    if (idx != -1) {
      _projects[idx] = project;
      _save();
      _trackWrite();
      CloudSyncService().saveProject(project);
      notifyListeners();
    }
  }

  void deleteProject(String id) {
    final proj = getProject(id);
    if (proj != null) {
      // Clean up project association from linked quotes and invoices
      for (final q in _quotes.where((q) => q.projectId == id)) {
        q.projectId = null;
        q.projectName = null;
        CloudSyncService().saveQuote(q);
      }
      for (final inv in _invoices.where((i) => i.projectId == id)) {
        inv.projectId = null;
        inv.projectName = null;
        CloudSyncService().saveInvoice(inv);
      }
    }
    _projects.removeWhere((p) => p.id == id);
    _save();
    CloudSyncService().deleteProject(id);
    notifyListeners();
  }

  // ── Project Expenses ───────────────────────────────────────────────────────
  void addProjectExpense(String projectId, ProjectExpense expense) {
    final idx = _projects.indexWhere((p) => p.id == projectId);
    if (idx != -1) {
      _projects[idx].expenses.insert(0, expense);
      _projects[idx].updatedAt = DateTime.now();
      _save();
      CloudSyncService().saveProject(_projects[idx]);
      notifyListeners();
    }
  }

  void updateProjectExpense(String projectId, ProjectExpense expense) {
    final pIdx = _projects.indexWhere((p) => p.id == projectId);
    if (pIdx != -1) {
      final eIdx = _projects[pIdx].expenses.indexWhere((e) => e.id == expense.id);
      if (eIdx != -1) {
        _projects[pIdx].expenses[eIdx] = expense;
        _projects[pIdx].updatedAt = DateTime.now();
        _save();
        CloudSyncService().saveProject(_projects[pIdx]);
        notifyListeners();
      }
    }
  }

  void deleteProjectExpense(String projectId, String expenseId) {
    final pIdx = _projects.indexWhere((p) => p.id == projectId);
    if (pIdx != -1) {
      _projects[pIdx].expenses.removeWhere((e) => e.id == expenseId);
      _projects[pIdx].updatedAt = DateTime.now();
      _save();
      CloudSyncService().saveProject(_projects[pIdx]);
      notifyListeners();
    }
  }

  // ── Project Payments ───────────────────────────────────────────────────────
  void addProjectPayment(String projectId, ProjectPayment payment) {
    final idx = _projects.indexWhere((p) => p.id == projectId);
    if (idx != -1) {
      _projects[idx].payments.insert(0, payment);
      _projects[idx].updatedAt = DateTime.now();
      _save();
      CloudSyncService().saveProject(_projects[idx]);
      notifyListeners();
    }
  }

  void updateProjectPayment(String projectId, ProjectPayment payment) {
    final pIdx = _projects.indexWhere((p) => p.id == projectId);
    if (pIdx != -1) {
      final payIdx = _projects[pIdx].payments.indexWhere((pay) => pay.id == payment.id);
      if (payIdx != -1) {
        _projects[pIdx].payments[payIdx] = payment;
        _projects[pIdx].updatedAt = DateTime.now();
        _save();
        CloudSyncService().saveProject(_projects[pIdx]);
        notifyListeners();
      }
    }
  }

  void deleteProjectPayment(String projectId, String paymentId) {
    final pIdx = _projects.indexWhere((p) => p.id == projectId);
    if (pIdx != -1) {
      _projects[pIdx].payments.removeWhere((p) => p.id == paymentId);
      _projects[pIdx].updatedAt = DateTime.now();
      _save();
      CloudSyncService().saveProject(_projects[pIdx]);
      notifyListeners();
    }
  }

  // ── Project Quote & Invoice Linking ────────────────────────────────────────
  void linkQuoteToProject(String projectId, String quoteId) {
    final pIdx = _projects.indexWhere((p) => p.id == projectId);
    if (pIdx != -1) {
      if (!_projects[pIdx].quoteIds.contains(quoteId)) {
        _projects[pIdx].quoteIds.add(quoteId);
        _projects[pIdx].updatedAt = DateTime.now();
      }
      final qIdx = _quotes.indexWhere((q) => q.id == quoteId);
      if (qIdx != -1) {
        _quotes[qIdx].projectId = projectId;
        _quotes[qIdx].projectName = _projects[pIdx].name;
        CloudSyncService().saveQuote(_quotes[qIdx]);
      }
      _save();
      CloudSyncService().saveProject(_projects[pIdx]);
      notifyListeners();
    }
  }

  void unlinkQuoteFromProject(String projectId, String quoteId) {
    final pIdx = _projects.indexWhere((p) => p.id == projectId);
    if (pIdx != -1) {
      _projects[pIdx].quoteIds.remove(quoteId);
      _projects[pIdx].updatedAt = DateTime.now();
      final qIdx = _quotes.indexWhere((q) => q.id == quoteId);
      if (qIdx != -1) {
        _quotes[qIdx].projectId = null;
        _quotes[qIdx].projectName = null;
        CloudSyncService().saveQuote(_quotes[qIdx]);
      }
      _save();
      CloudSyncService().saveProject(_projects[pIdx]);
      notifyListeners();
    }
  }

  void linkInvoiceToProject(String projectId, String invoiceId) {
    final pIdx = _projects.indexWhere((p) => p.id == projectId);
    if (pIdx != -1) {
      if (!_projects[pIdx].invoiceIds.contains(invoiceId)) {
        _projects[pIdx].invoiceIds.add(invoiceId);
        _projects[pIdx].updatedAt = DateTime.now();
      }
      final invIdx = _invoices.indexWhere((i) => i.id == invoiceId);
      if (invIdx != -1) {
        _invoices[invIdx].projectId = projectId;
        _invoices[invIdx].projectName = _projects[pIdx].name;
        CloudSyncService().saveInvoice(_invoices[invIdx]);
      }
      _save();
      CloudSyncService().saveProject(_projects[pIdx]);
      notifyListeners();
    }
  }

  void unlinkInvoiceFromProject(String projectId, String invoiceId) {
    final pIdx = _projects.indexWhere((p) => p.id == projectId);
    if (pIdx != -1) {
      _projects[pIdx].invoiceIds.remove(invoiceId);
      _projects[pIdx].updatedAt = DateTime.now();
      final invIdx = _invoices.indexWhere((i) => i.id == invoiceId);
      if (invIdx != -1) {
        _invoices[invIdx].projectId = null;
        _invoices[invIdx].projectName = null;
        CloudSyncService().saveInvoice(_invoices[invIdx]);
      }
      _save();
      CloudSyncService().saveProject(_projects[pIdx]);
      notifyListeners();
    }
  }

  // ── Data Management ───────────────────────────────────────────────────────
  void clearAllQuotes() { _quotes.clear(); _save(); notifyListeners(); }

  Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _clients.clear(); _products.clear(); _quotes.clear();
    _invoices.clear(); _tasks.clear(); _events.clear();
    _projects.clear();
    _loaded = false;
    await _seedDefaults();
    _uploadProductsToCloud();
    notifyListeners();
  }
}

/// A signature read back from the cloud document of a shared quote/invoice.
class _CloudSignature {
  const _CloudSignature(this.signatureData, this.signedAt, this.meta);
  final String signatureData;
  final DateTime signedAt;
  final SignatureMetadata meta;
}
