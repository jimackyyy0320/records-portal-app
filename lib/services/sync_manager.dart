import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';
import '../config/app_config.dart';
import 'api_service.dart';
import 'local_database.dart';
import 'session_service.dart';

/// Top-level background entrypoint for Android WorkManager.
/// Executes in a separate background isolate when internet connectivity returns.
@pragma('vm:entry-point')
void portalWorkmanagerDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      final ok = await executeHeadlessBatchSync();
      return ok;
    } catch (_) {
      return false;
    }
  });
}

/// Shared batch sync routine safe to run in both foreground UI and WorkManager isolate.
/// Strictly requires an active Faculty session before syncing attendance/recitation logs.
Future<bool> executeHeadlessBatchSync() async {
  final session = await SessionService.instance.restoreSession();
  if (session == null || !session.isFaculty) {
    return false;
  }

  final scriptUrl = await AppConfig.getScriptUrl();
  if (!AppConfig.isConfiguredUrl(scriptUrl)) {
    return true;
  }

  // Drain pending logs in batches of up to 100 rows per HTTP POST
  while (true) {
    final pending = await LocalDatabase.instance.getUnsyncedScans(limit: 100);
    if (pending.isEmpty) return true;

    try {
      final res = await ApiService.instance.syncScanBatch(pending);
      if (res['success'] == true) {
        final synced = (res['syncedIds'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const <String>[];
        final duplicates = (res['duplicateIds'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const <String>[];
        final allConfirmed = <String>[...synced, ...duplicates];
        await LocalDatabase.instance.markSynced(allConfirmed);

        final failedList = res['failed'] as List?;
        if (failedList != null && failedList.isNotEmpty) {
          final failedIds = <String>[];
          String reason = 'Validation error';
          for (final item in failedList.whereType<Map>()) {
            final id = item['logId']?.toString();
            if (id != null && id.isNotEmpty) failedIds.add(id);
            if (item['reason'] != null) reason = item['reason'].toString();
          }
          await LocalDatabase.instance.markFailed(failedIds, reason);
          // Break to avoid tight infinite loop on malformed records
          if (allConfirmed.isEmpty) return true;
        }
      } else {
        final msg = res['message']?.toString() ?? 'Batch sync rejected.';
        await LocalDatabase.instance.markFailed(
          pending.map((e) => e.logId).toList(),
          msg,
        );
        return false;
      }
    } catch (err) {
      await LocalDatabase.instance.markFailed(
        pending.map((e) => e.logId).toList(),
        err.toString(),
      );
      return false;
    }
  }
}

class SyncManager extends ChangeNotifier {
  SyncManager._();

  static final SyncManager instance = SyncManager._();

  bool _initialized = false;
  bool _isOnline = true;
  bool _isSyncing = false;
  int _pendingCount = 0;
  DateTime? _lastSyncTime;
  String? _lastError;

  StreamSubscription<List<ConnectivityResult>>? _connSub;
  Timer? _debounceTimer;
  Timer? _periodicForegroundTimer;

  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;
  int get pendingCount => _pendingCount;
  DateTime? get lastSyncTime => _lastSyncTime;
  String? get lastError => _lastError;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // 1. Initialize OS-level Android WorkManager for background offline-to-online sync
    try {
      await Workmanager().initialize(portalWorkmanagerDispatcher);
      await Workmanager().registerPeriodicTask(
        AppConfig.wmPeriodicSyncUniqueName,
        AppConfig.wmTaskSyncScans,
        frequency: const Duration(minutes: 15),
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      );
    } catch (_) {}

    // 2. Check initial connectivity & pending count
    await refreshPendingCount();
    final initialResults = await Connectivity().checkConnectivity();
    _updateConnectivity(initialResults, triggerSyncIfRestored: true);

    // 3. Subscribe to real-time connectivity transitions
    _connSub = Connectivity().onConnectivityChanged.listen((results) {
      _updateConnectivity(results, triggerSyncIfRestored: true);
    });

    // 4. Foreground safety sweep every 45s while app is open
    _periodicForegroundTimer = Timer.periodic(
      const Duration(seconds: 45),
      (_) {
        if (_isOnline && _pendingCount > 0 && !_isSyncing) {
          syncNow();
        }
      },
    );
  }

  void _updateConnectivity(
    List<ConnectivityResult> results, {
    required bool triggerSyncIfRestored,
  }) {
    final nowOnline =
        results.isNotEmpty && !results.contains(ConnectivityResult.none);
    final wasOffline = !_isOnline;
    _isOnline = nowOnline;
    notifyListeners();

    if (nowOnline && (wasOffline || triggerSyncIfRestored) && _pendingCount > 0) {
      syncNow();
    }
  }

  Future<void> refreshPendingCount() async {
    _pendingCount = await LocalDatabase.instance.getUnsyncedCount();
    notifyListeners();
  }

  /// Called immediately after each QR/NFC scan is written to SQLite.
  /// Batches rapid classroom scans together with a short 2.5s debounce when online,
  /// and arms a WorkManager network-connected one-off job as an OS-level guarantee.
  Future<void> onNewScanQueued() async {
    await refreshPendingCount();

    // Schedule OS-level WorkManager task that waits until NetworkType.connected
    try {
      await Workmanager().registerOneOffTask(
        AppConfig.wmOneOffSyncUniqueName,
        AppConfig.wmTaskSyncScans,
        initialDelay: const Duration(seconds: 5),
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingWorkPolicy.replace,
      );
    } catch (_) {}

    if (_isOnline) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 2500), () {
        syncNow();
      });
    }
  }

  Future<bool> syncNow() async {
    if (_isSyncing) return false;
    await refreshPendingCount();
    if (_pendingCount == 0) return true;

    _isSyncing = true;
    _lastError = null;
    notifyListeners();

    bool ok = false;
    try {
      ok = await executeHeadlessBatchSync();
      if (ok) {
        _lastSyncTime = DateTime.now();
        _lastError = null;
      } else {
        _lastError = 'Sync deferred — will retry automatically when online.';
      }
    } catch (e) {
      _lastError = e.toString();
      ok = false;
    } finally {
      _isSyncing = false;
      await refreshPendingCount();
    }
    return ok;
  }

  @override
  void dispose() {
    _connSub?.cancel();
    _debounceTimer?.cancel();
    _periodicForegroundTimer?.cancel();
    super.dispose();
  }
}
