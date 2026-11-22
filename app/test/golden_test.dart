@Tags(['golden'])
library;

import 'package:cnops_app/features/auth/domain/session.dart';
import 'package:cnops_app/features/network/domain/network.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fakes.dart';
import 'helpers/pump_app.dart';

// Regenerate: flutter test --update-goldens test/golden_test.dart
void main() {
  for (final brightness in Brightness.values) {
    final name = brightness.name;

    testWidgets('login ($name)', (t) async {
      t.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(t.platformDispatcher.clearPlatformBrightnessTestValue);
      final h = await pumpApp(t);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/login_$name.png'),
      );
      await h.dispose(t);
    });

    testWidgets('topology with a link down ($name)', (t) async {
      t.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(t.platformDispatcher.clearPlatformBrightnessTestValue);
      final net = FakeNetworkRepository()
        ..snapshot = sampleSnapshot(hqBr2: LinkStatus.down);
      final h = await pumpApp(t, signedIn: UserRole.operator, network: net);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/topology_$name.png'),
      );
      await h.dispose(t);
    });
  }

  testWidgets('topology desktop', (t) async {
    final h = await pumpApp(t, signedIn: UserRole.operator, size: desktop);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/topology_desktop.png'),
    );
    await h.dispose(t);
  });

  testWidgets('firewall rules', (t) async {
    final h = await pumpApp(t, signedIn: UserRole.operator);
    await t.tap(find.text('Firewall'));
    await t.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/firewall_light.png'),
    );
    await h.dispose(t);
  });
}
