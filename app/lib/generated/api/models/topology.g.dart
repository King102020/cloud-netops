// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'topology.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Topology _$TopologyFromJson(Map<String, dynamic> json) => Topology(
  sites: (json['sites'] as List<dynamic>)
      .map((e) => SiteInfo.fromJson(e as Map<String, dynamic>))
      .toList(),
  devices: (json['devices'] as List<dynamic>)
      .map((e) => Device.fromJson(e as Map<String, dynamic>))
      .toList(),
  links: (json['links'] as List<dynamic>)
      .map((e) => Link.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$TopologyToJson(Topology instance) => <String, dynamic>{
  'sites': instance.sites,
  'devices': instance.devices,
  'links': instance.links,
};
