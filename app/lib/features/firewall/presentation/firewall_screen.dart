import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design_system/app_spacing.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../shared/presentation/failure_text.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/state_views.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../auth/presentation/auth_cubit.dart';
import '../../network/presentation/topology_cubit.dart' show LoadStatus;
import '../domain/firewall.dart';
import 'firewall_cubit.dart';
import 'rule_form_sheet.dart';

class FirewallScreen extends StatefulWidget {
  const FirewallScreen({super.key});

  @override
  State<FirewallScreen> createState() => _FirewallScreenState();
}

class _FirewallScreenState extends State<FirewallScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(context.read<FirewallCubit>().load());
  }

  Future<void> _add() async {
    final cubit = context.read<FirewallCubit>()..newSubmissionKey();
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) =>
          BlocProvider.value(value: cubit, child: const RuleFormSheet()),
    );
    if ((created ?? false) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).changeSubmitted)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final canOperate = context.watch<AuthCubit>().role?.canOperate ?? false;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.firewallTitle),
        actions: const [SignOutAction()],
      ),
      floatingActionButton: canOperate
          ? FloatingActionButton.extended(
              key: const Key('rules.add'),
              onPressed: _add,
              icon: const Icon(Icons.add),
              label: Text(l.addRule),
            )
          : null,
      body: BlocConsumer<FirewallCubit, FirewallState>(
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
            onRetry: () => context.read<FirewallCubit>().load(),
          ),
          LoadStatus.ready when state.rules.isEmpty => EmptyView(
            message: l.firewallEmpty,
            icon: Icons.shield_outlined,
          ),
          LoadStatus.ready => RefreshIndicator(
            onRefresh: () => context.read<FirewallCubit>().load(),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppSpacing.maxContentWidth,
                ),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    96,
                  ),
                  itemCount: state.rules.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, i) => _RuleCard(
                    rule: state.rules[i],
                    busy: state.busy.contains(state.rules[i].id),
                    canOperate: canOperate,
                  ),
                ),
              ),
            ),
          ),
        },
      ),
    );
  }
}

class _RuleCard extends StatelessWidget {
  const _RuleCard({
    required this.rule,
    required this.busy,
    required this.canOperate,
  });

  final FirewallRuleItem rule;
  final bool busy;
  final bool canOperate;

  Future<void> _confirmDelete(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l.deleteRule),
        content: Text(l.deleteRuleConfirm(rule.id)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if ((ok ?? false) && context.mounted) {
      await context.read<FirewallCubit>().delete(rule.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final (status, tone) = switch (rule.status) {
      ChangeState.pending => (l.statusPending, Tone.neutral),
      ChangeState.applied => (l.statusApplied, Tone.ok),
      ChangeState.planned => (l.statusPlanned, Tone.ok),
      ChangeState.failed => (l.statusFailed, Tone.bad),
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              key: Key('rule.${rule.id}'),
              value: rule.enabled,
              onChanged: canOperate && !busy
                  ? (v) => context.read<FirewallCubit>().toggle(
                      rule.id,
                      enabled: v,
                    )
                  : null,
              title: Text(rule.description),
              subtitle: Text(
                l.ruleSummary(
                  rule.protocol.toUpperCase(),
                  rule.ports,
                  rule.cidr,
                  rule.site,
                  rule.tier,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                children: [
                  if (busy)
                    const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    StatusChip(label: status, tone: tone),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      '${rule.id} · ${rule.createdBy}',
                      style: Theme.of(context).textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (canOperate)
                    IconButton(
                      key: Key('rule.${rule.id}.delete'),
                      tooltip: l.deleteRule,
                      icon: const Icon(Icons.delete_outline),
                      onPressed: busy ? null : () => _confirmDelete(context),
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
