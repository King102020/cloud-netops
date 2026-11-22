from __future__ import annotations

import json

from fastapi.testclient import TestClient

from cnops_api.adapters.terraform import FakeTerraform
from cnops_api.settings import Settings
from tests.conftest import RULE, idem


def test_create_rule_goes_through_terraform(
    client: TestClient, operator: dict[str, str], terraform: FakeTerraform, settings: Settings
) -> None:
    r = client.post("/v1/firewall-rules", json=RULE, headers={**operator, **idem()})
    assert r.status_code == 202
    rule = r.json()
    assert rule["id"].startswith("fw-")
    assert rule["status"] == "applied"
    assert rule["created_by"] == "operator"
    assert terraform.runs == 1

    # The Terraform input file now contains the rule (that is what Terraform reads).
    on_disk = json.loads((settings.managed_dir / "firewall_rules.json").read_text())
    assert on_disk[0]["cidr"] == "10.20.10.0/24"
    assert on_disk[0]["site"] == "hq"

    job = client.get(f"/v1/jobs/{rule['job_id']}", headers=operator).json()
    assert job["state"] == "succeeded"
    assert job["summary"] == "Apply complete! (fake)"


def test_idempotency_replays_same_request(
    client: TestClient, operator: dict[str, str], terraform: FakeTerraform
) -> None:
    key = idem()
    first = client.post("/v1/firewall-rules", json=RULE, headers={**operator, **key})
    again = client.post("/v1/firewall-rules", json=RULE, headers={**operator, **key})
    assert again.status_code == 202
    assert again.json()["id"] == first.json()["id"]
    assert again.headers["Idempotent-Replayed"] == "true"
    assert terraform.runs == 1  # no second apply


def test_idempotency_key_reused_with_other_body(
    client: TestClient, operator: dict[str, str]
) -> None:
    key = idem()
    client.post("/v1/firewall-rules", json=RULE, headers={**operator, **key})
    other = {**RULE, "from_port": 9000, "to_port": 9000}
    r = client.post("/v1/firewall-rules", json=other, headers={**operator, **key})
    assert r.status_code == 422


def test_idempotency_key_is_required(client: TestClient, operator: dict[str, str]) -> None:
    r = client.post("/v1/firewall-rules", json=RULE, headers=operator)
    assert r.status_code == 422
    assert any("Idempotency-Key" in str(e["loc"]) for e in r.json()["errors"])


def test_duplicate_rule_conflicts(client: TestClient, operator: dict[str, str]) -> None:
    client.post("/v1/firewall-rules", json=RULE, headers={**operator, **idem()})
    r = client.post("/v1/firewall-rules", json=RULE, headers={**operator, **idem()})
    assert r.status_code == 409


def test_world_open_rule_is_rejected(client: TestClient, operator: dict[str, str]) -> None:
    r = client.post(
        "/v1/firewall-rules", json={**RULE, "cidr": "0.0.0.0/0"}, headers={**operator, **idem()}
    )
    assert r.status_code == 422
    assert "default deny" in json.dumps(r.json())


def test_public_source_is_rejected(client: TestClient, operator: dict[str, str]) -> None:
    r = client.post(
        "/v1/firewall-rules", json={**RULE, "cidr": "8.8.8.0/24"}, headers={**operator, **idem()}
    )
    assert r.status_code == 422


def test_host_bits_and_bad_ports_are_rejected(client: TestClient, operator: dict[str, str]) -> None:
    for bad in (
        {"cidr": "10.20.10.5/24"},
        {"from_port": 9000, "to_port": 8000},
        {"from_port": 0, "to_port": 0},
        {"tier": "guest"},
        {"site": "mars"},
        {"description": "x"},
        {"description": "drop table; --"},
        {"extra": "field"},
    ):
        r = client.post("/v1/firewall-rules", json={**RULE, **bad}, headers={**operator, **idem()})
        assert r.status_code == 422, bad


def test_icmp_rule_allows_type_code(client: TestClient, operator: dict[str, str]) -> None:
    body = {
        **RULE,
        "protocol": "icmp",
        "from_port": 8,
        "to_port": 0,
        "description": "ping from br1",
    }
    r = client.post("/v1/firewall-rules", json=body, headers={**operator, **idem()})
    assert r.status_code == 202


def test_viewer_cannot_create_rule(client: TestClient, viewer: dict[str, str]) -> None:
    r = client.post("/v1/firewall-rules", json=RULE, headers={**viewer, **idem()})
    assert r.status_code == 403


def test_toggle_and_delete_rule(
    client: TestClient, operator: dict[str, str], terraform: FakeTerraform
) -> None:
    rule = client.post("/v1/firewall-rules", json=RULE, headers={**operator, **idem()}).json()
    off = client.patch(
        f"/v1/firewall-rules/{rule['id']}", json={"enabled": False}, headers=operator
    )
    assert off.status_code == 202
    assert off.json()["enabled"] is False
    assert off.json()["status"] == "applied"

    gone = client.delete(f"/v1/firewall-rules/{rule['id']}", headers=operator)
    assert gone.status_code == 202
    assert gone.json()["state"] == "succeeded"
    assert client.get(f"/v1/firewall-rules/{rule['id']}", headers=operator).status_code == 404
    assert terraform.runs == 3


