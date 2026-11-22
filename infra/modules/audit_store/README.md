# Module: audit_store

DynamoDB tables used by the control API:

- **audit log:** `pk` / `sk`. It records who, what, when, and before/after
  (STANDARDS §2).
- **idempotency keys:** `key`, with a TTL on `expires_at` (STANDARDS §5).

Both tables use on-demand billing, point-in-time recovery and encryption at
rest.

| Input | Type | Default |
| --- | --- | --- |
| `name_prefix` | string | — |
| `deletion_protection` | bool | `false` |

Outputs: `audit_table_name`, `idempotency_table_name`.
