import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cnops_app/core/errors/app_failure.dart';
import 'package:cnops_app/core/errors/result.dart';
import 'package:cnops_app/features/audit/domain/audit.dart';
import 'package:cnops_app/features/auth/domain/session.dart';
import 'package:cnops_app/features/firewall/domain/firewall.dart';
import 'package:cnops_app/features/network/domain/network.dart';
import 'package:dio/dio.dart';

// ---------------------------------------------------------------- sample data
final checkedAt = DateTime.utc(2026, 11, 22, 10);

const routers = ['hq-edge-01', 'hq-core-01', 'br1-edge-01', 'br2-edge-01'];

NetworkSnapshot sampleSnapshot({LinkStatus hqBr2 = LinkStatus.up}) =>
    NetworkSnapshot(
      sites: const [
        Site(
          id: 'hq',
          name: 'Head office',
          cidr: '10.10.0.0/16',
          cloudCidr: '10.110.0.0/16',
          ospfArea: 0,
        ),
        Site(
          id: 'br1',
          name: 'Branch 1',
          cidr: '10.20.0.0/16',
          cloudCidr: '10.120.0.0/16',
          ospfArea: 1,
        ),
        Site(
          id: 'br2',
          name: 'Branch 2',
          cidr: '10.30.0.0/16',
          cloudCidr: '10.130.0.0/16',
          ospfArea: 2,
        ),
      ],
      nodes: [
        for (final r in routers)
          NetworkNode(
            id: r,
            site: r.split('-').first,
            role: NodeRole.router,
            model: 'FRR 10.2.1',
            routerId: '10.255.255.${routers.indexOf(r) + 1}',
            interfaces: const [
              NodeInterface(
                name: 'eth1',
                address: '10.255.0.2/30',
                state: LinkStatus.up,
              ),
            ],
          ),
        const NetworkNode(
          id: 'hq-srv-01',
          site: 'hq',
          role: NodeRole.server,
          model: 'multitool',
        ),
        const NetworkNode(
          id: 'isp-edge-01',
          site: 'isp',
          role: NodeRole.isp,
          model: 'FRR 10.2.1',
        ),
      ],
      links: [
        const NetworkLink(
          id: 'hq-br1',
          kind: 'wan',
          aDevice: 'hq-core-01',
          bDevice: 'br1-edge-01',
          subnet: '10.255.0.4/30',
          ospfCost: 10,
          state: LinkStatus.up,
          controllable: true,
        ),
        NetworkLink(
          id: 'hq-br2',
          kind: 'wan',
          aDevice: 'hq-core-01',
          bDevice: 'br2-edge-01',
          subnet: '10.255.0.8/30',
          ospfCost: 10,
          state: hqBr2,
          controllable: true,
        ),
        const NetworkLink(
          id: 'br1-br2',
          kind: 'backup',
          aDevice: 'br1-edge-01',
          bDevice: 'br2-edge-01',
          subnet: '10.255.0.12/30',
          ospfCost: 100,
          state: LinkStatus.up,
          controllable: true,
        ),
        const NetworkLink(
          id: 'hq-servers',
          kind: 'lan',
          aDevice: 'hq-core-01',
          bDevice: 'hq-srv-01',
          subnet: '10.10.20.0/24',
          state: LinkStatus.up,
          controllable: false,
        ),
      ],
    ); // fmt: skip

FirewallRuleItem sampleRule({
  String id = 'fw-0000aaaa',
  bool enabled = true,
  ChangeState status = ChangeState.applied,
}) => FirewallRuleItem(
  id: id,
  site: 'hq',
  tier: 'servers',
  protocol: 'tcp',
  fromPort: 8443,
  toPort: 8443,
  cidr: '10.20.10.0/24',
  description: 'br1 users to app port',
  enabled: enabled,
  status: status,
  createdBy: 'operator',
);

AuditEntry sampleAudit(int i) => AuditEntry(
  id: 'evt-$i',
  at: checkedAt.add(Duration(minutes: i)),
  actor: 'operator',
  role: 'operator',
  action: 'link.down',
  target: 'hq-br2',
  result: 'succeeded',
  before: const {'state': 'up'},
  after: const {'state': 'down'},
);

