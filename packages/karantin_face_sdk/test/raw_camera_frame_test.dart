import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:karantin_face_sdk/src/raw_camera_frame.dart';

void main() {
  group('decodeRawFrame', () {
    test('decodes a padded BGRA buffer and ignores the row padding', () {
      const width = 4;
      const height = 2;
      const bytesPerRow = 24; // 4 px * 4 bytes + 8 bytes of padding
      final bytes = Uint8List(bytesPerRow * height);
      for (var y = 0; y < height; y++) {
        for (var x = 0; x < width; x++) {
          final o = y * bytesPerRow + x * 4;
          bytes[o] = 10; // B
          bytes[o + 1] = 20; // G
          bytes[o + 2] = 30; // R
          bytes[o + 3] = 255; // A
        }
        // Garbage in the padding must never reach the image.
        for (var p = width * 4; p < bytesPerRow; p++) {
          bytes[y * bytesPerRow + p] = 200;
        }
      }

      final image = decodeRawFrame(
        RawCameraFrame(
          bytes: bytes,
          width: width,
          height: height,
          bytesPerRow: bytesPerRow,
          isBgra: true,
          rotationDegrees: 0,
          mirrored: false,
        ),
      );

      expect(image, isNotNull);
      expect(image!.width, width);
      expect(image.height, height);
      final pixel = image.getPixel(3, 1);
      expect(pixel.r, 30);
      expect(pixel.g, 20);
      expect(pixel.b, 10);
    });

    test('rotates a landscape buffer upright and can mirror it', () {
      const width = 4;
      const height = 2;
      final bytes = Uint8List(width * 4 * height);
      for (var i = 0; i < bytes.length; i += 4) {
        bytes[i + 3] = 255;
      }
      // Mark the top-left pixel red so the rotation can be followed.
      bytes[2] = 255;

      final image = decodeRawFrame(
        RawCameraFrame(
          bytes: bytes,
          width: width,
          height: height,
          bytesPerRow: width * 4,
          isBgra: true,
          rotationDegrees: 90,
          mirrored: false,
        ),
      );

      expect(image, isNotNull);
      // Landscape in, portrait out.
      expect(image!.width, height);
      expect(image.height, width);
      // 90 deg clockwise moves the top-left pixel to the top-right.
      expect(image.getPixel(image.width - 1, 0).r, 255);

      final mirrored = decodeRawFrame(
        RawCameraFrame(
          bytes: bytes,
          width: width,
          height: height,
          bytesPerRow: width * 4,
          isBgra: true,
          rotationDegrees: 90,
          mirrored: true,
        ),
      );
      expect(mirrored!.getPixel(0, 0).r, 255);
    });

    test('decodes NV21 into the expected colours', () {
      const width = 4;
      const height = 2;
      final bytes = Uint8List(width * height + width * height ~/ 2);
      // Pure white: Y = 255 with neutral chroma.
      for (var i = 0; i < width * height; i++) {
        bytes[i] = 255;
      }
      for (var i = width * height; i < bytes.length; i++) {
        bytes[i] = 128;
      }

      final image = decodeRawFrame(
        RawCameraFrame(
          bytes: bytes,
          width: width,
          height: height,
          bytesPerRow: width,
          isBgra: false,
          rotationDegrees: 0,
          mirrored: false,
        ),
      );

      expect(image, isNotNull);
      expect(image!.width, width);
      expect(image.height, height);
      final pixel = image.getPixel(2, 1);
      expect(pixel.r, 255);
      expect(pixel.g, 255);
      expect(pixel.b, 255);
    });

    test('rejects a truncated buffer instead of crashing', () {
      final frame = RawCameraFrame(
        bytes: Uint8List(4),
        width: 40,
        height: 40,
        bytesPerRow: 160,
        isBgra: true,
        rotationDegrees: 0,
        mirrored: false,
      );
      expect(decodeRawFrame(frame), isNull);
    });
  });
}
