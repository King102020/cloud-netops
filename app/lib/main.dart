import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/config/env.dart';
import 'core/network/api_client_factory.dart';
import 'core/storage/token_store.dart';
import 'features/audit/data/audit_repository_impl.dart';
import 'features/auth/data/auth_repository_impl.dart';
import 'features/auth/presentation/auth_cubit.dart';
import 'features/firewall/data/firewall_repository_impl.dart';
import 'features/network/data/network_repository_impl.dart';

/// Composition root. Run with:
///   flutter run -d chrome --web-port 8080 --dart-define-from-file=config/local.json
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final env = Env.fromDefines();
  late final AuthCubit auth;
  final client = buildApiClient(
    baseUrl: env.apiBaseUrl,
    token: () => auth.token,
    onUnauthorized: () => auth.sessionExpired(),
  );
  auth = AuthCubit(AuthRepositoryImpl(client.auth, SecureTokenStore()));
  await auth.restore();
  runApp(
    CnopsApp(
      deps: AppDependencies(
        env: env,
        auth: auth,
        network: NetworkRepositoryImpl(client),
        firewall: FirewallRepositoryImpl(client.firewall),
        audit: AuditRepositoryImpl(client.audit),
      ),
    ),
  );
}
