import '../../core/errors/app_failure.dart';
import '../../l10n/gen/app_localizations.dart';

String failureText(AppLocalizations l, AppFailure f) => switch (f) {
  NetworkFailure() => l.errorNetwork,
  UnauthorizedFailure() => l.errorUnauthorized,
  ForbiddenFailure() => l.errorForbidden,
  RateLimitedFailure() => l.errorRateLimited,
  ConflictFailure(:final detail) => l.errorConflict(detail ?? ''),
  ValidationFailure(:final detail) => l.errorValidation(detail ?? ''),
  ServerFailure(:final detail) =>
    detail == null ? l.errorGeneric : '${l.errorGeneric} ($detail)',
};
