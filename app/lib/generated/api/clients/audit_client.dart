// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/page_audit_event.dart';

part 'audit_client.g.dart';

@RestApi()
abstract class AuditClient {
  factory AuditClient(Dio dio, {String? baseUrl}) = _AuditClient;

  /// Audit log, newest first.
  ///
  /// [limit] - Page size.
  ///
  /// [cursor] - next_cursor from the previous page.
  @GET('/v1/audit-events')
  Future<PageAuditEvent> auditEvents({
    @Query('cursor') String? cursor,
    @Query('actor') String? actor,
    @Query('action') String? action,
    @Query('limit') int? limit = 50,
  });
}
