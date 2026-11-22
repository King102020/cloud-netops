import 'package:equatable/equatable.dart';

import '../../../core/errors/result.dart';

enum NodeRole { router, server, host, isp }

enum LinkStatus { up, down, unknown }

enum HealthLevel { healthy, degraded, down }

class Site extends Equatable {
  const Site({
    required this.id,
    required this.name,
    required this.cidr,
    this.cloudCidr,
    this.ospfArea,
  });

  final String id;
  final String name;
  final String cidr;
  final String? cloudCidr;
  final int? ospfArea;

  @override
  List<Object?> get props => [id, name, cidr, cloudCidr, ospfArea];
}

class NodeInterface extends Equatable {
  const NodeInterface({
    required this.name,
    required this.state,
    this.address,
    this.description,
  });

  final String name;
  final String? address;
  final String? description;
  final LinkStatus state;

  @override
  List<Object?> get props => [name, address, description, state];
}

class NetworkNode extends Equatable {
  const NetworkNode({
    required this.id,
    required this.site,
    required this.role,
    required this.model,
    this.routerId,
    this.interfaces = const [],
  });

  final String id;
  final String site;
  final NodeRole role;
  final String model;
  final String? routerId;
  final List<NodeInterface> interfaces;

  @override
  List<Object?> get props => [id, site, role, model, routerId, interfaces];
}

class NetworkLink extends Equatable {
  const NetworkLink({
    required this.id,
    required this.kind,
    required this.aDevice,
    required this.bDevice,
    required this.subnet,
    required this.state,
    required this.controllable,
    this.ospfCost,
  });

  final String id;
  final String kind;
  final String aDevice;
  final String bDevice;
  final String subnet;
  final int? ospfCost;
  final LinkStatus state;
  final bool controllable;

  bool touches(String device) => aDevice == device || bDevice == device;

  NetworkLink copyWith({LinkStatus? state}) => NetworkLink(
    id: id,
    kind: kind,
    aDevice: aDevice,
    bDevice: bDevice,
    subnet: subnet,
    ospfCost: ospfCost,
    state: state ?? this.state,
    controllable: controllable,
  );

  @override
  List<Object?> get props => [
    id,
    kind,
    aDevice,
    bDevice,
    subnet,
    ospfCost,
    state,
    controllable,
  ];
}

class NetworkSnapshot extends Equatable {
  const NetworkSnapshot({
    required this.sites,
    required this.nodes,
    required this.links,
  });

  final List<Site> sites;
  final List<NetworkNode> nodes;
  final List<NetworkLink> links;

  NetworkSnapshot withLink(NetworkLink link) => NetworkSnapshot(
    sites: sites,
    nodes: nodes,
    links: [for (final l in links) l.id == link.id ? link : l],
  );

  @override
  List<Object?> get props => [sites, nodes, links];
}

class OspfNeighborInfo extends Equatable {
  const OspfNeighborInfo({
    required this.routerId,
    required this.state,
    this.interface,
  });

  final String routerId;
  final String state;
  final String? interface;

  bool get isFull => state.startsWith('Full');

  @override
  List<Object?> get props => [routerId, state, interface];
}

class DeviceHealthInfo extends Equatable {
  const DeviceHealthInfo({
    required this.deviceId,
    required this.reachable,
    required this.level,
    required this.checkedAt,
    this.uptime,
    this.neighbors = const [],
    this.expectedNeighbors = const [],
  });

  final String deviceId;
  final bool reachable;
  final HealthLevel level;
  final Duration? uptime;
  final List<OspfNeighborInfo> neighbors;
  final List<String> expectedNeighbors;
  final DateTime checkedAt;

  List<String> get missingNeighbors {
    final full = {
      for (final n in neighbors)
        if (n.isFull) n.routerId,
    };
    return [
      for (final e in expectedNeighbors)
        if (!full.contains(e)) e,
    ];
  }

  @override
  List<Object?> get props => [
    deviceId,
    reachable,
    level,
    uptime,
    neighbors,
    expectedNeighbors,
    checkedAt,
  ];
}

class NetworkAlert extends Equatable {
  const NetworkAlert({
    required this.id,
    required this.critical,
    required this.kind,
    required this.target,
    required this.message,
    required this.since,
  });

  final String id;
  final bool critical;
  final String kind;
  final String target;
  final String message;
  final DateTime since;

  @override
  List<Object?> get props => [id, critical, kind, target, message, since];
}

abstract interface class NetworkRepository {
  Future<Result<NetworkSnapshot>> topology();
  Future<Result<NetworkNode>> device(String id);
  Future<Result<DeviceHealthInfo>> health(String id);
  Future<Result<NetworkLink>> setLink(String id, {required bool up});
  Future<Result<List<NetworkAlert>>> alerts();
}
