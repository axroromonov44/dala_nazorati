import 'package:hive_flutter/hive_flutter.dart';
import '../constants/app_constants.dart';

class HiveService {
  late Box<dynamic> offlineQueueBox;
  late Box<dynamic> userBox;

  static Future<HiveService> create() async {
    await Hive.initFlutter();
    final service = HiveService();
    service.offlineQueueBox = await Hive.openBox(AppConstants.offlineQueueBox);
    service.userBox = await Hive.openBox(AppConstants.userBox);
    return service;
  }
}
