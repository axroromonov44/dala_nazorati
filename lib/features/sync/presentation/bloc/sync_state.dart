part of 'sync_bloc.dart';

sealed class SyncState extends Equatable {
  const SyncState();
}

final class SyncIdle extends SyncState {
  const SyncIdle();

  @override
  List<Object> get props => [];
}

final class SyncInProgress extends SyncState {
  const SyncInProgress();

  @override
  List<Object> get props => [];
}

final class SyncCompleted extends SyncState {
  const SyncCompleted({required this.successCount, required this.failCount});

  final int successCount;
  final int failCount;

  @override
  List<Object> get props => [successCount, failCount];
}
