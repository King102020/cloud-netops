"""OSPF design checks (docs/network-design.md §5, acceptance tests 1-2)."""

from __future__ import annotations

from typing import Any

import pytest

from conftest import EXPECTED_NEIGHBORS, ROUTERS, ospf_full_neighbors, vtysh_json


def routes(router: str) -> dict[str, Any]:
    data: dict[str, Any] = vtysh_json(router, "show ip route")
    return data


def best_ospf(router: str, prefix: str) -> dict[str, Any] | None:
    for entry in routes(router).get(prefix, []):
        if entry.get("protocol") == "ospf" and entry.get("selected"):
            result: dict[str, Any] = entry
            return result
    return None


@pytest.mark.parametrize("router", ROUTERS)
def test_neighbors_full(router: str) -> None:
    assert ospf_full_neighbors(router) == EXPECTED_NEIGHBORS[router]


@pytest.mark.parametrize(
    ("router", "router_id"),
    [
        ("hq-edge-01", "10.255.255.1"),
        ("hq-core-01", "10.255.255.2"),
        ("br1-edge-01", "10.255.255.3"),
        ("br2-edge-01", "10.255.255.4"),
    ],
)
def test_router_id_is_loopback(router: str, router_id: str) -> None:
    assert vtysh_json(router, "show ip ospf")["routerId"] == router_id


def test_hq_sees_one_summary_per_branch() -> None:
    table = routes("hq-core-01")
    assert best_ospf("hq-core-01", "10.20.0.0/16") is not None
    assert best_ospf("hq-core-01", "10.30.0.0/16") is not None
    # ABR summarisation: no branch /24s leak into area 0.
    leaked = [p for p in table if p.startswith(("10.20.", "10.30.")) and not p.endswith("/16")]
    assert leaked == []


@pytest.mark.parametrize("router", ["hq-core-01", "br1-edge-01", "br2-edge-01"])
def test_default_route_from_hq_edge(router: str) -> None:
    assert best_ospf(router, "0.0.0.0/0") is not None, "no OSPF default route installed"
    ospf_default = vtysh_json(router, "show ip ospf route")["0.0.0.0/0"]
    assert ospf_default["routeType"] == "N E2"  # external type 2, injected by the ASBR
    advertisers = {nh["advertisedRouter"] for nh in ospf_default["nexthops"]}
    assert advertisers == {"10.255.255.1"}  # hq-edge-01


def test_backup_link_not_preferred() -> None:
    # br1 -> br2 LANs goes via the hub (cost 20), not the backup link (cost 100).
    route = best_ospf("br1-edge-01", "10.30.0.0/16")
    assert route is not None
    hops = {nh.get("ip") for nh in route.get("nexthops", [])}
    assert hops == {"10.255.0.5"}
