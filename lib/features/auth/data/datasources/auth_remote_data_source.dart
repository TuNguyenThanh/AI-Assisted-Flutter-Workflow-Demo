import 'package:demo_ai_workflow/core/error/exceptions.dart';
import 'package:demo_ai_workflow/features/auth/data/models/user_model.dart';
import 'package:dio/dio.dart';

abstract interface class AuthRemoteDataSource {
  Future<LoginResponseModel> login({
    required String username,
    required String password,
  });

  Future<UserModel> getMe();
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  const AuthRemoteDataSourceImpl(this._dio);

  final Dio _dio;

  @override
  Future<LoginResponseModel> login({
    required String username,
    required String password,
  }) => _guard(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'username': username, 'password': password, 'expiresInMins': 30},
    );
    return LoginResponseModel.fromJson(response.data!);
  }, isLogin: true);

  @override
  Future<UserModel> getMe() => _guard(() async {
    final response = await _dio.get<Map<String, dynamic>>('/auth/me');
    return UserModel.fromJson(response.data!);
  });

  /// Maps transport errors to typed exceptions in ONE place.
  Future<T> _guard<T>(
    Future<T> Function() request, {
    bool isLogin = false,
  }) async {
    try {
      return await request();
    } on DioException catch (e) {
      switch (e.type) {
        case DioExceptionType.connectionError:
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.transformTimeout:
          throw NetworkException(e.message);
        case DioExceptionType.badResponse:
          final status = e.response?.statusCode;
          if (isLogin && (status == 400 || status == 401)) {
            throw const InvalidCredentialsException();
          }
          if (status == 401) throw const UnauthorizedException();
          throw ServerException('HTTP $status');
        case DioExceptionType.badCertificate:
        case DioExceptionType.cancel:
        case DioExceptionType.unknown:
          throw ServerException(e.message);
      }
      // Malformed JSON / unexpected schema from `as` casts in fromJson.
      // ignore: avoid_catching_errors
    } on TypeError catch (e) {
      throw ServerException(e.toString());
    }
  }
}
