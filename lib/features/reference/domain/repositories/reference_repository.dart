import '../entities/pest.dart';
import '../entities/plant.dart';
import '../entities/reference_item.dart';
import '../entities/reference_sync_progress.dart';

abstract class ReferenceRepository {
  Future<List<ReferenceItem>> getCropTypes({bool forceRefresh = false});
  Future<List<ReferenceItem>> getPlantTypes({bool forceRefresh = false});
  Future<List<ReferenceItem>> getPropagationTypes({bool forceRefresh = false});
  Future<List<ReferenceItem>> getPestTypes({bool forceRefresh = false});
  Future<List<ReferenceItem>> getPestDistributionZones({
    bool forceRefresh = false,
  });
  Future<List<Plant>> getPlants({bool forceRefresh = false});
  Future<List<Pest>> getPests({bool forceRefresh = false});

  /// Whether every category is already cached in `referenceDataBox` — used
  /// to decide whether the post-login sync dialog needs to appear at all.
  bool isCatalogCached();

  /// Fetches every reference category in order, emitting a
  /// [ReferenceSyncProgress] whenever a category starts or finishes so a
  /// stepper UI can track each one's status live. Cached categories resolve
  /// instantly (unless [forceRefresh]); a category that fails to fetch is
  /// marked [ReferenceSyncStepStatus.error] rather than aborting the rest.
  Stream<ReferenceSyncProgress> syncCatalog({bool forceRefresh = false});
}
