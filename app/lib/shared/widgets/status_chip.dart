import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

enum Tone { ok, warn, bad, neutral }

/// Small coloured label. Colour is never the only signal: the text and icon
/// carry the meaning too (WCAG 1.4.1).
class StatusChip extends StatelessWidget {
  const StatusChip({required this.label, required this.tone, super.key});

  final String label;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (color, icon) = switch (tone) {
      Tone.ok => (scheme.ok, Icons.check_circle_outline),
      Tone.warn => (scheme.warn, Icons.error_outline),
      Tone.bad => (scheme.bad, Icons.cancel_outlined),
      Tone.neutral => (scheme.outline, Icons.schedule),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
