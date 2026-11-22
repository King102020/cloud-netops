// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'firewall_rule_create_protocol.dart';
import 'firewall_rule_create_site.dart';
import 'firewall_rule_create_tier.dart';

part 'firewall_rule_create.g.dart';

@JsonSerializable()
class FirewallRuleCreate {
  const FirewallRuleCreate({
    required this.site,
    required this.tier,
    required this.protocol,
    required this.fromPort,
    required this.toPort,
    required this.cidr,
    required this.description,
    this.enabled = true,
  });
  
  factory FirewallRuleCreate.fromJson(Map<String, Object?> json) => _$FirewallRuleCreateFromJson(json);
  
  final FirewallRuleCreateSite site;
  final FirewallRuleCreateTier tier;
  final FirewallRuleCreateProtocol protocol;

  /// ICMP: type (8 = echo)
  @JsonKey(name: 'from_port')
  final int fromPort;

  /// ICMP: code (0)
  @JsonKey(name: 'to_port')
  final int toPort;
  final String cidr;
  final String description;
  final bool enabled;

  Map<String, Object?> toJson() => _$FirewallRuleCreateToJson(this);
}
