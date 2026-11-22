# Lab (Containerlab + FRR)

Phase 2. Reproduces the Packet Tracer design with FRR routers in
Containerlab (inside WSL2).

- `*.clab.yml` — topology
- `configs/` — FRR configs per router
- `tests/` — scripted ping and OSPF neighbour checks

A clean `containerlab deploy` must pass `lab/tests` (STANDARDS §3).
