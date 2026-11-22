import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../domain/network.dart';

/// Where each device sits on the map, in 0..1 coordinates. Mirrors the
/// diagram in docs/network-design.md: ISP on top, HQ in the middle,
/// branches below.
const Map<String, Offset> nodePositions = {
  'isp-edge-01': Offset(0.5, 0.04),
  'isp-srv-01': Offset(0.85, 0.04),
  'hq-edge-01': Offset(0.5, 0.26),
  'hq-core-01': Offset(0.5, 0.50),
  'hq-pc-01': Offset(0.15, 0.50),
  'hq-srv-01': Offset(0.85, 0.36),
  'hq-srv-02': Offset(0.85, 0.62),
  'br1-edge-01': Offset(0.25, 0.78),
  'br2-edge-01': Offset(0.75, 0.78),
  'br1-pc-01': Offset(0.06, 0.96),
  'br2-pc-01': Offset(0.94, 0.96),
};

enum NodeHealth { ok, warn, bad }

class TopologyMap extends StatelessWidget {
  const TopologyMap({
    required this.snapshot,
    required this.health,
    required this.onDeviceTap,
    super.key,
  });

  final NetworkSnapshot snapshot;

  /// Health per device id from the alert feed (missing = ok).
  final Map<String, NodeHealth> health;
  final ValueChanged<String> onDeviceTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final nodes = [
      for (final n in snapshot.nodes)
        if (nodePositions.containsKey(n.id)) n,
    ];

    return Semantics(
      label: l.topologyMapLabel(nodes.length, snapshot.links.length),
      child: AspectRatio(
        aspectRatio: 1,
        child: LayoutBuilder(
          builder: (context, c) {
            const node = 48.0; // touch target
            Offset at(String id) {
              final p = nodePositions[id]!;
              return Offset(
                node / 2 + p.dx * (c.maxWidth - node),
                node / 2 + p.dy * (c.maxHeight - node),
              );
            }

            return Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _LinkPainter(
                      links: [
                        for (final link in snapshot.links)
                          if (nodePositions.containsKey(link.aDevice) &&
                              nodePositions.containsKey(link.bDevice))
                            (link, at(link.aDevice), at(link.bDevice)),
                      ],
                      upColor: scheme.primary,
                      lanColor: scheme.outlineVariant,
                      downColor: scheme.error,
                      backupColor: scheme.tertiary,
                    ),
                  ),
                ),
                for (final n in nodes)
                  Positioned(
                    left: at(n.id).dx - node / 2,
                    top: at(n.id).dy - node / 2,
                    child: _NodeButton(
                      node: n,
                      health: health[n.id] ?? NodeHealth.ok,
                      onTap: () => onDeviceTap(n.id),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _NodeButton extends StatelessWidget {
  const _NodeButton({
    required this.node,
    required this.health,
    required this.onTap,
  });

  final NetworkNode node;
  final NodeHealth health;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final (ring, status) = switch (health) {
      NodeHealth.ok => (scheme.ok, l.healthHealthy),
      NodeHealth.warn => (scheme.warn, l.healthDegraded),
      NodeHealth.bad => (scheme.bad, l.healthDown),
    };
    final icon = switch (node.role) {
      NodeRole.router => Icons.router_outlined,
      NodeRole.server => Icons.dns_outlined,
      NodeRole.isp => Icons.public,
      NodeRole.host => Icons.computer_outlined,
    };
    return Semantics(
      button: true,
      label: l.deviceNodeLabel(node.id, node.role.name, status),
      excludeSemantics: true,
      child: Tooltip(
        message: node.id,
        child: Material(
          shape: CircleBorder(side: BorderSide(color: ring, width: 3)),
          color: scheme.surfaceContainerHighest,
          child: InkWell(
            key: Key('node.${node.id}'),
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox.square(
              dimension: 48,
              child: Icon(icon, size: 24, color: scheme.onSurface),
            ),
          ),
        ),
      ),
    );
  }
}

class _LinkPainter extends CustomPainter {
  _LinkPainter({
    required this.links,
    required this.upColor,
    required this.lanColor,
    required this.downColor,
    required this.backupColor,
  });

  final List<(NetworkLink, Offset, Offset)> links;
  final Color upColor;
  final Color lanColor;
  final Color downColor;
  final Color backupColor;

  @override
  void paint(Canvas canvas, Size size) {
    for (final (link, a, b) in links) {
      final down = link.state == LinkStatus.down;
      final paint = Paint()
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke
        ..strokeWidth = link.kind == 'lan' ? 1.5 : 3
        ..color = down
            ? downColor
            : switch (link.kind) {
                'lan' => lanColor,
                'backup' => backupColor,
                _ => upColor,
              };
      if (down || link.kind == 'backup') {
        _dashed(canvas, a, b, paint, dash: down ? 6 : 10);
      } else {
        canvas.drawLine(a, b, paint);
      }
    }
  }

  void _dashed(
    Canvas canvas,
    Offset a,
    Offset b,
    Paint paint, {
    required double dash,
  }) {
    final total = (b - a).distance;
    final dir = (b - a) / total;
    for (var d = 0.0; d < total; d += dash * 2) {
      canvas.drawLine(a + dir * d, a + dir * math.min(d + dash, total), paint);
    }
  }

  @override
  bool shouldRepaint(_LinkPainter old) =>
      old.links != links ||
      old.upColor != upColor ||
      old.downColor != downColor;
}
