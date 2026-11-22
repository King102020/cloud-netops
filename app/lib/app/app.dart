import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../core/config/env.dart';
import '../core/notifications/alert_notifier.dart';
import '../core/theme/app_theme.dart';
import '../features/audit/domain/audit.dart';
import '../features/audit/presentation/audit_cubit.dart';
import '../features/audit/presentation/audit_screen.dart';
import '../features/auth/domain/session.dart';
import '../features/auth/presentation/auth_cubit.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/firewall/domain/firewall.dart';
import '../features/firewall/presentation/firewall_cubit.dart';
import '../features/firewall/presentation/firewall_screen.dart';
import '../features/network/domain/network.dart';
import '../features/network/presentation/alerts_cubit.dart';
import '../features/network/presentation/device_cubit.dart';
import '../features/network/presentation/device_detail_screen.dart';
import '../features/network/presentation/topology_cubit.dart';
import '../features/network/presentation/topology_screen.dart';
import '../l10n/gen/app_localizations.dart';
import '../shared/widgets/app_shell.dart';

/// Repositories the app runs on. Tests pass fakes; bootstrap passes real ones.
class AppDependencies {
  const AppDependencies({
    required this.env,
    required this.auth,
    required this.network,
    required this.firewall,
    required this.audit,
  });

  final Env env;
  final AuthCubit auth;
  final NetworkRepository network;
  final FirewallRepository firewall;
  final AuditRepository audit;
}

class CnopsApp extends StatefulWidget {
  const CnopsApp({required this.deps, this.notifier, super.key});

  final AppDependencies deps;
  final AlertNotifier? notifier;

  @override
  State<CnopsApp> createState() => _CnopsAppState();
}

class _CnopsAppState extends State<CnopsApp> {
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  late final AlertsCubit _alerts;
  late final GoRouter _router;
  late final StreamSubscription<AuthState> _authSub;

  @override
  void initState() {
    super.initState();
    final auth = widget.deps.auth;
    _alerts = AlertsCubit(
      widget.deps.network,
      widget.notifier ??
          InAppAlertNotifier(
            _messenger,
            message: (a) => AppLocalizations.of(
              _messenger.currentContext!,
            ).newAlert(a.message),
            clearedMessage: () =>
                AppLocalizations.of(_messenger.currentContext!).alertsCleared,
          ),
    );
    _authSub = auth.stream.listen(
      (s) => s is AuthSignedIn ? _alerts.start() : _alerts.stop(),
    );
    if (auth.state is AuthSignedIn) {
      _alerts.start();
    }
    _router = buildRouter(widget.deps);
  }

  @override
  void dispose() {
    unawaited(_authSub.cancel());
    unawaited(_alerts.close());
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: [
      BlocProvider.value(value: widget.deps.auth),
      BlocProvider.value(value: _alerts),
      BlocProvider(create: (_) => TopologyCubit(widget.deps.network)),
    ],
    child: MaterialApp.router(
      onGenerateTitle: (c) => AppLocalizations.of(c).appTitle,
      scaffoldMessengerKey: _messenger,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: _router,
    ),
  );
}

/// Auth stream as a Listenable so go_router re-runs redirects on sign in/out.
class _AuthListenable extends ChangeNotifier {
  _AuthListenable(AuthCubit auth) {
    _sub = auth.stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<AuthState> _sub;

  @override
  void dispose() {
    unawaited(_sub.cancel());
    super.dispose();
  }
}

GoRouter buildRouter(AppDependencies deps) => GoRouter(
  initialLocation: '/network',
  refreshListenable: _AuthListenable(deps.auth),
  redirect: (context, state) {
    final signedIn = deps.auth.state is AuthSignedIn;
    final atLogin = state.matchedLocation == '/login';
    if (!signedIn) {
      return atLogin ? null : '/login';
    }
    return atLogin ? '/network' : null;
  },
  routes: [
    GoRoute(
      path: '/login',
      builder: (_, _) => LoginScreen(apiBaseUrl: deps.env.apiBaseUrl),
    ),
    StatefulShellRoute.indexedStack(
      builder: (_, _, shell) => AppShell(shell: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/network',
              builder: (_, _) => const TopologyScreen(),
              routes: [
                // Deep link: /network/devices/hq-core-01
                GoRoute(
                  path: 'devices/:id',
                  builder: (_, s) {
                    final id = s.pathParameters['id']!;
                    return BlocProvider(
                      create: (_) {
                        final cubit = DeviceCubit(deps.network, id);
                        unawaited(cubit.load());
                        return cubit;
                      },
                      child: DeviceDetailScreen(deviceId: id),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/firewall',
              builder: (_, _) => BlocProvider(
                create: (_) => FirewallCubit(deps.firewall),
                child: const FirewallScreen(),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/audit',
              builder: (_, _) => BlocProvider(
                create: (_) => AuditCubit(deps.audit),
                child: const AuditScreen(),
              ),
            ),
          ],
        ),
      ],
    ),
  ],
);

/// Keeps the role type reachable for widgets that only import app.dart.
typedef Role = UserRole;