Session sampleSession({UserRole role = UserRole.operator}) => Session(
  token: 'token-${role.name}',
  username: role.name,
  role: role,
  expiresAt: DateTime.now().add(const Duration(hours: 1)),
);

// ---------------------------------------------------------------- fake repos
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.saved});

  Session? saved;
  final Map<String, (String, UserRole)> users = {
    'viewer': ('viewer-local', UserRole.viewer),
    'operator': ('operator-local', UserRole.operator),
  };

  @override
  Future<Result<Session>> login(String username, String password) async {
    final u = users[username];
    if (u == null || u.$1 != password) {
      return const Err(UnauthorizedFailure());
    }
    return Ok(saved = sampleSession(role: u.$2));
  }

  @override
  Future<Session?> restore() async => saved;

  @override
  Future<void> logout() async => saved = null;
}

/// In-memory network that behaves like the API's fake lab: taking a WAN link
/// down raises a link alert and an OSPF alert.
class FakeNetworkRepository implements NetworkRepository {
  NetworkSnapshot snapshot = sampleSnapshot();
  AppFailure? failNext;

  /// Fails only the next topology() call (alerts polls do not consume it).
  AppFailure? failTopology;
  int topologyCalls = 0;

  Result<T> _maybeFail<T>(T value) {
    final f = failNext;
    if (f != null) {
      failNext = null;
      return Err(f);
    }
    return Ok(value);
  }

  @override
  Future<Result<NetworkSnapshot>> topology() async {
    topologyCalls++;
    final f = failTopology;
    if (f != null) {
      failTopology = null;
      return Err(f);
    }
    return _maybeFail(snapshot);
  }

  @override
  Future<Result<NetworkNode>> device(String id) async {
    final node = snapshot.nodes.where((n) => n.id == id).firstOrNull;
    return node == null
        ? const Err(ServerFailure('not found'))
        : _maybeFail(node);
  }

  @override
  Future<Result<DeviceHealthInfo>> health(String id) async {
    final down = snapshot.links.any(
      (l) => l.id == 'hq-br2' && l.state == LinkStatus.down,
    );
    return _maybeFail(
      DeviceHealthInfo(
        deviceId: id,
        reachable: true,
        level: down && id == 'hq-core-01'
            ? HealthLevel.degraded
            : HealthLevel.healthy,
        uptime: const Duration(hours: 2, minutes: 5),
        neighbors: [
          const OspfNeighborInfo(
            routerId: '10.255.255.1',
            state: 'Full/-',
            interface: 'eth1',
          ),
          const OspfNeighborInfo(
            routerId: '10.255.255.3',
            state: 'Full/-',
            interface: 'eth2',
          ),
          if (!down)
            const OspfNeighborInfo(
              routerId: '10.255.255.4',
              state: 'Full/-',
              interface: 'eth3',
            ),
        ],
        expectedNeighbors: const [
          '10.255.255.1',
          '10.255.255.3',
          '10.255.255.4',
        ],
        checkedAt: checkedAt,
      ),
    );
  }

  @override
  Future<Result<NetworkLink>> setLink(String id, {required bool up}) async {
    final link = snapshot.links.firstWhere((l) => l.id == id);
    final changed = link.copyWith(state: up ? LinkStatus.up : LinkStatus.down);
    final r = _maybeFail(changed);
    if (r is Ok) {
      snapshot = snapshot.withLink(changed);
    }
    return r;
  }

  @override
  Future<Result<List<NetworkAlert>>> alerts() async => _maybeFail([
    for (final l in snapshot.links)
      if (l.controllable && l.state == LinkStatus.down) ...[
        NetworkAlert(
          id: 'link_down:${l.id}',
          critical: l.kind != 'backup',
          kind: 'link_down',
          target: l.id,
          message: 'link ${l.id} (${l.subnet}) is down',
          since: checkedAt,
        ),
        NetworkAlert(
          id: 'ospf:${l.aDevice}',
          critical: false,
          kind: 'ospf_neighbor_missing',
          target: l.aDevice,
          message: '${l.aDevice} lost an OSPF adjacency',
          since: checkedAt,
        ),
      ],
  ]); // fmt: skip
}

