"""Adapters: the only code that talks to the outside world (Docker / FRR,
Terraform, DynamoDB). Services depend on the Protocols, never on these
implementations directly, so tests swap in the fakes."""
