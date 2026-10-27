import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Answers each request according to its path, and records the order of calls.
class RoutingAdapter implements HttpClientAdapter {
  RoutingAdapter(this.routes);

  /// path -> (status, body)
  final Map<String, (int, Object?)> routes;
  final calls = <String>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    calls.add(options.path);
    final (status, body) = routes[options.path] ?? (404, {'message': 'no route'});
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
