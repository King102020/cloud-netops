// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/health_status.dart';

part 'system_client.g.dart';

@RestApi()
abstract class SystemClient {
  factory SystemClient(Dio dio, {String? baseUrl}) = _SystemClient;

  /// Liveness: the process is up
  @GET('/healthz')
  Future<HealthStatus> healthz();

  /// Readiness: dependencies are reachable
  @GET('/readyz')
  Future<HealthStatus> readyz();
}
