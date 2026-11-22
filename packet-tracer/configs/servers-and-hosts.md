# Servers and test hosts (GUI settings)

Packet Tracer servers and PCs have no CLI config, so set these in each
device's *Desktop* and *Services* tabs.

## Servers

| Device | IP / mask | Gateway | DNS | Services |
| --- | --- | --- | --- | --- |
| hq-srv-01 | `10.10.20.10 /24` | `10.10.20.1` | `10.10.20.10` | **DNS** on, **HTTP** on, HTTPS on. Everything else off |
| hq-srv-02 | `10.10.20.11 /24` | `10.10.20.1` | `10.10.20.10` | HTTP off; **FTP** on (stands in for SMB in Packet Tracer) |
| isp-srv-01 | `198.51.100.10 /24` | `198.51.100.1` | `198.51.100.10` | **DNS** on, **HTTP** on |

**hq-srv-01 DNS records** (Services → DNS, type A):

| Name | Address |
| --- | --- |
| `hq-srv-01.cnops.internal` | `10.10.20.10` |
| `hq-srv-02.cnops.internal` | `10.10.20.11` |
| `intranet.cnops.internal` | `10.10.20.10` |
| `hq-core-01.cnops.internal` | `10.10.99.1` |
| `br1-edge-01.cnops.internal` | `10.20.99.1` |
| `br2-edge-01.cnops.internal` | `10.30.99.1` |

**isp-srv-01 DNS records:** `www.internet.test` → `198.51.100.10`.

Edit the HTTP `index.html` on each server so you can tell them apart, e.g.
"cnops intranet (hq-srv-01)" and "the internet (isp-srv-01)".

## Test hosts

All hosts are on **DHCP** (Desktop → IP Configuration → DHCP).

| Host | Switch port | VLAN | Expected address |
| --- | --- | --- | --- |
| hq-pc-01 | hq-access-01 Fa0/1 | 10 | `10.10.10.100`+ |
| hq-guest-01 | hq-access-01 Fa0/16 | 30 | `10.10.30.100`+ |
| br1-pc-01 | br1-access-01 Fa0/1 | 10 | `10.20.10.100`+ |
| br1-guest-01 | br1-access-01 Fa0/16 | 30 | `10.20.30.100`+ |
| br2-pc-01 | br2-access-01 Fa0/1 | 10 | `10.30.10.100`+ |
| br2-guest-01 | br2-access-01 Fa0/16 | 30 | `10.30.30.100`+ |

**MGMT test host** for acceptance test 11: `hq-admin-01` on hq-access-01 Fa0/21
(that port is already in VLAN 99 in `hq-access-01.ios`). Give the host a
static address: `10.10.99.10 /27`, gateway `10.10.99.1`, DNS `10.10.20.10`.
