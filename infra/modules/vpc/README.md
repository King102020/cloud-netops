# Module: vpc

One VPC per site. In the design's terms, site = VPC (§9).

The module creates:
- the VPC with DNS support;
- a locked-down default security group, with all rules removed;
- a DHCP options set (`cnops.internal`);
- an optional internet gateway (hq only);
- VPC flow logs to CloudWatch, through a least-privilege IAM role.

| Input | Type | Default | Notes |
| --- | --- | --- | --- |
| `name` | string | — | `cnops-<env>-<site>-vpc` |
| `cidr_block` | string | — | Must be inside `10.0.0.0/8` |
| `domain_name` | string | `cnops.internal` | |
| `enable_internet_gateway` | bool | `false` | |
| `enable_flow_logs` | bool | `true` | |
| `flow_log_retention_days` | number | `14` | |

Outputs: `vpc_id`, `cidr_block`, `internet_gateway_id`.
