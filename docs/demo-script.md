# Demo script (≈ 5 minutes)

A screen recording for the portfolio. Everything runs locally. Rehearse
once with [`runbooks/start-the-lab.md`](runbooks/start-the-lab.md).

## Before recording

```sh
./lab/clab.sh deploy                                           # ~30 s
cd api && CNOPS_TERRAFORM_MODE=plan .venv/bin/uvicorn --factory cnops_api.main:create_app --port 8000
cd app && flutter run -d chrome --web-port 8080 --dart-define-from-file=config/local.json
```

Window layout: app on the left; on the right, a terminal with
`docker exec -it clab-cnops-br2-pc-01 sh`.

## Script

| Time | Show | Say |
| --- | --- | --- |
| 0:00 | README architecture diagram | "A three-site company network: designed in Packet Tracer, rebuilt as code for AWS, and run from one Flutter app." |
| 0:20 | `docs/network-design.md` IP plan table | "One /16 per site, third octet = VLAN. `10.30.30.157` is a guest at branch 2. The cloud VPCs are the same plan plus 100." |
| 0:45 | Packet Tracer `.pkt`, then `lab/` | "The same design runs as real FRR routers in Containerlab. 58 automated checks prove OSPF, ACLs, NAT and failover." |
| 1:15 | App: sign in as `operator` | "The app talks to a FastAPI control API with role-based JWTs." |
| 1:30 | Topology map | "Live map: the green rings are healthy routers. The dashed line is the backup link between the branches." |
| 1:50 | Terminal: `traceroute -n 10.10.20.10` | "Branch 2 reaches HQ through the hub." |
| 2:05 | App: switch **hq-br2** off | "I take the WAN link down. The API shuts the interfaces on the real routers." |
| 2:15 | Alert appears, hq-core-01 turns amber | "Within seconds an alert arrives: the link is down and OSPF lost an adjacency." |
| 2:30 | Terminal: `traceroute -n 10.10.20.10` again | "Traffic now flows over the backup link (10.255.0.13). OSPF rerouted on its own." |
| 2:45 | App: switch hq-br2 back on | "Back on; the alert clears." |
| 3:00 | App: Firewall → Add rule, `0.0.0.0/0` | "Default deny: the app, the API and Terraform all refuse a world-open rule." |
| 3:20 | Add `10.30.10.0/24` → 8443 | "A valid rule. The API never calls AWS directly: it writes Terraform inputs and runs a plan. The status goes from Applying to Planned." |
| 3:45 | App: Audit log, expand an entry | "Every change is audited: who, what, when, before and after." |
| 4:05 | `infra/` and `terraform test` output | "194 Terraform resources across two AZs, with a Transit Gateway as the hub, tested offline. checkov reports 0 failures, and every skip is justified in an ADR." |
| 4:30 | GitHub Actions run | "Every layer has a CI gate: lab, infra, API and app." |
| 4:45 | Desktop and phone layouts | "One Flutter codebase covers Android, iOS and the web." |

## After recording

```sh
./lab/clab.sh destroy
```
