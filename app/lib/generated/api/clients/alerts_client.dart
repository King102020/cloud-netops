// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/alert.dart';

part 'alerts_client.g.dart';

@RestApi()
abstract class AlertsClient {
  factory AlertsClient(Dio dio, {String? baseUrl}) = _AlertsClient;

  /// Active alerts from live health checks
  @GET('/v1/alerts')
  Future<List<Alert>> alerts();
}
