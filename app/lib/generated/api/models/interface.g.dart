// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'interface.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Interface _$InterfaceFromJson(Map<String, dynamic> json) => Interface(
  name: json['name'] as String,
  state: json['state'] == null
      ? InterfaceState.unknown
      : InterfaceState.fromJson(json['state'] as String),
  address: json['address'] as String?,
  description: json['description'] as String?,
);

Map<String, dynamic> _$InterfaceToJson(Interface instance) => <String, dynamic>{
  'name': instance.name,
  'address': instance.address,
  'description': instance.description,
  'state': instance.state,
};
