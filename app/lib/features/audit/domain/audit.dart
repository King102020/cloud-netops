import 'package:equatable/equatable.dart';

import '../../../core/errors/result.dart';

class AuditEntry extends Equatable {
  const AuditEntry({
    required this.id,
    required this.at,
    required this.actor,
    required this.role,
    required this.action,
    required this.target,
    required this.result,
    this.before,
    this.after,
  });

  final String id;
  final DateTime at;
  final String actor;
  final String role;
  final String action;
  final String target;
  final String result;
  final Map<String, Object?>? before;
  final Map<String, Object?>? after;

  @override
  List<Object?> get props => [
    id,
    at,
    actor,
    role,
    action,
    target,
    result,
    before,
    after,
  ];
}

class AuditPage extends Equatable {
  const AuditPage({required this.items, this.nextCursor});

  final List<AuditEntry> items;
  final String? nextCursor;

  @override
  List<Object?> get props => [items, nextCursor];
}

abstract interface class AuditRepository {
  Future<Result<AuditPage>> page({String? cursor, int limit = 25});
}
