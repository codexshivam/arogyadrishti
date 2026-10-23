import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../network/api_client.dart';

/// Representation of an offline queue item.
class OfflineQueueItem {
  const OfflineQueueItem({
    required this.id,
    required this.actionType,
    required this.payload,
    this.filePath,
    required this.createdAt,
    required this.status,
    this.retryCount = 0,
  });

  final int id;
  final String actionType; // "AI_SCAN", "VAN_REQUEST", "SUPPORT_TICKET"
  final Map<String, dynamic> payload;
  final String? filePath;
  final String createdAt;
  final String status; // "PENDING", "UPLOADING", "COMPLETED", "FAILED"
  final int retryCount;

  factory OfflineQueueItem.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic> parsedPayload = {};
    try {
      if (map['payload'] is String) {
        parsedPayload = jsonDecode(map['payload'] as String) as Map<String, dynamic>;
      } else if (map['payload'] is Map) {
        parsedPayload = Map<String, dynamic>.from(map['payload'] as Map);
      }
    } catch (_) {}

    return OfflineQueueItem(
      id: map['id'] as int,
      actionType: map['action_type'] as String,
      payload: parsedPayload,
      filePath: map['file_path'] as String?,
      createdAt: map['created_at'] as String,
      status: map['status'] as String,
      retryCount: (map['retry_count'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'action_type': actionType,
      'payload': jsonEncode(payload),
      'file_path': filePath,
      'created_at': createdAt,
      'status': status,
      'retry_count': retryCount,
    };
  }
}

/// Production-grade Offline Dispatch & Sync Manager using SQLite & ConnectivityPlus.
class OfflineSyncManager {
  OfflineSyncManager({required this.apiClient});

  final ArogyaApiClient apiClient;
  Database? _db;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _isDraining = false;

  final _pendingCountController = StreamController<int>.broadcast();
  Stream<int> get pendingCountStream => _pendingCountController.stream;

  final _syncNotificationsController = StreamController<String>.broadcast();
  Stream<String> get syncNotificationsStream => _syncNotificationsController.stream;

  /// Initializes the SQLite database and binds network connectivity listeners.
  Future<void> initialize() async {
    if (kIsWeb) return;

    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'offline_dispatch_queue.db');

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE offline_dispatch_queue (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            action_type TEXT NOT NULL,
            payload TEXT NOT NULL,
            file_path TEXT,
            created_at TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'PENDING',
            retry_count INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
    );

    // Initial queue count
    await _updatePendingCount();

