import 'package:flutter_test/flutter_test.dart';

import 'package:dala_nazorati/core/update/app_version.dart';

/// Version comparison drives the forced update, so a bug here can lock the
/// whole user base out of the app. The edge cases are covered in detail.
void main() {
  group('AppVersion.tryParse', () {
    test('reads a plain semantic version', () {
      expect(AppVersion.tryParse('1.4.2').toString(), '1.4.2');
    });

    test('drops the build number', () {
      expect(AppVersion.tryParse('1.0.0+18').toString(), '1.0.0');
    });

    test('tolerates surrounding whitespace', () {
      expect(AppVersion.tryParse('  2.1.0 ').toString(), '2.1.0');
    });

    test('returns null rather than guessing', () {
      for (final raw in ['', 'abc', '1.x.0', '1..0', '-1.0.0', null]) {
        expect(AppVersion.tryParse(raw), isNull, reason: 'input: $raw');
      }
    });
  });

  group('comparison', () {
    test('compares numerically, not as text', () {
      final ten = AppVersion.tryParse('1.10.0')!;
      final nine = AppVersion.tryParse('1.9.0')!;
      // Alphabetically "1.10.0" sorts below "1.9.0" — the classic mistake.
      expect(nine < ten, isTrue);
      expect(ten < nine, isFalse);
    });

    test('a missing component counts as zero', () {
      expect(
        AppVersion.tryParse('1.4')!.compareTo(AppVersion.tryParse('1.4.0')!),
        0,
      );
      expect(
        AppVersion.tryParse('1.4')! < AppVersion.tryParse('1.4.1')!,
        isTrue,
      );
    });
  });

  group('resolveUpdateRequirement', () {
    test('below the minimum is required', () {
      expect(
        resolveUpdateRequirement(
          current: '1.0.0',
          minimumSupported: '1.2.0',
          latest: '1.5.0',
        ),
        UpdateRequirement.required,
      );
    });

    test('above the minimum but behind the latest is optional', () {
      expect(
        resolveUpdateRequirement(
          current: '1.3.0',
          minimumSupported: '1.2.0',
          latest: '1.5.0',
        ),
        UpdateRequirement.optional,
      );
    });

    test('on the latest version asks for nothing', () {
      expect(
        resolveUpdateRequirement(
          current: '1.5.0',
          minimumSupported: '1.2.0',
          latest: '1.5.0',
        ),
        UpdateRequirement.none,
      );
    });

    test('an internal build ahead of the store is not blocked', () {
      expect(
        resolveUpdateRequirement(
          current: '2.0.0',
          minimumSupported: '1.2.0',
          latest: '1.5.0',
        ),
        UpdateRequirement.none,
      );
    });

    test('exactly at the minimum is not required to update', () {
      expect(
        resolveUpdateRequirement(current: '1.2.0', minimumSupported: '1.2.0'),
        UpdateRequirement.none,
      );
    });

    test('empty Remote Config blocks nobody', () {
      expect(
        resolveUpdateRequirement(current: '1.0.0'),
        UpdateRequirement.none,
      );
    });

    test('a typo in Remote Config blocks nobody', () {
      // The most important test here: typing "v1.2" instead of "1.2" in the
      // console must not throw the entire user base out of the app.
      expect(
        resolveUpdateRequirement(
          current: '1.0.0',
          minimumSupported: 'v1.2.0',
          latest: 'latest',
        ),
        UpdateRequirement.none,
      );
    });

    test('an unreadable installed version is not blocked', () {
      expect(
        resolveUpdateRequirement(current: '', minimumSupported: '9.9.9'),
        UpdateRequirement.none,
      );
    });
  });
}
