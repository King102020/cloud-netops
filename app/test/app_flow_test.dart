import 'package:cnops_app/core/errors/app_failure.dart';
import 'package:cnops_app/features/auth/domain/session.dart';
import 'package:cnops_app/features/network/domain/network.dart';
import 'package:cnops_app/features/network/presentation/device_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fakes.dart';
import 'helpers/pump_app.dart';

Finder switchOf(String key) =>
    find.descendant(of: find.byKey(Key(key)), matching: find.byType(Switch));

bool switchValue(WidgetTester t, String key) =>
    t.widget<Switch>(switchOf(key)).value;

void main() {
  testWidgets('sign in: validation, wrong password, then the network map', (
    t,
  ) async {
    final h = await pumpApp(t);
    expect(find.text('Sign in'), findsWidgets);
    expect(find.text('Control API: http://localhost:8000'), findsOneWidget);

    await t.tap(find.byKey(const Key('login.submit')));
    await t.pump();
    expect(find.text('Required'), findsNWidgets(2));

    await t.enterText(find.byKey(const Key('login.username')), 'operator');
    await t.enterText(find.byKey(const Key('login.password')), 'nope');
    await t.tap(find.byKey(const Key('login.submit')));
    await t.pumpAndSettle();
    expect(
      find.text('Wrong username or password, or your session expired.'),
      findsOneWidget,
    );

    await t.tap(find.byTooltip('Password')); // show/hide toggle
    await t.enterText(
      find.byKey(const Key('login.password')),
      'operator-local',
    );
    await t.tap(find.byKey(const Key('login.submit')));
    await t.pumpAndSettle();
    expect(find.text('Network'), findsWidgets);
    expect(find.byKey(const Key('node.hq-core-01')), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('Network map with 6 devices')),
      findsOneWidget,
    );
    await h.dispose(t);
  });

  testWidgets('operator takes a WAN link down: alert strip and notification', (
    t,
  ) async {
    final h = await pumpApp(t, signedIn: UserRole.operator);
    expect(switchValue(t, 'link.hq-br2'), isTrue);

    await t.tap(switchOf('link.hq-br2'));
    await t.pumpAndSettle();
    expect(switchValue(t, 'link.hq-br2'), isFalse);
    expect(
      h.network.snapshot.links.firstWhere((l) => l.id == 'hq-br2').state,
      LinkStatus.down,
    );

    await t.pump(const Duration(seconds: 11)); // next alerts poll
    await t.pumpAndSettle();
    expect(find.textContaining('2 active alerts'), findsOneWidget);
    expect(h.notifier.notified.map((a) => a.id), contains('link_down:hq-br2'));

    await t.tap(find.textContaining('2 active alerts'));
    await t.pumpAndSettle();
    expect(find.text('Alerts'), findsOneWidget);
    expect(find.text('link hq-br2 (10.255.0.8/30) is down'), findsWidgets);
    await h.dispose(t);
  });

  testWidgets('a failed link change is shown as a message', (t) async {
    final h = await pumpApp(t, signedIn: UserRole.operator);
    h.network.failNext = const ForbiddenFailure();
    await t.tap(switchOf('link.hq-br1'));
    await t.pumpAndSettle();
    expect(find.text('Your role cannot do this.'), findsOneWidget);
    expect(switchValue(t, 'link.hq-br1'), isTrue);
    await h.dispose(t);
  });

  testWidgets('viewer sees view-only mode', (t) async {
    final h = await pumpApp(t, signedIn: UserRole.viewer);
    expect(
      find.text('View only. Sign in as operator to change links and rules.'),
      findsOneWidget,
    );
    expect(t.widget<Switch>(switchOf('link.hq-br2')).onChanged, isNull);
    await t.tap(find.text('Firewall'));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('rules.add')), findsNothing);
    expect(t.widget<Switch>(switchOf('rule.fw-0000aaaa')).onChanged, isNull);
    await h.dispose(t);
  });

  testWidgets('tap a router: device detail with OSPF neighbours (deep link)', (
    t,
  ) async {
    final h = await pumpApp(t, signedIn: UserRole.operator);
    await t.tap(find.byKey(const Key('node.hq-core-01')));
    await t.pumpAndSettle();
    expect(find.text('hq-core-01'), findsWidgets);
    expect(find.text('OSPF neighbours'), findsOneWidget);
    expect(find.text('10.255.255.4'), findsOneWidget);
    expect(find.text('2h 5m'), findsOneWidget);
    await t.tap(find.byTooltip('Retry'));
    await t.pumpAndSettle();
    await t.pageBack();
    await t.pumpAndSettle();
    expect(find.byKey(const Key('node.hq-core-01')), findsOneWidget);
    await h.dispose(t);
  });

  testWidgets('device detail shows missing adjacencies when degraded', (
    t,
  ) async {
    final net = FakeNetworkRepository()
      ..snapshot = sampleSnapshot(hqBr2: LinkStatus.down);
    final h = await pumpApp(t, signedIn: UserRole.operator, network: net);
    await t.tap(find.byKey(const Key('node.hq-core-01')));
    await t.pumpAndSettle();
    expect(find.text('degraded'), findsOneWidget);
    expect(find.text('No adjacency with 10.255.255.4'), findsOneWidget);
    await h.dispose(t);
  });

  testWidgets('firewall: toggle, add with validation, delete', (t) async {
    final h = await pumpApp(t, signedIn: UserRole.operator);
    await t.tap(find.text('Firewall'));
    await t.pumpAndSettle();
    expect(find.text('br1 users to app port'), findsOneWidget);
    expect(find.text('Applied'), findsOneWidget);

    await t.tap(switchOf('rule.fw-0000aaaa'));
    await t.pumpAndSettle();
    expect(h.firewall.rules.single.enabled, isFalse);

    await t.tap(find.byKey(const Key('rules.add')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('form.cidr')), '0.0.0.0/0');
    await t.enterText(find.byKey(const Key('form.description')), 'x');
    await t.enterText(find.byKey(const Key('form.to')), '80');
    await t.tap(find.byKey(const Key('form.save')));
    await t.pumpAndSettle();
    expect(
      find.text('0.0.0.0/0 is not allowed (default deny)'),
      findsOneWidget,
    );
    expect(find.text('From must be ≤ to'), findsOneWidget);
    expect(find.textContaining('3–200 characters'), findsOneWidget);

    await t.enterText(find.byKey(const Key('form.cidr')), '10.30.10.5/24');
    await t.tap(find.byKey(const Key('form.save')));
    await t.pumpAndSettle();
    expect(
      find.text('Private IPv4 network, e.g. 10.20.10.0/24'),
      findsOneWidget,
    );

    await t.enterText(find.byKey(const Key('form.cidr')), '10.30.10.0/24');
    await t.enterText(find.byKey(const Key('form.to')), '443');
    await t.enterText(
      find.byKey(const Key('form.description')),
      'br2 users to intranet',
    );
    h.firewall.failNext = const ConflictFailure(
      'an identical rule already exists',
    );
    await t.tap(find.byKey(const Key('form.save')));
    await t.pumpAndSettle();
    expect(
      find.text('Conflict: an identical rule already exists'),
      findsOneWidget,
    );

    await t.tap(find.byKey(const Key('form.save'))); // retry with the same key
    await t.pumpAndSettle();
    expect(
      find.text('Change submitted. Terraform is running.'),
      findsOneWidget,
    );
    expect(h.firewall.keysSeen.toSet(), hasLength(1));
    expect(find.text('Applying'), findsOneWidget);

    h.firewall.finishPending();
    await t.pump(const Duration(seconds: 4)); // pending re-check
    await t.pumpAndSettle();
    expect(find.text('Applying'), findsNothing);

    await t.tap(find.byKey(const Key('rule.fw-0000aaaa.delete')));
    await t.pumpAndSettle();
    await t.tap(find.text('Delete'));
    await t.pumpAndSettle();
    expect(find.text('br1 users to app port'), findsNothing);
    await h.dispose(t);
  });

  testWidgets('firewall: ICMP switches the port defaults; empty list', (
    t,
  ) async {
    final h = await pumpApp(t, signedIn: UserRole.operator);
    h.firewall.rules = [];
    await t.tap(find.text('Firewall'));
    await t.pumpAndSettle();
    expect(find.textContaining('No API-managed rules yet'), findsOneWidget);
    await t.tap(find.byKey(const Key('rules.add')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('form.protocol')));
    await t.pumpAndSettle();
    await t.tap(find.text('icmp').last);
    await t.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, '8'), findsOneWidget);
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    await h.dispose(t);
  });

  testWidgets('audit log with pagination', (t) async {
    final h = await pumpApp(t, signedIn: UserRole.operator);
    await t.tap(find.text('Audit log'));
    await t.pumpAndSettle();
    expect(find.textContaining('operator · link.down · hq-br2'), findsWidgets);
    await t.tap(find.textContaining('operator · link.down · hq-br2').first);
    await t.pumpAndSettle();
    expect(find.textContaining('state=up  →  state=down'), findsOneWidget);
    await t.scrollUntilVisible(find.byKey(const Key('audit.more')), 300);
    await t.tap(find.byKey(const Key('audit.more')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('audit.more')), findsNothing);
    await h.dispose(t);
  });

  testWidgets('API unreachable: error view, retry recovers', (t) async {
    final net = FakeNetworkRepository()..failTopology = const NetworkFailure();
    final h = await pumpApp(t, signedIn: UserRole.operator, network: net);
    expect(
      find.text('Cannot reach the control API. Is it running?'),
      findsOneWidget,
    );
    await t.tap(find.text('Retry'));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('node.hq-core-01')), findsOneWidget);
    await h.dispose(t);
  });

  testWidgets(
    'desktop layout uses a navigation rail and sign-out returns to login',
    (t) async {
      final h = await pumpApp(t, signedIn: UserRole.admin, size: desktop);
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      await t.tap(find.text('Audit log'));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Sign out'));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('login.submit')), findsOneWidget);
      await h.dispose(t);
    },
  );

  test('formatUptime', () {
    expect(formatUptime(const Duration(days: 2, hours: 3)), '2d 3h');
    expect(formatUptime(const Duration(minutes: 3, seconds: 4)), '3m 4s');
  });
}
