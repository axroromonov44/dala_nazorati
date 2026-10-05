import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;

import '../../data/datasources/karantin_face_remote_datasource.dart';
import '../../data/face/face_readiness.dart';
import 'camera_input_image.dart';
import 'face_scan_animation.dart';

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
  static const _targetAdditional = 3;

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
        enableClassification: false,
        enableTracking: false,
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
    final box = faces.first.boundingBox;

    final metadata = inputImage.metadata;
    var size = metadata?.size ?? Size(image.width.toDouble(), image.height.toDouble());
    final rotation = metadata?.rotation;
    if (rotation == InputImageRotation.rotation90deg ||
        rotation == InputImageRotation.rotation270deg) {
      size = Size(size.height, size.width);
    }

    final centered = checkFaceCentered(box, size);
    final ratio = calculateFaceRatio(box, size);
    final isLive = updateLivenessPositions(_positions, box);

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

      final mainBytes = await _takePictureBytes(controller);
      if (mainBytes == null) {
        _resetAfterFailure('Rasm olinmadi. Qaytadan urinib koʻring.');
        return;
      }

      // Display the full frame (natural framing); upload the face-focused crop.
      if (mounted) setState(() => _mainPreview = mainBytes);
      final cropped = await _cropCenteredSquare(mainBytes);

      final additional = <Uint8List>[];
      for (var i = 0; i < _targetAdditional; i++) {
        final extra = await _takePictureBytes(controller);
        if (extra != null && !_isDuplicate(additional, extra)) {
          additional.add(extra);
        }
      }

      await widget.onCapture(
        KarantinFacePayload(faceImage: cropped, checkImages: additional),
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
    _positions.clear();
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

  bool _isDuplicate(List<Uint8List> existing, Uint8List candidate) {
    for (final e in existing) {
      if (e.length == candidate.length) return true;
    }
    return false;
  }

  /// Centered square crop, mirroring the web client's no-faceBox fallback in
  /// `getFaceFocusedCropArea` (the face is already centered by capture time).
  Future<Uint8List> _cropCenteredSquare(Uint8List bytes) async {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return bytes;
      final baked = img.bakeOrientation(decoded);
      final side = math.min(baked.width, baked.height);
      final offX = ((baked.width - side) / 2).round();
      final offY = ((baked.height - side) / 2).round();
      final cropped = img.copyCrop(
        baked,
        x: offX,
        y: offY,
        width: side,
        height: side,
      );
      return Uint8List.fromList(img.encodeJpg(cropped, quality: 95));
    } catch (_) {
      return bytes;
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
            child: LinearProgressIndicator(
              value: (_progress / 100).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: const Color(0xFFE9ECEF),
              valueColor: AlwaysStoppedAnimation(statusColor),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _statusText,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: statusColor,
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
    final glow = _cameraReady
        ? (_countdown != null || _isVerified)
              ? border
              : (_isCentered ? _readyColor : _errorColor)
        : Colors.transparent;

    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: border, width: 3),
        boxShadow: _cameraReady
            ? [BoxShadow(color: glow, blurRadius: 16, spreadRadius: 1)]
            : null,
      ),
      child: ClipOval(
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildCameraOrImage(diameter),
            if (_countdown != null && _mainPreview == null)
              _buildCountdown(_countdown!),
            if (_mainPreview != null) _buildScanOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraOrImage(double diameter) {
    // Selfie mirror, applied to both the live preview and the frozen frame so
    // the framing never flips at capture.
    final mirror = Matrix4.identity()..scaleByDouble(-1.0, 1.0, 1.0, 1.0);

    if (_mainPreview != null) {
      // Show the full captured frame (same natural framing as the preview); the
      // tighter face crop is only used for the upload payload.
      return Transform(
        alignment: Alignment.center,
        transform: mirror,
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

    // Cover-fit the preview using its real pixel size so the field of view
    // matches the native camera (no extra zoom/stretch). previewSize is in the
    // sensor's landscape orientation, so swap width/height for portrait display.
    final previewSize = controller.value.previewSize;
    final childWidth = previewSize?.height ?? diameter;
    final childHeight = previewSize?.width ?? diameter;
    return Transform(
      alignment: Alignment.center,
      transform: mirror,
      child: FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: childWidth,
          height: childHeight,
          child: CameraPreview(controller),
        ),
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
