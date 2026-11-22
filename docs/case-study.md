# Case study: Cloud NetOps

**Role:** sole engineer. **Stack:** Cisco Packet Tracer, Containerlab + FRR,
Terraform (AWS provider, LocalStack), Python/FastAPI, Flutter, GitHub
Actions.

## The problem

I build mobile apps (Flutter, Kotlin, Firebase) and I am moving into cloud
and network engineering. I wanted one project that shows the whole path:
from a classic enterprise network design, to the same network as code in
AWS, to an app that operates it. And it had to be tested, not just drawn.

## What I built

1. **A network design.** HQ plus two branches with VLANs, a non-overlapping
   RFC 1918 plan, multi-area OSPF with a backup link, default-deny ACLs,
   DHCP and NAT. It is written down first (`docs/network-design.md`), then
   configured in Packet Tracer.
2. **The same network as running routers.** Containerlab with FRR, and ACLs
   as iptables. 58 automated tests cover adjacencies, summaries, the ping
   matrix, NAT and guest isolation, including a link failure and recovery.
3. **The cloud version as code.** Terraform modules for VPCs, subnets in two
   AZs, a Transit Gateway hub, security groups and NACLs, a site-to-site
   VPN, Route 53 and DynamoDB: 194 resources. Each on-prem concept maps to an
   AWS one (site → VPC, VLAN → subnet, core router → TGW, ACL → SG, OSPF
   summary → TGW propagation).
4. **A control API.** FastAPI with JWT roles, RFC 9457 errors, idempotency
   keys and an audit log. Network changes only ever go through Terraform.
   Router operations go to the lab.
5. **An app.** Flutter for Android, iOS and Web: a live topology map,
   device health, link and rule toggles, the audit log and alerts.

## Decisions worth explaining

| Decision | Why | Trade-off |
| --- | --- | --- |
| Local-only until approved ([ADR 0001](decisions/0001-local-only-until-aws-approval.md)) | Zero cost, no credential risk, fast resets | No real latency numbers yet; LocalStack gaps are documented and tested other ways |
| `/16` per site, third octet = VLAN ([ADR 0002](decisions/0002-ip-addressing-scheme.md)) | Every address is readable; one summary per site | Generous with address space |
| Multi-area OSPF with a backup link ([ADR 0003](decisions/0003-ospf-multi-area.md)) | ABR summaries mirror one route per VPC; failover is visible and testable | More config than a single area at this size |
| WAN hub on the L3 core, not the edge router | The core plays exactly the TGW's role | The edge router is internet/NAT only |
| One NAT gateway, AWS-owned keys, 14-day logs ([ADR 0004](decisions/0004-cost-over-redundancy-in-the-lab.md)) | Cost for a demo lab | Lower AZ resilience; revisit for production |
| API → Terraform, never the SDK | One source of truth, reviewable plans, drift-free | Changes are asynchronous (202 + job) |
| `envs/local` provider hard-pinned to LocalStack | Even a plain `terraform apply` cannot touch AWS; a test proves it | Slight duplication with `lstk terraform` |

## Quality

| Layer | Gate | Result |
| --- | --- | --- |
| Lab | `containerlab deploy` + pytest | 58 passed, including failover |
| Terraform | fmt, validate, `terraform test` (mocked), tflint, checkov | 8/8 tests; 178 checkov passed, 0 failed |
| API | ruff, `mypy --strict`, pytest, OpenAPI drift, pip-audit | 73 tests, ~97% coverage, no known vulnerabilities |
| App | analyze, format, unit/cubit/widget/golden, live contract | 60 tests, ~94% coverage; web + APK build |
| Repo | pre-commit, gitleaks | clean |

## What I learned

- **Packet Tracer quirks:** the 3650 needs a power supply, and `/31` links
  are a bad idea there.
- **Docker networking:** Docker's default route inside FRR containers
  overrides the OSPF default route. You must remove it.
- **Terraform:** `count` cannot depend on IDs that only exist after apply.
- **Tooling compatibility:** code generators and test libraries pin analyzer
  versions. Picking compatible versions on purpose is part of the work.
- **Mapping on-prem to cloud:** writing the mapping table first made every
  Terraform module obvious.

## Next

- Phase 7: deploy to AWS behind a budget alarm, and destroy after each demo.
- Push notifications through FCM.
- A subnets screen in the app.
- BGP over the VPN.
