import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../domain/session.dart';

sealed class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

/// Before the saved session has been checked.
final class AuthUnknown extends AuthState {
  const AuthUnknown();
}

final class AuthSignedOut extends AuthState {
  const AuthSignedOut({this.busy = false, this.failure});

  final bool busy;
  final AppFailure? failure;

  @override
  List<Object?> get props => [busy, failure];
}

final class AuthSignedIn extends AuthState {
  const AuthSignedIn(this.session);

  final Session session;

  @override
  List<Object?> get props => [session];
}

/// App-scope: who is signed in. Holds the token the HTTP client reads.
class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this._repo) : super(const AuthUnknown());

  final AuthRepository _repo;

  String? get token => switch (state) {
    AuthSignedIn(:final session) => session.token,
    _ => null,
  };

  UserRole? get role => switch (state) {
    AuthSignedIn(:final session) => session.role,
    _ => null,
  };

  Future<void> restore() async {
    final session = await _repo.restore();
    emit(session == null ? const AuthSignedOut() : AuthSignedIn(session));
  }

  Future<void> login(String username, String password) async {
    emit(const AuthSignedOut(busy: true));
    final result = await _repo.login(username.trim(), password);
    emit(switch (result) {
      Ok(:final value) => AuthSignedIn(value),
      Err(:final failure) => AuthSignedOut(failure: failure),
    });
  }

  Future<void> logout() async {
    await _repo.logout();
    emit(const AuthSignedOut());
  }

  /// Called by the HTTP client on a 401: the token is no longer valid.
  Future<void> sessionExpired() async {
    if (state is AuthSignedIn) {
      await _repo.logout();
      emit(const AuthSignedOut(failure: UnauthorizedFailure()));
    }
  }
}
