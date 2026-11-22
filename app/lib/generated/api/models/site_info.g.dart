// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'site_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SiteInfo _$SiteInfoFromJson(Map<String, dynamic> json) => SiteInfo(
  id: json['id'] as String,
  name: json['name'] as String,
  cidr: json['cidr'] as String,
  cloudCidr: json['cloud_cidr'] as String?,
  ospfArea: (json['ospf_area'] as num?)?.toInt(),
);

Map<String, dynamic> _$SiteInfoToJson(SiteInfo instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'cidr': instance.cidr,
  'cloud_cidr': instance.cloudCidr,
  'ospf_area': instance.ospfArea,
};
