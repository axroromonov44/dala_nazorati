import 'package:equatable/equatable.dart';

enum ReferenceSyncStepStatus { pending, running, success, error }

class ReferenceSyncProgress extends Equatable {
  const ReferenceSyncProgress({required this.statuses, required this.done});

  final Map<String, ReferenceSyncStepStatus> statuses;
  final bool done;

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
  List<Object?> get props => [statuses, done];
}
