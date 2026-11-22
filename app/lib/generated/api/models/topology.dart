// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'device.dart';
import 'link.dart';
import 'site_info.dart';

part 'topology.g.dart';

@JsonSerializable()
class Topology {
  const Topology({
    required this.sites,
    required this.devices,
    required this.links,
  });
  
  factory Topology.fromJson(Map<String, Object?> json) => _$TopologyFromJson(json);
  
  final List<SiteInfo> sites;
  final List<Device> devices;
  final List<Link> links;

  Map<String, Object?> toJson() => _$TopologyToJson(this);
}
