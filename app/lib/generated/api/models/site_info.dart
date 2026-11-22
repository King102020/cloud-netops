// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'site_info.g.dart';

@JsonSerializable()
class SiteInfo {
  const SiteInfo({
    required this.id,
    required this.name,
    required this.cidr,
    required this.cloudCidr,
    required this.ospfArea,
  });
  
  factory SiteInfo.fromJson(Map<String, Object?> json) => _$SiteInfoFromJson(json);
  
  final String id;
  final String name;
  final String cidr;
  @JsonKey(name: 'cloud_cidr')
  final String? cloudCidr;
  @JsonKey(name: 'ospf_area')
  final int? ospfArea;

  Map<String, Object?> toJson() => _$SiteInfoToJson(this);
}