def test_failed_apply_marks_rule_failed(
    client: TestClient, operator: dict[str, str], terraform: FakeTerraform
) -> None:
    terraform.fail_next = True
    rule = client.post("/v1/firewall-rules", json=RULE, headers={**operator, **idem()}).json()
    assert rule["status"] == "failed"
    events = client.get("/v1/audit-events?action=firewall_rule.create.terraform", headers=operator)
    assert events.json()["items"][0]["result"] == "failed"


def test_list_rules_filters(client: TestClient, operator: dict[str, str]) -> None:
    client.post("/v1/firewall-rules", json=RULE, headers={**operator, **idem()})
    client.post(
        "/v1/firewall-rules",
        json={**RULE, "site": "br1", "tier": "users", "description": "other site"},
        headers={**operator, **idem()},
    )
    assert len(client.get("/v1/firewall-rules", headers=operator).json()["items"]) == 2
    hq = client.get("/v1/firewall-rules?site=hq", headers=operator).json()["items"]
    assert [r["site"] for r in hq] == ["hq"]


def test_rule_create_audit_has_after(client: TestClient, operator: dict[str, str]) -> None:
    rule = client.post("/v1/firewall-rules", json=RULE, headers={**operator, **idem()}).json()
    ev = client.get("/v1/audit-events?action=firewall_rule.create", headers=operator).json()[
        "items"
    ]
    assert ev[0]["target"] == rule["id"]
    assert ev[0]["before"] is None
    assert ev[0]["after"]["cidr"] == "10.20.10.0/24"


# ---------------- subnets ----------------
SUBNET = {
    "site": "br1",
    "name": "servers-a",
    "cidr_block": "10.120.20.0/24",
    "az": "a",
    "tier": "servers",
}


def test_admin_creates_subnet(
    client: TestClient, admin: dict[str, str], settings: Settings
) -> None:
    r = client.post("/v1/subnets", json=SUBNET, headers={**admin, **idem()})
    assert r.status_code == 202
    assert r.json()["status"] == "applied"
    on_disk = json.loads((settings.managed_dir / "subnets.json").read_text())
    assert on_disk[0]["cidr_block"] == "10.120.20.0/24"
    listed = client.get("/v1/subnets?site=br1", headers=admin).json()["items"]
    assert any(s["name"] == "servers-a" and s["managed"] for s in listed)


def test_operator_cannot_create_subnet(client: TestClient, operator: dict[str, str]) -> None:
    assert (
        client.post("/v1/subnets", json=SUBNET, headers={**operator, **idem()}).status_code == 403
    )


def test_subnet_conflicts(client: TestClient, admin: dict[str, str]) -> None:
    cases = [
        ({"cidr_block": "10.120.10.0/25", "name": "servers-a"}, "overlaps"),  # base users-a
        ({"cidr_block": "10.130.20.0/24"}, "outside"),  # br2 range in br1
        ({"site": "hq", "cidr_block": "10.110.40.0/24", "name": "servers-a"}, "already has"),
        ({"cidr_block": "10.120.250.0/28"}, "reserved"),
        ({"cidr_block": "10.120.20.0/29"}, "/16 and /28"),
    ]
    for override, word in cases:
        r = client.post("/v1/subnets", json={**SUBNET, **override}, headers={**admin, **idem()})
        assert r.status_code == 409, override
        assert word in r.json()["detail"], (override, r.json())


def test_subnet_name_must_match_tier_and_az(client: TestClient, admin: dict[str, str]) -> None:
    r = client.post("/v1/subnets", json={**SUBNET, "az": "b"}, headers={**admin, **idem()})
    assert r.status_code == 422


def test_duplicate_subnet_name(client: TestClient, admin: dict[str, str]) -> None:
    client.post("/v1/subnets", json=SUBNET, headers={**admin, **idem()})
    again = {**SUBNET, "cidr_block": "10.120.30.0/24"}
    r = client.post("/v1/subnets", json=again, headers={**admin, **idem()})
    assert r.status_code == 409
    assert "already has" in r.json()["detail"]


def test_base_subnets_listed(client: TestClient, viewer: dict[str, str]) -> None:
    items = client.get("/v1/subnets?limit=100", headers=viewer).json()["items"]
    assert len(items) == 14
    assert all(not s["managed"] for s in items)


def test_unknown_job_404(client: TestClient, viewer: dict[str, str]) -> None:
    assert client.get("/v1/jobs/job-00000000", headers=viewer).status_code == 404


def test_audit_pagination(client: TestClient, operator: dict[str, str]) -> None:
    for state in ("down", "up", "down", "up"):
        client.patch("/v1/links/hq-br1", json={"state": state}, headers=operator)
    page1 = client.get("/v1/audit-events?limit=3", headers=operator).json()
    assert len(page1["items"]) == 3
    page2 = client.get(f"/v1/audit-events?limit=3&cursor={page1['next_cursor']}", headers=operator)
    assert len(page2.json()["items"]) == 1
    assert client.get("/v1/audit-events?cursor=%%%", headers=operator).status_code == 400
