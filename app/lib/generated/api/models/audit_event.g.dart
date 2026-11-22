// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audit_event.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AuditEvent _$AuditEventFromJson(Map<String, dynamic> json) => AuditEvent(
  id: json['id'] as String,
  at: DateTime.parse(json['at'] as String),
  actor: json['actor'] as String,
  role: Role.fromJson(json['role'] as String),
  action: json['action'] as String,
  target: json['target'] as String,
  requestId: json['request_id'] as String,
  result: AuditEventResult.fromJson(json['result'] as String),
  before: json['before'],
  after: json['after'],
);

Map<String, dynamic> _$AuditEventToJson(AuditEvent instance) =>
    <String, dynamic>{
      'id': instance.id,
      'at': instance.at.toIso8601String(),
      'actor': instance.actor,
      'role': instance.role,
      'action': instance.action,
      'target': instance.target,
      'before': instance.before,
      'after': instance.after,
      'request_id': instance.requestId,
      'result': instance.result,
    };
