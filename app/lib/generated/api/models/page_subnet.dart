// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'subnet.dart';

part 'page_subnet.g.dart';

@JsonSerializable()
class PageSubnet {
  const PageSubnet({
    required this.items,
    this.nextCursor,
  });
  
  factory PageSubnet.fromJson(Map<String, Object?> json) => _$PageSubnetFromJson(json);
  
  final List<Subnet> items;
  @JsonKey(name: 'next_cursor')
  final String? nextCursor;

  Map<String, Object?> toJson() => _$PageSubnetToJson(this);
}
