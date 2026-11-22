import 'package:cnops_app/core/config/env.dart';
import 'package:cnops_app/core/errors/app_failure.dart';
import 'package:cnops_app/core/errors/result.dart';
import 'package:cnops_app/core/network/api_client_factory.dart';
import 'package:cnops_app/core/storage/token_store.dart';
import 'package:cnops_app/generated/api/export.dart' show TokenRequest;
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

DioException _err(int? status, [Object? data]) => DioException(
  requestOptions: RequestOptions(path: '/v1/x'),
  response: status == null
      ? null
      : Response(
          requestOptions: RequestOptions(path: '/v1/x'),
          statusCode: status,
          data: data,
        ),
  type: status == null
      ? DioExceptionType.connectionError
      : DioExceptionType.badResponse,
);

void main() {
  group('AppFailure.fromDio', () {
    test('maps status codes', () {
      expect(AppFailure.fromDio(_err(null)), const NetworkFailure());
      expect(AppFailure.fromDio(_err(401)), isA<UnauthorizedFailure>());
      expect(AppFailure.fromDio(_err(403)), isA<ForbiddenFailure>());
      expect(AppFailure.fromDio(_err(409)), isA<ConflictFailure>());
      expect(AppFailure.fromDio(_err(400)), isA<ValidationFailure>());
      expect(AppFailure.fromDio(_err(422)), isA<ValidationFailure>());
      expect(AppFailure.fromDio(_err(429)), isA<RateLimitedFailure>());
      expect(AppFailure.fromDio(_err(500)), isA<ServerFailure>());
    });

    test('reads RFC 9457 detail and the first validation message', () {
      expect(
        AppFailure.fromDio(_err(409, {'detail': 'overlaps br1'})).detail,
        'overlaps br1',
      );
      final v = AppFailure.fromDio(
        _err(422, {
          'detail': 'Request validation failed',
          'errors': [
            {
              'loc': ['body', 'cidr'],
              'msg': 'Value error, 0.0.0.0/0 is not allowed (default deny)',
            },
          ],
        }),
      );
      expect(v.detail, '0.0.0.0/0 is not allowed (default deny)');
      expect(AppFailure.fromDio(_err(500, 'plain text')).detail, isNull);
    });
  });

  group('guard', () {
    test('wraps values, Dio errors, format and type errors', () async {
      expect(await guard(() async => 1), isA<Ok<int>>());
      expect(
        (await guard<int>(() => throw _err(403)) as Err).failure,
        isA<ForbiddenFailure>(),
      );
      expect(
        (await guard<int>(() => throw const FormatException('bad')) as Err)
            .failure,
        isA<ServerFailure>(),
      );
      final typeErr = await guard<int>(() async => (null as Object?)! as int);
      expect(typeErr, isA<Err<int>>());
    });

    test('fold', () {
      expect(const Ok(2).fold((v) => v * 2, (_) => 0), 4);
      expect(const Err<int>(NetworkFailure()).fold((v) => v, (_) => -1), -1);
    });
  });

  group('interceptors', () {
    test('adds bearer token and request id, skips token on login', () async {
      final adapter = FakeHttpAdapter({
        'GET /v1/alerts': (_) => (200, <Object?>[]),
        'POST /v1/auth/token': (_) => (
          200,
          {'access_token': 'a.b.c', 'expires_in': 60, 'role': 'viewer'},
        ),
      });
      final client = buildApiClient(
        baseUrl: 'http://api',
        token: () => 'tok',
        onUnauthorized: () {},
        adapter: adapter,
      );
      await client.alerts.alerts();
      expect(adapter.requests.last.headers['Authorization'], 'Bearer tok');
      expect(
        (adapter.requests.last.headers['X-Request-ID'] as String).length,
        32,
      );
      await client.auth.login(
        body: const TokenRequest(username: 'u', password: 'p'),
      );
      expect(
        adapter.requests.last.headers.containsKey('Authorization'),
        isFalse,
      );
    });

    test('a 401 outside login signs the user out', () async {
      var expired = 0;
      final client = buildApiClient(
        baseUrl: 'http://api',
        token: () => 'old',
        onUnauthorized: () => expired++,
        adapter: FakeHttpAdapter({
          'GET /v1/alerts': (_) => (401, {'detail': 'expired'}),
        }),
      );
      await expectLater(client.alerts.alerts(), throwsA(isA<DioException>()));
      expect(expired, 1);
    });

    test('retries GETs on 5xx, never POSTs', () async {
      var gets = 0;
      var posts = 0;
      final dio = Dio(BaseOptions(baseUrl: 'http://api'))
        ..httpClientAdapter = FakeHttpAdapter({
          'GET /x': (_) =>
              ++gets < 3 ? (503, {'detail': 'busy'}) : (200, {'ok': true}),
          'POST /x': (_) {
            posts++;
            return (503, {'detail': 'busy'});
          },
        });
      dio.interceptors.add(RetryInterceptor(dio, baseDelay: Duration.zero));
      expect((await dio.get<Object?>('/x')).statusCode, 200);
      expect(gets, 3);
      await expectLater(dio.post<Object?>('/x'), throwsA(isA<DioException>()));
      expect(posts, 1);
    });

    test('gives up after maxRetries', () async {
      var gets = 0;
      final dio = Dio(BaseOptions(baseUrl: 'http://api'))
        ..httpClientAdapter = FakeHttpAdapter({
          'GET /x': (_) {
            gets++;
            return (500, {'detail': 'down'});
          },
        });
      dio.interceptors.add(RetryInterceptor(dio, baseDelay: Duration.zero));
      await expectLater(dio.get<Object?>('/x'), throwsA(isA<DioException>()));
      expect(gets, 3); // first try + 2 retries
    });
  });

  test('MemoryTokenStore', () async {
    final s = MemoryTokenStore();
    expect(await s.read(), isNull);
    await s.write('t');
    expect(await s.read(), 't');
    await s.clear();
    expect(await s.read(), isNull);
  });

  test('Env defaults to the local flavor', () {
    final env = Env.fromDefines();
    expect(env.flavor, 'local');
    expect(env.isLocal, isTrue);
    expect(env.apiBaseUrl, startsWith('http'));
  });
}
