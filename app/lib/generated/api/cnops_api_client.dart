// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';

import 'clients/system_client.dart';
import 'clients/auth_client.dart';
import 'clients/topology_client.dart';
import 'clients/devices_client.dart';
import 'clients/links_client.dart';
import 'clients/alerts_client.dart';
import 'clients/firewall_client.dart';
import 'clients/subnets_client.dart';
import 'clients/jobs_client.dart';
import 'clients/audit_client.dart';

/// Cloud NetOps API `v0.1.0`.
///
///
/// Control API for the Cloud NetOps network (docs/network-design.md).
///
/// * **Read:** topology, devices, health, links, alerts, subnets, firewall rules, audit log.
/// * **Change:** firewall rules and subnets go through **Terraform** (202 + job);.
///   links are taken up/down on the lab routers.
/// * **Auth:** `POST /v1/auth/token`, then `Authorization: Bearer <jwt>`.
///   Roles: viewer < operator < admin.
/// * **Errors:** RFC 9457 `application/problem+json`.
///
class CnopsApiClient {
  CnopsApiClient(
    Dio dio, {
    String? baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl;

  final Dio _dio;
  final String? _baseUrl;

  static String get version => '0.1.0';

  SystemClient? _system;
  AuthClient? _auth;
  TopologyClient? _topology;
  DevicesClient? _devices;
  LinksClient? _links;
  AlertsClient? _alerts;
  FirewallClient? _firewall;
  SubnetsClient? _subnets;
  JobsClient? _jobs;
  AuditClient? _audit;

  SystemClient get system => _system ??= SystemClient(_dio, baseUrl: _baseUrl);

  AuthClient get auth => _auth ??= AuthClient(_dio, baseUrl: _baseUrl);

  TopologyClient get topology => _topology ??= TopologyClient(_dio, baseUrl: _baseUrl);

  DevicesClient get devices => _devices ??= DevicesClient(_dio, baseUrl: _baseUrl);

  LinksClient get links => _links ??= LinksClient(_dio, baseUrl: _baseUrl);

  AlertsClient get alerts => _alerts ??= AlertsClient(_dio, baseUrl: _baseUrl);

  FirewallClient get firewall => _firewall ??= FirewallClient(_dio, baseUrl: _baseUrl);

  SubnetsClient get subnets => _subnets ??= SubnetsClient(_dio, baseUrl: _baseUrl);

  JobsClient get jobs => _jobs ??= JobsClient(_dio, baseUrl: _baseUrl);

  AuditClient get audit => _audit ??= AuditClient(_dio, baseUrl: _baseUrl);
}
