import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';

import '../../features/auth/data/datasources/auth_remote_datasource.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/login_usecase.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/home/data/repositories/location_repository_impl.dart';
import '../../features/home/domain/repositories/location_repository.dart';
import '../../features/home/domain/usecases/get_current_location_usecase.dart';
import '../../features/home/domain/usecases/watch_location_usecase.dart';
import '../../features/home/presentation/bloc/map_bloc.dart';
import '../../features/sync/presentation/bloc/sync_bloc.dart';
import '../connectivity/connectivity_cubit.dart';
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
    () => AuthRepositoryImpl(getIt()),
  );
  getIt.registerLazySingleton<LoginUseCase>(() => LoginUseCase(getIt()));
  getIt.registerFactory<AuthBloc>(() => AuthBloc(getIt()));

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
  getIt.registerFactory<MapBloc>(
    () => MapBloc(getIt(), getIt()),
  );

  // Sync
  getIt.registerSingleton<SyncBloc>(
    SyncBloc(getIt<OfflineSyncService>(), getIt<DioService>()),
  );
}
