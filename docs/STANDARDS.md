# Engineering Standards — Cloud NetOps

Every change in this repo follows these standards. If a standard can't be met, stop and write an ADR (`docs/decisions/`) explaining why before continuing.

---

## 0. Local-only mode (current phase)

This project runs **100% locally** until the owner explicitly says "deploy to AWS".

- AWS calls go to **LocalStack only** (`http://localhost:4566`) via `lstk terraform` / `lstk aws`. Never plain `terraform apply` or `aws` against real AWS.
- Use dummy credentials only: `AWS_ACCESS_KEY_ID=test`, `AWS_SECRET_ACCESS_KEY=test`, `AWS_DEFAULT_REGION=ap-south-1`.
- No real AWS profiles, account IDs, API keys or paid services in code, config or commits.
- Routers run in Containerlab (WSL2). The API runs on `localhost:8000`. The app talks to the local API through a `local` flavor.
- If a feature cannot be emulated locally (e.g. a LocalStack gap), document it in `docs/local-gaps.md` with how it is mocked/tested instead.

---

## 1. Repository & Git

- **Branching:** trunk-based. `main` is always green. Work on short-lived branches: `feat/…`, `fix/…`, `chore/…`, `docs/…`, `infra/…`.
- **Default branch:** `main` (not `master`). Workflow triggers must name `main`.
- **Commits:** [Conventional Commits](https://www.conventionalcommits.org) — `feat(api): add firewall rule endpoint`. **Scope is required** (`lab`, `infra`, `api`, `app`, `ci`, `docs`, `standards`, `repo`). One logical change per commit.
- **Pull requests:** small (< 400 lines where possible), template with *What / Why / How tested / Screenshots*. CI must pass.
- **Versioning:** [Semantic Versioning](https://semver.org); `CHANGELOG.md` in [Keep a Changelog](https://keepachangelog.com) format.
- **Pre-commit hooks** (`.pre-commit-config.yaml`): trailing whitespace, end-of-file, YAML/JSON checks, `gitleaks`, `terraform fmt`, `ruff`, `dart format`.
- Root files: `README.md`, `LICENSE`, `CHANGELOG.md`, `CONTRIBUTING.md`, `SECURITY.md`, `.editorconfig`, `.gitattributes`, `.gitignore`, `.env.example`.
- **Line endings:** LF everywhere (`.gitattributes` `* text=auto eol=lf`), so Windows, WSL and macOS produce identical diffs. `*.ps1` and `*.bat` keep CRLF.
- **No machine-specific paths** in code or docs (no `C:\Users\…`, `D:\flutter`). Everything is relative to the repo root so it runs from a clean clone.
- Local-only config files follow the `*.example` pattern: commit `foo.example`, git-ignore `foo`.

## 2. Security (applies everywhere)

- **No secrets in git.** `.env` is git-ignored; `.env.example` lists every variable with fake values. `gitleaks` runs in pre-commit and CI.
- **Least privilege** for every IAM role/policy — no `*` actions or resources unless justified in an ADR.
- **Default deny** for network rules; open only what is needed, documented with a reason.
- Follow **OWASP API Security Top 10** (API) and **OWASP MASVS** (mobile app).
- Validate all input at the boundary (Pydantic on the API, form validation in the app).
- Dependency scanning: Dependabot, `pip-audit`, `flutter pub outdated`; IaC scanning: `checkov` or `tfsec`.
- Every state-changing action is written to an **audit log** (who, what, when, before/after).

## 3. Network design

- Private addressing per **RFC 1918**; **non-overlapping CIDRs** across all sites and future VPCs.
- The IP plan is the source of truth: `docs/network-design.md` (sites, VLANs, subnets, gateways, DHCP ranges, reserved ranges).
- Consistent naming: `<site>-<role>-<n>` (e.g. `hq-core-01`, `br1-access-01`), VLAN IDs documented with purpose.
- Routing: OSPF with documented areas, router IDs and passive interfaces. ACLs explicit and commented.
- Every design decision mirrors to the cloud mapping table (site→VPC, VLAN→subnet, core→Transit Gateway, ACL→SG/NACL).
- Lab topologies are reproducible: `containerlab deploy` from a clean state must pass the scripted connectivity tests in `lab/tests/`.

## 4. Infrastructure as Code (Terraform)

- Follow HashiCorp's **standard module structure**: `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`, `README.md` per module.
- Layout: `infra/modules/<name>` reusable; `infra/envs/local` (LocalStack) and `infra/envs/aws` (later) as thin compositions.
- Pin Terraform and provider versions in `versions.tf`; commit `.terraform.lock.hcl`.
- Every variable has `type` + `description`; validate inputs with `validation` blocks.
- Naming: `cnops-<env>-<resource>`; **tags on everything**: `Project`, `Environment`, `Owner`, `ManagedBy=terraform`.
- CI gate: `terraform fmt -check`, `terraform validate`, `tflint`, `checkov`, `plan` on every PR.
- Design against the **AWS Well-Architected Framework** pillars (security, reliability, cost, operational excellence, performance, sustainability) and note trade-offs in ADRs.
- State: local backend for LocalStack; remote S3 + locking only when moving to AWS.

## 5. Control API (Python / FastAPI)

- Python 3.11+, FastAPI, Pydantic v2. Typed everywhere; `mypy --strict` clean.
- Lint/format: `ruff` (lint + format). Tests: `pytest` + `pytest-cov`, **≥ 80% coverage**, plus contract tests from the OpenAPI spec.
- **REST conventions:** plural nouns, versioned paths (`/v1/...`), correct status codes, pagination (`limit`/`cursor`), filtering via query params.
- Errors as **RFC 9457 Problem Details** (`application/problem+json`).
- **Idempotency keys** on state-changing POSTs; changes to infrastructure go through Terraform, never ad-hoc SDK calls.
- Auth: JWT bearer (local issuer now, Cognito later); role-based access (viewer / operator / admin).
- Structured JSON logs with request IDs; health (`/healthz`) and readiness (`/readyz`) endpoints.
- OpenAPI spec is generated and committed (`api/openapi.json`); the Flutter client is generated from it.
- Layered structure: `routers/` → `services/` → `adapters/` (terraform, router SSH/NETCONF, dynamodb). Business logic never in routers.

## 6. Flutter app (Android, iOS, Web from one codebase)

- **Platforms:** Android, iOS and Web are all first-class; every feature is tested on all three. Responsive layouts for phone, tablet and desktop web.
- Latest stable Flutter; Dart null-safety; **Material 3** with a single theme (light + dark).
- Lints: `flutter_lints` plus analyzer `strict-casts`, `strict-inference`, `strict-raw-types` and the extra rule set used in Privacy Lens (`always_declare_return_types`, `avoid_dynamic_calls`, `avoid_print`, `cancel_subscriptions`, `close_sinks`, `directives_ordering`, `discarded_futures`, `prefer_const_constructors`, `prefer_final_locals`, `prefer_single_quotes`, `require_trailing_commas`, `unawaited_futures`, `use_build_context_synchronously`, `use_super_parameters`, …). Generated files (`*.g.dart`, `lib/l10n/gen/**`) are excluded. Zero warnings; `dart format` enforced.
- **Architecture:** feature-first, clean layers. Folder layout:
  - `lib/app/` — `app.dart`, `bootstrap.dart` (composition root), `router.dart`, `dependency_injection.dart`
  - `lib/core/` — `theme/`, `design_system/` (spacing, radii, dimensions tokens), `errors/`, `logging/`, `network/`
  - `lib/features/<feature>/{data,domain,presentation}/`
  - `lib/shared/{widgets,presentation,extensions}/`
- **State management:** `flutter_bloc`, **Cubit by default** (a full `Bloc` only when event streams/transformers are needed). App-scope Cubits hold shared state; screen-local Cubits hold filters/UI state. One state library only. States model loading / empty / error explicitly; use `equatable` for state equality.
- **Errors:** repositories return a sealed `Result<T>` (`Ok` / `Err(AppFailure)`) from `lib/core/errors/`; they never throw into the UI.
- Navigation: **go_router** with deep links. DI: constructor injection wired in `bootstrap.dart` (Bloc providers / `RepositoryProvider`).
- Networking: generated API client from `api/openapi.json`; `dio` with interceptors for auth, retries and logging.
- **Flavors / environments:** `local` (localhost API, default) and `aws` (later), selected with `--dart-define-from-file`. No hard-coded URLs or keys.
- Secure storage for tokens (`flutter_secure_storage`); no secrets in the bundle.
- Accessibility: **WCAG 2.2 AA** — semantic labels, 48dp touch targets, contrast, text scaling, screen-reader tested.
- Localisation-ready (`flutter_localizations`, ARB files) even if English only. `l10n.yaml`: `arb-dir: lib/l10n`, `output-dir: lib/l10n/gen`, `nullable-getter: false`. Every UI string lives in `lib/l10n/app_en.arb`.
- Tests: unit (cubits with `bloc_test`, repositories), widget tests, golden tests for key screens, `integration_test` for core flows. Mocks with `mocktail`; shared fixtures in `test/helpers/`. Test folders mirror `lib/`. **≥ 70% coverage.**
- Push notifications via Firebase Cloud Messaging; local mode uses a mock notifier.
- Note: Android emulators reach the host API at `10.0.2.2`, iOS simulator and web at `localhost`.

## 7. Testing & quality gates

| Layer | Must pass before merge |
|---|---|
| Lab | `containerlab deploy` + `lab/tests` connectivity/OSPF checks |
| Terraform | fmt, validate, tflint, checkov, plan (LocalStack) |
| API | ruff, mypy, pytest (≥ 80%), OpenAPI diff |
| App | analyze (0 issues), format, unit + widget + golden (≥ 70%), web build |
| Repo | gitleaks, pre-commit |

**One local gate:** `tool/check.ps1` (Windows) and `tool/check.sh` (WSL/macOS) run every gate above for the layers that exist. Run it before every push; CI runs the same commands.

## 8. CI/CD (GitHub Actions)

- One workflow per area (`lab.yml`, `infra.yml`, `api.yml`, `app.yml`), triggered by path filters.
- Pin actions to a major version or SHA; least-privilege `permissions:` on every workflow.
- Pin toolchains exactly (e.g. `subosito/flutter-action@v2` with `flutter-version: "3.35.3"`, `cache: true`; exact Terraform and Python versions).
- Infra workflow runs against LocalStack in CI (service container). No real-cloud deploy job exists until the owner approves the AWS phase.
- Artifacts: API container image, Flutter web build, Android APK/AAB (debug), test and coverage reports.

## 9. Observability

- Structured logs (JSON) with correlation IDs from app → API → adapters.
- Metrics for API latency/error rate and device health; alert rules documented.
- Network health checks (ping/OSPF neighbour state) exposed by the API and surfaced in the app.

## 10. Documentation

- `README.md`: what it is, architecture diagram, quick start (local), demo GIF/video, tech stack. Sections in this order: intro, Requirements, Run, Quality gate, Architecture, What it can and cannot do, Tests.
- **Writing style:** short, plain sentences. State limits honestly ("can / cannot"). No marketing language.
- **ADRs** in `docs/decisions/NNNN-kebab-title.md` using the **MADR minimal** template: `Status`, `Context and Problem Statement`, `Considered Options`, `Decision Outcome`, `Consequences`. Keep them short (one screen) for every significant choice.
- Diagrams as code (Mermaid) in `docs/diagrams/`.
- Each module/package has its own short README.
- Runbooks in `docs/runbooks/` for: start the lab, reset everything, common failures.

## 11. Cost & cleanup (for the future AWS phase)

- Budget alarm before any resource is created. Prefer free-tier and serverless.
- Everything tagged; `terraform destroy` after each demo; no long-running instances.

## 12. Definition of Done

A task is done only when:
1. Code follows the standards above and all quality gates pass locally.
2. Tests were added/updated and pass.
3. Docs (README, ADR, IP plan, runbook) are updated.
4. It runs from a clean clone with the documented local steps.
5. Nothing touched real AWS or used real credentials.
