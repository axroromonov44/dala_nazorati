import 'package:equatable/equatable.dart';

enum ReferenceSyncStepStatus { pending, running, success, error }

/// Progress snapshot emitted while [ReferenceRepository.syncCatalog] works
/// through the reference categories one at a time. [statuses] maps each
/// category key (see `ReferenceRepositoryImpl._catalogKeys`) to its current
/// state, in category order — driving the `easy_stepper` sync dialog, where
/// a category that fails to fetch shows an error icon but doesn't stop the
/// rest from downloading.
class ReferenceSyncProgress extends Equatable {
  const ReferenceSyncProgress({required this.statuses, required this.done});

  final Map<String, ReferenceSyncStepStatus> statuses;
  final bool done;

  /// Index of the step currently running, or [statuses.length] once [done]
  /// — matches `EasyStepper.activeStep` semantics.
  int get activeIndex {
    final keys = statuses.keys.toList();
    final runningIndex = keys.indexWhere(
      (key) => statuses[key] == ReferenceSyncStepStatus.running,
    );
    return runningIndex == -1 ? keys.length : runningIndex;
  }

  bool get hasFailures =>
      statuses.values.any((status) => status == ReferenceSyncStepStatus.error);

  /// Share of steps that have finished (successfully or not) — drives the
  /// percent indicator under the stepper.
  double get fraction {
    if (statuses.isEmpty) return 1;
    final finished = statuses.values.where(
      (status) =>
          status == ReferenceSyncStepStatus.success ||
          status == ReferenceSyncStepStatus.error,
    );
    return finished.length / statuses.length;
  }

  @override
  List<Object?> get props => [statuses, done];
}