class FakeFirewallRepository implements FirewallRepository {
  FakeFirewallRepository([List<FirewallRuleItem>? rules])
    : rules = rules ?? [sampleRule()];

  List<FirewallRuleItem> rules;
  AppFailure? failNext;
  final List<String> keysSeen = [];
  int _n = 0;

  Err<T>? _fail<T>() {
    final f = failNext;
    failNext = null;
    return f == null ? null : Err(f);
  }

  @override
  Future<Result<List<FirewallRuleItem>>> list() async =>
      _fail() ?? Ok([...rules]);

  @override
  Future<Result<FirewallRuleItem>> create(
    NewFirewallRule rule, {
    required String idempotencyKey,
  }) async {
    keysSeen.add(idempotencyKey);
    final f = _fail<FirewallRuleItem>();
    if (f != null) {
      return f;
    }
    final item = FirewallRuleItem(
      id: 'fw-${(++_n).toRadixString(16).padLeft(8, '0')}',
      site: rule.site,
      tier: rule.tier,
      protocol: rule.protocol,
      fromPort: rule.fromPort,
      toPort: rule.toPort,
      cidr: rule.cidr,
      description: rule.description,
      enabled: true,
      status: ChangeState.pending,
      createdBy: 'operator',
    );
    rules = [...rules, item];
    return Ok(item);
  }

  /// Simulates Terraform finishing every pending change.
  void finishPending() => rules = [
    for (final r in rules)
      r.status == ChangeState.pending
          ? r.copyWith(status: ChangeState.applied)
          : r,
  ];

  @override
  Future<Result<FirewallRuleItem>> setEnabled(
    String id, {
    required bool enabled,
  }) async {
    final f = _fail<FirewallRuleItem>();
    if (f != null) {
      return f;
    }
    final updated = rules
        .firstWhere((r) => r.id == id)
        .copyWith(enabled: enabled, status: ChangeState.applied);
    rules = [for (final r in rules) r.id == id ? updated : r];
    return Ok(updated);
  }

  @override
  Future<Result<void>> delete(String id) async {
    final f = _fail<void>();
    if (f != null) {
      return f;
    }
    rules = rules.where((r) => r.id != id).toList();
    return const Ok(null);
  }
}

class FakeAuditRepository implements AuditRepository {
  FakeAuditRepository({this.total = 30});

  final int total;
  AppFailure? failNext;

  @override
  Future<Result<AuditPage>> page({String? cursor, int limit = 25}) async {
    final f = failNext;
    if (f != null) {
      failNext = null;
      return Err(f);
    }
    final start = int.tryParse(cursor ?? '0') ?? 0;
    final end = (start + limit).clamp(0, total);
    return Ok(
      AuditPage(
        items: [for (var i = start; i < end; i++) sampleAudit(total - i)],
        nextCursor: end < total ? '$end' : null,
      ),
    );
  }
}

// ---------------------------------------------------------------- fake HTTP
typedef FakeResponse = (int status, Object? body);

/// Dio adapter answering from a route table, so repository tests exercise
/// the real generated client and JSON mapping.
class FakeHttpAdapter implements HttpClientAdapter {
  FakeHttpAdapter(this.routes);

  /// Key: "METHOD /path" (query string ignored). Value: response or builder.
  final Map<String, FutureOr<FakeResponse> Function(RequestOptions)> routes;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final key = '${options.method} ${options.uri.path}';
    final handler = routes[key];
    if (handler == null) {
      return ResponseBody.fromString(
        jsonEncode({
          'title': 'Not Found',
          'status': 404,
          'detail': 'no fake for $key',
        }),
        404,
        headers: {
          Headers.contentTypeHeader: ['application/problem+json'],
        },
      );
    }
    final (status, body) = await handler(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [
          status >= 400 ? 'application/problem+json' : 'application/json',
        ],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
