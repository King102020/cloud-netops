# Module: subnets

Subnets: VLAN → one subnet per AZ (§9). The module also creates one route
table per tier, the public default route, and an optional single NAT gateway
for the tiers you list.

| Input | Type | Default | Notes |
| --- | --- | --- | --- |
| `vpc_id` | string | — | |
| `name_prefix` | string | — | `cnops-<env>-<site>` |
| `subnets` | map(object) | — | key `<tier>-<az>`; tier ∈ public, users, servers, mgmt, tgw |
| `internet_gateway_id` | string | `null` | target for the public default route |
| `create_public_default_route` | bool | `false` | adds `0.0.0.0/0 → IGW` to the public tier |
| `nat_gateway_subnet_key` | string | `null` | e.g. `public-a` |
| `nat_route_tiers` | list(string) | `[]` | e.g. `["users", "servers", "mgmt", "tgw"]` |

Outputs: `subnet_ids`, `subnet_ids_by_tier`, `route_table_ids`,
`nat_gateway_id`.

Routes towards the Transit Gateway are added by the `tgw` module. It needs
these route tables, and they need the TGW, so it cannot happen here without
a dependency cycle.
