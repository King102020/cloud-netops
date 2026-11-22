// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'link_end.dart';
import 'link_kind.dart';
import 'link_state.dart';

part 'link.g.dart';

@JsonSerializable()
class Link {
  const Link({
    required this.id,
    required this.kind,
    required this.a,
    required this.b,
    required this.subnet,
    required this.controllable,
    this.state = LinkState.unknown,
    this.ospfCost,
  });
  
  factory Link.fromJson(Map<String, Object?> json) => _$LinkFromJson(json);
  
  final String id;
  final LinkKind kind;
  final LinkEnd a;
  final LinkEnd b;
  final String subnet;
  @JsonKey(name: 'ospf_cost')
  final int? ospfCost;
  final LinkState state;

  /// Can be taken up/down through the API
  final bool controllable;

  Map<String, Object?> toJson() => _$LinkToJson(this);
}
