import 'package:cnops_app/app/app.dart';
import 'package:cnops_app/core/config/env.dart';
import 'package:cnops_app/core/notifications/alert_notifier.dart';
import 'package:cnops_app/features/auth/domain/session.dart';
import 'package:cnops_app/features/auth/presentation/auth_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

class Harness {
  Harness({
    required this.auth,
    required this.network,
    required this.firewall,
    required this.audit,
    required this.notifier,
  });

  final AuthCubit auth;
  final FakeNetworkRepository network;
  final FakeFirewallRepository firewall;
  final FakeAuditRepository audit;
  final RecordingAlertNotifier notifier;

  /// Unmount the app so its polling timers are cancelled before the test ends.
  Future<void> dispose(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await auth.close();
  }
}

const phone = Size(400, 860);
const desktop = Size(1280, 860);

Future<Harness> pumpApp(
  WidgetTester t, {
  UserRole? signedIn,
  Size size = phone,
  ThemeMode themeMode = ThemeMode.light,
  FakeNetworkRepository? network,
}) async {
  t.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final auth = AuthCubit(
    FakeAuthRepository(
      saved: signedIn == null ? null : sampleSession(role: signedIn),
    ),
  );
  await auth.restore();
  final h = Harness(
    auth: auth,
    network: network ?? FakeNetworkRepository(),
    firewall: FakeFirewallRepository(),
    audit: FakeAuditRepository(),
    notifier: RecordingAlertNotifier(),
  );
  await t.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: size,
        platformBrightness: themeMode == ThemeMode.dark
            ? Brightness.dark
            : Brightness.light,
      ),
      child: CnopsApp(
        deps: AppDependencies(
          env: const Env(flavor: 'local', apiBaseUrl: 'http://localhost:8000'),
          auth: auth,
          network: h.network,
          firewall: h.firewall,
          audit: h.audit,
        ),
        notifier: h.notifier,
      ),
    ),
  );
  await t.pumpAndSettle();
  return h;
}
