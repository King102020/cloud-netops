# Module: tgw

The Transit Gateway: hq-core-01 → TGW (§9.1). Hub and spoke, the same
shape as the OSPF design.

| Concept | OSPF (on-prem) | This module |
| --- | --- | --- |
| Hub | hq-core-01 | one TGW + one explicit route table |
| Spoke link | WAN /30 | VPC attachment in dedicated `tgw-a/b` /28 subnets |
| ABR summary | `area 1 range 10.20.0.0/16` | route **propagation** of the VPC /16 |
| Default route | `default-information originate` | static `0.0.0.0/0 → hq` attachment |

Default association and propagation are disabled on purpose, so every route
is declared here.

| Input | Type | Default |
| --- | --- | --- |
| `name_prefix` | string | — |
| `amazon_side_asn` | number | `64512` |
| `vpc_attachments` | map(object) | — |
| `default_route_attachment` | string | `null` |

Outputs: `transit_gateway_id`, `route_table_id`, `attachment_ids`, `vpc_routes`.
