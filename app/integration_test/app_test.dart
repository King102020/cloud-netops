// Core flow on a real device/emulator/simulator (STANDARDS §6):
//   flutter test integration_test -d <android emulator | iOS simulator>
// Uses the in-memory fakes, so no API is needed on the device.
import 'package:cnops_app/features/network/domain/network.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/helpers/pump_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'sign in, take a WAN link down, see the alert, add a firewall rule',
    (t) async {
      final h = await pumpApp(t);

      await t.enterText(find.byKey(const Key('login.username')), 'operator');
      await t.enterText(
        find.byKey(const Key('login.password')),
        'operator-local',
      );
      await t.tap(find.byKey(const Key('login.submit')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('node.hq-core-01')), findsOneWidget);

      await t.tap(
        find.descendant(
          of: find.byKey(const Key('link.hq-br2')),
          matching: find.byType(Switch),
        ),
      );
      await t.pumpAndSettle();
      expect(
        h.network.snapshot.links.firstWhere((l) => l.id == 'hq-br2').state,
        LinkStatus.down,
      );
      await t.pump(const Duration(seconds: 11));
      await t.pumpAndSettle();
      expect(find.textContaining('active alerts'), findsOneWidget);

      await t.tap(find.text('Firewall'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('rules.add')));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const Key('form.cidr')), '10.30.10.0/24');
      await t.enterText(
        find.byKey(const Key('form.description')),
        'br2 users to intranet',
      );
      await t.tap(find.byKey(const Key('form.save')));
      await t.pumpAndSettle();
      expect(
        find.text('Change submitted. Terraform is running.'),
        findsOneWidget,
      );

      await h.dispose(t);
    },
  );
}
