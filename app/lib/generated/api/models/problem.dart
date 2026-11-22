// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'problem.g.dart';

/// RFC 9457 problem details.
@JsonSerializable()
class Problem {
  const Problem({
    required this.title,
    required this.status,
    this.detail,
    this.instance,
    this.requestId,
    this.errors,
    this.type = 'about:blank',
  });
  
  factory Problem.fromJson(Map<String, Object?> json) => _$ProblemFromJson(json);
  
  final String type;
  final String title;
  final int status;
  final String? detail;
  final String? instance;
  @JsonKey(name: 'request_id')
  final String? requestId;
  final List<dynamic>? errors;

  Map<String, Object?> toJson() => _$ProblemToJson(this);
}
