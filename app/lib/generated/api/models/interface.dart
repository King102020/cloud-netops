// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'interface_state.dart';

part 'interface.g.dart';

@JsonSerializable()
class Interface {
  const Interface({
    required this.name,
    this.state = InterfaceState.unknown,
    this.address,
    this.description,
  });
  
  factory Interface.fromJson(Map<String, Object?> json) => _$InterfaceFromJson(json);
  
  final String name;
  final String? address;
  final String? description;
  final InterfaceState state;

  Map<String, Object?> toJson() => _$InterfaceToJson(this);
}
