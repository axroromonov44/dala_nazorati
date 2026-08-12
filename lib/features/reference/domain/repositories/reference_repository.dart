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

  bool isCatalogCached();

  Stream<ReferenceSyncProgress> syncCatalog({bool forceRefresh = false});
}
