# Contributing

Read [`docs/STANDARDS.md`](docs/STANDARDS.md) first. This file is the short
version.

## Setup

```sh
cp .env.example .env
pip install pre-commit
pre-commit install
```

## Branches

Trunk-based. `main` is always green. Branch from `main`:

`feat/…`, `fix/…`, `chore/…`, `docs/…`, `infra/…`

## Commits

[Conventional Commits](https://www.conventionalcommits.org) with a scope:

```
feat(api): add firewall rule endpoint
fix(lab): correct br2 OSPF area
docs(network): add IP plan table
```

Scopes: `lab`, `infra`, `api`, `app`, `ci`, `docs`, `network`, `standards`,
`repo`. One logical change per commit.

## Pull requests

- Small: under 400 changed lines where possible.
- Fill in the template: What / Why / How tested / Screenshots.
- Run the quality gate first: `.\tool\check.ps1` or `./tool/check.sh`.
- CI must pass.
- Significant choices get an ADR in `docs/decisions/`.
- Update `CHANGELOG.md` under `[Unreleased]`.

## Local only

Until the owner says "deploy to AWS", every AWS call goes to LocalStack with
dummy credentials. Never run plain `terraform apply` or `aws` against real
AWS.
