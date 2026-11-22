import 'package:equatable/equatable.dart';

import '../../../core/errors/result.dart';

enum UserRole {
  viewer,
  operator,
  admin;

  /// Operators and admins can change links and firewall rules.
  bool get canOperate => this != UserRole.viewer;

  static UserRole parse(String? value) => UserRole.values.firstWhere(
    (r) => r.name == value,
    orElse: () => UserRole.viewer,
  );
}

class Session extends Equatable {
  const Session({
    required this.token,
    required this.username,
    required this.role,
    required this.expiresAt,
  });

  final String token;
  final String username;
  final UserRole role;
  final DateTime expiresAt;

  bool isExpired(DateTime now) => !now.isBefore(expiresAt);

  @override
  List<Object?> get props => [token, username, role, expiresAt];
}

abstract interface class AuthRepository {
  Future<Result<Session>> login(String username, String password);

  /// The saved session, if there is one and it has not expired.
  Future<Session?> restore();

  Future<void> logout();
}
