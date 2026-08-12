import 'dart:math';

import 'package:latlong2/latlong.dart';

class UzRegion {
  const UzRegion({
    required this.nameUz,
    required this.nameRu,
    required this.nameEn,
    required this.center,
  });

  final String nameUz;
  final String nameRu;
  final String nameEn;
  final LatLng center;

  String localizedName(String languageCode) => switch (languageCode) {
    'ru' => nameRu,
    'en' => nameEn,
    _ => nameUz,
  };
}

class UzbekistanRegions {
  const UzbekistanRegions._();

  static const all = <UzRegion>[
    UzRegion(
      nameUz: "Toshkent",
      nameRu: 'Ташкент',
      nameEn: 'Tashkent',
      center: LatLng(41.2995, 69.2401),
    ),
    UzRegion(
      nameUz: 'Andijon',
      nameRu: 'Андижан',
      nameEn: 'Andijan',
      center: LatLng(40.7821, 72.3442),
    ),
    UzRegion(
      nameUz: "Farg'ona",
      nameRu: 'Фергана',
      nameEn: 'Fergana',
      center: LatLng(40.3894, 71.7864),
    ),
    UzRegion(
      nameUz: 'Namangan',
      nameRu: 'Наманган',
      nameEn: 'Namangan',
      center: LatLng(40.9983, 71.6726),
    ),
    UzRegion(
      nameUz: 'Sirdaryo',
      nameRu: 'Сырдарья',
      nameEn: 'Sirdaryo',
      center: LatLng(40.4897, 68.7842),
    ),
    UzRegion(
      nameUz: 'Jizzax',
      nameRu: 'Джизак',
      nameEn: 'Jizzakh',
      center: LatLng(40.1158, 67.8422),
    ),
    UzRegion(
      nameUz: 'Samarqand',
      nameRu: 'Самарканд',
      nameEn: 'Samarkand',
      center: LatLng(39.6270, 66.9750),
    ),
    UzRegion(
      nameUz: 'Qashqadaryo',
      nameRu: 'Кашкадарья',
      nameEn: 'Qashqadaryo',
      center: LatLng(38.8606, 65.7891),
    ),
    UzRegion(
      nameUz: 'Surxondaryo',
      nameRu: 'Сурхандарья',
      nameEn: 'Surkhandarya',
      center: LatLng(37.2242, 67.2783),
    ),
    UzRegion(
      nameUz: 'Buxoro',
      nameRu: 'Бухара',
      nameEn: 'Bukhara',
      center: LatLng(39.7747, 64.4286),
    ),
    UzRegion(
      nameUz: 'Navoiy',
      nameRu: 'Навои',
      nameEn: 'Navoiy',
      center: LatLng(40.1030, 65.3686),
    ),
    UzRegion(
      nameUz: 'Xorazm',
      nameRu: 'Хорезм',
      nameEn: 'Khorezm',
      center: LatLng(41.5500, 60.6333),
    ),
    UzRegion(
      nameUz: "Qoraqalpog'iston",
      nameRu: 'Каракалпакстан',
      nameEn: 'Karakalpakstan',
      center: LatLng(42.4600, 59.6100),
    ),
  ];

  static UzRegion nearestTo(LatLng point) {
    var best = all.first;
    var bestDistSq = double.infinity;
    for (final region in all) {
      final distSq = _distanceSquared(point, region.center);
      if (distSq < bestDistSq) {
        bestDistSq = distSq;
        best = region;
      }
    }
    return best;
  }

  static double _distanceSquared(LatLng a, LatLng b) {
    final dLat = a.latitude - b.latitude;
    final dLng = (a.longitude - b.longitude) * cos(a.latitude * pi / 180);
    return dLat * dLat + dLng * dLng;
  }
}
