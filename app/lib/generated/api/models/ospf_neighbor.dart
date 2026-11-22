// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'ospf_neighbor.g.dart';

@JsonSerializable()
class OspfNeighbor {
  const OspfNeighbor({
    required this.routerId,
    required this.state,
    this.interfaceValue,
    this.address,
  });
  
  factory OspfNeighbor.fromJson(Map<String, Object?> json) => _$OspfNeighborFromJson(json);
  
  @JsonKey(name: 'router_id')
  final String routerId;
  final String state;

  /// The name has been replaced because it contains a keyword. Original name: `interface`.
  /// The name has been replaced because it contains a keyword. Original name: `interface`.
  /// The name has been replaced because it contains a keyword. Original name: `interface`.
  @JsonKey(name: 'interface')
  final String? interfaceValue;
  final String? address;

  Map<String, Object?> toJson() => _$OspfNeighborToJson(this);
}
