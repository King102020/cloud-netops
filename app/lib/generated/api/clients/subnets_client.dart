// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/page_subnet.dart';
import '../models/subnet.dart';
import '../models/subnet_create.dart';

part 'subnets_client.g.dart';

@RestApi()
abstract class SubnetsClient {
  factory SubnetsClient(Dio dio, {String? baseUrl}) = _SubnetsClient;

  /// Cloud subnets: base design + API-managed.
  ///
  /// [limit] - Page size.
  ///
  /// [cursor] - next_cursor from the previous page.
  @GET('/v1/subnets')
  Future<PageSubnet> listSubnets({
    @Query('cursor') String? cursor,
    @Query('site') String? site,
    @Query('limit') int? limit = 50,
  });

  /// Create a subnet in a site's VPC (admin). Applied through Terraform.
  ///
  /// [idempotencyKey] - Unique per logical request, e.g. a UUID. Retries must reuse it.
  @POST('/v1/subnets')
  Future<Subnet> createSubnet({
    @Header('Idempotency-Key') required String idempotencyKey,
    @Body() required SubnetCreate body,
  });
}
