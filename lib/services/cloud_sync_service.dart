// services/cloud_sync_service.dart — Realtime Cloud Sync Service for QuotiMate
// Synchronizes quotes, invoices, clients, products, tasks, schedules, and quote numbers.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models.dart';

enum SyncStatus { offline, syncing, synced, error }

class CloudSyncService extends ChangeNotifier {
  static final CloudSyncService _instance = CloudSyncService._internal();
  factory CloudSyncService() => _instance;
  CloudSyncService._internal();

  bool _isInitialized = false;
  bool _firebaseAvailable = false;
  SyncStatus _status = SyncStatus.offline;
  String _statusMessage = 'Offline';

  SyncStatus get status => _status;
  String get statusMessage => _statusMessage;
  bool get isOnline => _firebaseAvailable && _status == SyncStatus.synced;

  // Stream subscriptions for real-time updates
  StreamSubscription? _quotesSub;
  StreamSubscription? _invoicesSub;
  StreamSubscription? _clientsSub;
  StreamSubscription? _productsSub;
  StreamSubscription? _tasksSub;
  StreamSubscription? _eventsSub;
  StreamSubscription? _projectsSub;
  StreamSubscription? _settingsSub;

  /// Docs received from each collection since the listeners started, and the
  /// last read error per collection. Firestore rules are evaluated per
  /// collection, so one denied read does not mean the others failed.
  final Map<String, int> _collectionCounts = {};
  final Map<String, String> _collectionErrors = {};
  Map<String, int> get collectionCounts => Map.unmodifiable(_collectionCounts);
  Map<String, String> get collectionErrors => Map.unmodifiable(_collectionErrors);

  void _recordCount(String collection, int count) {
    final changed = _collectionCounts[collection] != count ||
        _collectionErrors.containsKey(collection);
    _collectionCounts[collection] = count;
    _collectionErrors.remove(collection);
    if (changed) notifyListeners();
  }

  /// Stores a read failure and reports it once per attempt. A missing Firebase
  /// session is called out separately because it is a sign-in problem, not a
  /// rules problem.
  void _recordError(
    String collection,
    Object error, {
    void Function(String collection, String error)? onSyncError,
  }) {
    final text = FirebaseAuth.instance.currentUser == null
        ? 'Not signed in to Firebase — sign out and sign in again'
        : error.toString();
    _collectionErrors[collection] = text;
    debugPrint('$collection sync error: $error');
    onSyncError?.call(collection, text);
    notifyListeners();
  }

  /// Reports a read/write rejection raised outside a collection listener, such
  /// as the product backfill, so it shows up in the per-area status.
  void noteReadError(String collection, Object error) {
    _recordError(collection, error);
  }

  // Collections references
  CollectionReference? get _quotesCol =>
      _firebaseAvailable ? FirebaseFirestore.instance.collection('quotimate_quotes') : null;
  CollectionReference? get _invoicesCol =>
      _firebaseAvailable ? FirebaseFirestore.instance.collection('quotimate_invoices') : null;
  CollectionReference? get _clientsCol =>
      _firebaseAvailable ? FirebaseFirestore.instance.collection('quotimate_clients') : null;
  CollectionReference? get _productsCol =>
      _firebaseAvailable ? FirebaseFirestore.instance.collection('quotimate_products') : null;
  CollectionReference? get _tasksCol =>
      _firebaseAvailable ? FirebaseFirestore.instance.collection('quotimate_tasks') : null;
  CollectionReference? get _eventsCol =>
      _firebaseAvailable ? FirebaseFirestore.instance.collection('quotimate_events') : null;
  CollectionReference? get _projectsCol =>
      _firebaseAvailable ? FirebaseFirestore.instance.collection('quotimate_projects') : null;
  DocumentReference? get _settingsDoc =>
      _firebaseAvailable ? FirebaseFirestore.instance.collection('quotimate_settings').doc('global') : null;

  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;

