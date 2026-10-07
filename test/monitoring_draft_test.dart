import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:nazorat_aat/features/home/data/models/monitoring_draft.dart';

MonitoringDraft draft({
  String name = 'Dala 1',
  String area = '12.5',
  String variety = 'Bahor',
  String notes = 'ko\'rik o\'tkazildi',
  String? ownershipType = 'private',
  String? fieldStatus = 'active',
  String? cropType = 'wheat',
  String? irrigationType = 'drip',
  List<String> imagePaths = const ['/tmp/a.jpg'],
}) => MonitoringDraft(
  name: name,
  area: area,
  variety: variety,
  notes: notes,
  ownershipType: ownershipType,
  fieldStatus: fieldStatus,
  cropType: cropType,
  irrigationType: irrigationType,
  imagePaths: imagePaths,
  savedAt: DateTime.utc(2026, 10, 7, 12, 30),
);

void main() {
  group('monitoringDraftKey', () {
    final square = [
      const LatLng(41.311151, 69.279737),
      const LatLng(41.311151, 69.289737),
      const LatLng(41.321151, 69.289737),
    ];

    // The whole point of not using hashCode: the key has to find the same
    // draft after the app is closed and reopened.
    test('the same polygon always gives the same key', () {
      expect(monitoringDraftKey(square), monitoringDraftKey([...square]));
    });

    test('a different polygon gives a different key', () {
      final moved = [...square.sublist(1), const LatLng(41.4, 69.4)];
      expect(monitoringDraftKey(moved), isNot(monitoringDraftKey(square)));
    });

    // Six decimals is about 11 cm. Anything finer is noise in a polygon drawn
    // with a finger, and must not look like a different field.
    test('noise below 11 cm does not split the draft', () {
      final jittered = [
        const LatLng(41.3111509999, 69.2797370001),
        const LatLng(41.311151, 69.289737),
        const LatLng(41.321151, 69.289737),
      ];
      expect(monitoringDraftKey(jittered), monitoringDraftKey(square));
    });

    test('a real move does split the draft', () {
      final moved = [const LatLng(41.311251, 69.279737), ...square.sublist(1)];
      expect(monitoringDraftKey(moved), isNot(monitoringDraftKey(square)));
    });

    test('the order the corners were drawn in matters', () {
      expect(
        monitoringDraftKey(square.reversed.toList()),
        isNot(monitoringDraftKey(square)),
      );
    });
  });

  group('serialisation', () {
    test('a draft survives the trip through storage', () {
      final restored = MonitoringDraft.fromMap(draft().toMap());

      expect(restored.name, 'Dala 1');
      expect(restored.area, '12.5');
      expect(restored.variety, 'Bahor');
      expect(restored.notes, "ko'rik o'tkazildi");
      expect(restored.ownershipType, 'private');
      expect(restored.fieldStatus, 'active');
      expect(restored.cropType, 'wheat');
      expect(restored.irrigationType, 'drip');
      expect(restored.imagePaths, ['/tmp/a.jpg']);
      expect(restored.savedAt, DateTime.utc(2026, 10, 7, 12, 30));
    });

    test('unanswered dropdowns stay unanswered, not empty strings', () {
      final restored = MonitoringDraft.fromMap(
        draft(
          ownershipType: null,
          fieldStatus: null,
          cropType: null,
          irrigationType: null,
        ).toMap(),
      );

      expect(restored.ownershipType, isNull);
      expect(restored.fieldStatus, isNull);
      expect(restored.cropType, isNull);
      expect(restored.irrigationType, isNull);
    });

    // Hive returns the list it stored as List<dynamic>, so the cast has to be
    // the forgiving kind.
    test('a loosely typed list from storage still reads', () {
      final map = draft().toMap();
      map['imagePaths'] = <dynamic>['/tmp/a.jpg', '/tmp/b.jpg'];

      expect(MonitoringDraft.fromMap(map).imagePaths, [
        '/tmp/a.jpg',
        '/tmp/b.jpg',
      ]);
    });

    // A draft written by an older build must not take the form down with it.
    test('a draft missing every field reads as an empty one', () {
      final restored = MonitoringDraft.fromMap(const <String, dynamic>{});

      expect(restored.isEmpty, isTrue);
      expect(restored.name, '');
      expect(restored.imagePaths, isEmpty);
      expect(restored.savedAt, DateTime.fromMillisecondsSinceEpoch(0));
    });

    test('an unparseable timestamp does not throw', () {
      final map = draft().toMap();
      map['savedAt'] = 'not a date';

      expect(
        MonitoringDraft.fromMap(map).savedAt,
        DateTime.fromMillisecondsSinceEpoch(0),
      );
    });
  });

  group('isEmpty', () {
    test('a form nobody touched is empty', () {
      expect(
        draft(
          name: '',
          area: '',
          variety: '',
          notes: '',
          ownershipType: null,
          fieldStatus: null,
          cropType: null,
          irrigationType: null,
          imagePaths: const [],
        ).isEmpty,
        isTrue,
      );
    });

    test('whitespace is not an answer', () {
      expect(
        draft(
          name: '   ',
          area: '\n',
          variety: ' ',
          notes: '  ',
          ownershipType: null,
          fieldStatus: null,
          cropType: null,
          irrigationType: null,
          imagePaths: const [],
        ).isEmpty,
        isTrue,
      );
    });

    test('a single photo is enough to be worth keeping', () {
      expect(
        draft(
          name: '',
          area: '',
          variety: '',
          notes: '',
          ownershipType: null,
          fieldStatus: null,
          cropType: null,
          irrigationType: null,
          imagePaths: const ['/tmp/a.jpg'],
        ).isEmpty,
        isFalse,
      );
    });

    test('a dropdown on its own is enough too', () {
      expect(
        draft(
          name: '',
          area: '',
          variety: '',
          notes: '',
          ownershipType: null,
          fieldStatus: 'active',
          cropType: null,
          irrigationType: null,
          imagePaths: const [],
        ).isEmpty,
        isFalse,
      );
    });
  });

  group('withExistingImages', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('draft_photos'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('a photo whose file is gone is dropped', () {
      final kept = File('${dir.path}/kept.jpg')..writeAsBytesSync([1, 2, 3]);
      final missing = '${dir.path}/missing.jpg';

      final filtered = draft(
        imagePaths: [kept.path, missing],
      ).withExistingImages();

      expect(filtered.imagePaths, [kept.path]);
    });

    test('the answers are untouched when a photo is dropped', () {
      final filtered = draft(
        imagePaths: ['${dir.path}/missing.jpg'],
      ).withExistingImages();

      expect(filtered.imagePaths, isEmpty);
      expect(filtered.name, 'Dala 1');
      expect(filtered.fieldStatus, 'active');
      expect(filtered.savedAt, DateTime.utc(2026, 10, 7, 12, 30));
    });

    test('nothing is copied when every photo is still there', () {
      final photo = File('${dir.path}/kept.jpg')..writeAsBytesSync([1]);
      final original = draft(imagePaths: [photo.path]);

      expect(original.withExistingImages(), same(original));
    });
  });
}
