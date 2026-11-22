// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'device.dart';

part 'page_device.g.dart';

@JsonSerializable()
class PageDevice {
  const PageDevice({
    required this.items,
    this.nextCursor,
  });
  
  factory PageDevice.fromJson(Map<String, Object?> json) => _$PageDeviceFromJson(json);
  
  final List<Device> items;
  @JsonKey(name: 'next_cursor')
  final String? nextCursor;

  Map<String, Object?> toJson() => _$PageDeviceToJson(this);
}
