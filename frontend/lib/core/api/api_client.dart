import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session.dart';
import '../config.dart';

/// An API error the UI can show as-is. `code` matches the backend's error codes
/// (e.g. `qr_expired`, `route_full`) so screens can react specifically.
class ApiException implements Exception {
  ApiException(this.message, {this.status, this.code, this.data});

  final String message;
  final int? status;
  final String? code;
  final Map<String, dynamic>? data;

  factory ApiException.fromDio(DioException e) {
    final res = e.response;
    if (res == null) {
      return ApiException("Can't reach the transport server. Check your connection and try again.");
    }
    final body = res.data;
    if (body is Map<String, dynamic>) {
      final detail = body['detail'];
      final message = switch (detail) {
        String s => s,
        // FastAPI validation errors: [{loc, msg}, ...]
        List l when l.isNotEmpty =>
          l.map((x) => (x as Map)['msg'].toString().replaceFirst('Value error, ', '')).join('\n'),
        _ => 'Request failed (${res.statusCode}).',
      };
      return ApiException(message, status: res.statusCode, code: body['code'] as String?, data: body);
    }
    return ApiException('Request failed (${res.statusCode}).', status: res.statusCode);
  }

  @override
  String toString() => message;
}

String describeError(Object e) => e is ApiException ? e.message : e.toString();

/// Thin wrapper over Dio: adds the bearer token, renews it once on 401, and
/// turns errors into [ApiException].
class ApiClient {
  ApiClient(this._ref) {
    dio.interceptors.add(
      QueuedInterceptorsWrapper(
        onRequest: (options, handler) {
          final token = _ref.read(sessionProvider)?.accessToken;
          if (token != null) options.headers['Authorization'] = 'Bearer $token';
          handler.next(options);
        },
        onError: (e, handler) async {
          final isAuthCall = e.requestOptions.path.startsWith('/auth/');
          final retried = e.requestOptions.extra['retried'] == true;
          if (e.response?.statusCode == 401 && !isAuthCall && !retried) {
            final fresh = await _ref.read(sessionProvider.notifier).refresh();
            if (fresh != null) {
              final opts = e.requestOptions
                ..headers['Authorization'] = 'Bearer $fresh'
                ..extra['retried'] = true;
              try {
                return handler.resolve(await dio.fetch(opts));
              } on DioException catch (again) {
                return handler.next(again);
              }
            }
          }
          handler.next(e);
        },
      ),
    );
  }

  final Ref _ref;
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBase,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 20),
    ),
  );

  Future<T> _wrap<T>(Future<Response> Function() call) async {
    try {
      return (await call()).data as T;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<T> get<T>(String path, {Map<String, dynamic>? query}) =>
      _wrap(() => dio.get(path, queryParameters: _clean(query)));

  Future<T> post<T>(String path, [Object? body]) => _wrap(() => dio.post(path, data: body));

  Future<T> patch<T>(String path, Object body) => _wrap(() => dio.patch(path, data: body));

  Future<T> put<T>(String path, Object body) => _wrap(() => dio.put(path, data: body));

  Future<void> delete(String path) => _wrap<dynamic>(() => dio.delete(path));

  static Map<String, dynamic>? _clean(Map<String, dynamic>? q) =>
      q == null ? null : (Map.of(q)..removeWhere((_, v) => v == null));
}

final apiProvider = Provider<ApiClient>(ApiClient.new);

typedef Json = Map<String, dynamic>;

List<Json> asList(Object? v) => (v as List).cast<Json>();
