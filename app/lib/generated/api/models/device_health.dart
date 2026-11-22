// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'device_health_status.dart';
import 'interface.dart';
import 'ospf_neighbor.dart';

part 'device_health.g.dart';

@JsonSerializable()
class DeviceHealth {
  const DeviceHealth({
    required this.deviceId,
    required this.reachable,
    required this.status,
    required this.checkedAt,
    this.ospfNeighbors = const [],
    this.expectedNeighbors = const [],
    this.interfaces = const [],
    this.uptimeSeconds,
  });
  
  factory DeviceHealth.fromJson(Map<String, Object?> json) => _$DeviceHealthFromJson(json);
  
  @JsonKey(name: 'device_id')
  final String deviceId;
  final bool reachable;
  final DeviceHealthStatus status;
  @JsonKey(name: 'uptime_seconds')
  final num? uptimeSeconds;
  @JsonKey(name: 'ospf_neighbors')
  final List<OspfNeighbor> ospfNeighbors;
  @JsonKey(name: 'expected_neighbors')
  final List<String> expectedNeighbors;
  final List<Interface> interfaces;
  @JsonKey(name: 'checked_at')
  final DateTime checkedAt;

  Map<String, Object?> toJson() => _$DeviceHealthToJson(this);
}
