# Control API (FastAPI)

Phase 4. The API the Flutter app talks to. It reads the live network from
the lab, changes the cloud network **only through Terraform**, and writes
every change to an audit log.

## Run

```sh
cd api
python -m venv .venv
.venv/bin/pip install -e ".[dev]"            # Windows: .venv\Scripts\pip
cp ../.env.example ../.env                     # optional; defaults are safe
.venv/bin/uvicorn --factory cnops_api.main:create_app --port 8000
```

- Open http://localhost:8000/docs for Swagger.
- Log in with `POST /v1/auth/token`. The local users come from
  `CNOPS_DEV_USERS`: `viewer`, `operator` and `admin`, with password
  `<name>-local`.

| Setting | Values | Default | Effect |
| --- | --- | --- | --- |
| `CNOPS_LAB_MODE` | `real` / `fake` | `real` | `real` = `docker exec` into the Containerlab lab; `fake` = in-memory lab, which still simulates OSPF and link failures |
| `CNOPS_TERRAFORM_MODE` | `apply` / `plan` / `fake` | `plan` | `apply` needs LocalStack running; `plan` proves each change without applying it |
| `CNOPS_STORE_MODE` | `real` / `fake` | `fake` | `real` = DynamoDB tables on LocalStack (created by `infra/envs/local`) |

A demo with no Docker at all:
`CNOPS_LAB_MODE=fake CNOPS_TERRAFORM_MODE=fake uvicorn --factory cnops_api.main:create_app`.

## Endpoints (`/v1`)

| Method | Path | Role | What |
| --- | --- | --- | --- |
| POST | `/auth/token` | — | Log in, get a JWT |
| GET | `/topology` | viewer | Sites, devices and links with live state |
| GET | `/devices`, `/devices/{id}` | viewer | Paginated list (filters `site`, `role`) and detail |
| GET | `/devices/{id}/health` | viewer | Reachability, uptime, OSPF neighbours vs. expected |
| GET | `/links`, `/links/{id}` | viewer | Link state |
| PATCH | `/links/{id}` | operator | `{"state": "down"}`: shuts both ends; OSPF reroutes |
| GET | `/alerts` | viewer | Device down, link down, missing OSPF adjacency |
| GET / POST | `/firewall-rules` | viewer / operator | List / add a security-group rule → **202 + Terraform job** |
| PATCH / DELETE | `/firewall-rules/{id}` | operator | Enable/disable, remove → 202 + job |
| GET / POST | `/subnets` | viewer / admin | List (base + managed) / create in a site's VPC → 202 + job |
| GET | `/jobs/{id}` | viewer | Terraform job state and plan/apply summary |
| GET | `/audit-events` | viewer | Audit log, newest first (filters `actor`, `action`) |
| GET | `/healthz`, `/readyz` | — | Liveness / readiness (audit store, lab, terraform) |

## How it follows the standards

- **Layers:** `routers/` → `services/` → `adapters/` (`lab`, `terraform`,
  `store`). Routers hold no logic.
- **Infra changes go through Terraform only.** The API writes
  `infra/envs/local/.cnops/*.json`, then one worker thread runs
  `terraform plan|apply`. It never calls the AWS SDK for network
  changes. The child process gets dummy credentials and has AWS profile
  variables stripped.
- **Validation at the boundary:**
  - Pydantic, with `extra="forbid"`.
  - CIDRs must be private, have no host bits, and never be `0.0.0.0/0`.
  - Ports must be sane, and description text is restricted to a safe
    character set.
  - Subnets are checked for overlaps, VPC bounds, reserved ranges and the
    `/16`–`/28` size limits. Terraform validates all of this again.
- **RFC 9457** `application/problem+json` for every error, with a
  `request_id`.
- **Idempotency-Key** is required on `POST /firewall-rules` and
  `POST /subnets`. A same-key retry replays the stored response; reusing a
  key with a different body returns 422.
- **Auth:**
  - JWT HS256 with issuer, audience and expiry checks. `alg=none` is
    rejected.
  - Roles: viewer < operator < admin.
  - Login is rate-limited to 5 attempts per minute per user (OWASP API4).
- **Audit log:** who, role, what, target, before/after, request ID and
  result. Each Terraform outcome is a second event.
- **Logs:** JSON, one line per request, with `X-Request-ID` propagated.
- **OpenAPI:** generated into [`openapi.json`](openapi.json) and committed.
  A test fails if it drifts. The Flutter client is generated from it.

## Tests

```sh
.venv/bin/python -m pytest        # 73 tests, coverage gate 80% (currently ~97%)
.venv/bin/ruff check src tests && .venv/bin/mypy src tests
.venv/bin/python -m cnops_api.openapi_export --check
```

- `tests/test_lab_integration.py` runs against the real lab when it is
  deployed, and is skipped otherwise.
- The DynamoDB adapter is tested with `moto`.
