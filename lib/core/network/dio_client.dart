import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/auth_provider.dart';
import '../config/app_config.dart';
import '../storage/token_storage.dart';

/// Callback invoked when the server rejects a request with HTTP 401.
typedef UnauthorizedCallback = Future<void> Function();

/// Dio interceptor that injects `Authorization: Bearer <token>` and handles `401`.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this.tokenStorage,
    required this.onUnauthorized,
  });

  final TokenStorage tokenStorage;
  final UnauthorizedCallback onUnauthorized;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await tokenStorage.readToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401) {
      await tokenStorage.clearToken();
      await onUnauthorized();
    }
    handler.next(err);
  }
}

/// Builds a configured [Dio] instance with base URL, JSON headers, and [AuthInterceptor].
Dio createDioClient({
  required String baseUrl,
  required TokenStorage tokenStorage,
  required UnauthorizedCallback onUnauthorized,
  HttpClientAdapter? adapter,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ),
  );
  if (adapter != null) {
    dio.httpClientAdapter = adapter;
  }
  dio.interceptors.add(
    AuthInterceptor(
      tokenStorage: tokenStorage,
      onUnauthorized: onUnauthorized,
    ),
  );
  return dio;
}

/// Optional [HttpClientAdapter] override seam for high-seam widget tests.
final httpClientAdapterProvider = Provider<HttpClientAdapter?>((ref) => null);

/// Callback invoked on 401 responses; wired by auth state to sign out immediately.
final unauthorizedCallbackProvider = Provider<UnauthorizedCallback>(
  (ref) => () => ref.read(authNotifierProvider.notifier).handleUnauthorized(),
);

/// Shared [Dio] HTTP client provider.
final dioProvider = Provider<Dio>((ref) {
  final tokenStorage = ref.watch(tokenStorageProvider);
  final adapter = ref.watch(httpClientAdapterProvider);
  final onUnauthorized = ref.watch(unauthorizedCallbackProvider);
  return createDioClient(
    baseUrl: AppConfig.baseUrl,
    tokenStorage: tokenStorage,
    onUnauthorized: () => onUnauthorized(),
    adapter: adapter,
  );
});
