import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design_system/app_spacing.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../shared/presentation/failure_text.dart';
import '../domain/firewall.dart';
import 'firewall_cubit.dart';

/// Add-rule form. Validates like the API does; the API validates again.
class RuleFormSheet extends StatefulWidget {
  const RuleFormSheet({super.key});

  @override
  State<RuleFormSheet> createState() => _RuleFormSheetState();
}

class _RuleFormSheetState extends State<RuleFormSheet> {
  final _form = GlobalKey<FormState>();
  final _from = TextEditingController(text: '443');
  final _to = TextEditingController(text: '443');
  final _cidr = TextEditingController();
  final _desc = TextEditingController();
  String _site = sites.first;
  String _tier = tiers.first;
  String _protocol = protocols.first;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_from, _to, _cidr, _desc]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final l = AppLocalizations.of(context);
    final failure = await context.read<FirewallCubit>().create(
      NewFirewallRule(
        site: _site,
        tier: _tier,
        protocol: _protocol,
        fromPort: int.parse(_from.text),
        toPort: int.parse(_to.text),
        cidr: _cidr.text,
        description: _desc.text,
      ),
    );
    if (!mounted) {
      return;
    }
    if (failure == null) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _busy = false;
        _error = failureText(l, failure);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final icmp = _protocol == 'icmp';

    String? portValidator(String? v) {
      final n = int.tryParse(v ?? '');
      if (icmp) {
        return n == null || n < -1 || n > 255 ? l.invalidPort : null;
      }
      return RuleValidation.isPort(n) ? null : l.invalidPort;
    }

    Widget dropdown(
      String label,
      String value,
      List<String> items,
      ValueChanged<String> onChanged,
      String key,
    ) => DropdownButtonFormField<String>(
      key: Key(key),
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final i in items) DropdownMenuItem(value: i, child: Text(i)),
      ],
      onChanged: _busy ? null : (v) => setState(() => onChanged(v!)),
    );

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xl,
      ),
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.addRule, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: dropdown(
                      l.fieldSite,
                      _site,
                      sites,
                      (v) => _site = v,
                      'form.site',
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: dropdown(
                      l.fieldTier,
                      _tier,
                      tiers,
                      (v) => _tier = v,
                      'form.tier',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              dropdown(l.fieldProtocol, _protocol, protocols, (v) {
                _protocol = v;
                if (v == 'icmp') {
                  _from.text = '8';
                  _to.text = '0';
                }
              }, 'form.protocol'),
              const SizedBox(height: AppSpacing.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      key: const Key('form.from'),
                      controller: _from,
                      decoration: InputDecoration(labelText: l.fieldFromPort),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^-?\d*')),
                      ],
                      validator: portValidator,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: TextFormField(
                      key: const Key('form.to'),
                      controller: _to,
                      decoration: InputDecoration(labelText: l.fieldToPort),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^-?\d*')),
                      ],
                      validator: (v) {
                        final base = portValidator(v);
                        if (base != null || icmp) {
                          return base;
                        }
                        return int.parse(v!) <
                                int.parse(_from.text.isEmpty ? '0' : _from.text)
                            ? l.invalidPortRange
                            : null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                key: const Key('form.cidr'),
                controller: _cidr,
                decoration: InputDecoration(
                  labelText: l.fieldCidr,
                  hintText: l.fieldCidrHint,
                ),
                validator: (v) {
                  final value = v ?? '';
                  if (RuleValidation.isWorldOpen(value)) {
                    return l.worldOpen;
                  }
                  return RuleValidation.isPrivateCidr(value)
                      ? null
                      : l.invalidCidr;
                },
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                key: const Key('form.description'),
                controller: _desc,
                decoration: InputDecoration(labelText: l.fieldDescription),
                maxLength: 200,
                validator: (v) => RuleValidation.isDescription(v ?? '')
                    ? null
                    : l.invalidDescription,
              ),
              if (_error != null)
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => Navigator.pop(context, false),
                    child: Text(l.cancel),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton(
                    key: const Key('form.save'),
                    onPressed: _busy ? null : _save,
                    child: Text(l.save),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
