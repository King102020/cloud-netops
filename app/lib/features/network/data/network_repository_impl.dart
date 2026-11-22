import '../../../core/errors/result.dart';
import '../../../generated/api/export.dart' as api;
import '../domain/network.dart';

class NetworkRepositoryImpl implements NetworkRepository {
  NetworkRepositoryImpl(this._client);

  final api.CnopsApiClient _client;

  @override
  Future<Result<NetworkSnapshot>> topology() => guard(() async {
    final t = await _client.topology.topology();
    return NetworkSnapshot(
      sites: [
        for (final s in t.sites)
          Site(
            id: s.id,
            name: s.name,
            cidr: s.cidr,
            cloudCidr: s.cloudCidr,
            ospfArea: s.ospfArea,
          ),
      ],
      nodes: [for (final d in t.devices) mapDevice(d)],
      links: [for (final l in t.links) mapLink(l)],
    );
  });

  @override
  Future<Result<NetworkNode>> device(String id) => guard(
    () async => mapDevice(await _client.devices.getDevice(deviceId: id)),
  );

  @override
  Future<Result<DeviceHealthInfo>> health(String id) => guard(() async {
    final h = await _client.devices.deviceHealth(deviceId: id);
    return DeviceHealthInfo(
      deviceId: h.deviceId,
      reachable: h.reachable,
      level: switch (h.status) {
        api.DeviceHealthStatus.healthy => HealthLevel.healthy,
        api.DeviceHealthStatus.degraded => HealthLevel.degraded,
        _ => HealthLevel.down,
      },
      uptime: h.uptimeSeconds == null
          ? null
          : Duration(seconds: h.uptimeSeconds!.round()),
      neighbors: [
        for (final n in h.ospfNeighbors)
          OspfNeighborInfo(
            routerId: n.routerId,
            state: n.state,
            interface: n.interfaceValue,
          ),
      ],
      expectedNeighbors: h.expectedNeighbors,
      checkedAt: h.checkedAt,
    );
  });

  @override
  Future<Result<NetworkLink>> setLink(String id, {required bool up}) => guard(
    () async {
      final body = api.LinkStateChange(
        state: up ? api.LinkStateChangeState.up : api.LinkStateChangeState.down,
      );
      return mapLink(await _client.links.setLink(linkId: id, body: body));
    },
  );

  @override
  Future<Result<List<NetworkAlert>>> alerts() => guard(() async {
    final alerts = await _client.alerts.alerts();
    return [
      for (final a in alerts)
        NetworkAlert(
          id: a.id,
          critical: a.severity == api.AlertSeverity.critical,
          kind: a.kind.json ?? 'unknown',
          target: a.target,
          message: a.message,
          since: a.since,
        ),
    ];
  });

  static LinkStatus _status(Object? state) => switch (state) {
    api.LinkState.up || api.InterfaceState.up => LinkStatus.up,
    api.LinkState.down || api.InterfaceState.down => LinkStatus.down,
    _ => LinkStatus.unknown,
  };

  static NetworkNode mapDevice(api.Device d) => NetworkNode(
    id: d.id,
    site: d.site,
    role: switch (d.role) {
      api.DeviceRole.router => NodeRole.router,
      api.DeviceRole.server => NodeRole.server,
      api.DeviceRole.isp => NodeRole.isp,
      _ => NodeRole.host,
    },
    model: d.model,
    routerId: d.routerId,
    interfaces: [
      for (final i in d.interfaces)
        NodeInterface(
          name: i.name,
          address: i.address,
          description: i.description,
          state: _status(i.state),
        ),
    ],
  );

  static NetworkLink mapLink(api.Link l) => NetworkLink(
    id: l.id,
    kind: l.kind.json ?? 'unknown',
    aDevice: l.a.device,
    bDevice: l.b.device,
    subnet: l.subnet,
    ospfCost: l.ospfCost,
    state: _status(l.state),
    controllable: l.controllable,
  );
}
