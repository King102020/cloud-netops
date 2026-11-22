// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'link.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Link _$LinkFromJson(Map<String, dynamic> json) => Link(
  id: json['id'] as String,
  kind: LinkKind.fromJson(json['kind'] as String),
  a: LinkEnd.fromJson(json['a'] as Map<String, dynamic>),
  b: LinkEnd.fromJson(json['b'] as Map<String, dynamic>),
  subnet: json['subnet'] as String,
  controllable: json['controllable'] as bool,
  state: json['state'] == null
      ? LinkState.unknown
      : LinkState.fromJson(json['state'] as String),
  ospfCost: (json['ospf_cost'] as num?)?.toInt(),
);

Map<String, dynamic> _$LinkToJson(Link instance) => <String, dynamic>{
  'id': instance.id,
  'kind': instance.kind,
  'a': instance.a,
  'b': instance.b,
  'subnet': instance.subnet,
  'ospf_cost': instance.ospfCost,
  'state': instance.state,
  'controllable': instance.controllable,
};
