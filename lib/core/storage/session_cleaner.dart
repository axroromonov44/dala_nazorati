import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/presentation/bloc/profile_cubit.dart';
import '../../features/fields/data/field_media_cache.dart';
import '../../features/fields/domain/repositories/field_repository.dart';
import '../../features/home/data/monitoring_draft_store.dart';
import '../../features/reference/data/reference_image_cache.dart';
import '../constants/storage_keys.dart';
import '../di/injection.dart';
import '../map/tile_cache_service.dart';
import '../notifications/notification_center.dart';
import 'hive_service.dart';

/// Everything that has to disappear when an inspector logs out, in one place.
///
/// It used to be a list of calls inside the logout button, which is exactly the
/// kind of list that goes stale: whoever adds the next cache has no reason to
/// look inside a widget. A device can pass between inspectors, so anything left
/// behind is one person's data shown to another.
abstract final class SessionCleaner {
  /// Preferences deliberately survive. Logging out is not a reason to forget
  /// which language the phone is set to, and the install marker exists to
  /// detect a reinstall - clearing it would make the next launch wipe tokens
  /// that were just written.
  static const _keysThatSurvive = {
    StorageKeys.installMarker,
    StorageKeys.localeCode,
    StorageKeys.themeMode,
  };

  static Future<void> wipe() async {
    final hive = getIt<HiveService>();

    await getIt<AuthRepository>().logout();

    // Map objects, their details and the sync cursor - including any seeded
    // mock data, which must never be inherited by the next session.
    await getIt<FieldRepository>().clearLocalData();

    await FieldMediaCache.clear();
    await ReferenceImageCache.clear();
    await TileCacheService.clearCache(notify: false);

    // Unfinished monitoring forms, with the photos taken for them. A draft is
    // one inspector's field notes and has no business reappearing for the
    // next person to hold the phone.
    await MonitoringDraftStore.clear();

    await hive.offlineQueueBox.clear();
    await hive.referenceDataBox.clear();
    await hive.fieldDetailBox.clear();
    await hive.fieldPhotoMetaBox.clear();
    await hive.fieldsIndexBox.clear();

    // The cached profile lived on through a logout before this, so the next
    // person to open the app saw the previous inspector's name while the login
    // screen was still loading.
    await hive.userBox.deleteAll(
      hive.userBox.keys.where((key) => !_keysThatSurvive.contains(key)),
    );

    getIt<ProfileCubit>().reset();
    NotificationCenter.items.value = const [];
  }
}
