// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/topology.dart';

part 'topology_client.g.dart';

@RestApi()
abstract class TopologyClient {
  factory TopologyClient(Dio dio, {String? baseUrl}) = _TopologyClient;

  /// Sites, devices and links with live state
  @GET('/v1/topology')
  Future<Topology> topology();
}
