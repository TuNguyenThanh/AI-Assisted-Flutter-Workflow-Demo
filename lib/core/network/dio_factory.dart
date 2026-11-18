import 'package:demo_ai_workflow/core/network/api_config.dart';
import 'package:demo_ai_workflow/core/network/auth_interceptor.dart';
import 'package:demo_ai_workflow/core/storage/token_storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

abstract final class DioFactory {
  static Dio _base() => Dio(
    BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: ApiConfig.connectTimeout,
      receiveTimeout: ApiConfig.receiveTimeout,
      contentType: Headers.jsonContentType,
    ),
  );

  static Dio create(TokenStorage tokenStorage) {
    final dio = _base();
    dio.interceptors.add(
      AuthInterceptor(
        tokenStorage: tokenStorage,
        refreshClient: _base(),
        retryClient: _base(),
      ),
    );
    if (kDebugMode) {
      // Never log headers/bodies: they contain passwords and tokens.
      dio.interceptors.add(
        LogInterceptor(requestHeader: false, responseHeader: false),
      );
    }
    return dio;
  }
}
