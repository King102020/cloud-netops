# Module: vpn

A site-to-site IPsec VPN from on-prem `hq-edge-01` (the customer gateway)
to the Transit Gateway. It uses static routing for the on-prem `/16`s, the
tunnel inside addresses from `169.254.10.0/24`, and IKEv2 with AES-256-GCM,
SHA-384 and DH group 20 only.

| Input | Type | Default |
| --- | --- | --- |
| `name_prefix` | string | — |
| `transit_gateway_id` | string | — |
| `transit_gateway_route_table_id` | string | — |
| `customer_gateway_ip` | string | — |
| `customer_bgp_asn` | number | `65010` |
| `tunnel_inside_cidrs` | list(string) | `169.254.10.0/30`, `169.254.10.4/30` |
| `onprem_cidrs` | list(string) | the three site /16s |

Outputs: `vpn_connection_id`, `customer_gateway_id`,
`transit_gateway_attachment_id`.

LocalStack creates the API objects but does not bring tunnels up. See
`docs/local-gaps.md`.
