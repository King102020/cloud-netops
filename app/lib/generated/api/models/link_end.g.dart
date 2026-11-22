// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'link_end.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LinkEnd _$LinkEndFromJson(Map<String, dynamic> json) => LinkEnd(
  device: json['device'] as String,
  interfaceValue: json['interface'] as String,
  address: json['address'] as String?,
);

Map<String, dynamic> _$LinkEndToJson(LinkEnd instance) => <String, dynamic>{
  'device': instance.device,
  'interface': instance.interfaceValue,
  'address': instance.address,
};
