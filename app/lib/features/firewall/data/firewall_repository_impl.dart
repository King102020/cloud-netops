import '../../../core/errors/result.dart';
import '../../../generated/api/export.dart' as api;
import '../domain/firewall.dart';

class FirewallRepositoryImpl implements FirewallRepository {
  FirewallRepositoryImpl(this._client);

  final api.FirewallClient _client;

  @override
  Future<Result<List<FirewallRuleItem>>> list() => guard(() async {
    final items = <FirewallRuleItem>[];
    String? cursor;
    do {
      final page = await _client.listRules(cursor: cursor, limit: 100);
      items.addAll(page.items.map(map));
      cursor = page.nextCursor;
    } while (cursor != null);
    return items;
  });

  @override
  Future<Result<FirewallRuleItem>> create(
    NewFirewallRule rule, {
    required String idempotencyKey,
  }) => guard(() async {
    final body = api.FirewallRuleCreate(
      site: api.FirewallRuleCreateSite.fromJson(rule.site),
      tier: api.FirewallRuleCreateTier.fromJson(rule.tier),
      protocol: api.FirewallRuleCreateProtocol.fromJson(rule.protocol),
      fromPort: rule.fromPort,
      toPort: rule.toPort,
      cidr: rule.cidr.trim(),
      description: rule.description.trim(),
    );
    return map(
      await _client.createRule(idempotencyKey: idempotencyKey, body: body),
    );
  });

  @override
  Future<Result<FirewallRuleItem>> setEnabled(
    String id, {
    required bool enabled,
  }) => guard(
    () async => map(
      await _client.patchRule(
        ruleId: id,
        body: api.FirewallRulePatch(enabled: enabled),
      ),
    ),
  );

  @override
  Future<Result<void>> delete(String id) =>
      guard(() => _client.deleteRule(ruleId: id));

  static FirewallRuleItem map(api.FirewallRule r) => FirewallRuleItem(
    id: r.id,
    site: r.site.json ?? '?',
    tier: r.tier.json ?? '?',
    protocol: r.protocol.json ?? '?',
    fromPort: r.fromPort,
    toPort: r.toPort,
    cidr: r.cidr,
    description: r.description,
    enabled: r.enabled,
    status: switch (r.status) {
      api.ChangeStatus.applied => ChangeState.applied,
      api.ChangeStatus.planned => ChangeState.planned,
      api.ChangeStatus.failed => ChangeState.failed,
      _ => ChangeState.pending,
    },
    createdBy: r.createdBy,
  );
}
