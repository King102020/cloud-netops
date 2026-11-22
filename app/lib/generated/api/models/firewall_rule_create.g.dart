// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'firewall_rule_create.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FirewallRuleCreate _$FirewallRuleCreateFromJson(Map<String, dynamic> json) =>
    FirewallRuleCreate(
      site: FirewallRuleCreateSite.fromJson(json['site'] as String),
      tier: FirewallRuleCreateTier.fromJson(json['tier'] as String),
      protocol: FirewallRuleCreateProtocol.fromJson(json['protocol'] as String),
      fromPort: (json['from_port'] as num).toInt(),
      toPort: (json['to_port'] as num).toInt(),
      cidr: json['cidr'] as String,
      description: json['description'] as String,
      enabled: json['enabled'] as bool? ?? true,
    );

Map<String, dynamic> _$FirewallRuleCreateToJson(FirewallRuleCreate instance) =>
    <String, dynamic>{
      'site': instance.site,
      'tier': instance.tier,
      'protocol': instance.protocol,
      'from_port': instance.fromPort,
      'to_port': instance.toPort,
      'cidr': instance.cidr,
      'description': instance.description,
      'enabled': instance.enabled,
    };