    try {
      if (Firebase.apps.isNotEmpty) {
        _firebaseAvailable = true;
        _setStatus(SyncStatus.synced, 'Cloud Connected');
      } else {
        _setStatus(SyncStatus.offline, 'Local Storage (Cloud Ready)');
      }
    } catch (_) {
      _firebaseAvailable = false;
      _setStatus(SyncStatus.offline, 'Local Storage');
    }
  }

  void _setStatus(SyncStatus s, String msg) {
    _status = s;
    _statusMessage = msg;
    notifyListeners();
  }

  // ── Start Realtime Listeners ───────────────────────────────────────────────
  void startListening({
    required Function(List<Quote>) onQuotesUpdated,
    required Function(List<Invoice>) onInvoicesUpdated,
    required Function(List<Client>) onClientsUpdated,
    required Function(List<Product>) onProductsUpdated,
    required Function(List<AppTask>) onTasksUpdated,
    required Function(List<AppEvent>) onEventsUpdated,
    required Function(List<Project>) onProjectsUpdated,
    required Function(Map<String, dynamic>) onSettingsUpdated,
    void Function(String collection, String error)? onSyncError,
  }) {
    if (!_firebaseAvailable) return;
    // Firestore reads are authorised by the live Firebase session, not by the
    // profile cached in prefs. Starting listeners before sign-in made every
    // collection return permission_denied (and only products surfaced it).
    if (FirebaseAuth.instance.currentUser == null) {
      debugPrint('Cloud sync skipped: no Firebase session');
      return;
    }

    // A fresh listen pass re-reads every collection, so old results are stale.
    _collectionCounts.clear();
    _collectionErrors.clear();

    // Listen to Quotes
    _quotesSub?.cancel();
    _quotesSub = _quotesCol?.snapshots().listen((snap) {
      final quotes = snap.docs.map((d) {
        final data = d.data() as Map<String, dynamic>;
        data['id'] = d.id;
        return Quote.fromJson(data);
      }).toList();
      _recordCount('quotations', quotes.length);
      onQuotesUpdated(quotes);
    }, onError: (e) => _recordError('quotations', e, onSyncError: onSyncError));

    // Listen to Invoices
    _invoicesSub?.cancel();
    _invoicesSub = _invoicesCol?.snapshots().listen((snap) {
      final invoices = snap.docs.map((d) {
        final data = d.data() as Map<String, dynamic>;
        data['id'] = d.id;
        return Invoice.fromJson(data);
      }).toList();
      _recordCount('invoices', invoices.length);
      onInvoicesUpdated(invoices);
    }, onError: (e) => _recordError('invoices', e, onSyncError: onSyncError));

    // Listen to Clients
    _clientsSub?.cancel();
    _clientsSub = _clientsCol?.snapshots().listen((snap) {
      final clients = snap.docs.map((d) {
        final data = d.data() as Map<String, dynamic>;
        data['id'] = d.id;
        return Client.fromJson(data);
      }).toList();
      _recordCount('clients', clients.length);
      onClientsUpdated(clients);
    }, onError: (e) => _recordError('clients', e, onSyncError: onSyncError));

    // Listen to Products
    _productsSub?.cancel();
    _productsSub = _productsCol?.snapshots().listen((snap) {
      final products = snap.docs.map((d) {
        final data = d.data() as Map<String, dynamic>;
        data['id'] = d.id;
        return Product.fromJson(data);
      }).toList();
      _recordCount('products', products.length);
      onProductsUpdated(products);
    }, onError: (e) => _recordError('products', e, onSyncError: onSyncError));

    // Listen to Tasks
    _tasksSub?.cancel();
    _tasksSub = _tasksCol?.snapshots().listen((snap) {
      final tasks = snap.docs.map((d) {
        final data = d.data() as Map<String, dynamic>;
        data['id'] = d.id;
        return AppTask.fromJson(data);
      }).toList();
      _recordCount('tasks', tasks.length);
      onTasksUpdated(tasks);
    }, onError: (e) => _recordError('tasks', e, onSyncError: onSyncError));

    // Listen to Events / Schedules
    _eventsSub?.cancel();
    _eventsSub = _eventsCol?.snapshots().listen((snap) {
      final events = snap.docs.map((d) {
        final data = d.data() as Map<String, dynamic>;
        data['id'] = d.id;
        return AppEvent.fromJson(data);
      }).toList();
      _recordCount('schedules', events.length);
      onEventsUpdated(events);
    }, onError: (e) => _recordError('schedules', e, onSyncError: onSyncError));

    // Listen to Projects
    _projectsSub?.cancel();
    _projectsSub = _projectsCol?.snapshots().listen((snap) {
      final projects = snap.docs.map((d) {
        final data = d.data() as Map<String, dynamic>;
        data['id'] = d.id;
        return Project.fromJson(data);
      }).toList();
      _recordCount('projects', projects.length);
      onProjectsUpdated(projects);
    }, onError: (e) => _recordError('projects', e, onSyncError: onSyncError));

    // Listen to Settings & Next Quote Number
    _settingsSub?.cancel();
    _settingsSub = _settingsDoc?.snapshots().listen((snap) {
      _recordCount('settings', snap.exists ? 1 : 0);
      if (snap.exists) {
        final data = snap.data() as Map<String, dynamic>? ?? {};
        onSettingsUpdated(data);
      }
    }, onError: (e) => _recordError('settings', e, onSyncError: onSyncError));
  }

  // ── Sync Operations ────────────────────────────────────────────────────────
  Future<void> saveQuote(Quote quote) async {
    if (!_firebaseAvailable) return;
    try {
      _setStatus(SyncStatus.syncing, 'Syncing Quote...');
      await _quotesCol?.doc(quote.id).set(quote.toJson(), SetOptions(merge: true));
      _setStatus(SyncStatus.synced, 'Cloud Synced');
    } catch (e) {
      debugPrint('Save Quote error: $e');
      _setStatus(SyncStatus.error, 'Sync Error');
    }
  }

  Future<void> deleteQuote(String quoteId) async {
    if (!_firebaseAvailable) return;
    try {
      await _quotesCol?.doc(quoteId).delete();
    } catch (e) {
      debugPrint('Delete Quote error: $e');
    }
  }

  Future<Map<String, dynamic>?> fetchQuoteFromCloud(String quoteId) async {
    if (!_firebaseAvailable) return null;
    try {
      final doc = await _quotesCol?.doc(quoteId).get();
      if (doc != null && doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null) {
          data['id'] = doc.id;
          return data;
        }
      }
    } catch (e) {
      debugPrint('Fetch Quote error: $e');
    }
    return null;
  }

  Future<void> saveInvoice(Invoice invoice) async {
    if (!_firebaseAvailable) return;
    try {
      _setStatus(SyncStatus.syncing, 'Syncing Invoice...');
      await _invoicesCol?.doc(invoice.id).set(invoice.toJson(), SetOptions(merge: true));
      _setStatus(SyncStatus.synced, 'Cloud Synced');
    } catch (e) {
      debugPrint('Save Invoice error: $e');
      _setStatus(SyncStatus.error, 'Sync Error');
    }
  }

  Future<void> deleteInvoice(String invoiceId) async {
    if (!_firebaseAvailable) return;
    try {
      await _invoicesCol?.doc(invoiceId).delete();
    } catch (e) {
      debugPrint('Delete Invoice error: $e');
    }
  }

  Future<Map<String, dynamic>?> fetchInvoiceFromCloud(String invoiceId) async {
    if (!_firebaseAvailable) return null;
    try {
      final doc = await _invoicesCol?.doc(invoiceId).get();
      if (doc != null && doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null) {
          data['id'] = doc.id;
          return data;
        }
      }
    } catch (e) {
      debugPrint('Fetch Invoice error: $e');
    }
    return null;
  }

  Future<void> saveClient(Client client) async {
    if (!_firebaseAvailable) return;
    try {
      await _clientsCol?.doc(client.id).set(client.toJson(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('Save Client error: $e');
    }
  }

  Future<void> deleteClient(String clientId) async {
    if (!_firebaseAvailable) return;
    try {
      await _clientsCol?.doc(clientId).delete();
    } catch (e) {
      debugPrint('Delete Client error: $e');
    }
  }

  /// Legacy demo product ids (Website Design / Logo Design / SEO Package) that
  /// were seeded by mistake in earlier versions and must not live in the cloud.
  static const _legacyProductIds = {'p1', 'p2', 'p3'};

  /// Uploads any local products whose ids don't exist yet in the cloud collection,
  /// and removes legacy demo products from the cloud.
  /// Returns the number of products uploaded.
  Future<int> ensureProductsInCloud(List<Product> localProducts) async {
    if (!_firebaseAvailable) return 0;
    final snapshot = await _productsCol?.get();
    final existingIds = snapshot?.docs.map((d) => d.id).toSet() ?? <String>{};

    // Purge legacy demo docs that are no longer part of the local catalogue
    final legacyDocs = snapshot?.docs
            .where((d) => _legacyProductIds.contains(d.id) && !localProducts.any((p) => p.id == d.id))
            .toList() ??
        const [];
    if (legacyDocs.isNotEmpty) {
      final purge = FirebaseFirestore.instance.batch();
      for (final d in legacyDocs) {
        purge.delete(_productsCol!.doc(d.id));
      }
      await purge.commit();
      debugPrint('Purged ${legacyDocs.length} legacy demo products from cloud');
    }

    final missing = localProducts.where((p) => !existingIds.contains(p.id)).toList();
    if (missing.isEmpty) return 0;
    final batch = FirebaseFirestore.instance.batch();
    for (final p in missing) {
      batch.set(_productsCol!.doc(p.id), p.toJson(), SetOptions(merge: true));
    }
    await batch.commit();
    debugPrint('Uploaded ${missing.length} products to cloud');
    return missing.length;
  }

  Future<void> saveProduct(Product product) async {
    if (!_firebaseAvailable) return;
    try {
      await _productsCol?.doc(product.id).set(product.toJson(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('Save Product error: $e');
    }
  }

  Future<void> deleteProduct(String productId) async {
    if (!_firebaseAvailable) return;
    try {
      await _productsCol?.doc(productId).delete();
    } catch (e) {
      debugPrint('Delete Product error: $e');
    }
  }

  Future<void> saveTask(AppTask task) async {
    if (!_firebaseAvailable) return;
    try {
      await _tasksCol?.doc(task.id).set(task.toJson(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('Save Task error: $e');
    }
  }

  Future<void> deleteTask(String taskId) async {
    if (!_firebaseAvailable) return;
    try {
      await _tasksCol?.doc(taskId).delete();
    } catch (e) {
      debugPrint('Delete Task error: $e');
    }
  }

  Future<void> saveEvent(AppEvent event) async {
    if (!_firebaseAvailable) return;
    try {
      await _eventsCol?.doc(event.id).set(event.toJson(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('Save Event error: $e');
    }
  }

  Future<void> deleteEvent(String eventId) async {
    if (!_firebaseAvailable) return;
    try {
      await _eventsCol?.doc(eventId).delete();
    } catch (e) {
      debugPrint('Delete Event error: $e');
    }
  }

  Future<void> saveSettings(Map<String, dynamic> settingsMap) async {
    if (!_firebaseAvailable) return;
    try {
      await _settingsDoc?.set(settingsMap, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Save Settings error: $e');
    }
  }

  // Atomically increment and get the next sequential quote number in cloud
  Future<int> getAndIncrementNextQuoteNumber(int currentFallback) async {
    if (!_firebaseAvailable) return currentFallback;
    try {
      final docRef = _settingsDoc;
      if (docRef == null) return currentFallback;

      return await FirebaseFirestore.instance.runTransaction<int>((tx) async {
        final snapshot = await tx.get(docRef);
        int stored = currentFallback;
        if (snapshot.exists) {
          final data = snapshot.data() as Map<String, dynamic>?;
          stored = data?['nextQuoteNumber'] as int? ?? currentFallback;
        }
        // Never hand out a number below what this device already knows about,
        // otherwise a stale cloud counter would re-issue existing numbers.
        final nextNum = stored > currentFallback ? stored : currentFallback;
        tx.set(docRef, {'nextQuoteNumber': nextNum + 1}, SetOptions(merge: true));
        return nextNum;
      });
    } catch (e) {
      debugPrint('Increment quote number error: $e');
      return currentFallback;
    }
  }

  Future<void> saveProject(Project project) async {
    if (!_firebaseAvailable) return;
    try {
      await _projectsCol?.doc(project.id).set(project.toJson(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('Save Project error: $e');
    }
  }

  Future<void> deleteProject(String projectId) async {
    if (!_firebaseAvailable) return;
    try {
      await _projectsCol?.doc(projectId).delete();
    } catch (e) {
      debugPrint('Delete Project error: $e');
    }
  }

  void stopListening() {
    _quotesSub?.cancel();
    _invoicesSub?.cancel();
    _clientsSub?.cancel();
    _productsSub?.cancel();
    _tasksSub?.cancel();
    _eventsSub?.cancel();
    _projectsSub?.cancel();
    _settingsSub?.cancel();
    _collectionCounts.clear();
    _collectionErrors.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    stopListening();
    super.dispose();
  }
}
