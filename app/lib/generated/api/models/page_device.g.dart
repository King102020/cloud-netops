// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'page_device.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PageDevice _$PageDeviceFromJson(Map<String, dynamic> json) => PageDevice(
  items: (json['items'] as List<dynamic>)
      .map((e) => Device.fromJson(e as Map<String, dynamic>))
      .toList(),
  nextCursor: json['next_cursor'] as String?,
);

Map<String, dynamic> _$PageDeviceToJson(PageDevice instance) =>
    <String, dynamic>{
      'items': instance.items,
      'next_cursor': instance.nextCursor,
    };
