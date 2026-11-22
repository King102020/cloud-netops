import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design_system/app_spacing.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../shared/widgets/state_views.dart';
import '../../../shared/widgets/status_chip.dart';
import '../domain/network.dart';
import 'device_cubit.dart';
import 'topology_cubit.dart' show LoadStatus;

class DeviceDetailScreen extends StatelessWidget {
  const DeviceDetailScreen({required this.deviceId, super.key});

  final String deviceId;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(deviceId),
        actions: [
          IconButton(
            tooltip: l.retry,
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<DeviceCubit>().load(),
          ),
        ],
      ),
      body: BlocBuilder<DeviceCubit, DeviceState>(
        builder: (context, state) => switch (state.status) {
          LoadStatus.loading => const LoadingView(),
          LoadStatus.failure => ErrorView(
            failure: state.failure!,
            onRetry: () => context.read<DeviceCubit>().load(),
          ),
          LoadStatus.ready => _Detail(
            device: state.device!,
            health: state.health!,
          ),
        },
      ),
    );
  }
}

String formatUptime(Duration d) {
  if (d.inDays > 0) {
    return '${d.inDays}d ${d.inHours % 24}h';
  }
  if (d.inHours > 0) {
    return '${d.inHours}h ${d.inMinutes % 60}m';
  }
  return '${d.inMinutes}m ${d.inSeconds % 60}s';
}

class _Detail extends StatelessWidget {
  const _Detail({required this.device, required this.health});

  final NetworkNode device;
  final DeviceHealthInfo health;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final (label, tone) = switch (health.level) {
      HealthLevel.healthy => (l.healthHealthy, Tone.ok),
      HealthLevel.degraded => (l.healthDegraded, Tone.warn),
      HealthLevel.down => (l.healthDown, Tone.bad),
    };

    Widget row(String k, String v) => ListTile(
      dense: true,
      title: Text(k, style: text.bodySmall),
      subtitle: Text(v, style: text.bodyLarge),
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Card(
              child: Column(
                children: [
                  ListTile(
                    title: Text(l.deviceHealth, style: text.titleMedium),
                    trailing: StatusChip(label: label, tone: tone),
                  ),
                  row(l.deviceSite, device.site),
                  row(l.deviceModel, device.model),
                  if (device.routerId != null)
                    row(l.deviceRouterId, device.routerId!),
                  if (health.uptime != null)
                    row(l.deviceUptime, formatUptime(health.uptime!)),
                ],
              ),
            ),
            if (device.role == NodeRole.router) ...[
              const SizedBox(height: AppSpacing.lg),
              Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ListTile(
                      title: Text(l.ospfNeighbors, style: text.titleMedium),
                    ),
                    if (health.neighbors.isEmpty)
                      ListTile(title: Text(l.noNeighbors)),
                    for (final n in health.neighbors)
                      ListTile(
                        leading: Icon(n.isFull ? Icons.link : Icons.link_off),
                        title: Text(n.routerId),
                        subtitle: Text([n.state, ?n.interface].join(' · ')),
                      ),
                    for (final missing in health.missingNeighbors)
                      ListTile(
                        leading: Icon(
                          Icons.link_off,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        title: Text(l.ospfMissing(missing)),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListTile(
                    title: Text(l.interfacesTitle, style: text.titleMedium),
                  ),
                  for (final i in device.interfaces)
                    ListTile(
                      title: Text('${i.name}  ${i.address ?? ''}'),
                      subtitle: i.description == null
                          ? null
                          : Text(i.description!),
                      trailing: StatusChip(
                        label: switch (i.state) {
                          LinkStatus.up => l.stateUp,
                          LinkStatus.down => l.stateDown,
                          LinkStatus.unknown => l.stateUnknown,
                        },
                        tone: switch (i.state) {
                          LinkStatus.up => Tone.ok,
                          LinkStatus.down => Tone.bad,
                          LinkStatus.unknown => Tone.neutral,
                        },
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
