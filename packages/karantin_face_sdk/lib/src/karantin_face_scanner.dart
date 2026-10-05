import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;

import 'camera_input_image.dart';
import 'face_readiness.dart';
import 'face_scan_animation.dart';
import 'karantin_face_remote_datasource.dart';

/// Native face scanner, a faithful port of the web client's `FaceDetection`
/// component + `useFaceDetection` hook.
///
/// It drives the front camera, runs on-device ML Kit face detection to decide
/// when the face is centered/at distance/still, counts down, captures a primary
/// cropped frame plus a few additional frames, and hands them to [onCapture].
/// All actual identity verification happens server-side; this widget only
/// detects a face locally to gate the capture.
class KarantinFaceScanner extends StatefulWidget {
  const KarantinFaceScanner({
    super.key,
    required this.onCapture,
    required this.isUploading,
    required this.isUploaded,
    this.onError,
    this.onPermissionDenied,
  });

  /// Called once a payload has been captured. The parent performs the upload;
  /// while it is in flight [isUploading] should be true.
  final Future<void> Function(KarantinFacePayload payload) onCapture;
  final bool isUploading;
  final bool isUploaded;
  final void Function(String message)? onError;

  /// Called when the OS reports the camera permission was denied, so the parent
  /// can show a platform-native "open settings" dialog.
  final VoidCallback? onPermissionDenied;

  @override
  State<KarantinFaceScanner> createState() => _KarantinFaceScannerState();
}

