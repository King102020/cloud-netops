# Security policy

## Reporting a vulnerability

Please do not open a public issue. Use GitHub's
[private vulnerability reporting](https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing-information-about-vulnerabilities/privately-reporting-a-security-vulnerability)
on this repository. You will get a reply within 7 days.

## Scope

This is a portfolio project. It currently runs only on a local machine
against LocalStack and Containerlab. There is no hosted service.

## Practices

- No secrets in git. `.env` is ignored; `.env.example` holds fake values.
- `gitleaks` runs in pre-commit and CI.
- Least-privilege IAM and default-deny network rules.
- Dependency scanning with Dependabot and `pip-audit`; IaC scanning with
  `checkov`.
- OWASP API Security Top 10 for the API, OWASP MASVS for the app.

See [`docs/STANDARDS.md`](docs/STANDARDS.md) §2.
