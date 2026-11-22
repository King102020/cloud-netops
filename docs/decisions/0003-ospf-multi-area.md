# 0003: OSPF with one area per branch, hub-and-spoke WAN plus backup link

## Status

Proposed (2026-11-22). Becomes Accepted when the owner approves
`docs/network-design.md`.

## Context and Problem Statement

Three sites need dynamic routing that converges on its own when a link fails,
works in Packet Tracer, FRR (Containerlab) and on Cisco IOS, and maps
cleanly onto AWS Transit Gateway later.

## Considered Options

1. **OSPF multi-area.** Area 0 = HQ and all transit links; area 1 = br1
   LANs; area 2 = br2 LANs. Branch routers are ABRs and summarise their `/16`.
2. OSPF single area 0 everywhere.
3. Static routes only.
4. EIGRP (Cisco-only) or BGP.

## Decision Outcome

Option 1, with a hub-and-spoke WAN (hq-core-01 is the hub) and a br1 ↔ br2
backup link at cost 100.

- The WAN links land on the L3 core, not on the internet edge router. The
  core then plays the same role as the Transit Gateway in the cloud design.
- The edge router handles internet and NAT only. It injects the default
  route (`default-information originate`).

## Consequences

- Good: HQ sees one route per branch (`O IA 10.20.0.0/16`). This mirrors
  one TGW route per VPC and teaches ABR summarisation.
- Good: the backup link gives a visible, scriptable failover for the
  phase 4 "link down" feature.
- Good: OSPF is an open standard. The same design runs on Packet Tracer,
  FRR and real Cisco or Juniper gear.
- Bad: with only one router per branch area, multi-area adds configuration
  that a single area would not need at this size. We accept that because
  the summarisation is the point. A branch can be merged into area 0 later
  without readdressing.
- Rejected: static routes do not converge on their own, so the failover
  demo would be fake. EIGRP is Cisco-only (FRR's support is incomplete).
  BGP is overkill for three sites; it may come back for the AWS VPN, which
  uses BGP.
