// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ospf_neighbor.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OspfNeighbor _$OspfNeighborFromJson(Map<String, dynamic> json) => OspfNeighbor(
  routerId: json['router_id'] as String,
  state: json['state'] as String,
  interfaceValue: json['interface'] as String?,
  address: json['address'] as String?,
);

Map<String, dynamic> _$OspfNeighborToJson(OspfNeighbor instance) =>
    <String, dynamic>{
      'router_id': instance.routerId,
      'state': instance.state,
      'interface': instance.interfaceValue,
      'address': instance.address,
    };
