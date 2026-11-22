// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/firewall_rule.dart';
import '../models/firewall_rule_create.dart';
import '../models/firewall_rule_patch.dart';
import '../models/job.dart';
import '../models/page_firewall_rule.dart';

part 'firewall_client.g.dart';

@RestApi()
abstract class FirewallClient {
  factory FirewallClient(Dio dio, {String? baseUrl}) = _FirewallClient;

  /// List API-managed firewall rules.
  ///
  /// [limit] - Page size.
  ///
  /// [cursor] - next_cursor from the previous page.
  @GET('/v1/firewall-rules')
  Future<PageFirewallRule> listRules({
    @Query('cursor') String? cursor,
    @Query('site') String? site,
    @Query('tier') String? tier,
    @Query('limit') int? limit = 50,
  });

  /// Add a security-group rule (operator). Applied through Terraform.
  ///
  /// [idempotencyKey] - Unique per logical request, e.g. a UUID. Retries must reuse it.
  @POST('/v1/firewall-rules')
  Future<FirewallRule> createRule({
    @Header('Idempotency-Key') required String idempotencyKey,
    @Body() required FirewallRuleCreate body,
  });

  /// One firewall rule
  @GET('/v1/firewall-rules/{rule_id}')
  Future<FirewallRule> getRule({
    @Path('rule_id') required String ruleId,
  });

  /// Enable or disable a rule (operator). Applied through Terraform.
  @PATCH('/v1/firewall-rules/{rule_id}')
  Future<FirewallRule> patchRule({
    @Path('rule_id') required String ruleId,
    @Body() required FirewallRulePatch body,
  });

  /// Remove a rule (operator). Applied through Terraform.
  @DELETE('/v1/firewall-rules/{rule_id}')
  Future<Job> deleteRule({
    @Path('rule_id') required String ruleId,
  });
}
