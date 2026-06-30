part of 'sync_bloc.dart';

sealed class SyncEvent extends Equatable {
  const SyncEvent();
}

final class SyncStarted extends SyncEvent {
  const SyncStarted();

  @override
  List<Object> get props => [];
}

final class SyncTriggered extends SyncEvent {
  const SyncTriggered();

  @override
  List<Object> get props => [];
}

final class SyncStopped extends SyncEvent {
  const SyncStopped();

  @override
  List<Object> get props => [];
}
