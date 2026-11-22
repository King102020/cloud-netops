// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'page_audit_event.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PageAuditEvent _$PageAuditEventFromJson(Map<String, dynamic> json) =>
    PageAuditEvent(
      items: (json['items'] as List<dynamic>)
          .map((e) => AuditEvent.fromJson(e as Map<String, dynamic>))
          .toList(),
      nextCursor: json['next_cursor'] as String?,
    );

Map<String, dynamic> _$PageAuditEventToJson(PageAuditEvent instance) =>
    <String, dynamic>{
      'items': instance.items,
      'next_cursor': instance.nextCursor,
    };
