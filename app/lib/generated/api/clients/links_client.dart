// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/link.dart';
import '../models/link_state_change.dart';

part 'links_client.g.dart';

@RestApi()
abstract class LinksClient {
  factory LinksClient(Dio dio, {String? baseUrl}) = _LinksClient;

  /// List links with live state
  @GET('/v1/links')
  Future<List<Link>> listLinks();

  /// One link
  @GET('/v1/links/{link_id}')
  Future<Link> getLink({
    @Path('link_id') required String linkId,
  });

  /// Take a link up or down (operator). OSPF reroutes around it.
  @PATCH('/v1/links/{link_id}')
  Future<Link> setLink({
    @Path('link_id') required String linkId,
    @Body() required LinkStateChange body,
  });
}
