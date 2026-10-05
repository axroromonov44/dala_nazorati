import 'dart:io';
import 'dart:ui' show Size;

import 'package:camera/camera.dart';
import 'package:flutter/services.dart' show DeviceOrientation;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Rotation lookup for Android, keyed by the device's current UI orientation.
const _orientations = {
  DeviceOrientation.portraitUp: 0,
  DeviceOrientation.landscapeLeft: 90,
  DeviceOrientation.portraitDown: 180,
  DeviceOrientation.landscapeRight: 270,
};

/// Builds an ML Kit [InputImage] from a streamed [CameraImage].
///
/// Handles the platform differences the ML Kit sample code documents: iOS
/// delivers a single BGRA plane with a reliable rotation, while Android needs
/// the rotation computed from sensor + device orientation and (on this app's
/// config) an NV21 single-plane buffer.
InputImage? inputImageFromCameraImage({
  required CameraImage image,
  required CameraController controller,
  required CameraDescription camera,
}) {
  final sensorOrientation = camera.sensorOrientation;

  InputImageRotation? rotation;
  if (Platform.isIOS) {
    rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
  } else if (Platform.isAndroid) {
    var rotationCompensation =
        _orientations[controller.value.deviceOrientation] ?? 0;
    if (camera.lensDirection == CameraLensDirection.front) {
      rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
    } else {
      rotationCompensation =
          (sensorOrientation - rotationCompensation + 360) % 360;
    }
    rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
  }
  if (rotation == null) return null;

  final format = InputImageFormatValue.fromRawValue(image.format.raw);
  if (format == null) return null;

  // iOS: bgra8888 single plane. Android: nv21 single plane (requested via
  // ImageFormatGroup.nv21 on the controller).
  if (image.planes.isEmpty) return null;
  final plane = image.planes.first;

  return InputImage.fromBytes(
    bytes: plane.bytes,
    metadata: InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation,
      format: format,
      bytesPerRow: plane.bytesPerRow,
    ),
  );
}
