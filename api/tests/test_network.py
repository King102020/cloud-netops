from __future__ import annotations

from fastapi.testclient import TestClient


def test_topology_matches_design(client: TestClient, viewer: dict[str, str]) -> None:
    r = client.get("/v1/topology", headers=viewer)
    assert r.status_code == 200
    body = r.json()
    assert {s["id"] for s in body["sites"]} == {"hq", "br1", "br2", "isp"}
    links = {link["id"]: link for link in body["links"]}
    assert links["hq-br2"]["subnet"] == "10.255.0.8/30"
    assert links["br1-br2"]["ospf_cost"] == 100
    assert links["hq-br1"]["state"] == "up"
    routers = [d for d in body["devices"] if d["role"] == "router"]
    assert len(routers) == 4


def test_devices_pagination_and_filters(client: TestClient, viewer: dict[str, str]) -> None:
    first = client.get("/v1/devices?limit=3", headers=viewer).json()
    assert len(first["items"]) == 3
    assert first["next_cursor"]
    second = client.get(f"/v1/devices?limit=3&cursor={first['next_cursor']}", headers=viewer).json()
    assert {d["id"] for d in first["items"]}.isdisjoint({d["id"] for d in second["items"]})
    routers = client.get("/v1/devices?role=router&site=br1", headers=viewer).json()["items"]
    assert [d["id"] for d in routers] == ["br1-edge-01"]


def test_bad_cursor_is_400(client: TestClient, viewer: dict[str, str]) -> None:
    r = client.get("/v1/devices?cursor=not-a-cursor", headers=viewer)
    assert r.status_code == 400
    assert r.json()["type"].endswith("/bad-cursor")


def test_limit_is_bounded(client: TestClient, viewer: dict[str, str]) -> None:
    assert client.get("/v1/devices?limit=500", headers=viewer).status_code == 422


def test_device_detail_and_404(client: TestClient, viewer: dict[str, str]) -> None:
    d = client.get("/v1/devices/hq-core-01", headers=viewer).json()
    assert d["router_id"] == "10.255.255.2"
    assert {i["name"] for i in d["interfaces"]} >= {"eth1", "eth2", "eth3", "br20"}
    r = client.get("/v1/devices/nope-01", headers=viewer)
    assert r.status_code == 404
    assert r.json()["type"].endswith("/not-found")


def test_device_id_is_validated(client: TestClient, viewer: dict[str, str]) -> None:
    assert client.get("/v1/devices/BAD;rm", headers=viewer).status_code == 422


def test_health_healthy_router(client: TestClient, viewer: dict[str, str]) -> None:
    h = client.get("/v1/devices/hq-core-01/health", headers=viewer).json()
    assert h["status"] == "healthy"
    assert {n["router_id"] for n in h["ospf_neighbors"]} == {
        "10.255.255.1",
        "10.255.255.3",
        "10.255.255.4",
    }


def test_health_of_stopped_device(client: TestClient, viewer: dict[str, str], lab: object) -> None:
    lab.stop_device("br2-edge-01")  # type: ignore[attr-defined]
    h = client.get("/v1/devices/br2-edge-01/health", headers=viewer).json()
    assert h["status"] == "down"
    assert h["reachable"] is False
    alerts = client.get("/v1/alerts", headers=viewer).json()
    assert any(a["kind"] == "device_down" and a["target"] == "br2-edge-01" for a in alerts)


def test_no_alerts_when_healthy(client: TestClient, viewer: dict[str, str]) -> None:
    assert client.get("/v1/alerts", headers=viewer).json() == []


def test_link_down_reroutes_and_alerts(
    client: TestClient, operator: dict[str, str], viewer: dict[str, str]
) -> None:
    r = client.patch("/v1/links/hq-br2", json={"state": "down"}, headers=operator)
    assert r.status_code == 200
    assert r.json()["state"] == "down"

    health = client.get("/v1/devices/hq-core-01/health", headers=viewer).json()
    assert health["status"] == "degraded"
    assert "10.255.255.4" not in {n["router_id"] for n in health["ospf_neighbors"]}

    alerts = client.get("/v1/alerts", headers=viewer).json()
    kinds = {(a["kind"], a["target"]) for a in alerts}
    assert ("link_down", "hq-br2") in kinds
    assert ("ospf_neighbor_missing", "hq-core-01") in kinds
    assert all(a["severity"] == "critical" for a in alerts if a["kind"] == "link_down")

    # br2 still has the backup adjacency with br1
    br2 = client.get("/v1/devices/br2-edge-01/health", headers=viewer).json()
    assert {n["router_id"] for n in br2["ospf_neighbors"]} == {"10.255.255.3"}

    up = client.patch("/v1/links/hq-br2", json={"state": "up"}, headers=operator)
    assert up.json()["state"] == "up"
    assert client.get("/v1/alerts", headers=viewer).json() == []


def test_backup_link_down_is_only_a_warning(client: TestClient, operator: dict[str, str]) -> None:
    client.patch("/v1/links/br1-br2", json={"state": "down"}, headers=operator)
    alerts = client.get("/v1/alerts", headers=operator).json()
    link_alert = next(a for a in alerts if a["kind"] == "link_down")
    assert link_alert["severity"] == "warning"


def test_viewer_cannot_change_links(client: TestClient, viewer: dict[str, str]) -> None:
    r = client.patch("/v1/links/hq-br2", json={"state": "down"}, headers=viewer)
    assert r.status_code == 403
    assert "operator" in r.json()["detail"]


def test_lan_links_are_not_controllable(client: TestClient, operator: dict[str, str]) -> None:
    r = client.patch("/v1/links/hq-users", json={"state": "down"}, headers=operator)
    assert r.status_code == 409


def test_link_state_body_is_validated(client: TestClient, operator: dict[str, str]) -> None:
    r = client.patch("/v1/links/hq-br2", json={"state": "sideways"}, headers=operator)
    assert r.status_code == 422
    assert r.json()["errors"]


def test_link_change_is_audited(client: TestClient, operator: dict[str, str]) -> None:
    client.patch("/v1/links/hq-br1", json={"state": "down"}, headers=operator)
    events = client.get("/v1/audit-events?action=link.down", headers=operator).json()["items"]
    assert events[0]["target"] == "hq-br1"
    assert events[0]["before"] == {"state": "up"}
    assert events[0]["after"] == {"state": "down"}
    assert events[0]["actor"] == "operator"


def test_list_and_get_links(client: TestClient, viewer: dict[str, str]) -> None:
    links = client.get("/v1/links", headers=viewer).json()
    assert {link["id"] for link in links if link["controllable"]} == {
        "hq-edge-core",
        "hq-br1",
        "hq-br2",
        "br1-br2",
    }
    assert client.get("/v1/links/hq-br1", headers=viewer).json()["kind"] == "wan"
    assert client.get("/v1/links/zz-zz", headers=viewer).status_code == 404
