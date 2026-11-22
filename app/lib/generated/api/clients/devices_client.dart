// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/device.dart';
import '../models/device_health.dart';
import '../models/device_role.dart';
import '../models/page_device.dart';

part 'devices_client.g.dart';

@RestApi()
abstract class DevicesClient {
  factory DevicesClient(Dio dio, {String? baseUrl}) = _DevicesClient;

  /// List devices.
  ///
  /// [limit] - Page size.
  ///
  /// [cursor] - next_cursor from the previous page.
  @GET('/v1/devices')
  Future<PageDevice> listDevices({
    @Query('cursor') String? cursor,
    @Query('site') String? site,
    @Query('role') DeviceRole? role,
    @Query('limit') int? limit = 50,
  });

  /// Device detail with live interfaces
  @GET('/v1/devices/{device_id}')
  Future<Device> getDevice({
    @Path('device_id') required String deviceId,
  });

  /// Reachability and OSPF neighbours
  @GET('/v1/devices/{device_id}/health')
  Future<DeviceHealth> deviceHealth({
    @Path('device_id') required String deviceId,
  });
}
