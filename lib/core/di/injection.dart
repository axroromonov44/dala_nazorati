import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';

import '../../features/auth/data/datasources/auth_remote_datasource.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/gov_login_usecase.dart';
import '../../features/auth/domain/usecases/karantin_login_usecase.dart';
import '../../features/auth/domain/usecases/login_usecase.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/bloc/profile_cubit.dart';
import '../../features/fields/data/datasources/field_remote_datasource.dart';
import '../../features/fields/data/field_spatial_index.dart';
import '../../features/fields/data/repositories/field_repository_impl.dart';
import '../../features/fields/domain/repositories/field_repository.dart';
import '../../features/fields/presentation/bloc/fields_bloc.dart';
import '../../features/home/data/repositories/location_repository_impl.dart';
import '../../features/home/domain/repositories/location_repository.dart';
import '../../features/home/domain/usecases/get_current_location_usecase.dart';
import '../../features/home/domain/usecases/watch_location_usecase.dart';
import '../../features/home/presentation/bloc/map_bloc.dart';
import '../../features/reference/data/datasources/reference_remote_datasource.dart';
import '../../features/reference/data/repositories/reference_repository_impl.dart';
import '../../features/reference/domain/repositories/reference_repository.dart';
import '../../features/sync/presentation/bloc/sync_bloc.dart';
import '../connectivity/connectivity_cubit.dart';
import '../constants/storage_keys.dart';
import '../network/dio_service.dart';
import '../theme/theme_cubit.dart';
import '../update/shorebird_update_service.dart';
import '../router/app_router.dart';
import '../storage/hive_service.dart';
import '../storage/offline_sync_service.dart';
import '../storage/secure_storage_service.dart';

final getIt = GetIt.instance;

Future<void> configureDependencies() async {
  // External
  const secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  getIt.registerLazySingleton<FlutterSecureStorage>(() => secureStorage);
  getIt.registerLazySingleton<Connectivity>(() => Connectivity());

  // Storage
  getIt.registerLazySingleton<SecureStorageService>(
    () => SecureStorageService(getIt()),
  );
  final hiveService = await HiveService.create();
  getIt.registerSingleton<HiveService>(hiveService);
  getIt.registerLazySingleton<OfflineSyncService>(
    () => OfflineSyncService(getIt(), getIt()),
  );

  // iOS Keychain (used by flutter_secure_storage) survives app uninstalls,
  // unlike ordinary app storage — so a stale access token can silently log
  // the user back in after a fresh reinstall. Hive's on-disk box IS wiped on
  // uninstall (both platforms), so it doubles as a trip wire: if this marker
  // is missing, this is a fresh install and any leftover Keychain tokens
  // from a previous install are purged before the router ever checks them.
  if (hiveService.userBox.get(StorageKeys.installMarker) != true) {
    await getIt<SecureStorageService>().clearTokens();
    await hiveService.userBox.put(StorageKeys.installMarker, true);
  }

  // Network — barcha API chaqiruvlari DioService orqali
  getIt.registerLazySingleton<DioService>(
    () => DioService(getIt<SecureStorageService>()),
  );

  // Router
  getIt.registerLazySingleton<AppRouter>(() => AppRouter(getIt()));

  // Theme
  getIt.registerLazySingleton<ThemeCubit>(() => ThemeCubit(getIt()));

  // OTA update
  getIt.registerLazySingleton<ShorebirdUpdateService>(
    () => ShorebirdUpdateService(),
  );

  // Connectivity
  getIt.registerLazySingleton<ConnectivityCubit>(
    () => ConnectivityCubit(getIt()),
  );

  // Auth
  getIt.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSource(getIt()),
  );
  getIt.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(getIt(), getIt(), getIt()),
  );
  getIt.registerLazySingleton<LoginUseCase>(() => LoginUseCase(getIt()));
  getIt.registerLazySingleton<GovLoginUseCase>(() => GovLoginUseCase(getIt()));
  getIt.registerLazySingleton<KarantinLoginUseCase>(
    () => KarantinLoginUseCase(getIt()),
  );
  getIt.registerFactory<AuthBloc>(() => AuthBloc(getIt(), getIt(), getIt()));
  // Butun ilova bo'ylab bir marta yuklanadigan, keshlangan foydalanuvchi
  // profili — home page uni ochilganda `refresh()` bilan to'ldiradi, qolgan
  // ekranlar shu bitta nusxani o'qiydi (qayta so'rov yubormaydi).
  getIt.registerLazySingleton<ProfileCubit>(
    () => ProfileCubit(getIt(), getIt()),
  );

  // Home / Location
  getIt.registerLazySingleton<LocationRepository>(
    () => LocationRepositoryImpl(),
  );
  getIt.registerLazySingleton<GetCurrentLocationUseCase>(
    () => GetCurrentLocationUseCase(getIt()),
  );
  getIt.registerLazySingleton<WatchLocationUseCase>(
    () => WatchLocationUseCase(getIt()),
  );
  getIt.registerFactory<MapBloc>(() => MapBloc(getIt(), getIt()));

  // Fields ("dalalar") — lightweight index synced/cached for every field,
  // photos cached separately and lazily by FieldMediaCache (see main.dart).
  getIt.registerLazySingleton<FieldRemoteDataSource>(
    () => FieldRemoteDataSource(getIt()),
  );
  final fieldSpatialIndex = FieldSpatialIndex();
  getIt.registerSingleton<FieldSpatialIndex>(fieldSpatialIndex);
  final fieldRepository = FieldRepositoryImpl(
    getIt<FieldRemoteDataSource>(),
    getIt<HiveService>(),
    fieldSpatialIndex,
  )..loadCachedIndex();
  getIt.registerSingleton<FieldRepository>(fieldRepository);
  getIt.registerFactory<FieldsBloc>(() => FieldsBloc(getIt()));

  // Reference data (crop/plant/propagation/pest types, zones, plants,
  // pests) — open karantin.uz API, separate host and no auth, so it
  // bypasses DioService entirely. Cached in HiveService.referenceDataBox.
  getIt.registerLazySingleton<ReferenceRemoteDataSource>(
    () => ReferenceRemoteDataSource(),
  );
  getIt.registerLazySingleton<ReferenceRepository>(
    () => ReferenceRepositoryImpl(getIt(), getIt()),
  );

  // Sync
  getIt.registerSingleton<SyncBloc>(
    SyncBloc(getIt<OfflineSyncService>(), getIt<DioService>()),
  );
}
