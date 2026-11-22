import '../../../core/errors/result.dart';
import '../../../generated/api/export.dart' as api;
import '../domain/audit.dart';

class AuditRepositoryImpl implements AuditRepository {
  AuditRepositoryImpl(this._client);

  final api.AuditClient _client;

  @override
  Future<Result<AuditPage>> page({String? cursor, int limit = 25}) =>
      guard(() async {
        final p = await _client.auditEvents(cursor: cursor, limit: limit);
        return AuditPage(
          items: [for (final e in p.items) map(e)],
          nextCursor: p.nextCursor,
        );
      });

  static Map<String, Object?>? _asMap(Object? v) =>
      v is Map ? {for (final e in v.entries) '${e.key}': e.value} : null;

  static AuditEntry map(api.AuditEvent e) => AuditEntry(
    id: e.id,
    at: e.at,
    actor: e.actor,
    role: e.role.json ?? '?',
    action: e.action,
    target: e.target,
    result: e.result.json ?? '?',
    before: _asMap(e.before),
    after: _asMap(e.after),
  );
}
