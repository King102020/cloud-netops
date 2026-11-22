// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'firewall_rule.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FirewallRule _$FirewallRuleFromJson(Map<String, dynamic> json) => FirewallRule(
  site: FirewallRuleSite.fromJson(json['site'] as String),
  tier: FirewallRuleTier.fromJson(json['tier'] as String),
  protocol: FirewallRuleProtocol.fromJson(json['protocol'] as String),
  fromPort: (json['from_port'] as num).toInt(),
  toPort: (json['to_port'] as num).toInt(),
  cidr: json['cidr'] as String,
  description: json['description'] as String,
  id: json['id'] as String,
  createdAt: DateTime.parse(json['created_at'] as String),
  createdBy: json['created_by'] as String,
  jobId: json['job_id'] as String?,
  enabled: json['enabled'] as bool? ?? true,
  status: json['status'] == null
      ? ChangeStatus.pending
      : ChangeStatus.fromJson(json['status'] as String),
);

Map<String, dynamic> _$FirewallRuleToJson(FirewallRule instance) =>
    <String, dynamic>{
      'site': instance.site,
      'tier': instance.tier,
      'protocol': instance.protocol,
      'from_port': instance.fromPort,
      'to_port': instance.toPort,
      'cidr': instance.cidr,
      'description': instance.description,
      'enabled': instance.enabled,
      'id': instance.id,
      'status': instance.status,
      'job_id': instance.jobId,
      'created_at': instance.createdAt.toIso8601String(),
      'created_by': instance.createdBy,
    };
