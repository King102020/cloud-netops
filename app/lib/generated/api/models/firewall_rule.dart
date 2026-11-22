// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'change_status.dart';
import 'firewall_rule_protocol.dart';
import 'firewall_rule_site.dart';
import 'firewall_rule_tier.dart';

part 'firewall_rule.g.dart';

@JsonSerializable()
class FirewallRule {
  const FirewallRule({
    required this.site,
    required this.tier,
    required this.protocol,
    required this.fromPort,
    required this.toPort,
    required this.cidr,
    required this.description,
    required this.id,
    required this.createdAt,
    required this.createdBy,
    this.jobId,
    this.enabled = true,
    this.status = ChangeStatus.pending,
  });
  
  factory FirewallRule.fromJson(Map<String, Object?> json) => _$FirewallRuleFromJson(json);
  
  final FirewallRuleSite site;
  final FirewallRuleTier tier;
  final FirewallRuleProtocol protocol;

  /// ICMP: type (8 = echo)
  @JsonKey(name: 'from_port')
  final int fromPort;

  /// ICMP: code (0)
  @JsonKey(name: 'to_port')
  final int toPort;
  final String cidr;
  final String description;
  final bool enabled;
  final String id;
  final ChangeStatus status;
  @JsonKey(name: 'job_id')
  final String? jobId;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'created_by')
  final String createdBy;

  Map<String, Object?> toJson() => _$FirewallRuleToJson(this);
}
