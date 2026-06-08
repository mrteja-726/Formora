import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:formora/core/storage/secure_storage.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

class ApiClient {
  final Dio _dio;

  ApiClient({String baseUrl = 'http://localhost:3000/api/v1'})
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          headers: {
            'Content-Type': 'application/json',
          },
        )) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await SecureStorage.getAccessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) async {
          if (error.response?.statusCode == 401) {
            final refreshToken = await SecureStorage.getRefreshToken();
            if (refreshToken != null) {
              try {
                // Separate Dio client to avoid interceptor loop during refresh request
                final refreshDio = Dio(BaseOptions(baseUrl: baseUrl));
                final response = await refreshDio.post(
                  '/auth/refresh',
                  data: {'refreshToken': refreshToken},
                );

                if (response.statusCode == 200 || response.statusCode == 201) {
                  final responseData = response.data;
                  final data = responseData['data'];
                  final newAccess = data['accessToken'] as String;
                  final newRefresh = data['refreshToken'] as String;
                  final expiresIn = data['expiresIn'] as int;

                  await SecureStorage.saveTokens(
                    accessToken: newAccess,
                    refreshToken: newRefresh,
                    expiresAtMs: DateTime.now().millisecondsSinceEpoch + (expiresIn * 1000),
                  );

                  // Retry the original request
                  final options = error.requestOptions;
                  options.headers['Authorization'] = 'Bearer $newAccess';
                  
                  final retryResponse = await _dio.fetch(options);
                  return handler.resolve(retryResponse);
                }
              } catch (e) {
                // Refresh failed — clear secure storage so user has to log in again
                await SecureStorage.clear();
              }
            }
          }
          return handler.next(error);
        },
      ),
    );
  }

  Dio get dio => _dio;
}
