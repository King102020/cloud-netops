// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'audit_event_result.dart';
import 'role.dart';

part 'audit_event.g.dart';

@JsonSerializable()
class AuditEvent {
  const AuditEvent({
    required this.id,
    required this.at,
    required this.actor,
    required this.role,
    required this.action,
    required this.target,
    required this.requestId,
    required this.result,
    this.before,
    this.after,
  });
  
  factory AuditEvent.fromJson(Map<String, Object?> json) => _$AuditEventFromJson(json);
  
  final String id;
  final DateTime at;
  final String actor;
  final Role role;
  final String action;
  final String target;
  final dynamic before;
  final dynamic after;
  @JsonKey(name: 'request_id')
  final String requestId;
  final AuditEventResult result;

  Map<String, Object?> toJson() => _$AuditEventToJson(this);
}
