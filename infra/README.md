# Infrastructure (Terraform)

Phase 3.

- `modules/<name>/` — reusable modules (`main.tf`, `variables.tf`,
  `outputs.tf`, `versions.tf`, `README.md`)
- `envs/local/` — LocalStack composition, run with `lstk terraform`
- `envs/aws/` — real AWS composition. **Not used until the owner approves
  the AWS phase.**

Naming: `cnops-<env>-<resource>`. Tags on everything: `Project`,
`Environment`, `Owner`, `ManagedBy=terraform`.
