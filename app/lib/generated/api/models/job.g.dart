// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'job.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Job _$JobFromJson(Map<String, dynamic> json) => Job(
  id: json['id'] as String,
  kind: json['kind'] as String,
  mode: json['mode'] as String,
  state: JobState.fromJson(json['state'] as String),
  reason: json['reason'] as String,
  createdAt: DateTime.parse(json['created_at'] as String),
  finishedAt: json['finished_at'] == null
      ? null
      : DateTime.parse(json['finished_at'] as String),
  summary: json['summary'] as String?,
  outputTail: json['output_tail'] as String?,
);

Map<String, dynamic> _$JobToJson(Job instance) => <String, dynamic>{
  'id': instance.id,
  'kind': instance.kind,
  'mode': instance.mode,
  'state': instance.state,
  'reason': instance.reason,
  'created_at': instance.createdAt.toIso8601String(),
  'finished_at': instance.finishedAt?.toIso8601String(),
  'summary': instance.summary,
  'output_tail': instance.outputTail,
};
