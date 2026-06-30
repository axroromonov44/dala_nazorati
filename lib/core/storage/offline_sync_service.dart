import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'hive_service.dart';

enum SyncStatus { pending, syncing, synced, failed }

class OfflineQueueItem {
  const OfflineQueueItem({
    required this.id,
    required this.endpoint,
    required this.method,
    required this.body,
    required this.createdAt,
    this.status = SyncStatus.pending,
  });

  final String id;
  final String endpoint;
  final String method;
  final Map<String, dynamic> body;
  final DateTime createdAt;
  final SyncStatus status;

  Map<String, dynamic> toJson() => {
        'id': id,
        'endpoint': endpoint,
        'method': method,
        'body': body,
        'createdAt': createdAt.toIso8601String(),
        'status': status.name,
      };

  factory OfflineQueueItem.fromJson(Map<String, dynamic> json) =>
      OfflineQueueItem(
        id: json['id'] as String,
        endpoint: json['endpoint'] as String,
        method: json['method'] as String,
        body: Map<String, dynamic>.from(json['body'] as Map),
        createdAt: DateTime.parse(json['createdAt'] as String),
        status: SyncStatus.values.byName(json['status'] as String),
      );
}

class OfflineSyncService {
  const OfflineSyncService(this._hiveService, this._connectivity);

  final HiveService _hiveService;
  final Connectivity _connectivity;

  Future<void> enqueue(OfflineQueueItem item) async {
    await _hiveService.offlineQueueBox.put(
      item.id,
      jsonEncode(item.toJson()),
    );
  }

  List<OfflineQueueItem> getPendingItems() {
    return _hiveService.offlineQueueBox.values
        .map((v) => OfflineQueueItem.fromJson(
              jsonDecode(v as String) as Map<String, dynamic>,
            ))
        .where((item) => item.status == SyncStatus.pending)
        .toList();
  }

  Future<void> markSynced(String id) =>
      _hiveService.offlineQueueBox.delete(id);

  Future<bool> isOnline() async {
    final result = await _connectivity.checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }

  Stream<List<ConnectivityResult>> get connectivityStream =>
      _connectivity.onConnectivityChanged;
}
