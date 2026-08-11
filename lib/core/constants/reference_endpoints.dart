/// Open/public reference-data API (no auth) — a different host than the
/// main app backend ([ApiEndpoints]), so it gets its own base URL and its
/// own [DioService]-less client rather than sharing the authenticated one.
class ReferenceEndpoints {
  const ReferenceEndpoints._();

  static const String baseUrl = 'https://datahub.karantin.uz/api';

  static const String cropTypes = '/reference/crop-types/';
  static const String plantTypes = '/reference/plant-types/';
  static const String propagationTypes = '/reference/propagation-types/';
  static const String plants = '/reference/plants/';
  static const String pestDistributionZones =
      '/reference/pest-distribution-zones/';
  static const String pestTypes = '/reference/pest-types/';
  static const String pests = '/reference/pests/';
}
