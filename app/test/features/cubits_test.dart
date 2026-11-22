import 'package:bloc_test/bloc_test.dart';
import 'package:cnops_app/core/errors/app_failure.dart';
import 'package:cnops_app/core/notifications/alert_notifier.dart';
import 'package:cnops_app/features/audit/presentation/audit_cubit.dart';
import 'package:cnops_app/features/auth/domain/session.dart';
import 'package:cnops_app/features/auth/presentation/auth_cubit.dart';
import 'package:cnops_app/features/firewall/domain/firewall.dart';
import 'package:cnops_app/features/firewall/presentation/firewall_cubit.dart';
import 'package:cnops_app/features/network/domain/network.dart';
import 'package:cnops_app/features/network/presentation/alerts_cubit.dart';
import 'package:cnops_app/features/network/presentation/device_cubit.dart';
import 'package:cnops_app/features/network/presentation/topology_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

const newRule = NewFirewallRule(
  site: 'hq',
  tier: 'servers',
  protocol: 'tcp',
  fromPort: 9000,
  toPort: 9000,
  cidr: '10.30.10.0/24',
  description: 'br2 users',
); // fmt: skip

void main() {
  group('AuthCubit', () {
    blocTest<AuthCubit, AuthState>(
      'restore with no session -> signed out',
      build: () => AuthCubit(FakeAuthRepository()),
      act: (c) => c.restore(),
      expect: () => [const AuthSignedOut()],
    );

    blocTest<AuthCubit, AuthState>(
      'restore with a session -> signed in',
      build: () => AuthCubit(FakeAuthRepository(saved: sampleSession())),
      act: (c) => c.restore(),
      verify: (c) {
        expect(c.token, 'token-operator');
        expect(c.role, UserRole.operator);
      },
      expect: () => [isA<AuthSignedIn>()],
    );

    blocTest<AuthCubit, AuthState>(
      'login: busy then signed in; bad password: failure',
      build: () => AuthCubit(FakeAuthRepository()),
      act: (c) async {
        await c.login(' operator ', 'operator-local');
        await c.logout();
        await c.login('operator', 'wrong');
      },
      expect: () => [
        const AuthSignedOut(busy: true),
        isA<AuthSignedIn>(),
        const AuthSignedOut(),
        const AuthSignedOut(busy: true),
        const AuthSignedOut(failure: UnauthorizedFailure()),
      ],
    );

    blocTest<AuthCubit, AuthState>(
      'sessionExpired signs out only when signed in',
      build: () => AuthCubit(FakeAuthRepository(saved: sampleSession())),
      act: (c) async {
        await c.sessionExpired(); // unknown state: ignored
        await c.restore();
        await c.sessionExpired();
      },
      verify: (c) => expect(c.token, isNull),
      expect: () => [
        isA<AuthSignedIn>(),
        const AuthSignedOut(failure: UnauthorizedFailure()),
      ],
    );
  });

  group('TopologyCubit', () {
    late FakeNetworkRepository repo;
    setUp(() => repo = FakeNetworkRepository());
    final now = DateTime.utc(2026);

    blocTest<TopologyCubit, TopologyState>(
      'load ok',
      build: () => TopologyCubit(repo, clock: () => now),
      act: (c) => c.load(),
      expect: () => [
        const TopologyState(),
        TopologyState(
          status: LoadStatus.ready,
          snapshot: sampleSnapshot(),
          updatedAt: now,
        ),
      ],
    );

    blocTest<TopologyCubit, TopologyState>(
      'first load fails -> failure; later refresh failure keeps the snapshot',
      build: () => TopologyCubit(repo, clock: () => now),
      act: (c) async {
        repo.failNext = const NetworkFailure();
        await c.load();
        await c.load();
        repo.failNext = const NetworkFailure();
        await c.load();
      },
      // Third load fails but keeps the last snapshot: no new state at all.
      expect: () => [
        const TopologyState(),
        const TopologyState(
          status: LoadStatus.failure,
          failure: NetworkFailure(),
        ),
        const TopologyState(),
        TopologyState(
          status: LoadStatus.ready,
          snapshot: sampleSnapshot(),
          updatedAt: now,
        ),
      ],
    );

    blocTest<TopologyCubit, TopologyState>(
      'setLink: busy, then the snapshot shows the new state',
      build: () => TopologyCubit(repo, clock: () => now),
      seed: () =>
          TopologyState(status: LoadStatus.ready, snapshot: sampleSnapshot()),
      act: (c) => c.setLink('hq-br2', up: false),
      expect: () => [
        TopologyState(
          status: LoadStatus.ready,
          snapshot: sampleSnapshot(),
          busyLinks: const {'hq-br2'},
        ),
        TopologyState(
          status: LoadStatus.ready,
          snapshot: sampleSnapshot(hqBr2: LinkStatus.down),
          updatedAt: now,
        ),
      ],
    );

    blocTest<TopologyCubit, TopologyState>(
      'setLink failure is reported once and the link is no longer busy',
      build: () => TopologyCubit(repo),
      seed: () =>
          TopologyState(status: LoadStatus.ready, snapshot: sampleSnapshot()),
      act: (c) {
        repo.failNext = const ForbiddenFailure();
        return c.setLink('hq-br2', up: false);
      },
      expect: () => [
        isA<TopologyState>().having((s) => s.busyLinks, 'busy', {'hq-br2'}),
        isA<TopologyState>()
            .having((s) => s.busyLinks, 'busy', isEmpty)
            .having(
              (s) => s.actionFailure,
              'failure',
              const ForbiddenFailure(),
            ),
      ],
    );

    test('polling refreshes on a timer and stops on close', () async {
      final c = TopologyCubit(
        repo,
        refreshEvery: const Duration(milliseconds: 10),
      )..startPolling();
      await Future<void>.delayed(const Duration(milliseconds: 60));
      c.stopPolling();
      final calls = repo.topologyCalls;
      expect(calls, greaterThan(1));
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(repo.topologyCalls, calls);
      c.startPolling();
      await c.close();
    });
  });

  group('DeviceCubit', () {
    blocTest<DeviceCubit, DeviceState>(
      'loads device and health together',
      build: () => DeviceCubit(FakeNetworkRepository(), 'hq-core-01'),
      act: (c) => c.load(),
      expect: () => [
        isA<DeviceState>()
            .having((s) => s.status, 'status', LoadStatus.ready)
            .having((s) => s.device?.routerId, 'rid', '10.255.255.2')
            .having((s) => s.health?.missingNeighbors, 'missing', isEmpty),
      ],
    );

    blocTest<DeviceCubit, DeviceState>(
      'unknown device -> failure',
      build: () => DeviceCubit(FakeNetworkRepository(), 'nope'),
      act: (c) => c.load(),
      expect: () => [
        isA<DeviceState>().having(
          (s) => s.status,
          'status',
          LoadStatus.failure,
        ),
      ],
    );
  });

  group('AlertsCubit', () {
    test(
      'notifies only NEW alerts after the first poll, and when they clear',
      () async {
        final repo = FakeNetworkRepository();
        final notifier = RecordingAlertNotifier();
        final cubit = AlertsCubit(repo, notifier);

        repo.snapshot = sampleSnapshot(hqBr2: LinkStatus.down);
        await cubit.poll(); // alerts that existed at start-up: no notification
        expect(cubit.state.alerts, hasLength(2));
        expect(cubit.state.criticalCount, 1);
        expect(notifier.notified, isEmpty);

        await repo.setLink('br1-br2', up: false);
        await cubit.poll();
        expect(
          notifier.notified.map((a) => a.id),
          contains('link_down:br1-br2'),
        );

        repo.snapshot = sampleSnapshot();
        await cubit.poll();
        expect(cubit.state.alerts, isEmpty);
        expect(notifier.clearedCount, 1);

        repo.failNext = const NetworkFailure();
        await cubit.poll();
        expect(cubit.state.reachable, isFalse);

        cubit
          ..start()
          ..stop();
        expect(cubit.state, const AlertsState());
        await cubit.close();
      },
    );
  });

  group('FirewallCubit', () {
    late FakeFirewallRepository repo;
    setUp(() => repo = FakeFirewallRepository());

    blocTest<FirewallCubit, FirewallState>(
      'load, toggle, delete',
      build: () => FirewallCubit(repo),
      act: (c) async {
        await c.load();
        await c.toggle('fw-0000aaaa', enabled: false);
        await c.delete('fw-0000aaaa');
      },
      expect: () => [
        FirewallState(status: LoadStatus.ready, rules: [sampleRule()]),
        FirewallState(
          status: LoadStatus.ready,
          rules: [sampleRule()],
          busy: const {'fw-0000aaaa'},
        ),
        FirewallState(
          status: LoadStatus.ready,
          rules: [sampleRule(enabled: false)],
        ),
        FirewallState(
          status: LoadStatus.ready,
          rules: [sampleRule(enabled: false)],
          busy: const {'fw-0000aaaa'},
        ),
        const FirewallState(status: LoadStatus.ready),
      ],
    );

    blocTest<FirewallCubit, FirewallState>(
      'load failure with no rules -> failure state; toggle failure -> action failure',
      build: () => FirewallCubit(repo),
      act: (c) async {
        repo.failNext = const NetworkFailure();
        await c.load();
        await c.load();
        repo.failNext = const ForbiddenFailure();
        await c.toggle('fw-0000aaaa', enabled: false);
      },
      expect: () => [
        const FirewallState(
          status: LoadStatus.failure,
          failure: NetworkFailure(),
        ),
        FirewallState(status: LoadStatus.ready, rules: [sampleRule()]),
        FirewallState(
          status: LoadStatus.ready,
          rules: [sampleRule()],
          busy: const {'fw-0000aaaa'},
        ),
        FirewallState(
          status: LoadStatus.ready,
          rules: [sampleRule()],
          actionFailure: const ForbiddenFailure(),
        ),
      ],
    );

    test(
      'create reuses the idempotency key on retry, new key after success',
      () async {
        final c = FirewallCubit(
          repo,
          pendingPoll: const Duration(milliseconds: 10),
        );
        await c.load();
        final key = c.newSubmissionKey();
        repo.failNext = const NetworkFailure();
        expect(await c.create(newRule), const NetworkFailure());
        expect(await c.create(newRule), isNull); // retry
        expect(repo.keysSeen, [key, key]);
        expect(c.state.hasPending, isTrue);

        // pending rules are re-checked until Terraform finishes
        repo.finishPending();
        await Future<void>.delayed(const Duration(milliseconds: 40));
        expect(c.state.hasPending, isFalse);

        expect(await c.create(newRule.copyWithPort(9001)), isNull);
        expect(repo.keysSeen.last, isNot(key));
        await c.close();
      },
    );
  });

  group('AuditCubit', () {
    blocTest<AuditCubit, AuditState>(
      'load, then load more until the end',
      build: () => AuditCubit(FakeAuditRepository()),
      act: (c) async {
        await c.load();
        await c.loadMore();
        await c.loadMore(); // no more pages: ignored
      },
      verify: (c) {
        expect(c.state.items, hasLength(30));
        expect(c.state.hasMore, isFalse);
      },
      expect: () => [
        isA<AuditState>()
            .having((s) => s.items.length, 'n', 25)
            .having((s) => s.hasMore, 'more', isTrue),
        isA<AuditState>().having((s) => s.loadingMore, 'loadingMore', isTrue),
        isA<AuditState>().having((s) => s.items.length, 'n', 30),
      ],
    );

    blocTest<AuditCubit, AuditState>(
      'load failure',
      build: () =>
          AuditCubit(FakeAuditRepository()..failNext = const NetworkFailure()),
      act: (c) => c.load(),
      expect: () => [
        const AuditState(status: LoadStatus.failure, failure: NetworkFailure()),
      ],
    );

    test('loadMore failure keeps items and shows the failure', () async {
      final repo = FakeAuditRepository();
      final c = AuditCubit(repo);
      await c.load();
      repo.failNext = const ServerFailure();
      await c.loadMore();
      expect(c.state.items, hasLength(25));
      expect(c.state.failure, const ServerFailure());
      await c.close();
    });
  });
}

extension on NewFirewallRule {
  NewFirewallRule copyWithPort(int p) => NewFirewallRule(
    site: site,
    tier: tier,
    protocol: protocol,
    fromPort: p,
    toPort: p,
    cidr: cidr,
    description: description,
  ); // fmt: skip
}
