import 'package:hive_flutter/hive_flutter.dart';
import '../constants/storage_keys.dart';

class HiveService {
  late Box<dynamic> offlineQueueBox;
  late Box<dynamic> userBox;

  /// Lightweight field index (geometry + metadata) — kept fully populated for
  /// every field, since it's small. This is what the map reads from offline.
  late Box<dynamic> fieldsIndexBox;

  /// Cached field detail (description, crop info, photo metadata — not photo
  /// bytes) fetched on demand when a field is opened.
  late Box<dynamic> fieldDetailBox;

  /// Metadata for on-disk cached field photos (path/size/lastAccessed), used
  /// by the LRU eviction pass. The photo bytes themselves live as files under
  /// the app documents directory, not in this box.
  late Box<dynamic> fieldPhotoMetaBox;

  /// Reference catalog (crop/plant/propagation/pest types, distribution
  /// zones, plants, pests) fetched from the open karantin.uz API — one
  /// `jsonEncode`d list per category, cached indefinitely since the catalog
  /// is stable and only refreshed on explicit request. Image *bytes* are
  /// never stored here, only their URLs.
  late Box<dynamic> referenceDataBox;

  static Future<HiveService> create() async {
    await Hive.initFlutter();
    final service = HiveService();
    service.offlineQueueBox = await Hive.openBox(StorageKeys.offlineQueueBox);
    service.userBox = await Hive.openBox(StorageKeys.userBox);
    service.fieldsIndexBox = await Hive.openBox(StorageKeys.fieldsIndexBox);
    service.fieldDetailBox = await Hive.openBox(StorageKeys.fieldDetailBox);
    service.fieldPhotoMetaBox = await Hive.openBox(
      StorageKeys.fieldPhotoMetaBox,
    );
    service.referenceDataBox = await Hive.openBox(StorageKeys.referenceDataBox);
    return service;
  }
}
