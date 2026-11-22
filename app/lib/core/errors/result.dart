import 'package:dio/dio.dart';

import 'app_failure.dart';

/// Repositories return a Result and never throw into the UI (STANDARDS §6).
sealed class Result<T> {
  const Result();

  R fold<R>(R Function(T value) onOk, R Function(AppFailure failure) onErr) =>
      switch (this) {
        Ok<T>(:final value) => onOk(value),
        Err<T>(:final failure) => onErr(failure),
      };
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);

  final T value;
}

final class Err<T> extends Result<T> {
  const Err(this.failure);

  final AppFailure failure;
}

/// Runs an API call and turns any Dio error into an [Err].
Future<Result<T>> guard<T>(Future<T> Function() call) async {
  try {
    return Ok(await call());
  } on DioException catch (e) {
    return Err(AppFailure.fromDio(e));
  } on FormatException catch (e) {
    return Err(ServerFailure(e.message));
  } on TypeError {
    return const Err(ServerFailure('unexpected response from the API'));
  }
}
