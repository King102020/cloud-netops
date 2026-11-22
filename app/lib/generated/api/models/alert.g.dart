// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'alert.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Alert _$AlertFromJson(Map<String, dynamic> json) => Alert(
  id: json['id'] as String,
  severity: AlertSeverity.fromJson(json['severity'] as String),
  kind: AlertKind.fromJson(json['kind'] as String),
  target: json['target'] as String,
  message: json['message'] as String,
  since: DateTime.parse(json['since'] as String),
);

Map<String, dynamic> _$AlertToJson(Alert instance) => <String, dynamic>{
  'id': instance.id,
  'severity': instance.severity,
  'kind': instance.kind,
  'target': instance.target,
  'message': instance.message,
  'since': instance.since.toIso8601String(),
};
