# Cloud NetOps — project brief

## Who I am
Parag Jain — app developer (Flutter, Kotlin, Firebase; 2+ yrs, live app with 10K+ users; Microsoft Azure experience) moving into **cloud / DevOps / cloud networking** roles. This project is the flagship piece of my new portfolio, so it must be real, well documented and demo-able.

## The project in one line
Design a multi-site network in Cisco Packet Tracer, build the same network on AWS with Terraform, and manage it from a simple Flutter app through a serverless control API.

## Rules
- **Follow `docs/STANDARDS.md` for every change.** Read it before starting any phase.
- **Local only for now.** Everything runs on this machine: LocalStack (`lstk`), Containerlab, FastAPI on localhost, Flutter `local` flavor. No real AWS calls, accounts, credentials or paid services until I explicitly say "deploy to AWS".
- **Never** run plain `terraform apply`/`aws` against real AWS, or create anything that costs money.
- **Apps are Flutter only**, one codebase covering **Android, iOS and Web**; test every feature on all three. iOS builds/simulator need macOS: develop and test Android + Web on Windows, run iOS checks on my MacBook (keep the code iOS-ready: no Windows-only paths or plugins).
- Infrastructure is code only (Terraform). No manual console changes.
- No secrets in the repo. Use `.env` (git-ignored) and `.env.example`.
- Small, reviewable commits with clear messages. Explain what you did and why after each step — I am learning cloud networking through this.
- Windows 11 host + WSL2 **Ubuntu-22.04**. Run Linux tooling (containerlab, lstk, terraform for local) inside WSL.

## My setup (verified)
Windows: Git, GitHub CLI, Docker Desktop 29.9, Terraform 1.17, AWS CLI v2, Python 3.11, Node 24, Flutter 3.35, Claude Code.
WSL Ubuntu-22.04: Docker, Containerlab 0.83, Terraform 1.17, lstk 1.5 (LocalStack — use `lstk terraform` / `lstk aws`; legacy `tflocal`/`awslocal` also installed), AWS CLI v1.
Cisco Packet Tracer on Windows.

## Architecture
```
Flutter app ──HTTPS──> Control API ──> Terraform (via CI) ──> AWS network
                         │                                   (VPCs, subnets, TGW, SGs, VPN)
                         └──> Router mgmt (SSH/NETCONF) ──> Containerlab routers (FRR/VyOS, OSPF)
Alerts: health checks -> Firebase Cloud Messaging -> app
```

| Layer | Local | Cloud (later) |
|---|---|---|
| Design blueprint | Packet Tracer `.pkt` + diagram | same |
| Routers / OSPF | Containerlab + FRR in WSL | Containerlab on one small EC2 |
| VPCs, subnets, routing, security | LocalStack via `lstk terraform` | AWS via `terraform` |
| Control API | Python FastAPI on localhost | Lambda + API Gateway (+ Cognito auth) |
| State / audit log | DynamoDB on LocalStack | DynamoDB |
| App | Flutter → localhost API | Flutter → AWS API |

Packet Tracer → cloud mapping: site = VPC, VLAN = subnet, core router = Transit Gateway, ACL = security group / NACL, branch link = site-to-site VPN, DNS = Route 53 private zone.

## Phases (do in order, finish + test each before moving on)
1. **Network design** — HQ + 2 branches: VLANs, IP plan (document subnets), OSPF, ACLs, DHCP, NAT. Write `docs/network-design.md` with the IP plan table and diagram; I build the `.pkt` in Packet Tracer from it.
2. **Routers in Containerlab** — topology file reproducing the design with FRR; OSPF converges; ping tests scripted.
3. **Cloud network in Terraform (LocalStack)** — modules for vpc, subnets, tgw, security, vpn; `lstk terraform plan/apply` works locally. Note any AWS feature LocalStack's plan does not support and how we test it instead.
4. **Control API (FastAPI)** — endpoints: topology, device health, list/add/remove firewall rule, create subnet, link up/down, audit log. Changes go through Terraform, never ad-hoc. Tests with pytest.
5. **Flutter app (Android, iOS, Web)** — live topology map, device detail, rule toggles, audit log, push alerts. Clean, simple UI is the whole point.
6. **CI/CD** — GitHub Actions: fmt/validate/plan on PR, tests, app build.
7. **Deploy to AWS** (NOT NOW — only when I explicitly approve) — budget alarm first; `terraform destroy` after demos.
8. **Showcase** — README with architecture diagram, demo video script, and a portfolio case study.

## Repo layout
```
CLAUDE.md        this brief (repo root so Claude Code auto-loads it)
tool/            check.ps1 / check.sh — local quality gate (run before every push)
docs/            STANDARDS.md, network-design.md, local-gaps.md, decisions/, diagrams/, runbooks/
packet-tracer/   *.pkt
lab/             containerlab topology + FRR configs + tests
infra/           terraform modules + envs/local, envs/aws
api/             FastAPI app + tests
app/             Flutter app
.github/workflows/
```

## Start here
First: read docs/STANDARDS.md, set up the repo skeleton (git init, .gitignore, .editorconfig, .env.example, pre-commit, README, CHANGELOG, folder layout) and push to a new private GitHub repo `cloud-netops` with `gh`. Then begin phase 1. Ask me which cloud region and site names I want, then propose the IP plan.
