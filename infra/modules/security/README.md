# Module: security

Security groups per tier (= ACLs `TO-SERVERS` and `MGMT-VTY`) and network
ACLs per subnet group. Mapping: §6 and §9.1.

- **Ingress:** baseline rules follow the on-prem ACLs line by line. Each
  rule's description starts with the ACL line number. Rules added by the
  control API come in through `firewall_rules`.
- **Egress:** anything internal; HTTP(S) to the internet only for users and
  servers. Mgmt is internal only.
- **NACLs:** allow `10.0.0.0/8` plus return traffic on ephemeral ports;
  everything else is denied.
- `firewall_rules` is validated: no `0.0.0.0/0` sources, sane ports, and
  only tcp/udp/icmp.

| Input | Type | Default |
| --- | --- | --- |
| `vpc_id` | string | — |
| `name_prefix` | string | — |
| `tiers` | set(string) | — |
| `users_cidrs`, `mgmt_cidrs` | list(string) | — |
| `subnet_ids_by_nacl` | map(list(string)) | `{}` |
| `firewall_rules` | list(object) | `[]` |
| `ephemeral_port_from` | number | `32768` |

Outputs: `security_group_ids`, `ingress_rule_ids`, `ingress_rules`, `network_acl_ids`.
