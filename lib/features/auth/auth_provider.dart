import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/dio_client.dart';
import '../../core/storage/token_storage.dart';
import 'auth_models.dart';

/// Extracts a human-readable error message from a [DioException] or fallback.
String extractApiError(Object error, {String fallback = 'Request failed'}) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final msg = data['message'] ?? data['error'] ?? data['title'];
      if (msg is String && msg.isNotEmpty) {
        return msg;
      }
    }
    if (error.message != null && error.message!.isNotEmpty) {
      return error.message!;
    }
  }
  return fallback;
}

/// Manages learner authentication, JWT persistence, and 401 session invalidation.
class AuthNotifier extends Notifier<AuthState> {
  bool _restoreStarted = false;

  @override
  AuthState build() {
    if (!_restoreStarted) {
      _restoreStarted = true;
      Future.microtask(restoreSession);
    }
    return const AuthState.unknown();
  }

  Future<void> restoreSession() async {
    final storage = ref.read(tokenStorageProvider);
    final token = await storage.readToken();
    if (token == null || token.isEmpty) {
      state = const AuthState.unauthenticated();
      return;
    }

    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get<Map<String, dynamic>>('/api/auth/me');
      final data = response.data;
      if (data == null) {
        await storage.clearToken();
        state = const AuthState.unauthenticated();
        return;
      }
      state = AuthState.authenticated(AuthUser.fromJson(data));
    } catch (_) {
      await storage.clearToken();
      state = const AuthState.unauthenticated();
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    final dio = ref.read(dioProvider);
    final response = await dio.post<Map<String, dynamic>>(
      '/api/auth/sign-in',
      data: {'email': email.trim(), 'password': password},
    );
    final data = response.data ?? const <String, dynamic>{};
    final token = data['token'] as String? ?? '';
    final userMap = data['user'] as Map<String, dynamic>?;
    if (token.isEmpty || userMap == null) {
      throw StateError('Invalid sign-in response from server');
    }

    await ref.read(tokenStorageProvider).writeToken(token);
    state = AuthState.authenticated(AuthUser.fromJson(userMap));
  }

  Future<String> register({
    required String fullName,
    required String email,
    String? phone,
    required String password,
    required bool termsAccepted,
  }) async {
    final dio = ref.read(dioProvider);
    final response = await dio.post<Map<String, dynamic>>(
      '/api/auth/register',
      data: {
        'fullName': fullName.trim(),
        'email': email.trim(),
        'phone': (phone == null || phone.trim().isEmpty) ? null : phone.trim(),
        'password': password,
        'termsAccepted': termsAccepted,
      },
    );
    return (response.data?['message'] as String?) ?? 'Registration successful';
  }

  Future<String> verifyEmail({required String token}) async {
    final dio = ref.read(dioProvider);
    final response = await dio.post<Map<String, dynamic>>(
      '/api/auth/verify-email',
      data: {'token': token.trim()},
    );
    return (response.data?['message'] as String?) ?? 'Email verified';
  }

  Future<String> resendActivation() async {
    final dio = ref.read(dioProvider);
    final response = await dio.post<Map<String, dynamic>>(
      '/api/auth/resend-activation',
      data: const <String, dynamic>{},
    );
    return (response.data?['message'] as String?) ?? 'Activation email sent';
  }

  Future<String> forgotPassword({required String email}) async {
    final dio = ref.read(dioProvider);
    final response = await dio.post<Map<String, dynamic>>(
      '/api/auth/forgot-password',
      data: {'email': email.trim()},
    );
    return (response.data?['message'] as String?) ??
        'Password reset instructions sent';
  }

  Future<String> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    final dio = ref.read(dioProvider);
    final response = await dio.post<Map<String, dynamic>>(
      '/api/auth/reset-password',
      data: {
        'token': token.trim(),
        'newPassword': newPassword,
      },
    );
    return (response.data?['message'] as String?) ?? 'Password reset complete';
  }

  Future<void> signOut() async {
    await ref.read(tokenStorageProvider).clearToken();
    state = const AuthState.unauthenticated();
  }

  Future<void> handleUnauthorized() async {
    await ref.read(tokenStorageProvider).clearToken();
    if (state.status != AuthStatus.unauthenticated) {
      state = const AuthState.unauthenticated();
    }
  }
}

final authNotifierProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

/// Bridges [authNotifierProvider] state changes to a [Listenable] for `go_router`.
class AuthRouterRefresh extends ChangeNotifier {
  AuthRouterRefresh(Ref ref) {
    ref.listen<AuthState>(authNotifierProvider, (_, _) {
      notifyListeners();
    });
  }
}

final authRouterRefreshProvider = Provider<AuthRouterRefresh>((ref) {
  final refresh = AuthRouterRefresh(ref);
  ref.onDispose(refresh.dispose);
  return refresh;
});
