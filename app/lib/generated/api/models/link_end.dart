// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'link_end.g.dart';

@JsonSerializable()
class LinkEnd {
  const LinkEnd({
    required this.device,
    required this.interfaceValue,
    this.address,
  });
  
  factory LinkEnd.fromJson(Map<String, Object?> json) => _$LinkEndFromJson(json);
  
  final String device;

  /// The name has been replaced because it contains a keyword. Original name: `interface`.
  @JsonKey(name: 'interface')
  final String interfaceValue;
  final String? address;

  Map<String, Object?> toJson() => _$LinkEndToJson(this);
}
