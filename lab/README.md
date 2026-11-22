# Lab (Containerlab + FRR)

Phase 2. The [network design](../docs/network-design.md), running for real.
It has 5 FRR routers and 9 Linux hosts, with OSPF, ACLs (iptables) and NAT.

## Run

```sh
./lab/clab.sh deploy           # ~30 s; builds cnops/frr:10.2.1 the first time
python -m venv lab/.venv
lab/.venv/bin/pip install -r lab/requirements.txt      # Windows: lab\.venv\Scripts\pip
lab/.venv/bin/python -m pytest lab/tests               # ~2 min, 58 checks
./lab/clab.sh destroy
```

`clab.sh` runs native containerlab when the Docker Engine socket is local.
With Docker Desktop (Windows, macOS, or WSL with Desktop integration) it
runs containerlab in a container instead (`ghcr.io/srl-labs/clab:0.83.0`,
with `--pid host`). That is the containerlab-documented way to use Docker
Desktop, so the same command works on every machine.

Poke around:

```sh
docker exec -it clab-cnops-hq-core-01 vtysh       # show ip ospf neighbor, show ip route
docker exec -it clab-cnops-br1-pc-01 sh           # traceroute -n 10.30.10.100
docker exec clab-cnops-hq-core-01 iptables -L -v -n   # ACL hit counters
```

## What is in it

| Node | Image | Role |
| --- | --- | --- |
| hq-edge-01, hq-core-01, br1-edge-01, br2-edge-01 | `cnops/frr:10.2.1` ([`images/frr`](images/frr/Dockerfile): FRR + iptables) | Company routers |
| isp-edge-01 | `cnops/frr:10.2.1` | Simulated ISP, no OSPF |
| hq-pc-01, hq-admin-01, hq-guest-01, br1/br2-pc-01, br1/br2-guest-01 | `network-multitool` (pinned by digest) | Test hosts |
| hq-srv-01 | `network-multitool` | Intranet web (nginx 80/443) |
| hq-srv-02 | `network-multitool` | File server stand-in (TCP 445) |
| isp-srv-01 | `network-multitool` | "The internet": web on 80, "what is my IP" on 8080 |

Per router: `configs/<router>/frr.conf` (routing, the same design as the
`.ios` files) and `configs/<router>/init.sh`. The `init.sh` scripts set up
the VLAN 20 bridge, the dummy MGMT interfaces, the ACLs and NAT.

## Interface map

| Device | Lab interface | Packet Tracer port | Address |
| --- | --- | --- | --- |
| hq-edge-01 | eth1 | Gi0/0/0 → ISP | `203.0.113.2/30` |
| | eth2 | Gi0/0/1 → hq-core-01 | `10.255.0.1/30` |
| hq-core-01 | eth1 | Gi1/0/24 → hq-edge-01 | `10.255.0.2/30` |
| | eth2 | Gi1/0/23 → br1 | `10.255.0.5/30` |
| | eth3 | Gi1/0/22 → br2 | `10.255.0.9/30` |
| | eth4 | SVI VLAN 10 | `10.10.10.1/24` |
| | br20 (eth5 + eth8) | SVI VLAN 20 | `10.10.20.1/24` |
| | eth6 | SVI VLAN 30 | `10.10.30.1/24` |
| | eth7 | SVI VLAN 99 | `10.10.99.1/27` |
| br1-edge-01 | eth1 | Gi0/0/0 → hq-core-01 | `10.255.0.6/30` |
| | eth2 | Gi0/0/1 → br2 (backup) | `10.255.0.13/30` |
| | eth3 / eth4 / mgmt99 | Gi0/0/2.10 / .30 / .99 | `10.20.10.1/24` / `10.20.30.1/24` / `10.20.99.1/27` |
| br2-edge-01 | eth1 | Gi0/0/0 → hq-core-01 | `10.255.0.10/30` |
| | eth2 | Gi0/0/1 → br1 (backup) | `10.255.0.14/30` |
| | eth3 / eth4 / mgmt99 | Gi0/0/2.10 / .30 / .99 | `10.30.10.1/24` / `10.30.30.1/24` / `10.30.99.1/27` |

Management (out of band): `172.20.20.0/24`. Routers are `.11`–`.15` and
hosts `.101`–`.131`.

## Tests

`lab/tests` runs the design's acceptance tests (§10):

- OSPF adjacencies, router IDs, ABR summaries, default route from the ASBR
  and the backup-link cost.
- Full ping matrix between staff hosts. Intranet and file access from every
  site. Internet via HQ NAT; the ISP only ever sees `203.0.113.2`.
- Guest isolation, anti-spoofing and the default-deny server ACL.
- **Failover:** take HQ↔br2 down, check that br2 reroutes over the backup
  link, then restore it and reconverge.

## What the lab does not model

| Design item | In the lab | Why / how it is covered |
| --- | --- | --- |
| Access switches, trunks, native VLAN | Not modelled. Each VLAN is a router interface | L2 is covered in Packet Tracer; the API and cloud work at L3 |
| DHCP pools | Hosts use static addresses from the DHCP range | Packet Tracer tests DHCP (acceptance test 3) |
| `MGMT-VTY` / SSH to routers | Management is `docker exec` over the OOB network | The control API uses the same path (phase 4) |
| ACL `log` keyword | Hit counters (`iptables -L -v`) instead of syslog | Tests assert on the counters |
| DNS on hq-srv-01 | Not running | Name resolution is tested in Packet Tracer and Route 53 (phase 3) |
