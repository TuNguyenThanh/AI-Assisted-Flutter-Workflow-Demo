import 'package:demo_ai_workflow/core/network/dio_factory.dart';
import 'package:demo_ai_workflow/core/storage/token_storage.dart';
import 'package:demo_ai_workflow/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:demo_ai_workflow/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:demo_ai_workflow/features/auth/domain/repositories/auth_repository.dart';
import 'package:demo_ai_workflow/features/auth/domain/usecases/get_profile_usecase.dart';
import 'package:demo_ai_workflow/features/auth/domain/usecases/login_usecase.dart';
import 'package:demo_ai_workflow/features/auth/domain/usecases/logout_usecase.dart';
import 'package:demo_ai_workflow/features/auth/presentation/cubit/login_cubit.dart';
import 'package:demo_ai_workflow/features/auth/presentation/cubit/profile_cubit.dart';
import 'package:get_it/get_it.dart';

final GetIt sl = GetIt.instance;

void configureDependencies() {
  sl
    // Core
    ..registerLazySingleton<TokenStorage>(SecureTokenStorage.new)
    ..registerLazySingleton(() => DioFactory.create(sl()))
    // Auth – data
    ..registerLazySingleton<AuthRemoteDataSource>(
      () => AuthRemoteDataSourceImpl(sl()),
    )
    ..registerLazySingleton<AuthRepository>(
      () => AuthRepositoryImpl(remote: sl(), tokenStorage: sl()),
    )
    // Auth – domain
    ..registerLazySingleton(() => LoginUseCase(sl()))
    ..registerLazySingleton(() => GetProfileUseCase(sl()))
    ..registerLazySingleton(() => LogoutUseCase(sl()))
    // Auth – presentation (new instance per screen)
    ..registerFactory(() => LoginCubit(sl()))
    ..registerFactory(() => ProfileCubit(getProfile: sl(), logout: sl()));
}
