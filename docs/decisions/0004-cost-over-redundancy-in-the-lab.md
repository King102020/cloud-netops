# 0004: Cost and simplicity over full redundancy and compliance in the lab

## Status

Accepted (2026-11-22)

## Context and Problem Statement

The AWS Well-Architected Framework asks for trade-offs to be written down.
checkov flags several controls that cost money per hour or per GB on real
AWS. This project is a portfolio lab that will run on AWS only for short
demos (STANDARDS §11), so we have to choose where to be strict.

## Considered Options

1. Enable every control: one NAT gateway per AZ, KMS customer-managed keys,
   1-year log retention, Route 53 query logging.
2. Keep the controls that are free or cheap, and skip the costly ones with
   an inline reason that points here.

## Decision Outcome

Option 2.

| Control | Choice | Pillar traded | Cost avoided |
| --- | --- | --- | --- |
| NAT gateway per AZ | **One** NAT gateway in `hq public-a` | Reliability (an AZ-a outage cuts internet for all sites) | ~US$35/month per extra NAT GW + data |
| KMS CMK for logs / DynamoDB | AWS-owned keys (still encrypted) | Security (no key-level audit or rotation control) | US$1/month per key + API calls |
| Flow log retention | 14 days | Operational excellence (shorter forensics window) | Log storage |
| Route 53 query logging | Off | Security (no DNS query audit) | Log group + ingestion |
| SG "attached" / NACL "attached" checks | Skipped | none: no workloads, and checkov cannot follow module inputs | — |

Kept on purpose, because they are free:
- locked default SGs, least-privilege flow-log IAM, VPC flow logs;
- DynamoDB PITR and encryption;
- IKEv2 with AES-256-GCM only;
- NACL ephemeral range limited to 32768–65535;
- no `0.0.0.0/0` ingress anywhere.

## Consequences

- Every skip is an inline `checkov:skip` comment that names its reason. CI
  stays green, and a reviewer can see each trade-off in place.
- For a production version, revisit this ADR first. Add NAT gateways in
  `public-b`, add CMKs, and raise retention. The modules already take these
  as inputs or are a small change.
