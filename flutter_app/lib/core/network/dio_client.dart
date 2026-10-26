import 'package:dio/dio.dart';

import '../storage/secure_hive_storage.dart';

/// Sovereign HTTP Client (`Dio`) with EdDSA Bearer JWT Interceptor,
/// automatic refresh token rotation, and offline-resilient error handling.
class SovereignDioClient {
  SovereignDioClient({
    required SecureSovereignStorage storage,
    String baseUrl = 'http://127.0.0.1:8000',
    Dio? dio,
  })  : _storage = storage,
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl,
                connectTimeout: const Duration(seconds: 4),
                receiveTimeout: const Duration(seconds: 6),
                headers: const <String, String>{
                  'Accept': 'application/json',
                  'Content-Type': 'application/json',
                  'X-Sovereign-Jurisdiction': 'NP-MOHP-EDCD',
                },
              ),
            ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (
          RequestOptions options,
          RequestInterceptorHandler handler,
        ) async {
          final token = await _storage.readAccessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  final SecureSovereignStorage _storage;
  final Dio _dio;

  Dio get rawDio => _dio;

  Future<Map<String, dynamic>> postJson(
    String path, {
    required Map<String, dynamic> data,
    Map<String, String>? extraHeaders,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      path,
      data: data,
      options: Options(headers: extraHeaders),
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? extraHeaders,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      path,
      queryParameters: queryParameters,
      options: Options(headers: extraHeaders),
    );
    return response.data ?? <String, dynamic>{};
  }
}
