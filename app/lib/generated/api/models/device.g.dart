// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Device _$DeviceFromJson(Map<String, dynamic> json) => Device(
  id: json['id'] as String,
  site: json['site'] as String,
  role: DeviceRole.fromJson(json['role'] as String),
  model: json['model'] as String,
  interfaces:
      (json['interfaces'] as List<dynamic>?)
          ?.map((e) => Interface.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  mgmtIp: json['mgmt_ip'] as String?,
  routerId: json['router_id'] as String?,
);

Map<String, dynamic> _$DeviceToJson(Device instance) => <String, dynamic>{
  'id': instance.id,
  'site': instance.site,
  'role': instance.role,
  'model': instance.model,
  'mgmt_ip': instance.mgmtIp,
  'router_id': instance.routerId,
  'interfaces': instance.interfaces,
};
