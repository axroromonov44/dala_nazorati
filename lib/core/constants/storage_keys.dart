class StorageKeys {
  const StorageKeys._();

  static const String accessToken = 'access_token';
  static const String refreshToken = 'refresh_token';
  static const String userData = 'user_data';

  static const String offlineQueueBox = 'offline_queue_box';
  static const String userBox = 'user_box';

  static const String mapRegionDownloadedPrefix = 'map_region_downloaded_';
  static const String mapRegionDeclinedPrefix = 'map_region_declined_';

  static const String installMarker = 'install_marker';

  /// Preferences, not session data: they survive a logout. Named here rather
  /// than inside each cubit so [SessionCleaner] cannot drift out of step with
  /// whatever string the cubit happens to use.
  static const String localeCode = 'locale';
  static const String themeMode = 'theme_mode';

  static const String fieldsIndexBox = 'fields_index_box';
  static const String fieldPhotoMetaBox = 'field_photo_meta_box';
  static const String fieldDetailBox = 'field_detail_box';
  static const String fieldsIndexSyncCursor = 'fields_index_sync_cursor';

  static const String referenceDataBox = 'reference_data_box';
}
