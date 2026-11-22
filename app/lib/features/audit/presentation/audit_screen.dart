import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/design_system/app_spacing.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/state_views.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../network/presentation/topology_cubit.dart' show LoadStatus;
import '../domain/audit.dart';
import 'audit_cubit.dart';

class AuditScreen extends StatefulWidget {
  const AuditScreen({super.key});

  @override
  State<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends State<AuditScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(context.read<AuditCubit>().load());
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.auditTitle),
        actions: [
          IconButton(
            tooltip: l.retry,
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<AuditCubit>().load(),
          ),
          const SignOutAction(),
        ],
      ),
      body: BlocBuilder<AuditCubit, AuditState>(
        builder: (context, state) => switch (state.status) {
          LoadStatus.loading => const LoadingView(),
          LoadStatus.failure => ErrorView(
            failure: state.failure!,
            onRetry: () => context.read<AuditCubit>().load(),
          ),
          LoadStatus.ready when state.items.isEmpty => EmptyView(
            message: l.auditEmpty,
            icon: Icons.history,
          ),
          LoadStatus.ready => RefreshIndicator(
            onRefresh: () => context.read<AuditCubit>().load(),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppSpacing.maxContentWidth,
                ),
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    Card(
                      child: Column(
                        children: [
                          for (final e in state.items) _AuditTile(entry: e),
                        ],
                      ),
                    ),
                    if (state.hasMore)
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Center(
                          child: state.loadingMore
                              ? const CircularProgressIndicator()
                              : OutlinedButton(
                                  key: const Key('audit.more'),
                                  onPressed: () =>
                                      context.read<AuditCubit>().loadMore(),
                                  child: Text(l.loadMore),
                                ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        },
      ),
    );
  }
}

class _AuditTile extends StatelessWidget {
  const _AuditTile({required this.entry});

  final AuditEntry entry;

  String _change() {
    String fmt(Map<String, Object?>? m) => m == null
        ? '–'
        : m.entries.take(3).map((e) => '${e.key}=${e.value}').join(', ');
    return '${fmt(entry.before)}  →  ${fmt(entry.after)}';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final when = DateFormat.yMMMd().add_Hms().format(entry.at.toLocal());
    return ExpansionTile(
      title: Text(l.auditEntry(entry.actor, entry.action, entry.target)),
      subtitle: Text(when),
      trailing: StatusChip(
        label: entry.result,
        tone: switch (entry.result) {
          'succeeded' => Tone.ok,
          'failed' => Tone.bad,
          _ => Tone.neutral,
        },
      ),
      children: [
        ListTile(
          dense: true,
          title: Text(_change()),
          subtitle: Text('${entry.role} · ${entry.id}'),
        ),
      ],
    );
  }
}
