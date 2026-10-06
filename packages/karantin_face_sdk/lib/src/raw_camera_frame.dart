import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart' show DeviceOrientation;
import 'package:image/image.dart' as img;

/// Rotation lookup for Android, keyed by the device's current UI orientation.
const _orientations = {
  DeviceOrientation.portraitUp: 0,
  DeviceOrientation.landscapeLeft: 90,
  DeviceOrientation.portraitDown: 180,
  DeviceOrientation.landscapeRight: 270,
};

/// A single preview frame copied out of the camera stream.
///
/// The scanner grabs its burst straight from the running preview instead of
/// calling `takePicture()`: a still capture makes iOS interrupt the preview
/// layer (and Android re-configure the session), which is exactly the white
/// flash the user sees. Everything here is plain data so it can be shipped to
/// an isolate for decoding.
class RawCameraFrame {
  const RawCameraFrame({
    required this.bytes,
    required this.width,
    required this.height,
    required this.bytesPerRow,
    required this.isBgra,
    required this.rotationDegrees,
    required this.mirrored,
  });

  final Uint8List bytes;
  final int width;
  final int height;
  final int bytesPerRow;

  /// iOS streams BGRA8888, Android streams NV21 (requested on the controller).
  final bool isBgra;

  /// Degrees to rotate clockwise to get an upright portrait image.
  final int rotationDegrees;

  /// True when the buffer is a mirrored selfie view and has to be flipped back
  /// to match what a still capture would have produced.
  final bool mirrored;
}

/// Copies [image] out of the camera stream buffer (which the plugin reuses) and
/// records how it has to be rotated/flipped to become an upright photo.
RawCameraFrame? rawFrameFromCameraImage({
  required CameraImage image,
  required CameraController controller,
  required CameraDescription camera,
}) {
  if (image.planes.isEmpty) return null;

  final isBgra = Platform.isIOS;
  final Uint8List bytes;
  if (isBgra) {
    bytes = Uint8List.fromList(image.planes.first.bytes);
  } else {
    // NV21 arrives as one contiguous plane; keep the copy defensive in case a
    // device still hands over separate Y/VU planes.
    if (image.planes.length == 1) {
      bytes = Uint8List.fromList(image.planes.first.bytes);
    } else {
      final total = image.planes.fold<int>(0, (sum, p) => sum + p.bytes.length);
      bytes = Uint8List(total);
      var offset = 0;
      for (final plane in image.planes) {
        bytes.setRange(offset, offset + plane.bytes.length, plane.bytes);
        offset += plane.bytes.length;
      }
    }
  }

  return RawCameraFrame(
    bytes: bytes,
    width: image.width,
    height: image.height,
    bytesPerRow: image.planes.first.bytesPerRow,
    isBgra: isBgra,
    rotationDegrees: _rotationDegrees(controller: controller, camera: camera),
    // The iOS plugin sets `isVideoMirrored` on the front-camera video
    // connection, so streamed frames come back mirrored; the photo output is
    // not mirrored. Flip to keep the uploaded image identical to a still shot.
    mirrored: isBgra && camera.lensDirection == CameraLensDirection.front,
  );
}

int _rotationDegrees({
  required CameraController controller,
  required CameraDescription camera,
}) {
  final sensorOrientation = camera.sensorOrientation;
  if (Platform.isIOS) return sensorOrientation % 360;

  var compensation = _orientations[controller.value.deviceOrientation] ?? 0;
  if (camera.lensDirection == CameraLensDirection.front) {
    compensation = (sensorOrientation + compensation) % 360;
  } else {
    compensation = (sensorOrientation - compensation + 360) % 360;
  }
  return compensation;
}

/// Decodes a streamed frame into an upright RGB image. Isolate-safe.
img.Image? decodeRawFrame(RawCameraFrame frame) {
  img.Image? decoded;
  try {
    decoded = frame.isBgra ? _decodeBgra(frame) : _decodeNv21(frame);
  } catch (_) {
    return null;
  }
  if (decoded == null) return null;

  // The scanner is portrait-locked, so an upright result is always taller than
  // it is wide. iOS already hands over a portrait buffer (the plugin pins the
  // connection to `.portrait`), Android does not — rotating only landscape
  // buffers keeps both correct without guessing per device.
  final rotation = frame.rotationDegrees % 360;
  if (decoded.width > decoded.height && rotation != 0) {
    decoded = img.copyRotate(decoded, angle: rotation);
  }
  if (frame.mirrored) {
    decoded = img.copyFlip(decoded, direction: img.FlipDirection.horizontal);
  }
  return decoded;
}

img.Image? _decodeBgra(RawCameraFrame frame) {
  final expected = frame.bytesPerRow * frame.height;
  if (frame.bytes.length < expected) return null;
  return img.Image.fromBytes(
    width: frame.width,
    height: frame.height,
    bytes: frame.bytes.buffer,
    bytesOffset: frame.bytes.offsetInBytes,
    rowStride: frame.bytesPerRow,
    numChannels: 4,
    order: img.ChannelOrder.bgra,
  );
}

/// NV21 -> RGB. Written against a flat byte buffer (rather than `setPixel`) so
/// a 720p frame converts in a few milliseconds inside the isolate.
img.Image? _decodeNv21(RawCameraFrame frame) {
  final w = frame.width;
  final h = frame.height;
  final yStride = frame.bytesPerRow > 0 ? frame.bytesPerRow : w;
  final bytes = frame.bytes;
  final uvStart = yStride * h;
  if (bytes.length < uvStart) return null;

  final rgb = Uint8List(w * h * 3);
  var out = 0;
  for (var y = 0; y < h; y++) {
    final yRow = y * yStride;
    final uvRow = uvStart + (y >> 1) * yStride;
    for (var x = 0; x < w; x++) {
      final luma = bytes[yRow + x].toDouble();
      final uvIndex = uvRow + (x & ~1);
      var u = 128, v = 128;
      if (uvIndex + 1 < bytes.length) {
        v = bytes[uvIndex]; // NV21 stores V before U.
        u = bytes[uvIndex + 1];
      }
      final du = u - 128;
      final dv = v - 128;
      rgb[out++] = _clamp8(luma + 1.402 * dv);
      rgb[out++] = _clamp8(luma - 0.344136 * du - 0.714136 * dv);
      rgb[out++] = _clamp8(luma + 1.772 * du);
    }
  }

  return img.Image.fromBytes(
    width: w,
    height: h,
    bytes: rgb.buffer,
    numChannels: 3,
    order: img.ChannelOrder.rgb,
  );
}

int _clamp8(double value) {
  if (value <= 0) return 0;
  if (value >= 255) return 255;
  return value.toInt();
}
