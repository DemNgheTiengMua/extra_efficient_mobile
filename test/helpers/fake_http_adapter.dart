import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

typedef RouteHandler = Future<ResponseBody> Function(
  RequestOptions options,
  dynamic body,
);

/// Deterministic fake [HttpClientAdapter] for high-seam widget tests.
class FakeHttpClientAdapter implements HttpClientAdapter {
  FakeHttpClientAdapter(this.handler);

  final RouteHandler handler;
  final List<RequestOptions> requests = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    dynamic body = options.data;
    if (body is String && body.isNotEmpty) {
      try {
        body = jsonDecode(body);
      } catch (_) {}
    }
    return handler(options, body);
  }

  static ResponseBody jsonResponse(Object? data, {int statusCode = 200}) {
    return ResponseBody.fromString(
      data == null ? '' : jsonEncode(data),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}
