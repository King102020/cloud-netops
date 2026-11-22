// Canned API responses, shaped exactly like api/openapi.json.

const topologyJson = {
  'sites': [
    {
      'id': 'hq',
      'name': 'Head office',
      'cidr': '10.10.0.0/16',
      'cloud_cidr': '10.110.0.0/16',
      'ospf_area': 0,
    },
    {
      'id': 'isp',
      'name': 'ISP',
      'cidr': '203.0.113.0/24',
      'cloud_cidr': null,
      'ospf_area': null,
    },
  ],
  'devices': [
    {
      'id': 'hq-core-01',
      'site': 'hq',
      'role': 'router',
      'model': '3650 / FRR',
      'mgmt_ip': '172.20.20.12',
      'router_id': '10.255.255.2',
      'interfaces': [
        {
          'name': 'eth1',
          'address': '10.255.0.2/30',
          'description': 'TRANSIT',
          'state': 'up',
        },
        {
          'name': 'eth3',
          'address': '10.255.0.9/30',
          'description': 'WAN br2',
          'state': 'down',
        },
      ],
    },
    {
      'id': 'hq-srv-01',
      'site': 'hq',
      'role': 'server',
      'model': 'multitool',
      'interfaces': <Object?>[],
    },
    {
      'id': 'isp-edge-01',
      'site': 'isp',
      'role': 'isp',
      'model': '2911',
      'interfaces': <Object?>[],
    },
    {
      'id': 'hq-pc-01',
      'site': 'hq',
      'role': 'host',
      'model': 'PC',
      'interfaces': <Object?>[],
    },
  ],
  'links': [
    {
      'id': 'hq-br2',
      'kind': 'wan',
      'subnet': '10.255.0.8/30',
      'ospf_cost': 10,
      'state': 'down',
      'controllable': true,
      'a': {
        'device': 'hq-core-01',
        'interface': 'eth3',
        'address': '10.255.0.9',
      },
      'b': {
        'device': 'br2-edge-01',
        'interface': 'eth1',
        'address': '10.255.0.10',
      },
    },
    {
      'id': 'hq-servers',
      'kind': 'lan',
      'subnet': '10.10.20.0/24',
      'state': 'unknown',
      'controllable': false,
      'a': {'device': 'hq-core-01', 'interface': 'br20'},
      'b': {'device': 'hq-srv-01', 'interface': 'eth1'},
    },
  ],
}; // fmt: skip

const healthJson = {
  'device_id': 'hq-core-01',
  'reachable': true,
  'status': 'degraded',
  'uptime_seconds': 7322.6,
  'ospf_neighbors': [
    {
      'router_id': '10.255.255.1',
      'state': 'Full/-',
      'interface': 'eth1',
      'address': '10.255.0.1',
    },
  ],
  'expected_neighbors': ['10.255.255.1', '10.255.255.4'],
  'interfaces': <Object?>[],
  'checked_at': '2026-11-22T10:00:00Z',
};

Map<String, Object?> ruleJson({
  String id = 'fw-0000aaaa',
  String status = 'applied',
  bool enabled = true,
}) => {
  'id': id,
  'site': 'hq',
  'tier': 'servers',
  'protocol': 'tcp',
  'from_port': 8443,
  'to_port': 8443,
  'cidr': '10.20.10.0/24',
  'description': 'br1 users to app port',
  'enabled': enabled,
  'status': status,
  'job_id': 'job-12345678',
  'created_at': '2026-11-22T10:00:00Z',
  'created_by': 'operator',
};

const alertsJson = [
  {
    'id': 'link_down:hq-br2',
    'severity': 'critical',
    'kind': 'link_down',
    'target': 'hq-br2',
    'message': 'link hq-br2 (10.255.0.8/30) is down',
    'since': '2026-11-22T10:00:00Z',
  },
  {
    'id': 'ospf:hq-core-01:10.255.255.4',
    'severity': 'warning',
    'kind': 'ospf_neighbor_missing',
    'target': 'hq-core-01',
    'message': 'no adjacency',
    'since': '2026-11-22T10:00:00Z',
  },
]; // fmt: skip

Map<String, Object?> auditJson(String? cursor) => {
  'items': [
    {
      'id': 'evt-1',
      'at': '2026-11-22T10:00:00Z',
      'actor': 'operator',
      'role': 'operator',
      'action': 'link.down',
      'target': 'hq-br2',
      'before': {'state': 'up'},
      'after': {'state': 'down'},
      'request_id': 'abc',
      'result': 'succeeded',
    },
    {
      'id': 'evt-2',
      'at': '2026-11-22T09:00:00Z',
      'actor': 'operator',
      'role': 'operator',
      'action': 'firewall_rule.create',
      'target': 'fw-0000aaaa',
      'before': null,
      'after': 'not-a-map',
      'request_id': 'abd',
      'result': 'accepted',
    },
  ],
  'next_cursor': cursor == null ? 'page2' : null,
}; // fmt: skip
