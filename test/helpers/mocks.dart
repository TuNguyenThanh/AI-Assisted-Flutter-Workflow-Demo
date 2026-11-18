import 'package:demo_ai_workflow/core/storage/token_storage.dart';
import 'package:demo_ai_workflow/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:demo_ai_workflow/features/auth/domain/repositories/auth_repository.dart';
import 'package:demo_ai_workflow/features/auth/domain/usecases/get_profile_usecase.dart';
import 'package:demo_ai_workflow/features/auth/domain/usecases/login_usecase.dart';
import 'package:demo_ai_workflow/features/auth/domain/usecases/logout_usecase.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockAuthRemoteDataSource extends Mock implements AuthRemoteDataSource {}

class MockTokenStorage extends Mock implements TokenStorage {}

class MockLoginUseCase extends Mock implements LoginUseCase {}

class MockGetProfileUseCase extends Mock implements GetProfileUseCase {}

class MockLogoutUseCase extends Mock implements LogoutUseCase {}

class MockDio extends Mock implements Dio {}

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}
