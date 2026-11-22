// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'firewall_rule.dart';

part 'page_firewall_rule.g.dart';

@JsonSerializable()
class PageFirewallRule {
  const PageFirewallRule({
    required this.items,
    this.nextCursor,
  });
  
  factory PageFirewallRule.fromJson(Map<String, Object?> json) => _$PageFirewallRuleFromJson(json);
  
  final List<FirewallRule> items;
  @JsonKey(name: 'next_cursor')
  final String? nextCursor;

  Map<String, Object?> toJson() => _$PageFirewallRuleToJson(this);
}
