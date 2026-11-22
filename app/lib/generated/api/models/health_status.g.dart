// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'health_status.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HealthStatus _$HealthStatusFromJson(Map<String, dynamic> json) => HealthStatus(
  status: HealthStatusStatus.fromJson(json['status'] as String),
  checks: Map<String, String>.from(json['checks'] as Map),
);

Map<String, dynamic> _$HealthStatusToJson(HealthStatus instance) =>
    <String, dynamic>{'status': instance.status, 'checks': instance.checks};
