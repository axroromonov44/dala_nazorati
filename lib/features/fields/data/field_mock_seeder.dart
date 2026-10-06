import 'dart:math';

import 'package:latlong2/latlong.dart';

import 'models/field_summary_model.dart';

/// Whether seeded fields are shipped at all.
///
/// **Temporarily true in release builds**, so the offline map can be checked on
/// a real device through Play internal testing - a debug build installed over
/// the cable could not be, and the behaviour being tested is exactly what a
/// signed build does on a phone with no connection.
///
/// Set this back to `kDebugMode` before the next test build. Nothing else needs
/// changing: when it is false the seeder also deletes whatever it seeded
/// earlier, so a phone that already received these polygons clears them on its
/// next launch rather than keeping them next to real data.
const bool kSeedMockFields = true;

/// Fields invented around a point, so the map can be worked on before the
/// backend serves any. Nothing here touches the network.
abstract final class FieldMockSeeder {
  /// Mock ids carry this prefix, so the first real sync can recognise them and
  /// drop them instead of leaving invented polygons mixed into live data.
  static const idPrefix = 'mock-';

  static const _fieldCount = 36;

  /// Rings rather than one disc: panning outward has to keep finding fields
  /// that were never on screen before, which is the whole point of the
  /// viewport query. A single cluster around the inspector would look correct
  /// while testing nothing.
  static const _ringRadiiMeters = <double>[450, 1200, 2100, 3300];

  static const _metersPerDegreeLatitude = 111320.0;

  static const _crops = <String>[
    'Bugʻdoy',
    'Paxta',
    'Sholi',
    'Makkajoʻxori',
    'Kartoshka',
    'Sabzi',
    'Piyoz',
    'Uzum',
    'Olma',
    'Bodring',
  ];

  static const _statuses = <String>['active', 'inspected', 'pending'];

  /// The seed is fixed. Polygons that moved between launches would make the
  /// offline tile cache untestable, because the tiles are downloaded for
  /// wherever the fields happened to be the previous time.
  static List<FieldSummaryModel> around(LatLng center) {
    final random = Random(20261007);
    final now = DateTime.now().toUtc();

    return [
      for (var i = 0; i < _fieldCount; i++)
        _fieldAt(
          index: i,
          center: center,
          random: random,
          updatedAt: now.subtract(Duration(hours: i * 7)),
        ),
    ];
  }

  static FieldSummaryModel _fieldAt({
    required int index,
    required LatLng center,
    required Random random,
    required DateTime updatedAt,
  }) {
    final ring = index % _ringRadiiMeters.length;
    final withinRing = index ~/ _ringRadiiMeters.length;
    final perRing = (_fieldCount / _ringRadiiMeters.length).ceil();

    // Each ring starts at a different angle, otherwise the fields line up in
    // spokes and large parts of the map stay empty.
    final angle =
        (withinRing / perRing) * 2 * pi +
        ring * 0.7 +
        (random.nextDouble() - 0.5) * 0.4;
    final distance =
        _ringRadiiMeters[ring] * (0.82 + random.nextDouble() * 0.36);

    final fieldCenter = _offset(
      center,
      eastMeters: cos(angle) * distance,
      northMeters: sin(angle) * distance,
    );

    // Real parcels are neither square nor identical, and a map covered in
    // equal rectangles hides clipping and hit-testing mistakes.
    final halfWidth = 70 + random.nextDouble() * 80;
    final halfHeight = 55 + random.nextDouble() * 70;
    final rotation = random.nextDouble() * pi;

    final corners = <LatLng>[
      for (final corner in const [
        [-1.0, -1.0],
        [1.0, -1.0],
        [1.0, 1.0],
        [-1.0, 1.0],
      ])
        _rotatedCorner(
          fieldCenter,
          eastMeters:
              corner[0] * halfWidth * (0.85 + random.nextDouble() * 0.3),
          northMeters:
              corner[1] * halfHeight * (0.85 + random.nextDouble() * 0.3),
          rotation: rotation,
        ),
    ];

    return FieldSummaryModel(
      id: '$idPrefix${(index + 1).toString().padLeft(3, '0')}',
      points: corners,
      name: 'Namuna dala ${index + 1}',
      cropType: _crops[index % _crops.length],
      status: _statuses[index % _statuses.length],
      updatedAt: updatedAt,
    );
  }

  static LatLng _rotatedCorner(
    LatLng origin, {
    required double eastMeters,
    required double northMeters,
    required double rotation,
  }) => _offset(
    origin,
    eastMeters: eastMeters * cos(rotation) - northMeters * sin(rotation),
    northMeters: eastMeters * sin(rotation) + northMeters * cos(rotation),
  );

  static LatLng _offset(
    LatLng origin, {
    required double eastMeters,
    required double northMeters,
  }) {
    final metersPerDegreeLongitude =
        _metersPerDegreeLatitude * cos(origin.latitude * pi / 180);
    return LatLng(
      origin.latitude + northMeters / _metersPerDegreeLatitude,
      origin.longitude + eastMeters / metersPerDegreeLongitude,
    );
  }
}
