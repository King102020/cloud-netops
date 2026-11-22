// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'audit_event.dart';

part 'page_audit_event.g.dart';

@JsonSerializable()
class PageAuditEvent {
  const PageAuditEvent({
    required this.items,
    this.nextCursor,
  });
  
  factory PageAuditEvent.fromJson(Map<String, Object?> json) => _$PageAuditEventFromJson(json);
  
  final List<AuditEvent> items;
  @JsonKey(name: 'next_cursor')
  final String? nextCursor;

  Map<String, Object?> toJson() => _$PageAuditEventToJson(this);
}
