# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Repository skeleton: standards, licence, contribution guide, security
  policy, pre-commit hooks, local quality-gate scripts and folder layout.
- ADR 0001: local-only development until AWS deployment is approved.
- Network design (phase 1, draft): `docs/network-design.md` with IP plan,
  VLANs, OSPF, ACLs, DHCP, NAT, cloud mapping and acceptance tests;
  Mermaid topology diagram; Packet Tracer build guide.
- ADR 0002 (IP addressing scheme) and ADR 0003 (OSPF multi-area,
  hub-and-spoke with backup link), both proposed.
- Paste-ready IOS configs for every Packet Tracer device.
- Containerlab lab (phase 2): 5 FRR routers and 9 hosts reproducing the
  design, with OSPF, iptables ACLs and NAT. `lab/clab.sh` works with native
  Docker or Docker Desktop. 58 pytest acceptance checks, including
  link-failover.
- Runbooks: start the lab, reset everything, common failures.
- Terraform (phase 3): modules `vpc`, `subnets`, `tgw`, `security`, `vpn`,
  `dns`, `audit_store`, and the `envs/local` LocalStack composition
  (194 resources, `ap-south-1`, two AZs). The provider is hard-pinned to a
  validated local endpoint.
- 8 offline `terraform test` checks with a mocked provider. tflint is clean;
  checkov reports 178 passed and 0 failed.
- ADR 0004 (cost over redundancy in the lab) and `docs/local-gaps.md`
  entries for LocalStack.
- Control API (phase 4), built with FastAPI. Endpoints: topology, devices,
  health, links up/down, alerts, firewall rules, subnets, Terraform jobs
  and the audit log.
  - Infrastructure changes go through Terraform only (202 + job).
  - JWT roles, RFC 9457 errors, idempotency keys and JSON logs with
    request IDs.
  - Committed `api/openapi.json`, with a drift test.
  - 73 tests at ~97% coverage, including integration against the real
    lab. `mypy --strict` and ruff are clean, and pip-audit is clean.
