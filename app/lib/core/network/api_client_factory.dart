import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../generated/api/export.dart';

typedef TokenProvider = String? Function();
typedef UnauthorizedHandler = void Function();

/// Builds the generated API client on a Dio with interceptors for auth,
/// request IDs, retries and (debug-only) logging (STANDARDS §6, §9).
CnopsApiClient buildApiClient({
  required String baseUrl,
  required TokenProvider token,
  required UnauthorizedHandler onUnauthorized,
  HttpClientAdapter? adapter,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 20),
      headers: {'Accept': 'application/json'},
    ),
  );
  if (adapter != null) {
    dio.httpClientAdapter = adapter;
  }
  dio.interceptors.addAll([
    RequestIdInterceptor(),
    AuthInterceptor(token, onUnauthorized),
    RetryInterceptor(dio),
    if (kDebugMode) SafeLogInterceptor(),
  ]);
  return CnopsApiClient(dio, baseUrl: baseUrl);
}

/// Correlation ID on every call; the API echoes it and logs it (STANDARDS §9).
class RequestIdInterceptor extends Interceptor {
  RequestIdInterceptor([Uuid? uuid]) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers.putIfAbsent(
      'X-Request-ID',
      () => _uuid.v4().replaceAll('-', ''),
    );
    handler.next(options);
  }
}

class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._token, this._onUnauthorized);

  final TokenProvider _token;
  final UnauthorizedHandler _onUnauthorized;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _token();
    if (token != null && !options.path.endsWith('/auth/token')) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final isLogin = err.requestOptions.path.endsWith('/auth/token');
    if (err.response?.statusCode == 401 && !isLogin) {
      _onUnauthorized();
    }
    handler.next(err);
  }
}

/// Retries idempotent reads on network errors and 5xx, with backoff.
/// Writes are never retried here: POSTs carry an Idempotency-Key and the
/// user decides whether to retry.
class RetryInterceptor extends Interceptor {
  RetryInterceptor(this._dio, {this.maxRetries = 2, Duration? baseDelay})
    : _baseDelay = baseDelay ?? const Duration(milliseconds: 300);

  final Dio _dio;
  final int maxRetries;
  final Duration _baseDelay;

  static bool _retryable(DioException e) =>
      e.requestOptions.method == 'GET' &&
      (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          (e.response?.statusCode ?? 0) >= 500);

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final attempt = (err.requestOptions.extra['retry'] as int?) ?? 0;
    if (!_retryable(err) || attempt >= maxRetries) {
      return handler.next(err);
    }
    await Future<void>.delayed(_baseDelay * pow(2, attempt).toInt());
    final options = err.requestOptions..extra['retry'] = attempt + 1;
    try {
      handler.resolve(await _dio.fetch<Object?>(options));
    } on DioException catch (e) {
      handler.next(e);
    }
  }
}

/// Debug logging that never prints tokens or passwords.
class SafeLogInterceptor extends Interceptor {
  @override
  void onResponse(
    Response<Object?> response,
    ResponseInterceptorHandler handler,
  ) {
    debugPrint(
      '[api] ${response.requestOptions.method} ${response.requestOptions.path} '
      '-> ${response.statusCode} (${response.headers.value('x-request-id')})',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    debugPrint(
      '[api] ${err.requestOptions.method} ${err.requestOptions.path} '
      '-> ${err.response?.statusCode ?? err.type.name}',
    );
    handler.next(err);
  }
}
