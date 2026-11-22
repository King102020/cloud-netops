// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'change_status.dart';
import 'subnet_az.dart';
import 'subnet_site.dart';
import 'subnet_tier.dart';

part 'subnet.g.dart';

@JsonSerializable()
class Subnet {
  const Subnet({
    required this.site,
    required this.name,
    required this.cidrBlock,
    required this.az,
    required this.tier,
    this.jobId,
    this.status = ChangeStatus.pending,
    this.managed = true,
  });
  
  factory Subnet.fromJson(Map<String, Object?> json) => _$SubnetFromJson(json);
  
  final SubnetSite site;
  final String name;
  @JsonKey(name: 'cidr_block')
  final String cidrBlock;
  final SubnetAz az;
  final SubnetTier tier;
  final ChangeStatus status;
  @JsonKey(name: 'job_id')
  final String? jobId;

  /// false = part of the base design
  final bool managed;

  Map<String, Object?> toJson() => _$SubnetToJson(this);
}
