import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/design_system/app_spacing.dart';
import '../../features/auth/presentation/auth_cubit.dart';
import '../../features/network/presentation/alerts_cubit.dart';
import '../../l10n/gen/app_localizations.dart';

/// Navigation for every screen size: bottom bar on phones, rail on tablet
/// and desktop web. The alert strip sits above the content on all tabs.
class AppShell extends StatelessWidget {
  const AppShell({required this.shell, super.key});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final destinations = [
      (Icons.hub_outlined, Icons.hub, l.navNetwork),
      (Icons.shield_outlined, Icons.shield, l.navFirewall),
      (Icons.history_outlined, Icons.history, l.navAudit),
    ];
    void go(int i) =>
        shell.goBranch(i, initialLocation: i == shell.currentIndex);
    final body = Column(
      children: [
        const AlertStrip(),
        Expanded(child: shell),
      ],
    );

    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth >= AppSpacing.wideBreakpoint) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: shell.currentIndex,
                  onDestinationSelected: go,
                  labelType: NavigationRailLabelType.all,
                  leading: const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                    child: Icon(Icons.lan_outlined, size: 32),
                  ),
                  trailing: const Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: _SignOutButton(),
                    ),
                  ),
                  destinations: [
                    for (final (icon, selected, label) in destinations)
                      NavigationRailDestination(
                        icon: Icon(icon),
                        selectedIcon: Icon(selected),
                        label: Text(label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: body),
              ],
            ),
          );
        }
        return Scaffold(
          body: body,
          bottomNavigationBar: NavigationBar(
            selectedIndex: shell.currentIndex,
            onDestinationSelected: go,
            destinations: [
              for (final (icon, selected, label) in destinations)
                NavigationDestination(
                  icon: Icon(icon),
                  selectedIcon: Icon(selected),
                  label: label,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SignOutButton extends StatelessWidget {
  const _SignOutButton();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
    child: IconButton(
      tooltip: AppLocalizations.of(context).signOut,
      icon: const Icon(Icons.logout),
      onPressed: () => context.read<AuthCubit>().logout(),
    ),
  );
}

/// Sign-out action for app bars (phones have no rail).
class SignOutAction extends StatelessWidget {
  const SignOutAction({super.key});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) =>
        MediaQuery.sizeOf(context).width >= AppSpacing.wideBreakpoint
        ? const SizedBox.shrink()
        : IconButton(
            tooltip: AppLocalizations.of(context).signOut,
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthCubit>().logout(),
          ),
  );
}

/// Live alert summary. Tapping it lists the alerts.
class AlertStrip extends StatelessWidget {
  const AlertStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return BlocBuilder<AlertsCubit, AlertsState>(
      builder: (context, state) {
        if (state.alerts.isEmpty) {
          return const SizedBox.shrink();
        }
        final scheme = Theme.of(context).colorScheme;
        final critical = state.criticalCount > 0;
        return SafeArea(
          bottom: false,
          child: Material(
            color: critical ? scheme.errorContainer : scheme.tertiaryContainer,
            child: InkWell(
              onTap: () => showModalBottomSheet<void>(
                context: context,
                showDragHandle: true,
                builder: (_) => _AlertList(state: state),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                child: Row(
                  children: [
                    Icon(
                      critical
                          ? Icons.warning_amber_rounded
                          : Icons.info_outline,
                      color: critical
                          ? scheme.onErrorContainer
                          : scheme.onTertiaryContainer,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        '${l.alertsCount(state.alerts.length)}: ${state.alerts.first.message}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: critical
                              ? scheme.onErrorContainer
                              : scheme.onTertiaryContainer,
                        ),
                      ),
                    ),
                    const Icon(Icons.expand_more),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AlertList extends StatelessWidget {
  const _AlertList({required this.state});

  final AlertsState state;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            title: Text(
              l.alertsTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          for (final a in state.alerts)
            ListTile(
              leading: Icon(
                a.critical ? Icons.error : Icons.warning_amber,
                color: a.critical ? scheme.error : scheme.tertiary,
              ),
              title: Text(a.message),
              subtitle: Text('${a.kind} · ${a.target}'),
            ),
        ],
      ),
    );
  }
}
