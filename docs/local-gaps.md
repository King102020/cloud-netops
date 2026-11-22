# Local gaps

AWS features that LocalStack (or the local setup) cannot emulate, and how
each is mocked or tested instead.

| Feature | Gap | How we mock / test it | Phase |
| --- | --- | --- | --- |
| Site-to-site VPN tunnels | LocalStack stores the customer gateway and VPN connection, but no IPsec tunnel comes up and no traffic flows | `terraform test` asserts the config (IKEv2, AES-256-GCM, 169.254.10.0/30s, on-prem routes). The on-prem side is real in Containerlab. Tunnel bring-up is checked in the AWS phase | 3 |
| Transit Gateway data plane | Route tables, attachments, propagation and routes are stored, but packets are not forwarded between VPCs | Routing intent is tested offline (`tgw_routes` test). The same hub-and-spoke routing is tested with real packets in the Containerlab lab (OSPF) | 3 |
| NAT gateway / internet gateway | Objects exist; no real internet egress | PAT is tested for real in the lab (the ISP only sees `203.0.113.2`) | 3 |
| Security groups / NACLs enforcement | Rules are stored, not enforced (no EC2 traffic in this project) | Rule content is tested offline (`baseline_rules_never_open_to_world`, managed rules). Enforcement of the same ACLs is tested in the lab with iptables | 3 |
| VPC flow logs | Log groups and the flow log resource exist; no records are delivered | — (AWS phase) | 3 |
| Route 53 private zone resolution from VPCs | Zone and records exist; no VPC resolver | `dig` against LocalStack DNS can resolve records; full test in the AWS phase | 3 |
| Lab: L2 switching, DHCP, SSH to routers | Not modelled in Containerlab | Covered in Packet Tracer; see `lab/README.md` | 2 |
| Push notifications (FCM) | Needs a Firebase project and real devices | `local` flavor uses an in-app notifier fed by API health polling | 5 |
