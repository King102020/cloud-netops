# Infrastructure (Terraform)

Phase 3. The cloud copy of the network design (§9) for `ap-south-1`. It
runs against **LocalStack only** for now.

## Layout

| Path | What |
| --- | --- |
| `modules/vpc` | VPC, locked default SG, DHCP options, IGW (hq), flow logs |
| `modules/subnets` | Subnets per tier and AZ, route tables, single NAT gateway |
| `modules/tgw` | Transit Gateway (= hq-core-01), explicit route table, attachments, VPC routes |
| `modules/security` | Security groups (= ACLs) and NACLs, plus API-managed rules |
| `modules/vpn` | Site-to-site VPN from on-prem hq-edge-01 to the TGW |
| `modules/dns` | Route 53 private zone `cnops.internal` |
| `modules/audit_store` | DynamoDB audit log and idempotency tables for the API |
| `envs/local` | LocalStack composition: 194 resources |
| `envs/aws` | Placeholder. **Not used until the AWS phase is approved** |

## Run (local)

```sh
cd infra/envs/local
terraform init
terraform test                  # offline, mocked provider: 8 design checks
terraform plan                  # works offline too (no data sources)

lstk start                      # LocalStack (needs `lstk login` once)
lstk terraform apply            # or plain `terraform apply`: safe here, see below
```

**Why plain `terraform` is safe in `envs/local`:** the provider pins every
endpoint to `var.localstack_endpoint`. That variable is validated to be a
local address, and the credentials are LocalStack's dummy `test` / `test`.
A test (`rejects_non_local_endpoint`) proves that the guard holds.

## Runtime inputs from the control API

The API never calls the AWS SDK to change the network. It writes JSON to
`envs/local/.cnops/` (git-ignored), then runs `terraform apply`
(STANDARDS §5):

- `firewall_rules.json`:
  `[{id, site, tier, protocol, from_port, to_port, cidr, description, enabled}]`
- `subnets.json`: `[{site, name, cidr_block, az, tier}]`

Both are validated twice: by the API (Pydantic), and again by Terraform
`validation` blocks, which reject `0.0.0.0/0`, bad ports and unknown tiers.

## Quality gates

```sh
terraform fmt -check -recursive
terraform validate
terraform test
docker run --rm -v "$PWD:/data" -w /data ghcr.io/terraform-linters/tflint:v0.60.0 --recursive   # after --init
docker run --rm -v "$PWD:/data" bridgecrew/checkov:3.4.6 -d /data --framework terraform
# or simply: ./infra/check.sh   (runs all of the above)
```

Current results: tflint clean; checkov 178 passed, 0 failed, 18 skipped.
Every skip has an inline reason and links to
[ADR 0004](../docs/decisions/0004-cost-over-redundancy-in-the-lab.md).

What LocalStack cannot emulate, and how it is tested instead:
[`docs/local-gaps.md`](../docs/local-gaps.md).

Naming: `cnops-<env>-<site>-<resource>`. Tags on everything: `Project`,
`Environment`, `Owner`, `ManagedBy=terraform`.
