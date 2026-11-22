import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';

/// Everything that can go wrong, in terms the UI can explain.
sealed class AppFailure extends Equatable {
  const AppFailure([this.detail]);

  /// Server-provided explanation (RFC 9457 `detail`), when there is one.
  final String? detail;

  @override
  List<Object?> get props => [runtimeType, detail];

  /// Maps a Dio error (and its RFC 9457 problem body) to a failure.
  static AppFailure fromDio(DioException e) {
    final response = e.response;
    if (response == null) {
      return const NetworkFailure();
    }
    final detail = _detail(response.data);
    return switch (response.statusCode) {
      401 => UnauthorizedFailure(detail),
      403 => ForbiddenFailure(detail),
      409 => ConflictFailure(detail),
      422 || 400 => ValidationFailure(detail),
      429 => RateLimitedFailure(detail),
      _ => ServerFailure(detail),
    };
  }

  static String? _detail(Object? data) {
    if (data is! Map) {
      return null;
    }
    final detail = data['detail'];
    final errors = data['errors'];
    if (errors is List && errors.isNotEmpty && errors.first is Map) {
      final first = errors.first as Map;
      final msg = first['msg'];
      if (msg is String) {
        return msg.replaceFirst('Value error, ', '');
      }
    }
    return detail is String ? detail : null;
  }
}

final class NetworkFailure extends AppFailure {
  const NetworkFailure();
}

final class UnauthorizedFailure extends AppFailure {
  const UnauthorizedFailure([super.detail]);
}

final class ForbiddenFailure extends AppFailure {
  const ForbiddenFailure([super.detail]);
}

final class ConflictFailure extends AppFailure {
  const ConflictFailure([super.detail]);
}

final class ValidationFailure extends AppFailure {
  const ValidationFailure([super.detail]);
}

final class RateLimitedFailure extends AppFailure {
  const RateLimitedFailure([super.detail]);
}

final class ServerFailure extends AppFailure {
  const ServerFailure([super.detail]);
}
