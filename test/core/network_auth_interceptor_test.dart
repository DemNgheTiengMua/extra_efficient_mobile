import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:extra_efficient_mobile/core/network/dio_client.dart';
import 'package:extra_efficient_mobile/core/storage/token_storage.dart';

class _FakeHttpClientAdapter implements HttpClientAdapter {
  _FakeHttpClientAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;
  final List<RequestOptions> recordedRequests = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    recordedRequests.add(options);
    return handler(options);
  }
}

void main() {
  group('Dio AuthInterceptor & TokenStorage', () {
    test('injects Bearer token from TokenStorage when present', () async {
      final storage = InMemoryTokenStorage(initialToken: 'jwt-abc-123');
      final adapter = _FakeHttpClientAdapter((options) async {
        return ResponseBody.fromString(
          jsonEncode({'ok': true}),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final dio = createDioClient(
        baseUrl: 'http://localhost:5001',
        tokenStorage: storage,
        onUnauthorized: () async {},
        adapter: adapter,
      );

      final response = await dio.get<Map<String, dynamic>>('/api/auth/me');

      expect(response.statusCode, 200);
      expect(
        adapter.recordedRequests.single.headers['Authorization'],
        'Bearer jwt-abc-123',
      );
    });

    test('clears TokenStorage and calls onUnauthorized on 401 response', () async {
      final storage = InMemoryTokenStorage(initialToken: 'expired-jwt');
      var unauthorizedCalled = 0;

      final adapter = _FakeHttpClientAdapter((options) async {
        return ResponseBody.fromString(
          jsonEncode({'message': 'Unauthorized'}),
          401,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final dio = createDioClient(
        baseUrl: 'http://localhost:5001',
        tokenStorage: storage,
        onUnauthorized: () async {
          unauthorizedCalled++;
        },
        adapter: adapter,
      );

      await expectLater(
        () => dio.get<Map<String, dynamic>>('/api/learner/context'),
        throwsA(isA<DioException>()),
      );

      expect(await storage.readToken(), isNull);
      expect(unauthorizedCalled, 1);
    });
  });
}
