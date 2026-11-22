// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'link_state_change_state.dart';

part 'link_state_change.g.dart';

@JsonSerializable()
class LinkStateChange {
  const LinkStateChange({
    required this.state,
  });
  
  factory LinkStateChange.fromJson(Map<String, Object?> json) => _$LinkStateChangeFromJson(json);
  
  final LinkStateChangeState state;

  Map<String, Object?> toJson() => _$LinkStateChangeToJson(this);
}
