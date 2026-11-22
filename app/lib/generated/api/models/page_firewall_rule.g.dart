// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'page_firewall_rule.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PageFirewallRule _$PageFirewallRuleFromJson(Map<String, dynamic> json) =>
    PageFirewallRule(
      items: (json['items'] as List<dynamic>)
          .map((e) => FirewallRule.fromJson(e as Map<String, dynamic>))
          .toList(),
      nextCursor: json['next_cursor'] as String?,
    );

Map<String, dynamic> _$PageFirewallRuleToJson(PageFirewallRule instance) =>
    <String, dynamic>{
      'items': instance.items,
      'next_cursor': instance.nextCursor,
    };
