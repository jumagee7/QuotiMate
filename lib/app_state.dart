// app_state.dart — QuotiMate state with SharedPreferences persistence

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

class AppState extends ChangeNotifier {
  // ── Persistent lists ───────────────────────────────────────────────────────
  final List<Client> _clients = [];
  final List<Product> _products = [];
  final List<Quote> _quotes = [];
  final List<Invoice> _invoices = [];
  final List<AppTask> _tasks = [];
  final List<AppEvent> _events = [];
  final List<Project> _projects = [];

  // ── Non-persistent (session only) ─────────────────────────────────────────
  final List<AppNotification> _notifications = [];

  // ── Settings ───────────────────────────────────────────────────────────────
  String companyName = 'MAJUMA INTERIORS';
  String companyPhone = '0710272083';
  String companyEmail = 'jumaink19@gmail.com';
  String companyAddress = 'Nairobi, Kenya';
  String companyKraPin = 'A011821254M';
  String preparedBy = 'Admin';
  int defaultExpiryDays = 30;
  String currency = 'Ksh';
  String pdfTemplate = 'majuma';
  double defaultVatPercent = 0.0;
  String defaultPaymentTerms = '70% Advance, 30% on Completion';
  String defaultNotes = 'Validity: 30 days.';
  bool notificationsEnabled = true;
  int nextQuoteNumber = 1001;

  // ── User Profile ───────────────────────────────────────────────────────────
  String userName = '';
  String userEmail = '';
  String userRole = 'Admin';
  String userPhotoUrl = '';

