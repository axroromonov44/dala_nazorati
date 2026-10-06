import 'package:equatable/equatable.dart';

enum ReferenceSyncStepStatus { pending, running, success, error }

class ReferenceSyncProgress extends Equatable {
  const ReferenceSyncProgress({
    required this.statuses,
    required this.done,
    this.activeFraction = 0,
  });

  final Map<String, ReferenceSyncStepStatus> statuses;
  final bool done;

  /// How far the currently running step has got, 0..1. Only the image step
  /// reports this; the others finish too quickly to be worth sub-dividing.
  final double activeFraction;

  int get activeIndex {
    final keys = statuses.keys.toList();
    final runningIndex = keys.indexWhere(
      (key) => statuses[key] == ReferenceSyncStepStatus.running,
    );
    return runningIndex == -1 ? keys.length : runningIndex;
  }

  bool get hasFailures =>
      statuses.values.any((status) => status == ReferenceSyncStepStatus.error);

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
  List<Object?> get props => [statuses, done, activeFraction];
}
