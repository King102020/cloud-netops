// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'subnet_create_az.dart';
import 'subnet_create_site.dart';
import 'subnet_create_tier.dart';

part 'subnet_create.g.dart';

@JsonSerializable()
class SubnetCreate {
  const SubnetCreate({
    required this.site,
    required this.name,
    required this.cidrBlock,
    required this.az,
    required this.tier,
  });
  
  factory SubnetCreate.fromJson(Map<String, Object?> json) => _$SubnetCreateFromJson(json);
  
  final SubnetCreateSite site;
  final String name;
  @JsonKey(name: 'cidr_block')
  final String cidrBlock;
  final SubnetCreateAz az;
  final SubnetCreateTier tier;

  Map<String, Object?> toJson() => _$SubnetCreateToJson(this);
}
