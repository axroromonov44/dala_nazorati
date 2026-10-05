import 'dart:math' as math;
import 'dart:ui';

/// Dart port of the web client's `faceReadiness.ts` + `constants.ts`.
///
/// The logic decides, frame by frame, whether the detected face is centered,
/// at the right distance and "live" enough to start the capture countdown. The
/// thresholds are copied verbatim from the web client so the native scanner
/// behaves identically.

/// On-screen instructions, indexed by [FaceReadiness.step].
const List<String> kFaceInstructions = [
  "Kameraga yuzingizni ko'rsating",
  'Yuzingizni doiraning markaziga joylashtiring',
  'Kameraga 20-30 sm yaqinlashing',
  'Yana 10-15 sm yaqinroq keling',
  'Qimirlamay turing!',
  'Telefonni biroz uzoqroq tuting',
];

const double _faceRatioMin = 0.18;
const double _faceRatioMax = 0.82;
const double _faceRatioClose = 0.12;
const double _centerThreshold = 0.38;
const int _livenessMinFrames = 1;
const double _livenessMovementThreshold = 0.02;
const int kReadyFrameCount = 5;

enum FaceReadinessReason {
  notCentered,
  tooFar,
  moveCloser,
  tooClose,
  waitingLiveness,
  ready,
}

class FaceReadiness {
  const FaceReadiness({
    required this.step,
    required this.progress,
    required this.readyFrames,
    required this.shouldStartCountdown,
    required this.reason,
  });

  final int step;
  final double progress;
  final int readyFrames;
  final bool shouldStartCountdown;
  final FaceReadinessReason reason;
}

bool checkFaceCentered(Rect box, Size image) {
  final faceCenterX = box.left + box.width / 2;
  final faceCenterY = box.top + box.height / 2;
  final centerX = image.width / 2;
  final centerY = image.height / 2;

  final dx = (centerX - faceCenterX).abs();
  final dy = (centerY - faceCenterY).abs();

  return dx < image.width * _centerThreshold &&
      dy < image.height * _centerThreshold;
}

double calculateFaceRatio(Rect box, Size image) {
  final area = image.width * image.height;
  if (area <= 0) return 0;
  return (box.width * box.height) / area;
}

/// Mirrors `updateLivenessPositions`: pushes [position] into [positions]
/// (capped at [maxPositions]) and returns whether enough movement was seen.
bool updateLivenessPositions(
  List<Rect> positions,
  Rect position, {
  int maxPositions = 10,
}) {
  positions.add(position);
  if (positions.length > maxPositions) positions.removeAt(0);

  if (positions.length <= _livenessMinFrames) return true;

  var totalMovement = 0.0;
  for (var i = 1; i < positions.length; i++) {
    final prev = positions[i - 1];
    final curr = positions[i];
    final movement =
        (curr.left - prev.left).abs() +
        (curr.top - prev.top).abs() +
        ((curr.width - prev.width).abs() + (curr.height - prev.height).abs()) *
            0.4;
    totalMovement += movement;
  }

  final avgMovement = totalMovement / (positions.length - 1);
  return avgMovement > _livenessMovementThreshold;
}

FaceReadinessReason getFaceReadinessReason({
  required bool isCentered,
  required double faceRatio,
  required bool isLive,
}) {
  if (!isCentered) return FaceReadinessReason.notCentered;
  if (faceRatio < _faceRatioClose) return FaceReadinessReason.tooFar;
  if (faceRatio < _faceRatioMin) return FaceReadinessReason.moveCloser;
  if (faceRatio > _faceRatioMax) return FaceReadinessReason.tooClose;
  if (!isLive) return FaceReadinessReason.waitingLiveness;
  return FaceReadinessReason.ready;
}

FaceReadiness getFaceReadinessStep({
  required bool isCentered,
  required double faceRatio,
  required bool isLive,
  required int readyFrames,
}) {
  final reason = getFaceReadinessReason(
    isCentered: isCentered,
    faceRatio: faceRatio,
    isLive: isLive,
  );

  switch (reason) {
    case FaceReadinessReason.notCentered:
      return FaceReadiness(
        step: 1,
        progress: 0,
        readyFrames: 0,
        shouldStartCountdown: false,
        reason: reason,
      );
    case FaceReadinessReason.tooFar:
      return FaceReadiness(
        step: 2,
        progress: 25,
        readyFrames: 0,
        shouldStartCountdown: false,
        reason: reason,
      );
    case FaceReadinessReason.moveCloser:
      return FaceReadiness(
        step: 3,
        progress: 50,
        readyFrames: 0,
        shouldStartCountdown: false,
        reason: reason,
      );
    case FaceReadinessReason.tooClose:
      return FaceReadiness(
        step: 5,
        progress: 65,
        readyFrames: 0,
        shouldStartCountdown: false,
        reason: reason,
      );
    case FaceReadinessReason.ready:
      final nextReadyFrames = readyFrames + 1;
      return FaceReadiness(
        step: 4,
        progress: 75 + math.min((nextReadyFrames / kReadyFrameCount) * 25, 25),
        readyFrames: nextReadyFrames,
        shouldStartCountdown: nextReadyFrames >= kReadyFrameCount,
        reason: reason,
      );
    case FaceReadinessReason.waitingLiveness:
      return FaceReadiness(
        step: 4,
        progress: 75,
        readyFrames: 0,
        shouldStartCountdown: false,
        reason: reason,
      );
  }
}
