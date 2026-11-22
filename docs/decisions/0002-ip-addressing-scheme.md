# 0002: IP addressing scheme

## Status

Proposed (2026-11-22). Becomes Accepted when the owner approves
`docs/network-design.md`.

## Context and Problem Statement

We need one address plan for three on-prem sites, three matching VPCs,
transit links and loopbacks. It must:

- never overlap, because on-prem and cloud are joined by VPN and Transit
  Gateway, and overlapping CIDRs cannot be routed;
- summarise cleanly per site, for OSPF areas and TGW route tables;
- be readable by a human at a glance;
- leave room for more sites.

## Considered Options

1. **One `/16` per site, third octet = VLAN ID, cloud = on-prem + 100.**
2. Pack sites tightly (e.g. `/20` per site from `10.0.0.0/16`).
3. Use `172.16.0.0/12` for on-prem and `10.0.0.0/8` for cloud.

## Decision Outcome

Option 1.

- hq `10.10/16`, br1 `10.20/16`, br2 `10.30/16`.
- VPCs `10.110/16`, `10.120/16`, `10.130/16`.
- Links `10.255.0.0/24` (`/30`s) and loopbacks `10.255.255.0/24`.

Full rules are in `docs/network-design.md` §2.

## Consequences

- Good: any address tells you the site and the VLAN (`10.20.30.x` = br1
  guest). Fast troubleshooting, easy to teach.
- Good: each site is a single `/16` summary. This works for the OSPF ABR
  range and for one TGW route per VPC.
- Good: 60 more on-prem sites (`10.40`–`10.99`) and 60 more VPCs fit
  without renumbering.
- Bad: uses address space generously (a `/16` per small branch). That is
  fine inside a private `10/8`, but would not suit a company that must
  share `10/8` with partners.
- Option 3 was rejected because `172.16/12` overlaps Docker (`172.17/16`)
  and the WSL2 NAT ranges on the dev machine.
