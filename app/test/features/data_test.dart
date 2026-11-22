// Repository tests: the real generated client + mapping, over a fake HTTP adapter.
import 'dart:convert';

import 'package:cnops_app/core/errors/app_failure.dart';
import 'package:cnops_app/core/errors/result.dart';
import 'package:cnops_app/core/network/api_client_factory.dart';
import 'package:cnops_app/core/storage/token_store.dart';
import 'package:cnops_app/features/audit/data/audit_repository_impl.dart';
import 'package:cnops_app/features/auth/data/auth_repository_impl.dart';
import 'package:cnops_app/features/auth/domain/session.dart';
import 'package:cnops_app/features/firewall/data/firewall_repository_impl.dart';
import 'package:cnops_app/features/firewall/domain/firewall.dart';
import 'package:cnops_app/features/network/data/network_repository_impl.dart';
import 'package:cnops_app/features/network/domain/network.dart';
import 'package:cnops_app/generated/api/export.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/api_json.dart';
import '../helpers/fakes.dart';

CnopsApiClient client(FakeHttpAdapter adapter) => buildApiClient(
  baseUrl: 'http://api',
  token: () => 't',
  onUnauthorized: () {},
  adapter: adapter,
);

String jwt(Object claims) {
  String part(Object o) =>
      base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${part({'alg': 'HS256'})}.${part(claims)}.sig';
}

T ok<T>(Result<T> r) => (r as Ok<T>).value;

