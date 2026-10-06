import 'package:flutter_test/flutter_test.dart';

import 'package:dala_nazorati/core/download/app_download_controller.dart';
import 'package:dala_nazorati/features/reference/domain/entities/reference_sync_progress.dart';

/// The progress bar used to count steps, so it jumped to 63% within a second
/// and then sat there for the whole image download — which is the bulk of the
/// work. It now weighs each step and folds in how far the running one has got.
void main() {
  const lookups = [
    'crop_types',
    'plant_types',
    'propagation_types',
    'pest_types',
    'pest_distribution_zones',
  ];
  const catalogKeys = [...lookups, 'plants', 'pests', 'images'];

  AppDownloadController controllerWith(
    Map<String, ReferenceSyncStepStatus> statuses, {
    double catalogStepFraction = 0,
  }) {
    return AppDownloadController()
      ..orderedKeys = statuses.keys.toList()
      ..statuses = statuses
      ..catalogStepFraction = catalogStepFraction;
  }

  Map<String, ReferenceSyncStepStatus> allPending(List<String> keys) => {
    for (final key in keys) key: ReferenceSyncStepStatus.pending,
  };

  test('nothing to download reads as complete', () {
    expect(AppDownloadController().fraction, 1);
  });

  test('nothing started yet is zero', () {
    expect(controllerWith(allPending(catalogKeys)).fraction, 0);
  });

  test('everything finished is exactly one', () {
    expect(
      controllerWith({
        for (final key in catalogKeys) key: ReferenceSyncStepStatus.success,
      }).fraction,
      1,
    );
  });

  test('a failed step still counts as finished, so the bar can reach one', () {
    expect(
      controllerWith({
        for (final key in catalogKeys) key: ReferenceSyncStepStatus.success,
        'images': ReferenceSyncStepStatus.error,
      }).fraction,
      1,
    );
  });

  test('the five quick lookups are only a small slice of the bar', () {
    final statuses = allPending(catalogKeys);
    for (final key in lookups) {
      statuses[key] = ReferenceSyncStepStatus.success;
    }

    final fraction = controllerWith(statuses).fraction;
    expect(
      fraction,
      lessThan(0.15),
      reason: 'five small requests must not look like most of the work',
    );
  });

  test('the image step dominates and moves while it runs', () {
    final statuses = allPending(catalogKeys);
    for (final key in [...lookups, 'plants', 'pests']) {
      statuses[key] = ReferenceSyncStepStatus.success;
    }
    statuses['images'] = ReferenceSyncStepStatus.running;

    final atStart = controllerWith(statuses).fraction;
    final atHalf = controllerWith(statuses, catalogStepFraction: 0.5).fraction;
    final atEnd = controllerWith(statuses, catalogStepFraction: 1).fraction;

    expect(atHalf, greaterThan(atStart));
    expect(atEnd, greaterThan(atHalf));
    expect(atEnd, closeTo(1, 0.0001));
    // Half the images downloaded should land around the middle of the bar,
    // not pinned near the end like the step-counting version did.
    expect(atHalf, inInclusiveRange(0.5, 0.65));
  });

  test('the fraction never leaves 0..1', () {
    final statuses = allPending(catalogKeys);
    statuses['images'] = ReferenceSyncStepStatus.running;

    expect(controllerWith(statuses, catalogStepFraction: -5).fraction, 0);
    expect(
      controllerWith(statuses, catalogStepFraction: 42).fraction,
      lessThanOrEqualTo(1),
    );
  });

  test('a map-only download tracks the tile progress, not the catalog', () {
    final controller = controllerWith({
      mapStepKey: ReferenceSyncStepStatus.running,
    }, catalogStepFraction: 1);

    // No tile progress reported yet, and the catalog fraction must not leak in.
    expect(controller.fraction, 0);
  });

  test('progress carries the running step fraction', () {
    const progress = ReferenceSyncProgress(
      statuses: {'images': ReferenceSyncStepStatus.running},
      done: false,
      activeFraction: 0.25,
    );

    expect(progress.activeFraction, 0.25);
    expect(progress.hasFailures, isFalse);
  });
}
