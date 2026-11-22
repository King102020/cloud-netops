// Live contract check: the app's repositories against a running control API.
//   cd api && uvicorn --factory cnops_api.main:create_app --port 8000
//   flutter test --tags live
// Skipped automatically when nothing listens on localhost:8000.
@Tags(['live'])
library;

import 'dart:io';

import 'package:cnops_app/core/errors/result.dart';
import 'package:cnops_app/core/network/api_client_factory.dart';
import 'package:cnops_app/core/storage/token_store.dart';
import 'package:cnops_app/features/audit/data/audit_repository_impl.dart';
import 'package:cnops_app/features/auth/data/auth_repository_impl.dart';
import 'package:cnops_app/features/firewall/data/firewall_repository_impl.dart';
import 'package:cnops_app/features/firewall/domain/firewall.dart';
import 'package:cnops_app/features/network/data/network_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

const base = 'http://localhost:8000';

Future<bool> apiUp() async {
  try {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 1);
    final res = await (await client.getUrl(Uri.parse('$base/healthz'))).close();
    client.close();
    return res.statusCode == 200;
  } on Object {
    return false;
  }
}

T ok<T>(Result<T> r) => switch (r) {
  Ok(:final value) => value,
  Err(:final failure) => throw TestFailure('API call failed: $failure'),
};

Future<void> main() async {
  final up = await apiUp();

  test(
    'every repository works against the real API',
    () async {
      String? token;
      final client = buildApiClient(
        baseUrl: base,
        token: () => token,
        onUnauthorized: () {},
      );
      final session = ok(
        await AuthRepositoryImpl(
          client.auth,
          MemoryTokenStore(),
        ).login('operator', 'operator-local'),
      );
      token = session.token;

      final net = NetworkRepositoryImpl(client);
      final topo = ok(await net.topology());
      expect(topo.nodes.map((n) => n.id), contains('hq-core-01'));
      expect(topo.links.where((l) => l.controllable), hasLength(4));
      final health = ok(await net.health('hq-core-01'));
      expect(health.expectedNeighbors, hasLength(3));
      ok(await net.alerts());

      final fw = FirewallRepositoryImpl(client.firewall);
      final rule = ok(
        await fw.create(
          const NewFirewallRule(
            site: 'br2',
            tier: 'users',
            protocol: 'tcp',
            fromPort: 9443,
            toPort: 9443,
            cidr: '10.20.10.0/24',
            description: 'live contract test',
          ),
          idempotencyKey: 'live-${DateTime.now().microsecondsSinceEpoch}',
        ),
      ); // fmt: skip
      expect(ok(await fw.list()).map((r) => r.id), contains(rule.id));
      ok(await fw.delete(rule.id));

      final audit = ok(await AuditRepositoryImpl(client.audit).page(limit: 5));
      expect(audit.items.first.actor, 'operator');
    },
    skip: up ? false : 'no API on $base',
  );
}
