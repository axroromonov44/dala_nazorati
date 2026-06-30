import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/network/dio_service.dart';
import '../../../../core/storage/offline_sync_service.dart';

part 'sync_event.dart';
part 'sync_state.dart';

class SyncBloc extends Bloc<SyncEvent, SyncState> {
  SyncBloc(this._syncService, this._dioService) : super(const SyncIdle()) {
    on<SyncStarted>(_onStarted);
    on<SyncTriggered>(_onTriggered);
    on<SyncStopped>(_onStopped);
  }

  final OfflineSyncService _syncService;
  final DioService _dioService;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  Future<void> _onStarted(SyncStarted event, Emitter<SyncState> emit) async {
    await _connectivitySub?.cancel();
    _connectivitySub = _syncService.connectivityStream.listen((results) {
      if (!results.contains(ConnectivityResult.none)) {
        add(const SyncTriggered());
      }
    });
    add(const SyncTriggered());
  }

  Future<void> _onTriggered(
    SyncTriggered event,
    Emitter<SyncState> emit,
  ) async {
    final pending = _syncService.getPendingItems();
    if (pending.isEmpty) return;

    emit(const SyncInProgress());
    var successCount = 0;
    var failCount = 0;

    for (final item in pending) {
      try {
        await _dioService.client.request<void>(
          item.endpoint,
          data: item.body,
          options: Options(method: item.method),
        );
        await _syncService.markSynced(item.id);
        successCount++;
      } catch (_) {
        failCount++;
      }
    }

    emit(SyncCompleted(
      successCount: successCount,
      failCount: failCount,
    ));
  }

  Future<void> _onStopped(SyncStopped event, Emitter<SyncState> emit) async {
    await _connectivitySub?.cancel();
    emit(const SyncIdle());
  }

  @override
  Future<void> close() {
    _connectivitySub?.cancel();
    return super.close();
  }
}
