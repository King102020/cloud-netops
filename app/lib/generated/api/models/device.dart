// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'device_role.dart';
import 'interface.dart';

part 'device.g.dart';

@JsonSerializable()
class Device {
  const Device({
    required this.id,
    required this.site,
    required this.role,
    required this.model,
    this.interfaces = const [],
    this.mgmtIp,
    this.routerId,
  });
  
  factory Device.fromJson(Map<String, Object?> json) => _$DeviceFromJson(json);
  
  final String id;
  final String site;
  final DeviceRole role;

  /// Packet Tracer model / lab image
  final String model;
  @JsonKey(name: 'mgmt_ip')
  final String? mgmtIp;
  @JsonKey(name: 'router_id')
  final String? routerId;
  final List<Interface> interfaces;

  Map<String, Object?> toJson() => _$DeviceToJson(this);
}