class _KarantinFaceScannerState extends State<KarantinFaceScanner>
    with WidgetsBindingObserver {
  static const _readyColor = Color(0xFF228BE6); // blue
  static const _verifiedColor = Color(0xFF07C23C); // green
  static const _holdColor = Color(0xFFFFA500); // orange
  static const _errorColor = Color(0xFFFF0000); // red

  // Detection pacing: process at most one frame per interval.
  static const _detectionIntervalMs = 150;
  static const _countdownSeconds = 1;
  // Frames captured in a short burst; the best becomes the main image and the
  // rest (deduplicated) become the additional check images.
  static const _burstCount = 3;
  static const _mainMaxDim = 720;
  static const _additionalMaxDim = 640;

  // Passive liveness signals collected across frames (no user prompts).
  double _minEyeOpen = 1.0;
  double _maxEyeOpen = 0.0;
  double _headYMin = 999;
  double _headYMax = -999;
  double _headXMin = 999;
  double _headXMax = -999;

  CameraController? _controller;
  FaceDetector? _detector;

  bool _cameraReady = false;
  bool _streaming = false;
  bool _processing = false;
  int _lastProcessedMs = 0;

  int _step = 0;
  double _progress = 0;
  bool _isCentered = false;
  int _readyFrames = 0;
  final List<Rect> _positions = [];

  int? _countdown;
  Timer? _countdownTimer;
  bool _isVerified = false;
  bool _isMutating = false;
  bool _hasCaptured = false;

  Uint8List? _mainPreview;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _detector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.fast,
        enableContours: false,
        enableLandmarks: false,
        // Classification gives eye-open probabilities for passive liveness
        // (a natural blink) without ever asking the user to do anything.
        enableClassification: true,
        enableTracking: true,
      ),
    );
    _initCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _stopStream();
    } else if (state == AppLifecycleState.resumed && !_hasCaptured) {
      _startStream();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    _stopStream();
    _controller?.dispose();
    _detector?.close();
    super.dispose();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        front,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isIOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.nv21,
      );

      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }

      _controller = controller;
      setState(() => _cameraReady = true);
      await _startStream();
    } on CameraException catch (e) {
      if (_isPermissionDenied(e)) {
        widget.onPermissionDenied?.call();
      } else {
        widget.onError?.call('Kamerani ochib boʻlmadi. Qaytadan urinib koʻring.');
      }
    } catch (_) {
      widget.onError?.call('Kamerani ochib boʻlmadi. Qaytadan urinib koʻring.');
    }
  }

  bool _isPermissionDenied(CameraException e) {
    final code = e.code.toLowerCase();
    return code.contains('denied') ||
        code.contains('permission') ||
        code.contains('restricted');
  }

  Future<void> _startStream() async {
    final controller = _controller;
    if (controller == null || _streaming || _hasCaptured) return;
    try {
      await controller.startImageStream(_onFrame);
      _streaming = true;
    } catch (_) {
      // ignore: stream may already be running
    }
  }

  Future<void> _stopStream() async {
    final controller = _controller;
    if (controller == null || !_streaming) return;
    try {
      await controller.stopImageStream();
    } catch (_) {}
    _streaming = false;
  }

  void _onFrame(CameraImage image) {
    if (_hasCaptured || _processing || _countdown != null) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastProcessedMs < _detectionIntervalMs) return;
    _lastProcessedMs = now;

    _processing = true;
    _processFrame(image).whenComplete(() => _processing = false);
  }

  Future<void> _processFrame(CameraImage image) async {
    final controller = _controller;
    final detector = _detector;
    if (controller == null || detector == null) return;

    final inputImage = inputImageFromCameraImage(
      image: image,
      controller: controller,
      camera: controller.description,
    );
    if (inputImage == null) return;

    final List<Face> faces;
    try {
      faces = await detector.processImage(inputImage);
    } catch (_) {
      return;
    }
    if (!mounted || _hasCaptured || _countdown != null) return;

    if (faces.isEmpty) {
      _applyReadiness(step: 0, progress: 0, centered: false, resetReady: true);
      return;
    }

    // Largest face wins.
    faces.sort(
      (a, b) => (b.boundingBox.width * b.boundingBox.height).compareTo(
        a.boundingBox.width * a.boundingBox.height,
      ),
    );
    final face = faces.first;
    final box = face.boundingBox;

    final metadata = inputImage.metadata;
    var size = metadata?.size ?? Size(image.width.toDouble(), image.height.toDouble());
    final rotation = metadata?.rotation;
    if (rotation == InputImageRotation.rotation90deg ||
        rotation == InputImageRotation.rotation270deg) {
      size = Size(size.height, size.width);
    }

    final centered = checkFaceCentered(box, size);
    final ratio = calculateFaceRatio(box, size);
    _updatePassiveLiveness(face);
    // Lenient liveness: any natural movement, a natural blink, or a small head
    // pose change counts — a real person passes effortlessly, a perfectly still
    // printed photo does not. We never prompt the user to move or blink.
    final isLive = updateLivenessPositions(_positions, box) ||
        _blinkDetected ||
        _headMoved;

    final readiness = getFaceReadinessStep(
      isCentered: centered,
      faceRatio: ratio,
      isLive: isLive,
      readyFrames: _readyFrames,
    );

    _readyFrames = readiness.readyFrames;
    if (!mounted) return;
    setState(() {
      _isCentered = centered;
      _progress = readiness.progress;
      _step = readiness.step;
    });

    if (readiness.shouldStartCountdown) {
      _readyFrames = 0;
      _startCountdown();
    }
  }

  void _updatePassiveLiveness(Face face) {
    final left = face.leftEyeOpenProbability;
    final right = face.rightEyeOpenProbability;
    if (left != null && right != null) {
      final open = (left + right) / 2;
      _minEyeOpen = math.min(_minEyeOpen, open);
      _maxEyeOpen = math.max(_maxEyeOpen, open);
    }
    final y = face.headEulerAngleY;
    if (y != null) {
      _headYMin = math.min(_headYMin, y);
      _headYMax = math.max(_headYMax, y);
    }
    final x = face.headEulerAngleX;
    if (x != null) {
      _headXMin = math.min(_headXMin, x);
      _headXMax = math.max(_headXMax, x);
    }
  }

  // A natural blink: eyes clearly open at some point and clearly closed at another.
  bool get _blinkDetected => _maxEyeOpen > 0.7 && _minEyeOpen < 0.35;

  // Small natural head-pose variation over the scan (degrees).
  bool get _headMoved =>
      (_headYMax - _headYMin) > 6 || (_headXMax - _headXMin) > 6;

  void _resetLiveness() {
    _positions.clear();
    _minEyeOpen = 1.0;
    _maxEyeOpen = 0.0;
    _headYMin = 999;
    _headYMax = -999;
    _headXMin = 999;
    _headXMax = -999;
  }

  void _applyReadiness({
    required int step,
    required double progress,
    required bool centered,
    bool resetReady = false,
  }) {
    if (resetReady) _readyFrames = 0;
    if (!mounted) return;
    setState(() {
      _step = step;
      _progress = progress;
      _isCentered = centered;
    });
  }

  void _startCountdown() {
    if (_countdownTimer != null || _hasCaptured) return;
    setState(() => _countdown = _countdownSeconds);
    _countdownTimer = Timer(const Duration(seconds: 1), () {
      _countdownTimer = null;
      setState(() => _countdown = null);
      _capture();
    });
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || _hasCaptured) return;
    _hasCaptured = true;

    setState(() {
      _isVerified = true;
      _progress = 100;
      _isMutating = true;
    });

    try {
      await _stopStream();

      // Take the first shot and freeze it on screen immediately, so the user
      // never sees the live preview flicker while the remaining shots are taken.
      final first = await _takePictureBytes(controller);
      if (first == null) {
        _resetAfterFailure('Rasm olinmadi. Qaytadan urinib koʻring.');
        return;
      }
      if (mounted) setState(() => _mainPreview = first);

      // Burst the remaining frames behind the frozen image; the natural latency
      // between shots gives slight variation (acts like scan-time collection).
      final frames = <Uint8List>[first];
      for (var i = 1; i < _burstCount; i++) {
        final f = await _takePictureBytes(controller);
        if (f != null) frames.add(f);
      }

      // Score, crop and compress off the UI thread: pick the sharpest/brightest
      // frame as the main image, resize + JPEG-compress everything for upload.
      final result = await compute(
        processCapturedFrames,
        FrameJob(
          frames: frames,
          mainMaxDim: _mainMaxDim,
          additionalMaxDim: _additionalMaxDim,
          maxAdditional: 4,
        ),
      );
      if (!mounted || !_hasCaptured) return;

      await widget.onCapture(
        KarantinFacePayload(
          faceImage: result.main,
          checkImages: result.additional,
        ),
      );
      // Success: the parent navigates away; keep showing the captured frame.
    } catch (_) {
      // Upload failed; the parent surfaces the message. Just reset to retry.
      restart();
    } finally {
      if (mounted) setState(() => _isMutating = false);
    }
  }

  /// Called by the parent (via key/state) to reset the scanner after a failed
  /// verification so the user can retry.
  void restart() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _resetLiveness();
    _readyFrames = 0;
    _hasCaptured = false;
    if (mounted) {
      setState(() {
        _step = 0;
        _progress = 0;
        _isCentered = false;
        _countdown = null;
        _isVerified = false;
        _isMutating = false;
        _mainPreview = null;
      });
    }
    _startStream();
  }

  void _resetAfterFailure(String message) {
    widget.onError?.call(message);
    restart();
  }

  Future<Uint8List?> _takePictureBytes(CameraController controller) async {
    try {
      final file = await controller.takePicture();
      return await file.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------- UI

  Color get _borderColor {
    if (_isMutating && _isVerified) return _verifiedColor;
    if (_countdown != null) return _readyColor;
    if (_isVerified && !_isMutating) return _holdColor;
    if (_step >= 2 && _isCentered) return _readyColor;
    return _errorColor;
  }

  String get _statusText {
    if (_mainPreview != null && widget.isUploaded) {
      return 'Yuz muvaffaqiyatli tasdiqlandi!';
    }
    if (_countdown != null) return 'Qimirlamay turing!';
    if (_isMutating && _isVerified) return 'Skanerlanmoqda...';
    if (_isVerified && !_isMutating) return 'Yuborilmoqda, iltimos kuting...';
    return kFaceInstructions[_step.clamp(0, kFaceInstructions.length - 1)];
  }

  @override
  Widget build(BuildContext context) {
    final progressGreen = _isVerified || _isMutating;
    final statusColor = progressGreen ? _verifiedColor : _readyColor;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildPreview(),
        const SizedBox(height: 20),
        SizedBox(
          width: 220,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: (_progress / 100).clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 8,
                backgroundColor: const Color(0xFFE9ECEF),
                valueColor: AlwaysStoppedAnimation(statusColor),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, 0.3),
                end: Offset.zero,
              ).animate(anim),
              child: child,
            ),
          ),
          child: Text(
            _statusText,
            key: ValueKey(_statusText),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: statusColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreview() {
    const diameter = 320.0;
    final border = _cameraReady
        ? _countdown != null
              ? _readyColor
              : _isVerified
              ? _verifiedColor
              : _borderColor
        : Colors.transparent;
    // Soft glow only for the positive states; no red halo when off-centre.
    Color? glow;
    if (_cameraReady) {
      if (_isVerified) {
        glow = _verifiedColor;
      } else if (_countdown != null || (_isCentered && _step >= 2)) {
        glow = _readyColor;
      }
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: border, width: 3),
        boxShadow: glow != null
            ? [BoxShadow(color: glow.withValues(alpha: 0.4), blurRadius: 12)]
            : null,
      ),
      child: ClipOval(
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              child: KeyedSubtree(
                key: ValueKey(
                  _mainPreview != null
                      ? 'image'
                      : _cameraReady
                      ? 'camera'
                      : 'loading',
                ),
                child: _buildCameraOrImage(diameter),
              ),
            ),
            if (_countdown != null && _mainPreview == null)
              _buildCountdown(_countdown!),
            if (_mainPreview != null) _buildScanOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraOrImage(double diameter) {
    if (_mainPreview != null) {
      // The live preview is already selfie-mirrored by the platform, but the
      // captured still is saved un-mirrored; mirror the frozen frame so the
      // framing does not flip at capture.
      return Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()..scaleByDouble(-1.0, 1.0, 1.0, 1.0),
        child: Image.memory(_mainPreview!, fit: BoxFit.cover),
      );
    }

    final controller = _controller;
    if (!_cameraReady || controller == null) {
      return const ColoredBox(
        color: Color(0xFF111111),
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFF07C23C)),
        ),
      );
    }

    // Cover-fit the preview without distortion. The scanner is portrait-locked,
    // so build a portrait box from the camera's own aspect (shorter x longer)
    // regardless of how the platform reports previewSize orientation; FittedBox
    // then crops it to the square circle with a uniform (non-stretching) scale.
    final previewSize = controller.value.previewSize;
    final double childWidth;
    final double childHeight;
    if (previewSize == null) {
      childWidth = diameter;
      childHeight = diameter;
    } else {
      childWidth = math.min(previewSize.width, previewSize.height);
      childHeight = math.max(previewSize.width, previewSize.height);
    }
    // No manual mirror here: the platform already shows the front camera as a
    // natural selfie view. Adding a flip would reverse it relative to the
    // native camera.
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: childWidth,
        height: childHeight,
        child: CameraPreview(controller),
      ),
    );
  }

  Widget _buildCountdown(int countdown) {
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.95, end: 1.05),
        duration: const Duration(milliseconds: 625),
        curve: Curves.easeInOut,
        builder: (context, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: Container(
          width: 110,
          height: 110,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _readyColor.withValues(alpha: 0.15),
            border: Border.all(color: _readyColor.withValues(alpha: 0.1), width: 2),
          ),
          child: Text(
            '${countdown + 1}',
            style: const TextStyle(
              color: _readyColor,
              fontSize: 48,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScanOverlay() {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withValues(alpha: 0.3),
        border: Border.all(color: _verifiedColor, width: 3),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const FaceScanAnimation(),
          if (widget.isUploading)
            const Center(
              child: Text(
                'Tekshirilmoqda...',
                style: TextStyle(
                  color: Color(0xFF00FF88),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Off-thread frame processing (best-frame selection + crop + resize + compress)
// ---------------------------------------------------------------------------

/// Input for [processCapturedFrames]. All fields are isolate-sendable.
class FrameJob {
  const FrameJob({
    required this.frames,
    required this.mainMaxDim,
    required this.additionalMaxDim,
    required this.maxAdditional,
  });

  final List<Uint8List> frames;
  final int mainMaxDim;
  final int additionalMaxDim;
  final int maxAdditional;
}

class FrameResult {
  const FrameResult({required this.main, required this.additional});

  final Uint8List main;
  final List<Uint8List> additional;
}

/// Picks the sharpest, best-exposed frame as the main image (centre-cropped to a
/// square and down-scaled), and compresses the remaining frames as additional
/// check images. Runs in an isolate via `compute` so decoding never janks the UI.
FrameResult processCapturedFrames(FrameJob job) {
  final decoded = <img.Image>[];
  for (final bytes in job.frames) {
    final im = img.decodeImage(bytes);
    if (im != null) decoded.add(img.bakeOrientation(im));
  }

  if (decoded.isEmpty) {
    // Could not decode: fall back to the raw bytes so the flow still proceeds.
    return FrameResult(
      main: job.frames.first,
      additional: job.frames.skip(1).take(job.maxAdditional).toList(),
    );
  }

  var bestIndex = 0;
  var bestScore = -1.0;
  for (var i = 0; i < decoded.length; i++) {
    final score = _frameScore(decoded[i]);
    if (score > bestScore) {
      bestScore = score;
      bestIndex = i;
    }
  }

  final main = _cropSquareResizeJpg(decoded[bestIndex], job.mainMaxDim, 85);

  final additional = <Uint8List>[];
  for (var i = 0; i < decoded.length && additional.length < job.maxAdditional; i++) {
    if (i == bestIndex) continue;
    additional.add(_resizeJpg(decoded[i], job.additionalMaxDim, 80));
  }
  // Ensure at least one additional frame when possible (backend expects >= 1).
  if (additional.isEmpty && decoded.length == 1) {
    additional.add(_resizeJpg(decoded[bestIndex], job.additionalMaxDim, 80));
  }

  return FrameResult(main: main, additional: additional);
}

/// Sharpness (gradient energy) weighted by how well-exposed the frame is.
double _frameScore(img.Image image) {
  final small = img.grayscale(img.copyResize(image, width: 200));
  final w = small.width;
  final h = small.height;
  var energy = 0.0;
  var lumSum = 0.0;
  var count = 0;
  for (var y = 2; y < h; y += 2) {
    for (var x = 2; x < w; x += 2) {
      final cur = small.getPixel(x, y).r.toDouble();
      final left = small.getPixel(x - 2, y).r.toDouble();
      final up = small.getPixel(x, y - 2).r.toDouble();
      final gx = cur - left;
      final gy = cur - up;
      energy += gx * gx + gy * gy;
      lumSum += cur;
      count++;
    }
  }
  if (count == 0) return 0;
  final sharpness = energy / count;
  final brightness = lumSum / count;
  final exposure = 1 - ((brightness - 128).abs() / 128); // 1 at mid, 0 at extremes
  return sharpness * (0.5 + 0.5 * exposure.clamp(0.0, 1.0));
}

Uint8List _cropSquareResizeJpg(img.Image image, int maxDim, int quality) {
  final side = math.min(image.width, image.height);
  final offX = ((image.width - side) / 2).round();
  final offY = ((image.height - side) / 2).round();
  var out = img.copyCrop(image, x: offX, y: offY, width: side, height: side);
  if (side > maxDim) {
    out = img.copyResize(out, width: maxDim, height: maxDim);
  }
  return Uint8List.fromList(img.encodeJpg(out, quality: quality));
}

Uint8List _resizeJpg(img.Image image, int maxDim, int quality) {
  var out = image;
  final longest = math.max(image.width, image.height);
  if (longest > maxDim) {
    out = image.width >= image.height
        ? img.copyResize(image, width: maxDim)
        : img.copyResize(image, height: maxDim);
  }
  return Uint8List.fromList(img.encodeJpg(out, quality: quality));
}
