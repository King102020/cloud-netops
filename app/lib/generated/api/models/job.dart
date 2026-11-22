// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'job_state.dart';

part 'job.g.dart';

@JsonSerializable()
class Job {
  const Job({
    required this.id,
    required this.kind,
    required this.mode,
    required this.state,
    required this.reason,
    required this.createdAt,
    this.finishedAt,
    this.summary,
    this.outputTail,
  });
  
  factory Job.fromJson(Map<String, Object?> json) => _$JobFromJson(json);
  
  final String id;
  final String kind;
  final String mode;
  final JobState state;
  final String reason;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'finished_at')
  final DateTime? finishedAt;
  final String? summary;
  @JsonKey(name: 'output_tail')
  final String? outputTail;

  Map<String, Object?> toJson() => _$JobToJson(this);
}
