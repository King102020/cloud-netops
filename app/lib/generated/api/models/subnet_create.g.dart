// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subnet_create.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SubnetCreate _$SubnetCreateFromJson(Map<String, dynamic> json) => SubnetCreate(
  site: SubnetCreateSite.fromJson(json['site'] as String),
  name: json['name'] as String,
  cidrBlock: json['cidr_block'] as String,
  az: SubnetCreateAz.fromJson(json['az'] as String),
  tier: SubnetCreateTier.fromJson(json['tier'] as String),
);

Map<String, dynamic> _$SubnetCreateToJson(SubnetCreate instance) =>
    <String, dynamic>{
      'site': instance.site,
      'name': instance.name,
      'cidr_block': instance.cidrBlock,
      'az': instance.az,
      'tier': instance.tier,
    };
