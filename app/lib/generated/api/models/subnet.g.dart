// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subnet.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Subnet _$SubnetFromJson(Map<String, dynamic> json) => Subnet(
  site: SubnetSite.fromJson(json['site'] as String),
  name: json['name'] as String,
  cidrBlock: json['cidr_block'] as String,
  az: SubnetAz.fromJson(json['az'] as String),
  tier: SubnetTier.fromJson(json['tier'] as String),
  jobId: json['job_id'] as String?,
  status: json['status'] == null
      ? ChangeStatus.pending
      : ChangeStatus.fromJson(json['status'] as String),
  managed: json['managed'] as bool? ?? true,
);

Map<String, dynamic> _$SubnetToJson(Subnet instance) => <String, dynamic>{
  'site': instance.site,
  'name': instance.name,
  'cidr_block': instance.cidrBlock,
  'az': instance.az,
  'tier': instance.tier,
  'status': instance.status,
  'job_id': instance.jobId,
  'managed': instance.managed,
};
