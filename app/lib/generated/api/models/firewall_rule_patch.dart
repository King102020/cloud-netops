// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'firewall_rule_patch.g.dart';

@JsonSerializable()
class FirewallRulePatch {
  const FirewallRulePatch({
    required this.enabled,
  });
  
  factory FirewallRulePatch.fromJson(Map<String, Object?> json) => _$FirewallRulePatchFromJson(json);
  
  final bool enabled;

  Map<String, Object?> toJson() => _$FirewallRulePatchToJson(this);
}
