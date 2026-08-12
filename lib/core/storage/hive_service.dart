import 'package:hive_flutter/hive_flutter.dart';
import '../constants/storage_keys.dart';

class HiveService {
  late Box<dynamic> offlineQueueBox;
  late Box<dynamic> userBox;

  late Box<dynamic> fieldsIndexBox;

  late Box<dynamic> fieldDetailBox;

  late Box<dynamic> fieldPhotoMetaBox;

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
