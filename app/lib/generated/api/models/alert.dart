// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'alert_kind.dart';
import 'alert_severity.dart';

part 'alert.g.dart';

@JsonSerializable()
class Alert {
  const Alert({
    required this.id,
    required this.severity,
    required this.kind,
    required this.target,
    required this.message,
    required this.since,
  });
  
  factory Alert.fromJson(Map<String, Object?> json) => _$AlertFromJson(json);
  
  final String id;
  final AlertSeverity severity;
  final AlertKind kind;
  final String target;
  final String message;
  final DateTime since;

  Map<String, Object?> toJson() => _$AlertToJson(this);
}
