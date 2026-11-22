# Packet Tracer

Cisco Packet Tracer files for the design blueprint.

The `.pkt` is built by hand from [`docs/network-design.md`](../docs/network-design.md),
which is the source of truth. If the two disagree, the doc wins and the
`.pkt` is fixed.

File: [`cloud-netops.pkt`](cloud-netops.pkt). Open it in Packet Tracer 8.2 or later.

## Fast path: paste the configs

[`configs/`](configs/) has a complete, paste-ready IOS config for every
router and switch, plus [`servers-and-hosts.md`](configs/servers-and-hosts.md)
for the GUI-only devices.

1. Place and cable the devices as in steps 1–2 below.
2. Open each device's **CLI** tab and paste its `.ios` file. Replace
   `CHANGE_ME` with a lab password first. These are placeholders, so no
   real secret is ever committed.
3. Set up the servers and hosts from `servers-and-hosts.md`.
4. Run the acceptance tests (design doc §10).

The step-by-step guide below explains what each block of those configs
does.

## Build order

Each step lists the doc section it comes from.

1. **Place devices** (§4.4). Use the suggested models.
   - The 3650 has no power supply by default. Open it, go to *Physical*,
     and drag an `AC-POWER-SUPPLY` into the slot.
   - Name each device with its hostname from the doc.
2. **Cable it** (§4.2, §4.4).
   - Copper straight-through between router and switch.
   - Router ↔ router and router ↔ L3 switch routed port: copper
     straight-through also works on Gi ports (auto-MDIX).
3. **Base config on every device:**
   - `hostname`, `ip domain-name cnops.internal`
   - `crypto key generate rsa modulus 2048`
   - a local user, `ip ssh version 2`
   - `line vty 0 15` with `transport input ssh` and `login local`
4. **VLANs and trunks** (§3).
   - Create VLANs 10/20/30/99/999 with names.
   - Assign the access ports.
   - Trunks: `switchport trunk native vlan 999` and
     `switchport trunk allowed vlan` with that site's VLANs only.
   - Shut unused ports and move them to VLAN 999.
5. **Gateways** (§4.1).
   - hq-core-01: `ip routing`, SVIs 10/20/30/99, and routed ports
     (`no switchport`) for the transit links.
   - Branches: router-on-a-stick subinterfaces `Gi0/0/2.10`, `.30` and
     `.99`, each with `encapsulation dot1Q <vlan>`.
6. **Transit links and loopbacks** (§4.2, §4.3).
7. **OSPF** (§5).
   - `router ospf 1`, `router-id`, `auto-cost reference-bandwidth 10000`.
   - `passive-interface default`, then `no passive-interface` on each
     transit link.
   - `network` statements per area, or `ip ospf 1 area X` on each
     interface.
   - `ip ospf network point-to-point` and `ip ospf cost` on the transit
     links.
   - ABRs: `area 1 range 10.20.0.0 255.255.0.0` (br1) and the same for
     area 2 on br2.
   - hq-edge-01: static default route to the ISP and
     `default-information originate`.
8. **DHCP** (§7): `ip dhcp excluded-address` and pools, with
   `default-router`, `dns-server` and `domain-name`.
9. **NAT** (§8) on hq-edge-01.
10. **ACLs** (§6). Named extended ACLs with `remark` lines. Apply each one
    in the direction the doc states.
11. **Servers**:
    - hq-srv-01: DNS records for `hq-srv-01.cnops.internal` etc., plus HTTP.
    - isp-srv-01: HTTP, and DNS for a test name.
12. **Run the acceptance tests** (§10). Save with *File → Save* and commit.

## Notes

- Built and tested in Packet Tracer 8.2.2: `cloud-netops.pkt` passes all
  11 acceptance tests in design doc §10.
- Packet Tracer rejects the `log` keyword on ACL entries, so these configs
  end each ACL with a plain `deny`. The design (§6) keeps `log`, which
  real IOS supports.
- The 3650 only does dot1q, so it rejects `switchport trunk encapsulation
  dot1q`. That one error is expected.
- The console asks for `admin` and the lab password after a reload
  (`login local`). The password is not in the repo.
- Packet Tracer's SMB support is limited. Line 50 of `TO-SERVERS` (port 445)
  is configured but checked for real in Containerlab (phase 2).
- Save often. Packet Tracer can crash on large simulations.
