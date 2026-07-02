import 'package:hive_flutter/hive_flutter.dart';
import '../constants/storage_keys.dart';

class HiveService {
  late Box<dynamic> offlineQueueBox;
  late Box<dynamic> userBox;

  static Future<HiveService> create() async {
    await Hive.initFlutter();
    final service = HiveService();
    service.offlineQueueBox = await Hive.openBox(StorageKeys.offlineQueueBox);
    service.userBox = await Hive.openBox(StorageKeys.userBox);
    return service;
  }
}