  // ── Init ───────────────────────────────────────────────────────────────────
  bool _loaded = false;
  bool _productsRetrievalToastShown = false;

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
    await notifications.cancelAllReminders();
    for (final t in _tasks) {
      if (t.status != TaskStatus.done) {
        await notifications.scheduleEventReminder(
          id: t.id,
          title: 'Task Due: ${t.title}',
          body: t.description,
          scheduledTime: t.dueDate,
          alarm: t.alarmEnabled,
        );
      }
    }
    for (final e in _events) {
      await notifications.scheduleEventReminders(
        id: e.id,
        title: e.title,
        description: e.description,
        startTime: e.startTime,
        alarm: e.alarmEnabled,
      );
    }
  }

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
  static const _kActivities = 'qm_activities';
  static const _kSettings  = 'qm_settings';
  static const _kProfile   = 'qm_profile';
  static const _kSeeded    = 'qm_seeded';

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
    final activitiesRaw = prefs.getString(_kActivities);
    if (activitiesRaw != null) {
      try {
        _activities
          ..clear()
          ..addAll((jsonDecode(activitiesRaw) as List).map((e) => ActivityEntry.fromJson(e as Map<String, dynamic>)));
      } catch (e) {
        debugPrint('Activity log load error: $e');
      }
    }
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
    await prefs.setString(_kActivities, jsonEncode(_activities.map((e) => e.toJson()).toList()));
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
      'nextQuoteNumber': nextQuoteNumber,
    }));
    await prefs.setString(_kProfile, jsonEncode({
      'userName': userName, 'userEmail': userEmail, 'userRole': userRole,
    }));
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

  int    get unreadCount         => _notifications.where((n) => !n.isRead).length;
  int    quoteCountForClient(String clientId) => _quotes.where((q) => q.clientId == clientId).length;
  String get nextClientId        => 'C-${DateTime.now().millisecondsSinceEpoch}';
  String get nextProductId       => 'P-${DateTime.now().millisecondsSinceEpoch}';
  String get nextTaskId          => 'T-${DateTime.now().millisecondsSinceEpoch}';
  String get nextEventId         => 'EV-${DateTime.now().millisecondsSinceEpoch}';
  String get nextProjectId       => 'PRJ-${DateTime.now().millisecondsSinceEpoch}';
  String get nextExpenseId       => 'EXP-${DateTime.now().millisecondsSinceEpoch}';
  String get nextPaymentId       => 'PAY-${DateTime.now().millisecondsSinceEpoch}';

  // ── Product catalogue lookups (for item suggestions) ──────────────────────
  List<String> get productNames => _products.map((p) => p.name).toList();
  Product? productByName(String name) {
    final idx = _products.indexWhere((p) => p.name.toLowerCase() == name.toLowerCase());
    return idx == -1 ? null : _products[idx];
  }

  List<Quote>  get pinnedQuotes  => _quotes.where((q) => q.isPinned).toList();
  List<ActivityEntry> get activities => List.unmodifiable(_activities);

  final List<ActivityEntry> _activities = [];

  void logActivity(String title, ActivityType type) {
    _activities.insert(0, ActivityEntry(
      id: 'act_${DateTime.now().microsecondsSinceEpoch}',
      title: title,
      type: type,
      timestamp: DateTime.now(),
    ));
    if (_activities.length > 100) _activities.removeRange(100, _activities.length);
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
    notifyListeners();
  }

  void markNotificationRead(String id) {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx != -1) { _notifications[idx].isRead = true; notifyListeners(); }
  }

  void addNotification(AppNotification notification) {
    _notifications.insert(0, notification);
    notifyListeners();
  }

  // ── Settings ───────────────────────────────────────────────────────────────
  void updateSettings({
    String? companyName, String? companyPhone, String? companyEmail,
    String? companyAddress, String? companyKraPin, String? preparedBy,
    int? defaultExpiryDays,
    String? currency, String? pdfTemplate, double? defaultVatPercent,
    String? defaultPaymentTerms, String? defaultNotes, bool? notificationsEnabled,
    int? nextQuoteNumber,
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
    if (notificationsEnabled!= null) this.notificationsEnabled= notificationsEnabled;
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
      'nextQuoteNumber': this.nextQuoteNumber,
    });
    notifyListeners();
  }

  void resetSettingsToDefaults() {
    companyName = 'MAJUMA INTERIORS';
    companyPhone = '0710272083';
    companyEmail = 'jumaink19@gmail.com';
    companyAddress = 'Nairobi, Kenya';
    companyKraPin = 'A011821254M';
    preparedBy = 'Admin';
    defaultExpiryDays = 30;
    currency = 'Ksh';
    pdfTemplate = 'majuma';
    defaultVatPercent = 0.0;
    defaultPaymentTerms = 'Payment due within 30 days of invoice date.';
    defaultNotes = 'Thank you for your business!';
    notificationsEnabled = true;
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
      'notificationsEnabled': notificationsEnabled,
    });
    notifyListeners();
  }

  // ── Clients ────────────────────────────────────────────────────────────────
  void addClient(Client client) {
    logActivity('Client "${client.name}" added', ActivityType.client);
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
    logActivity('Product "${product.name}" added', ActivityType.product);
    _products.add(product);
    _save();
    CloudSyncService().saveProduct(product);
    notifyListeners();
  }
  void updateProduct(Product product) {
    logActivity('Product "${product.name}" updated', ActivityType.product);
    final idx = _products.indexWhere((p) => p.id == product.id);
    if (idx != -1) {
      _products[idx] = product;
      _save();
      CloudSyncService().saveProduct(product);
      notifyListeners();
    }
  }
  /// Quote items whose name doesn't match any catalogue product (deduplicated).
  List<QuoteItem> findItemsNotInCatalogue(Iterable<QuoteItem> items) {
    final known = _products.map((p) => p.name.trim().toLowerCase()).toSet();
    final seen = <String>{};
    final result = <QuoteItem>[];
    for (final i in items) {
      final key = i.name.trim().toLowerCase();
      if (key.isEmpty || known.contains(key) || !seen.add(key)) continue;
      result.add(i);
    }
    return result;
  }

  void addProductsFromItems(List<QuoteItem> items) {
    if (items.isEmpty) return;
    final base = DateTime.now().millisecondsSinceEpoch;
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final product = Product(
        id: 'p_${base}_$i',
        name: item.name.trim(),
        unitPrice: item.unitPrice,
        unit: item.unit,
      );
      _products.add(product);
      CloudSyncService().saveProduct(product);
    }
    logActivity('Added ${items.length} new product(s) to catalogue', ActivityType.product);
    _save();
    notifyListeners();
  }

  void deleteProduct(String id) {
    _products.removeWhere((p) => p.id == id);
    _save();
    CloudSyncService().deleteProduct(id);
    notifyListeners();
  }

  // ── Quotes ─────────────────────────────────────────────────────────────────
  void addQuote(Quote quote) {
    logActivity('Quotation #${quote.id} created for ${quote.clientName}', ActivityType.quote);
    _quotes.add(quote);
    _save();
    CloudSyncService().saveQuote(quote);
    notifyListeners();
  }
  void updateQuote(Quote quote) {
    logActivity('Quotation #${quote.id} updated (${quote.status.name})', ActivityType.quote);
    final idx = _quotes.indexWhere((q) => q.id == quote.id);
    if (idx != -1) {
      _quotes[idx] = quote;
      _save();
      CloudSyncService().saveQuote(quote);
      notifyListeners();
    }
  }
  void deleteQuote(String id) {
    logActivity('Quotation #$id deleted', ActivityType.quote);
    _quotes.removeWhere((q) => q.id == id);
    final lastIssued = nextQuoteNumber - 1;
    if (id == 'Q-$lastIssued') {
      nextQuoteNumber = lastIssued;
      CloudSyncService().releaseQuoteNumber(lastIssued);
    }
    _save();
    CloudSyncService().deleteQuote(id);
    notifyListeners();
  }

  /// Reserves a new sequential quote ID (e.g. `Q-1005`) from the cloud.
  /// Returns null when offline — quote numbers are only issued online so that
  /// numbering stays unique across devices.
  Future<String?> reserveQuoteId() async {
    final taken = <int>{};
    for (final q in _quotes) {
      final n = int.tryParse(q.id.replaceFirst('Q-', ''));
      if (n != null) taken.add(n);
    }
    final number = await CloudSyncService().reserveNextQuoteNumber(nextQuoteNumber, taken: taken);
    if (number == null) return null;
    nextQuoteNumber = number + 1;
    _save();
    notifyListeners();
    return 'Q-$number';
  }

  void markQuoteSigned(String quoteId, String signatureBase64, [DateTime? signedAt, SignerInfo? signerInfo]) {
    logActivity('Quotation #$quoteId signed by client', ActivityType.signature);
    final idx = _quotes.indexWhere((q) => q.id == quoteId);
    if (idx != -1) {
      _quotes[idx].signatureData = signatureBase64;
      _quotes[idx].signedAt = signedAt ?? DateTime.now();
      if (signerInfo != null) _quotes[idx].signerInfo = signerInfo;
      _quotes[idx].status = QuoteStatus.approved;
      _save();
      CloudSyncService().saveQuote(_quotes[idx]);
      notifyListeners();
    }
  }

  void markInvoiceSigned(String invoiceId, String signatureBase64, [DateTime? signedAt, SignerInfo? signerInfo]) {
    logActivity('Invoice #$invoiceId signed by client', ActivityType.signature);
    final idx = _invoices.indexWhere((i) => i.id == invoiceId);
    if (idx != -1) {
      _invoices[idx].signatureData = signatureBase64;
      _invoices[idx].signedAt = signedAt ?? DateTime.now();
      if (signerInfo != null) _invoices[idx].signerInfo = signerInfo;
      _save();
      CloudSyncService().saveInvoice(_invoices[idx]);
      notifyListeners();
    }
  }

  Future<bool> checkCloudSignatureForQuote(String quoteId) async {
    final data = await CloudSyncService().fetchQuoteFromCloud(quoteId);
    if (data != null && data['signatureData'] != null) {
      final sig = data['signatureData'] as String;
      if (sig.isNotEmpty) {
        final signedAt = data['signedAt'] != null
            ? DateTime.tryParse(data['signedAt'].toString())
            : DateTime.now();
        final signer = data['signerInfo'] is Map
            ? SignerInfo.fromJson(Map<String, dynamic>.from(data['signerInfo'] as Map))
            : null;
        markQuoteSigned(quoteId, sig, signedAt, signer);
        return true;
      }
    }
    return false;
  }

  Future<bool> checkCloudSignatureForInvoice(String invoiceId) async {
    final data = await CloudSyncService().fetchInvoiceFromCloud(invoiceId);
    if (data != null && data['signatureData'] != null) {
      final sig = data['signatureData'] as String;
      if (sig.isNotEmpty) {
        final signedAt = data['signedAt'] != null
            ? DateTime.tryParse(data['signedAt'].toString())
            : DateTime.now();
        final signer = data['signerInfo'] is Map
            ? SignerInfo.fromJson(Map<String, dynamic>.from(data['signerInfo'] as Map))
            : null;
        markInvoiceSigned(invoiceId, sig, signedAt, signer);
        return true;
      }
    }
    return false;
  }

  String generateShareToken() {
    final rand = dartMath.Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  // ── Invoices ───────────────────────────────────────────────────────────────
  void addInvoice(Invoice invoice) {
    logActivity('Invoice #${invoice.id} created for ${invoice.clientName}', ActivityType.invoice);
    final idx = _invoices.indexWhere((i) => i.id == invoice.id);
    if (idx != -1) {
      _invoices[idx] = invoice;
    } else {
      _invoices.insert(0, invoice);
    }
    _save();
    CloudSyncService().saveInvoice(invoice);
    notifyListeners();
  }

  void updateInvoice(Invoice invoice) {
    final idx = _invoices.indexWhere((i) => i.id == invoice.id);
    if (idx != -1) {
      _invoices[idx] = invoice;
      _save();
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
    logActivity('Invoice #$invoiceId marked ${newStatus.name}', ActivityType.invoice);
    final idx = _invoices.indexWhere((i) => i.id == invoiceId);
    if (idx != -1) {
      _invoices[idx].status = newStatus;
      _save();
      CloudSyncService().saveInvoice(_invoices[idx]);
      notifyListeners();
    }
  }

  // ── Tasks ──────────────────────────────────────────────────────────────────
  void addTask(AppTask task) {
    logActivity('Task "${task.title}" added', ActivityType.task);
    _tasks.add(task);
    _save();
    CloudSyncService().saveTask(task);
    if (task.status != TaskStatus.done) {
      NotificationService().scheduleEventReminder(id: task.id, title: 'Task Due: ${task.title}', body: task.description, scheduledTime: task.dueDate, alarm: task.alarmEnabled);
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
        NotificationService().scheduleEventReminder(id: task.id, title: 'Task Due: ${task.title}', body: task.description, scheduledTime: task.dueDate, alarm: task.alarmEnabled);
      }
      notifyListeners();
    }
  }
  List<AppTask> tasksForProject(String projectId) =>
      _tasks.where((t) => t.projectId == projectId).toList();

  void deleteTask(String id) {
    _tasks.removeWhere((t) => t.id == id);
    _save(); 
    CloudSyncService().deleteTask(id);
    NotificationService().cancelReminder(id);
    notifyListeners();
  }

  // ── Events ────────────────────────────────────────────────────────────────
  void addEvent(AppEvent event) {
    logActivity('Event "${event.title}" scheduled', ActivityType.event);
    _events.add(event);
    _save();
    CloudSyncService().saveEvent(event);
    NotificationService().scheduleEventReminders(id: event.id, title: event.title, description: event.description, startTime: event.startTime, alarm: event.alarmEnabled);
    notifyListeners();
  }
  void updateEvent(AppEvent event) {
    final idx = _events.indexWhere((e) => e.id == event.id);
    if (idx != -1) {
      _events[idx] = event;
      _save();
      CloudSyncService().saveEvent(event);
      NotificationService().scheduleEventReminders(id: event.id, title: event.title, description: event.description, startTime: event.startTime, alarm: event.alarmEnabled);
      notifyListeners();
    }
  }
  void deleteEvent(String id) {
    _events.removeWhere((e) => e.id == id);
    _save(); 
    CloudSyncService().deleteEvent(id);
    NotificationService().cancelReminder(id);
    notifyListeners();
  }

  // ── Projects ───────────────────────────────────────────────────────────────
  void addProject(Project project) {
    logActivity('Project "${project.name}" created', ActivityType.project);
    _projects.insert(0, project);
    _save();
    CloudSyncService().saveProject(project);
    notifyListeners();
  }

  void updateProject(Project project) {
    final idx = _projects.indexWhere((p) => p.id == project.id);
    if (idx != -1) {
      _projects[idx] = project;
      _save();
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
  void addProjectNote(String projectId, ProjectNote note) {
    final project = getProject(projectId);
    if (project == null) return;
    updateProject(project.copyWith(notes: [note, ...project.notes]));
    logActivity('Note added to project ${project.name}', ActivityType.project);
  }

  void deleteProjectNote(String projectId, String noteId) {
    final project = getProject(projectId);
    if (project == null) return;
    updateProject(project.copyWith(notes: project.notes.where((n) => n.id != noteId).toList()));
  }

  void setProjectSummaryImages(String projectId, List<String> images) {
    final project = getProject(projectId);
    if (project == null) return;
    updateProject(project.copyWith(summaryImages: images));
  }

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
    logActivity('Payment recorded on project ${getProject(projectId)?.name ?? projectId}', ActivityType.payment);
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