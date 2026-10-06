import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show DeviceOrientation;
import 'package:flutter_test/flutter_test.dart';
import 'package:karantin_face_sdk/src/karantin_face_scanner.dart';

void main() {
  group('previewBoxAspect', () {
    test('portrait flips the controller ratio', () {
      expect(
        previewBoxAspect(
          aspectRatio: 1280 / 720,
          orientation: DeviceOrientation.portraitUp,
        ),
        closeTo(720 / 1280, 1e-9),
      );
    });

    test('landscape keeps the controller ratio', () {
      expect(
        previewBoxAspect(
          aspectRatio: 1280 / 720,
          orientation: DeviceOrientation.landscapeLeft,
        ),
        closeTo(1280 / 720, 1e-9),
      );
    });

    test('a preview size reported portrait still produces a filling box', () {
      // Some platforms report previewSize already rotated.
      final aspect = previewBoxAspect(
        aspectRatio: 720 / 1280,
        orientation: DeviceOrientation.portraitUp,
      );
      expect(aspect, closeTo(1280 / 720, 1e-9));
    });

    test('falls back to square on a bogus ratio', () {
      for (final bad in <double>[0, -1, double.nan, double.infinity]) {
        expect(
          previewBoxAspect(
            aspectRatio: bad,
            orientation: DeviceOrientation.portraitUp,
          ),
          1,
        );
      }
    });
  });

  testWidgets('the preview covers the whole circle, leaving no gap', (
    tester,
  ) async {
    const diameter = 300.0;
    const controllerRatio = 1280 / 720; // landscape-reported preview

    final boxAspect = previewBoxAspect(
      aspectRatio: controllerRatio,
      orientation: DeviceOrientation.portraitUp,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: diameter,
            height: diameter,
            child: ClipOval(
              child: FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: diameter * boxAspect,
                  height: diameter,
                  // Stands in for CameraPreview, which sizes itself exactly
                  // like this.
                  child: AspectRatio(
                    aspectRatio: 1 / controllerRatio,
                    child: const ColoredBox(
                      key: ValueKey('texture'),
                      color: Color(0xFF00FF00),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // The texture must be laid out over the full box it was given...
    final textureSize = tester.getSize(find.byKey(const ValueKey('texture')));
    expect(textureSize.width, closeTo(diameter * boxAspect, 0.01));
    expect(textureSize.height, closeTo(diameter, 0.01));

    // ...and after the cover-fit it must reach every edge of the circle.
    final rect = tester.getRect(find.byKey(const ValueKey('texture')));
    final circle = tester.getRect(find.byType(ClipOval));
    expect(rect.width, greaterThanOrEqualTo(circle.width - 0.01));
    expect(rect.height, greaterThanOrEqualTo(circle.height - 0.01));
    expect(rect.center.dx, closeTo(circle.center.dx, 0.01));
    expect(rect.center.dy, closeTo(circle.center.dy, 0.01));
  });
}
