import 'package:dio/dio.dart';

import '../config/env.dart';
import 'api_exception.dart';

typedef TokenReader = String? Function();

/// Thin wrapper around Dio for the OyaEat backend.
///
/// The backend is not uniform: most routes reply `{success, data, message}`
/// but a few (rider login, rider dashboard, track-rider) put their payload at
/// the top level. [unwrap] hides that difference from the repositories.
class ApiClient {
  ApiClient({
    required TokenReader readToken,
    required void Function() onUnauthorized,
    Dio? dio,
  }) : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: Env.apiBaseUrl,
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 30),
              headers: {'Content-Type': 'application/json'},
            )) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = readToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        // A rejected token on an authenticated call means the session expired.
        if (error.response?.statusCode == 401 &&
            error.requestOptions.headers.containsKey('Authorization')) {
          onUnauthorized();
        }
        handler.next(error);
      },
    ));
  }

  final Dio _dio;

  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => _dio.get<dynamic>(path, queryParameters: query));

  Future<Map<String, dynamic>> post(String path, {Object? body}) =>
      _send(() => _dio.post<dynamic>(path, data: body));

  Future<Map<String, dynamic>> put(String path, {Object? body}) =>
      _send(() => _dio.put<dynamic>(path, data: body));

  Future<Map<String, dynamic>> patch(String path, {Object? body}) =>
      _send(() => _dio.patch<dynamic>(path, data: body));

  Future<Map<String, dynamic>> delete(String path) =>
      _send(() => _dio.delete<dynamic>(path));

  /// Multipart upload (rider registration, avatar).
  Future<Map<String, dynamic>> postForm(String path, FormData form) =>
      _send(() => _dio.post<dynamic>(
            path,
            data: form,
            options: Options(contentType: 'multipart/form-data'),
          ));

  Future<Map<String, dynamic>> _send(Future<Response<dynamic>> Function() call) async {
    try {
      final res = await call();
      final body = res.data;
      if (body is Map<String, dynamic>) return body;
      return {'data': body};
    } on DioException catch (e) {
      throw _toException(e);
    }
  }

  static ApiException _toException(DioException e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;
    if (data is Map && (data['message'] ?? data['error']) != null) {
      return ApiException('${data['message'] ?? data['error']}', statusCode: status);
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException('The request timed out. Check your connection.', statusCode: status);
      case DioExceptionType.connectionError:
        return const ApiException('Cannot reach the server. Check your connection.');
      default:
        return ApiException(
          status == null ? 'Something went wrong.' : 'Request failed ($status)',
          statusCode: status,
        );
    }
  }

  /// Returns the payload of a response whether or not it is wrapped in `data`.
  static Map<String, dynamic> unwrap(Map<String, dynamic> body) {
    final data = body['data'];
    if (data is Map<String, dynamic>) return data;
    return body;
  }
}