    // Listen to network changes
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final isOnline = results.any((r) => r != ConnectivityResult.none);
      if (isOnline) {
        debugPrint('OfflineSyncManager: Network restored. Auto-draining queue...');
        drainQueue();
      }
    });

    // Attempt initial drain if already online
    final initialResults = await Connectivity().checkConnectivity();
    if (initialResults.any((r) => r != ConnectivityResult.none)) {
      drainQueue();
    }
  }

  /// Closes database connection and unsubscribes from streams.
  Future<void> dispose() async {
    await _connectivitySub?.cancel();
    await _pendingCountController.close();
    await _syncNotificationsController.close();
    await _db?.close();
  }

  /// Queues an action for store-and-forward execution.
  Future<int> enqueueAction({
    required String actionType,
    required Map<String, dynamic> payload,
    String? filePath,
  }) async {
    if (_db == null) return -1;

    final id = await _db!.insert('offline_dispatch_queue', {
      'action_type': actionType,
      'payload': jsonEncode(payload),
      'file_path': filePath,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'status': 'PENDING',
      'retry_count': 0,
    });

    await _updatePendingCount();

    // If online, immediately trigger drain
    final current = await Connectivity().checkConnectivity();
    if (current.any((r) => r != ConnectivityResult.none)) {
      drainQueue();
    }

    return id;
  }

  /// Returns all currently pending queue items in FIFO order.
  Future<List<OfflineQueueItem>> getPendingItems() async {
    if (_db == null) return [];
    final maps = await _db!.query(
      'offline_dispatch_queue',
      where: 'status = ? OR status = ?',
      whereArgs: ['PENDING', 'FAILED'],
      orderBy: 'id ASC',
    );
    return maps.map(OfflineQueueItem.fromMap).toList();
  }

  /// Returns count of pending offline items.
  Future<int> getPendingCount() async {
    if (_db == null) return 0;
    final res = await _db!.rawQuery(
      "SELECT COUNT(*) as cnt FROM offline_dispatch_queue WHERE status IN ('PENDING', 'UPLOADING', 'FAILED')",
    );
    return Sqflite.firstIntValue(res) ?? 0;
  }

  Future<void> _updatePendingCount() async {
    final cnt = await getPendingCount();
    if (!_pendingCountController.isClosed) {
      _pendingCountController.add(cnt);
    }
  }

  /// Sequentially drains the offline queue in FIFO order.
  Future<void> drainQueue() async {
    if (_isDraining || _db == null) return;
    _isDraining = true;

    try {
      final items = await getPendingItems();
      for (final item in items) {
        // Mark as UPLOADING
        await _db!.update(
          'offline_dispatch_queue',
          {'status': 'UPLOADING'},
          where: 'id = ?',
          whereArgs: [item.id],
        );

        bool success = false;
        try {
          switch (item.actionType) {
            case 'AI_SCAN':
              success = await _processAiScanItem(item);
              break;
            case 'VAN_REQUEST':
              success = await _processVanRequestItem(item);
              break;
            case 'SUPPORT_TICKET':
              success = await _processSupportTicketItem(item);
              break;
            default:
              debugPrint('Unknown actionType: ${item.actionType}');
              success = true;
          }
        } catch (e) {
          debugPrint('OfflineSyncManager: Error processing item #${item.id}: $e');
          success = false;
        }

        if (success) {
          // Clean up file if present
          if (item.filePath != null) {
            try {
              final file = File(item.filePath!);
              if (await file.exists()) {
                await file.delete();
              }
            } catch (_) {}
          }

          await _db!.delete(
            'offline_dispatch_queue',
            where: 'id = ?',
            whereArgs: [item.id],
          );
        } else {
          await _db!.update(
            'offline_dispatch_queue',
            {
              'status': 'FAILED',
              'retry_count': item.retryCount + 1,
            },
            where: 'id = ?',
            whereArgs: [item.id],
          );
        }
        await _updatePendingCount();
      }
    } finally {
      _isDraining = false;
      await _updatePendingCount();
    }
  }

  Future<bool> _processAiScanItem(OfflineQueueItem item) async {
    Uint8List? imageBytes;
    if (item.filePath != null) {
      final file = File(item.filePath!);
      if (await file.exists()) {
        imageBytes = await file.readAsBytes();
      }
    }

    final p = item.payload;
    final lat = (p['lat'] ?? p['latitude'] as num?)?.toDouble() ?? 30.7333;
    final lng = (p['lng'] ?? p['longitude'] as num?)?.toDouble() ?? 76.7794;
    final wardLgd = p['ward_lgd']?.toString() ?? '0404400017';
    final wardName = p['ward_name']?.toString() ?? 'Chandigarh';
    final filename = p['filename']?.toString() ?? 'scan.jpg';
    final officerUid = p['officer_uid']?.toString() ?? 'officer_9915549455';

    final res = await apiClient.scanBreedingSite(
      imageBytes: imageBytes ?? Uint8List(0),
      filename: filename,
      lat: lat,
      lng: lng,
      wardLgd: wardLgd,
      wardName: wardName,
      officerUid: officerUid,
    );

    final score = (res['composite_risk_score'] as num?)?.toDouble() ?? 0.0;
    final tier = res['risk_tier']?.toString() ?? 'MODERATE';
    final alertMsg = 'Sync Completed: Inspection for $wardName processed (Score: ${(score * 100).toStringAsFixed(0)}%, Tier: $tier).';

    if (!_syncNotificationsController.isClosed) {
      _syncNotificationsController.add(alertMsg);
    }
    return true;
  }

  Future<bool> _processVanRequestItem(OfflineQueueItem item) async {
    final p = item.payload;
    await apiClient.dispatchAction(
      officerUid: p['officer_uid']?.toString() ?? 'offline_officer',
      actionType: 'REQUEST_VAN',
      wardVillage: p['ward_village']?.toString() ?? 'Ward 17',
      districtLgd: p['district_lgd']?.toString() ?? '0404400017',
      latitude: (p['latitude'] as num?)?.toDouble() ?? 30.7333,
      longitude: (p['longitude'] as num?)?.toDouble() ?? 76.7794,
      notes: p['notes']?.toString() ?? 'Dispatched from offline sync queue',
    );
    if (!_syncNotificationsController.isClosed) {
      _syncNotificationsController.add('Sync Completed: Van request dispatched for ${p['ward_village']}.');
    }
    return true;
  }

  Future<bool> _processSupportTicketItem(OfflineQueueItem item) async {
    final p = item.payload;
    await apiClient.createSupportTicket(
      wardLgdCode: p['ward_lgd_code']?.toString() ?? '0404400017',
      category: p['category']?.toString() ?? 'Vector Infestation',
      severity: p['severity']?.toString() ?? 'HIGH',
      officerUid: p['officer_uid']?.toString(),
      wardVillage: p['ward_village']?.toString(),
      description: (p['description'] ?? p['observation_notes'] ?? 'Offline report').toString(),
    );
    if (!_syncNotificationsController.isClosed) {
      _syncNotificationsController.add('Sync Completed: Support ticket logged for ${p['ward_village']}.');
    }
    return true;
  }
}

/// Global provider for OfflineSyncManager.
final offlineSyncManagerProvider = Provider<OfflineSyncManager>((ref) {
  final client = ref.read(apiClientProvider);
  final manager = OfflineSyncManager(apiClient: client);
  manager.initialize();
  ref.onDispose(() => manager.dispose());
  return manager;
});

/// Reactive stream of pending queue count.
final pendingQueueCountProvider = StreamProvider<int>((ref) {
  final manager = ref.watch(offlineSyncManagerProvider);
  return manager.pendingCountStream;
});

/// Reactive stream of connectivity status (true = connected, false = disconnected).
final isNetworkConnectedProvider = StreamProvider<bool>((ref) async* {
  final initial = await Connectivity().checkConnectivity();
  yield initial.any((r) => r != ConnectivityResult.none);

  yield* Connectivity().onConnectivityChanged.map((results) {
    return results.any((r) => r != ConnectivityResult.none);
  });
});
