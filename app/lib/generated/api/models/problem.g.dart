// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'problem.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Problem _$ProblemFromJson(Map<String, dynamic> json) => Problem(
  title: json['title'] as String,
  status: (json['status'] as num).toInt(),
  detail: json['detail'] as String?,
  instance: json['instance'] as String?,
  requestId: json['request_id'] as String?,
  errors: json['errors'] as List<dynamic>?,
  type: json['type'] as String? ?? 'about:blank',
);

Map<String, dynamic> _$ProblemToJson(Problem instance) => <String, dynamic>{
  'type': instance.type,
  'title': instance.title,
  'status': instance.status,
  'detail': instance.detail,
  'instance': instance.instance,
  'request_id': instance.requestId,
  'errors': instance.errors,
};
