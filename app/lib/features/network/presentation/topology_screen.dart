import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/design_system/app_spacing.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../shared/presentation/failure_text.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/state_views.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../auth/presentation/auth_cubit.dart';
import '../domain/network.dart';
import 'alerts_cubit.dart';
import 'topology_cubit.dart';
import 'topology_map.dart';

class TopologyScreen extends StatefulWidget {
  const TopologyScreen({super.key});

  @override
  State<TopologyScreen> createState() => _TopologyScreenState();
}

class _TopologyScreenState extends State<TopologyScreen> {
  @override
  void initState() {
    super.initState();
    final cubit = context.read<TopologyCubit>();
    if (cubit.state.snapshot == null) {
      unawaited(cubit.load());
    }
    cubit.startPolling();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.topologyTitle),
        actions: [
          IconButton(
            tooltip: l.retry,
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<TopologyCubit>().load(),
          ),
          const SignOutAction(),
        ],
      ),
      body: BlocConsumer<TopologyCubit, TopologyState>(
        listenWhen: (a, b) =>
            b.actionFailure != null && a.actionFailure != b.actionFailure,
        listener: (context, state) =>
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(failureText(l, state.actionFailure!))),
            ),
        builder: (context, state) => switch (state.status) {
          LoadStatus.loading => const LoadingView(),
          LoadStatus.failure => ErrorView(
            failure: state.failure!,
            onRetry: () => context.read<TopologyCubit>().load(),
          ),
          LoadStatus.ready => _Ready(state: state),
        },
      ),
    );
  }
}

class _Ready extends StatelessWidget {
  const _Ready({required this.state});

  final TopologyState state;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final snapshot = state.snapshot!;
    final alerts = context.watch<AlertsCubit>().state.alerts;
    final health = <String, NodeHealth>{};
    for (final a in alerts) {
      final level = a.kind == 'device_down' ? NodeHealth.bad : NodeHealth.warn;
      if (health[a.target] != NodeHealth.bad) {
        health[a.target] = level;
      }
    }
    final role = context.watch<AuthCubit>().role;
    final canOperate = role?.canOperate ?? false;
    final wan = [
      for (final link in snapshot.links)
        if (link.controllable) link,
    ];

    final map = Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: TopologyMap(
          snapshot: snapshot,
          health: health,
          onDeviceTap: (id) => context.go('/network/devices/$id'),
        ),
      ),
    );
    final links = Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            title: Text(
              l.linksTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            subtitle: state.updatedAt == null
                ? null
                : Text(
                    l.updatedAt(
                      DateFormat.Hms().format(state.updatedAt!.toLocal()),
                    ),
                  ),
          ),
          if (!canOperate)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Text(
                l.viewOnly,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          for (final link in wan)
            _LinkTile(
              link: link,
              busy: state.busyLinks.contains(link.id),
              canOperate: canOperate,
            ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );

    return RefreshIndicator(
      onRefresh: () => context.read<TopologyCubit>().load(),
      child: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= AppSpacing.wideBreakpoint;
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: map),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(flex: 2, child: links),
                  ],
                )
              else ...[
                map,
                const SizedBox(height: AppSpacing.lg),
                links,
              ],
            ],
          );
        },
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.link,
    required this.busy,
    required this.canOperate,
  });

  final NetworkLink link;
  final bool busy;
  final bool canOperate;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final up = link.state == LinkStatus.up;
    final stateText = switch (link.state) {
      LinkStatus.up => l.stateUp,
      LinkStatus.down => l.stateDown,
      LinkStatus.unknown => l.stateUnknown,
    };
    return MergeSemantics(
      child: SwitchListTile(
        key: Key('link.${link.id}'),
        value: up,
        onChanged: canOperate && !busy && link.state != LinkStatus.unknown
            ? (v) => context.read<TopologyCubit>().setLink(link.id, up: v)
            : null,
        title: Text(l.linkTitle(link.id, link.subnet)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.linkSubtitle(
                link.aDevice,
                link.bDevice,
                '${link.ospfCost ?? '-'}',
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            if (busy)
              const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              StatusChip(
                label: stateText,
                tone: switch (link.state) {
                  LinkStatus.up => Tone.ok,
                  LinkStatus.down =>
                    link.kind == 'backup' ? Tone.warn : Tone.bad,
                  LinkStatus.unknown => Tone.neutral,
                },
              ),
          ],
        ),
      ),
    );
  }
}
