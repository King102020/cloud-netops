"""Contract tests: the committed OpenAPI spec is the API (STANDARDS §5)."""

from __future__ import annotations

import json

from fastapi.testclient import TestClient

from cnops_api.openapi_export import SPEC_PATH, build_spec, main, render
from tests.conftest import RULE, idem


def test_committed_spec_is_up_to_date() -> None:
    assert SPEC_PATH.read_text(encoding="utf-8") == render(build_spec()), (
        "api/openapi.json is stale: run `python -m cnops_api.openapi_export`"
    )
    assert main(["--check"]) == 0


def test_spec_covers_every_required_endpoint() -> None:
    paths = json.loads(SPEC_PATH.read_text(encoding="utf-8"))["paths"]
    required = {
        ("get", "/v1/topology"),
        ("get", "/v1/devices/{device_id}/health"),
        ("get", "/v1/firewall-rules"),
        ("post", "/v1/firewall-rules"),
        ("delete", "/v1/firewall-rules/{rule_id}"),
        ("post", "/v1/subnets"),
        ("patch", "/v1/links/{link_id}"),
        ("get", "/v1/audit-events"),
        ("get", "/healthz"),
        ("get", "/readyz"),
    }
    present = {(m, p) for p, ops in paths.items() for m in ops}
    assert required <= present


def test_state_changing_posts_require_idempotency_key() -> None:
    paths = json.loads(SPEC_PATH.read_text(encoding="utf-8"))["paths"]
    for path in ("/v1/firewall-rules", "/v1/subnets"):
        params = {p["name"]: p for p in paths[path]["post"]["parameters"]}
        assert params["Idempotency-Key"]["required"] is True


def test_responses_validate_against_spec_shapes(
    client: TestClient, operator: dict[str, str]
) -> None:
    """Every field the API returns is declared in the spec's schema."""
    spec = build_spec()
    schemas = spec["components"]["schemas"]
    rule = client.post("/v1/firewall-rules", json=RULE, headers={**operator, **idem()}).json()
    assert set(rule) <= set(schemas["FirewallRule"]["properties"])
    topo = client.get("/v1/topology", headers=operator).json()
    assert set(topo) == set(schemas["Topology"]["properties"])
    problem = client.get("/v1/devices/nope-01", headers=operator).json()
    assert set(problem) <= set(schemas["Problem"]["properties"])
