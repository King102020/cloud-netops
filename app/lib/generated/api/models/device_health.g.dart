// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_health.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DeviceHealth _$DeviceHealthFromJson(Map<String, dynamic> json) => DeviceHealth(
  deviceId: json['device_id'] as String,
  reachable: json['reachable'] as bool,
  status: DeviceHealthStatus.fromJson(json['status'] as String),
  checkedAt: DateTime.parse(json['checked_at'] as String),
  ospfNeighbors:
      (json['ospf_neighbors'] as List<dynamic>?)
          ?.map((e) => OspfNeighbor.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  expectedNeighbors:
      (json['expected_neighbors'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  interfaces:
      (json['interfaces'] as List<dynamic>?)
          ?.map((e) => Interface.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  uptimeSeconds: json['uptime_seconds'] as num?,
);

Map<String, dynamic> _$DeviceHealthToJson(DeviceHealth instance) =>
    <String, dynamic>{
      'device_id': instance.deviceId,
      'reachable': instance.reachable,
      'status': instance.status,
      'uptime_seconds': instance.uptimeSeconds,
      'ospf_neighbors': instance.ospfNeighbors,
      'expected_neighbors': instance.expectedNeighbors,
      'interfaces': instance.interfaces,
      'checked_at': instance.checkedAt.toIso8601String(),
    };
