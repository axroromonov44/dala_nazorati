import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:latlong2/latlong.dart';

/// Identifies a draft by the polygon it belongs to.
///
/// The inspector draws a field on the map and only then fills the form, so the
/// polygon is what the answers are about: redrawing it is a different subject
/// and deserves its own draft.
///
/// `hashCode` would have been the obvious choice and is the wrong one — Dart
/// does not promise the same value across launches, and a key that changes
/// overnight loses the draft it was meant to find. Coordinates are rounded to
/// six decimals, about 11 cm, so float noise in the drawing does not invent a
/// second draft for the same field.
String monitoringDraftKey(List<LatLng> points) {
  final canonical = points
      .map(
        (p) =>
            '${p.latitude.toStringAsFixed(6)},${p.longitude.toStringAsFixed(6)}',
      )
      .join(';');
  return sha1.convert(utf8.encode(canonical)).toString();
}

/// A monitoring form as far as it has been filled in.
///
/// Written to disk while the inspector types, because the form is long, it is
/// filled in a field with one hand, and anything that interrupts the app —
/// a call, the camera, Android reclaiming memory — used to throw all of it
/// away.
class MonitoringDraft {
  const MonitoringDraft({
    required this.name,
    required this.area,
    required this.variety,
    required this.notes,
    required this.ownershipType,
    required this.fieldStatus,
    required this.cropType,
    required this.irrigationType,
    required this.imagePaths,
    required this.savedAt,
  });

  factory MonitoringDraft.fromMap(Map<dynamic, dynamic> map) {
    final saved = map['savedAt'];
    return MonitoringDraft(
      name: map['name'] as String? ?? '',
      area: map['area'] as String? ?? '',
      variety: map['variety'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
      ownershipType: map['ownershipType'] as String?,
      fieldStatus: map['fieldStatus'] as String?,
      cropType: map['cropType'] as String?,
      irrigationType: map['irrigationType'] as String?,
      // Hive hands back List<dynamic> even for a list that went in as strings.
      imagePaths: (map['imagePaths'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
      savedAt:
          (saved is String ? DateTime.tryParse(saved) : null) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  final String name;
  final String area;
  final String variety;
  final String notes;
  final String? ownershipType;
  final String? fieldStatus;
  final String? cropType;
  final String? irrigationType;
  final List<String> imagePaths;
  final DateTime savedAt;

  /// Nothing has been filled in, so there is nothing worth keeping.
  ///
  /// Checked before writing: opening the form and leaving again must not
  /// leave a draft behind, or the next visit announces a restore that
  /// restored nothing.
  bool get isEmpty =>
      name.trim().isEmpty &&
      area.trim().isEmpty &&
      variety.trim().isEmpty &&
      notes.trim().isEmpty &&
      ownershipType == null &&
      fieldStatus == null &&
      cropType == null &&
      irrigationType == null &&
      imagePaths.isEmpty;

  Map<String, dynamic> toMap() => {
    'name': name,
    'area': area,
    'variety': variety,
    'notes': notes,
    'ownershipType': ownershipType,
    'fieldStatus': fieldStatus,
    'cropType': cropType,
    'irrigationType': irrigationType,
    'imagePaths': imagePaths,
    'savedAt': savedAt.toIso8601String(),
  };

  /// Drops photos whose file is gone.
  ///
  /// The draft stores paths, not bytes, and a path can outlive its file — the
  /// system clears caches, the inspector clears storage. Showing a tile for a
  /// file that cannot be read is worse than not showing it.
  MonitoringDraft withExistingImages() {
    final kept = imagePaths.where((p) => File(p).existsSync()).toList();
    if (kept.length == imagePaths.length) return this;
    return copyWith(imagePaths: kept);
  }

  MonitoringDraft copyWith({List<String>? imagePaths}) => MonitoringDraft(
    name: name,
    area: area,
    variety: variety,
    notes: notes,
    ownershipType: ownershipType,
    fieldStatus: fieldStatus,
    cropType: cropType,
    irrigationType: irrigationType,
    imagePaths: imagePaths ?? this.imagePaths,
    savedAt: savedAt,
  );
}
