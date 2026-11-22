// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'page_subnet.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PageSubnet _$PageSubnetFromJson(Map<String, dynamic> json) => PageSubnet(
  items: (json['items'] as List<dynamic>)
      .map((e) => Subnet.fromJson(e as Map<String, dynamic>))
      .toList(),
  nextCursor: json['next_cursor'] as String?,
);

Map<String, dynamic> _$PageSubnetToJson(PageSubnet instance) =>
    <String, dynamic>{
      'items': instance.items,
      'next_cursor': instance.nextCursor,
    };
