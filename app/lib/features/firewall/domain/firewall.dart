import 'package:equatable/equatable.dart';

import '../../../core/errors/result.dart';

enum ChangeState { pending, applied, planned, failed }

const sites = ['hq', 'br1', 'br2'];
const tiers = ['servers', 'users', 'mgmt'];
const protocols = ['tcp', 'udp', 'icmp'];

class FirewallRuleItem extends Equatable {
  const FirewallRuleItem({
    required this.id,
    required this.site,
    required this.tier,
    required this.protocol,
    required this.fromPort,
    required this.toPort,
    required this.cidr,
    required this.description,
    required this.enabled,
    required this.status,
    required this.createdBy,
  });

  final String id;
  final String site;
  final String tier;
  final String protocol;
  final int fromPort;
  final int toPort;
  final String cidr;
  final String description;
  final bool enabled;
  final ChangeState status;
  final String createdBy;

  String get ports {
    if (protocol == 'icmp') {
      return 'type $fromPort';
    }
    return fromPort == toPort ? '$fromPort' : '$fromPort-$toPort';
  }

  FirewallRuleItem copyWith({bool? enabled, ChangeState? status}) =>
      FirewallRuleItem(
        id: id,
        site: site,
        tier: tier,
        protocol: protocol,
        fromPort: fromPort,
        toPort: toPort,
        cidr: cidr,
        description: description,
        enabled: enabled ?? this.enabled,
        status: status ?? this.status,
        createdBy: createdBy,
      );

  @override
  List<Object?> get props => [
    id,
    site,
    tier,
    protocol,
    fromPort,
    toPort,
    cidr,
    description,
    enabled,
    status,
    createdBy,
  ];
}

class NewFirewallRule extends Equatable {
  const NewFirewallRule({
    required this.site,
    required this.tier,
    required this.protocol,
    required this.fromPort,
    required this.toPort,
    required this.cidr,
    required this.description,
  });

  final String site;
  final String tier;
  final String protocol;
  final int fromPort;
  final int toPort;
  final String cidr;
  final String description;

  @override
  List<Object?> get props => [
    site,
    tier,
    protocol,
    fromPort,
    toPort,
    cidr,
    description,
  ];
}

abstract interface class FirewallRepository {
  Future<Result<List<FirewallRuleItem>>> list();

  /// [idempotencyKey] must be reused when retrying the same submission.
  Future<Result<FirewallRuleItem>> create(
    NewFirewallRule rule, {
    required String idempotencyKey,
  });
  Future<Result<FirewallRuleItem>> setEnabled(
    String id, {
    required bool enabled,
  });
  Future<Result<void>> delete(String id);
}

/// Client-side checks that mirror the API (the API checks again).
abstract final class RuleValidation {
  static final _ipv4Cidr = RegExp(
    r'^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})/(\d{1,2})$',
  );
  static final _description = RegExp(r'^[\w .,:/()+-]{3,200}$');

  static bool isPort(int? v) => v != null && v >= 1 && v <= 65535;

  static bool isDescription(String v) => _description.hasMatch(v.trim());

  static bool isWorldOpen(String v) => v.trim().endsWith('/0');

  /// Private IPv4 network (RFC 1918) with no host bits set.
  static bool isPrivateCidr(String value) {
    final m = _ipv4Cidr.firstMatch(value.trim());
    if (m == null) {
      return false;
    }
    final octets = [for (var i = 1; i <= 4; i++) int.parse(m.group(i)!)];
    final prefix = int.parse(m.group(5)!);
    if (octets.any((o) => o > 255) || prefix < 8 || prefix > 32) {
      return false;
    }
    final ip = octets.fold<int>(0, (acc, o) => (acc << 8) | o);
    final mask = prefix == 0 ? 0 : (0xFFFFFFFF << (32 - prefix)) & 0xFFFFFFFF;
    if (ip & ~mask & 0xFFFFFFFF != 0) {
      return false; // host bits set
    }
    final (a, b) = (octets[0], octets[1]);
    return a == 10 ||
        (a == 172 && b >= 16 && b <= 31) ||
        (a == 192 && b == 168);
  }
}
