# 0001: Local-only development until AWS deployment is approved

## Status

Accepted (2026-11-22)

## Context and Problem Statement

This is a portfolio project built by one person. Real AWS resources cost
money. Mistakes with credentials leak access, and a forgotten Transit
Gateway or VPN costs money by the hour. We still want the full design and the
code to be real and testable from day one.

## Considered Options

1. Develop directly against a personal AWS account with a budget alarm.
2. Develop fully locally (LocalStack, Containerlab, FastAPI on localhost)
   and add a real-AWS environment later.
3. Write the Terraform but never apply it anywhere.

## Decision Outcome

Option 2. Every AWS call goes to LocalStack through `lstk terraform` /
`lstk aws` with dummy credentials (`test` / `test`, `ap-south-1`).

- Routers run in Containerlab in WSL2.
- The API runs on `localhost:8000`.
- The app uses a `local` flavor.
- `infra/envs/aws` exists only as a placeholder.
- No CI job deploys to real AWS until the owner explicitly says
  "deploy to AWS".

## Consequences

- Good: zero cost, no credential risk, fast reset (`docker` +
  `containerlab destroy`), runs from a clean clone.
- Good: the Terraform modules are shared, so the AWS phase is a new thin
  `envs/aws` composition, not a rewrite.
- Bad: LocalStack does not fully emulate some services (for example VPN data
  plane and parts of Transit Gateway routing). Each gap goes in
  `docs/local-gaps.md` with how it is mocked or tested instead.
- Bad: no real performance or latency numbers until phase 7.