void main() {
  group('NetworkRepositoryImpl', () {
    final adapter = FakeHttpAdapter({
      'GET /v1/topology': (_) => (200, topologyJson),
      'GET /v1/devices/hq-core-01': (_) =>
          (200, (topologyJson['devices']! as List).first),
      'GET /v1/devices/hq-core-01/health': (_) => (200, healthJson),
      'GET /v1/alerts': (_) => (200, alertsJson),
      'PATCH /v1/links/hq-br2': (o) {
        final state = (o.data as Map)['state'];
        final link = Map<String, Object?>.of(
          (topologyJson['links']! as List).first as Map<String, Object?>,
        )..['state'] = state;
        return (200, link);
      },
    });
    final repo = NetworkRepositoryImpl(client(adapter));

    test('topology maps sites, roles and link states', () async {
      final t = ok(await repo.topology());
      expect(t.sites.map((s) => s.id), ['hq', 'isp']);
      expect(t.sites.last.cloudCidr, isNull);
      expect(
        {for (final n in t.nodes) n.id: n.role},
        {
          'hq-core-01': NodeRole.router,
          'hq-srv-01': NodeRole.server,
          'isp-edge-01': NodeRole.isp,
          'hq-pc-01': NodeRole.host,
        },
      );
      final core = t.nodes.first;
      expect(core.interfaces.map((i) => i.state), [
        LinkStatus.up,
        LinkStatus.down,
      ]);
      expect(t.links.first.state, LinkStatus.down);
      expect(t.links.first.touches('br2-edge-01'), isTrue);
      expect(t.links.last.state, LinkStatus.unknown);
      expect(t.links.last.controllable, isFalse);
    });

    test('device and health', () async {
      expect(ok(await repo.device('hq-core-01')).routerId, '10.255.255.2');
      final h = ok(await repo.health('hq-core-01'));
      expect(h.level, HealthLevel.degraded);
      expect(h.uptime, const Duration(seconds: 7323));
      expect(h.neighbors.single.interface, 'eth1');
      expect(h.missingNeighbors, ['10.255.255.4']);
    });

    test('setLink sends the state and maps the reply', () async {
      final link = ok(await repo.setLink('hq-br2', up: true));
      expect(link.state, LinkStatus.up);
      expect(jsonDecode(jsonEncode(adapter.requests.last.data)), {
        'state': 'up',
      });
    });

    test('alerts', () async {
      final alerts = ok(await repo.alerts());
      expect(alerts.first.critical, isTrue);
      expect(alerts.first.kind, 'link_down');
      expect(alerts.last.critical, isFalse);
    });

    test('404 becomes a failure, not an exception', () async {
      final r = await repo.device('nope-01');
      expect((r as Err).failure, isA<ServerFailure>());
    });
  });

  group('FirewallRepositoryImpl', () {
    test(
      'list follows cursors; create sends Idempotency-Key; patch; delete',
      () async {
        final adapter = FakeHttpAdapter({
          'GET /v1/firewall-rules': (o) => o.queryParameters['cursor'] == null
              ? (
                  200,
                  {
                    'items': [ruleJson()],
                    'next_cursor': 'c2',
                  },
                )
              : (
                  200,
                  {
                    'items': [ruleJson(id: 'fw-0000bbbb', status: 'pending')],
                    'next_cursor': null,
                  },
                ),
          'POST /v1/firewall-rules': (_) =>
              (202, ruleJson(id: 'fw-0000cccc', status: 'planned')),
          'PATCH /v1/firewall-rules/fw-0000aaaa': (_) =>
              (202, ruleJson(enabled: false, status: 'failed')),
          'DELETE /v1/firewall-rules/fw-0000aaaa': (_) => (
            202,
            {
              'id': 'job-12345678',
              'kind': 'terraform',
              'mode': 'apply',
              'state': 'queued',
              'reason': 'delete',
              'created_at': '2026-11-22T10:00:00Z',
            },
          ),
        }); // fmt: skip
        final repo = FirewallRepositoryImpl(client(adapter).firewall);

        final rules = ok(await repo.list());
        expect(rules.map((r) => r.status), [
          ChangeState.applied,
          ChangeState.pending,
        ]);
        expect(rules.first.ports, '8443');

        final created = ok(
          await repo.create(
            const NewFirewallRule(
              site: 'hq',
              tier: 'servers',
              protocol: 'tcp',
              fromPort: 8443,
              toPort: 8443,
              cidr: ' 10.20.10.0/24 ',
              description: ' app port ',
            ),
            idempotencyKey: 'key-123456',
          ),
        ); // fmt: skip
        expect(created.status, ChangeState.planned);
        final post = adapter.requests.firstWhere((r) => r.method == 'POST');
        expect(post.headers['Idempotency-Key'], 'key-123456');
        expect(
          (jsonDecode(jsonEncode(post.data)) as Map)['cidr'],
          '10.20.10.0/24',
        );

        final off = ok(await repo.setEnabled('fw-0000aaaa', enabled: false));
        expect(off.enabled, isFalse);
        expect(off.status, ChangeState.failed);
        expect(await repo.delete('fw-0000aaaa'), isA<Ok<void>>());
      },
    );

    test('409 conflict carries the API detail', () async {
      final repo = FirewallRepositoryImpl(
        client(
          FakeHttpAdapter({
            'POST /v1/firewall-rules': (_) =>
                (409, {'detail': 'identical rule exists'}),
          }),
        ).firewall,
      );
      final r = await repo.create(
        const NewFirewallRule(
          site: 'hq',
          tier: 'servers',
          protocol: 'tcp',
          fromPort: 1,
          toPort: 1,
          cidr: '10.0.0.0/8',
          description: 'abc',
        ),
        idempotencyKey: 'k-12345678',
      );
      expect(
        (r as Err).failure,
        const ConflictFailure('identical rule exists'),
      );
    });
  });

  group('AuditRepositoryImpl', () {
    test('maps pages and tolerates non-map before/after', () async {
      final repo = AuditRepositoryImpl(
        client(
          FakeHttpAdapter({
            'GET /v1/audit-events': (o) =>
                (200, auditJson(o.queryParameters['cursor'] as String?)),
          }),
        ).audit,
      );
      final p1 = ok(await repo.page());
      expect(p1.items.first.before, {'state': 'up'});
      expect(p1.items.last.after, isNull);
      expect(p1.nextCursor, 'page2');
      expect(ok(await repo.page(cursor: 'page2')).nextCursor, isNull);
    });
  });

  group('AuthRepositoryImpl', () {
    final future = DateTime.utc(2030).millisecondsSinceEpoch ~/ 1000;

    test('login stores the token and decodes role and expiry', () async {
      final token = jwt({'sub': 'alice', 'role': 'operator', 'exp': future});
      final store = MemoryTokenStore();
      final repo = AuthRepositoryImpl(
        client(
          FakeHttpAdapter({
            'POST /v1/auth/token': (_) => (
              200,
              {'access_token': token, 'expires_in': 60, 'role': 'operator'},
            ),
          }),
        ).auth,
        store,
      );
      final s = ok(await repo.login('alice', 'pw'));
      expect(s.username, 'alice');
      expect(s.role, UserRole.operator);
      expect(s.role.canOperate, isTrue);
      expect(await store.read(), token);
      expect(await repo.restore(), s);
      await repo.logout();
      expect(await store.read(), isNull);
    });

    test(
      'wrong password is Unauthorized; unreadable token is a server failure',
      () async {
        final bad = AuthRepositoryImpl(
          client(
            FakeHttpAdapter({
              'POST /v1/auth/token': (_) => (401, {'detail': 'invalid'}),
            }),
          ).auth,
          MemoryTokenStore(),
        );
        expect(
          (await bad.login('a', 'b') as Err).failure,
          isA<UnauthorizedFailure>(),
        );
        final garbled = AuthRepositoryImpl(
          client(
            FakeHttpAdapter({
              'POST /v1/auth/token': (_) => (
                200,
                {
                  'access_token': 'not-a-jwt',
                  'expires_in': 60,
                  'role': 'admin',
                },
              ),
            }),
          ).auth,
          MemoryTokenStore(),
        );
        expect(
          (await garbled.login('a', 'b') as Err).failure,
          isA<ServerFailure>(),
        );
      },
    );

    test('restore drops expired or malformed tokens', () async {
      final store = MemoryTokenStore();
      final repo = AuthRepositoryImpl(
        client(FakeHttpAdapter({})).auth,
        store,
        clock: () => DateTime.utc(2031),
      );
      await store.write(jwt({'sub': 'a', 'role': 'admin', 'exp': future}));
      expect(await repo.restore(), isNull);
      expect(await store.read(), isNull);
      await store.write('x.%%%.y');
      expect(await repo.restore(), isNull);
      expect(AuthRepositoryImpl.decode(jwt({'sub': 1})), isNull);
      expect(AuthRepositoryImpl.decode(jwt(['list'])), isNull);
      expect(UserRole.parse('superuser'), UserRole.viewer);
    });
  });

  group('RuleValidation', () {
    test('private CIDRs only, no host bits, no /0', () {
      for (final good in [
        '10.20.10.0/24',
        '172.16.0.0/12',
        '192.168.1.0/24',
        '10.0.0.0/8',
        '10.1.1.1/32',
      ]) {
        expect(RuleValidation.isPrivateCidr(good), isTrue, reason: good);
      }
      for (final bad in [
        '8.8.8.0/24',
        '10.20.10.5/24',
        '0.0.0.0/0',
        '10.0.0.0',
        '300.1.1.0/24',
        '172.32.0.0/16',
        '10.0.0.0/4',
      ]) {
        expect(RuleValidation.isPrivateCidr(bad), isFalse, reason: bad);
      }
      expect(RuleValidation.isWorldOpen('0.0.0.0/0'), isTrue);
    });

    test('ports and descriptions', () {
      expect(RuleValidation.isPort(443), isTrue);
      expect(RuleValidation.isPort(0), isFalse);
      expect(RuleValidation.isPort(70000), isFalse);
      expect(RuleValidation.isPort(null), isFalse);
      expect(RuleValidation.isDescription('br1 users to app (8443)'), isTrue);
      expect(RuleValidation.isDescription('x'), isFalse);
      expect(RuleValidation.isDescription('drop table; --'), isFalse);
    });

    test('icmp ports label', () {
      expect(sampleRule().copyWith(enabled: false).enabled, isFalse);
      const icmp = FirewallRuleItem(
        id: 'fw-1',
        site: 'hq',
        tier: 'servers',
        protocol: 'icmp',
        fromPort: 8,
        toPort: 0,
        cidr: '10.0.0.0/8',
        description: 'ping',
        enabled: true,
        status: ChangeState.applied,
        createdBy: 'x',
      ); // fmt: skip
      expect(icmp.ports, 'type 8');
      expect(
        sampleRule().copyWith(status: ChangeState.failed).status,
        ChangeState.failed,
      );
    });
  });
}
