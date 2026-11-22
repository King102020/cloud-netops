# Module: dns

A Route 53 private hosted zone (`cnops.internal`), associated with every
VPC, plus optional A records. It replaces hq-srv-01's DNS role (§9.1).

| Input | Type | Default |
| --- | --- | --- |
| `zone_name` | string | `cnops.internal` |
| `vpc_ids` | map(string) | — |
| `a_records` | map(string) | `{}` |

Outputs: `zone_id`, `zone_name`.
