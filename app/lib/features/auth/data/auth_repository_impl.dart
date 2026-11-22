import 'dart:convert';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/storage/token_store.dart';
import '../../../generated/api/export.dart';
import '../domain/session.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._client, this._store, {DateTime Function()? clock})
    : _now = clock ?? DateTime.now;

  final AuthClient _client;
  final TokenStore _store;
  final DateTime Function() _now;

  @override
  Future<Result<Session>> login(String username, String password) async {
    final result = await guard(
      () => _client.login(
        body: TokenRequest(username: username, password: password),
      ),
    );
    return switch (result) {
      Ok(:final value) => await _save(value.accessToken),
      Err(:final failure) => Err(failure),
    };
  }

  Future<Result<Session>> _save(String token) async {
    final session = decode(token);
    if (session == null) {
      await _store.clear();
      return const Err(ServerFailureMarker.invalidToken);
    }
    await _store.write(token);
    return Ok(session);
  }

  @override
  Future<Session?> restore() async {
    final token = await _store.read();
    final session = token == null ? null : decode(token);
    if (session == null || session.isExpired(_now())) {
      await _store.clear();
      return null;
    }
    return session;
  }

  @override
  Future<void> logout() => _store.clear();

  /// Reads the claims the UI needs. The token is verified by the API, not
  /// here: the app never trusts its own decoding for authorisation.
  static Session? decode(String token) {
    final parts = token.split('.');
    if (parts.length != 3) {
      return null;
    }
    try {
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final claims = jsonDecode(payload);
      if (claims is! Map<String, Object?>) {
        return null;
      }
      final exp = claims['exp'];
      final sub = claims['sub'];
      if (exp is! int || sub is! String) {
        return null;
      }
      return Session(
        token: token,
        username: sub,
        role: UserRole.parse(claims['role'] as String?),
        expiresAt: DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true),
      );
    } on FormatException {
      return null;
    }
  }
}

/// Named failures produced by this repository itself.
abstract final class ServerFailureMarker {
  static const invalidToken = ServerFailure(
    'the API returned an unreadable token',
  );
}
