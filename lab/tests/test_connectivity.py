"""Reachability, NAT and failover (docs/network-design.md §10, tests 4-8)."""

from __future__ import annotations

from itertools import permutations

import pytest

from conftest import converged, run, wait_until

HOSTS = {
    "hq-pc-01": "10.10.10.100",
    "hq-admin-01": "10.10.99.10",
    "br1-pc-01": "10.20.10.100",
    "br2-pc-01": "10.30.10.100",
}


def http(node: str, url: str) -> str:
    return run(node, f"curl -s -m 5 {url}").out


def hops(node: str, target: str) -> list[str]:
    out = run(node, f"traceroute -n -w 1 -q 1 -m 8 {target}").out
    return [line.split()[1] for line in out.splitlines()[1:] if len(line.split()) > 1]


@pytest.mark.parametrize(("src", "dst"), list(permutations(HOSTS, 2)))
def test_staff_hosts_reach_each_other(src: str, dst: str) -> None:
    assert run(src, f"ping -c 2 -W 2 {HOSTS[dst]}").rc == 0


@pytest.mark.parametrize("src", ["hq-pc-01", "br1-pc-01", "br2-pc-01"])
def test_users_reach_intranet(src: str) -> None:
    assert "cnops intranet" in http(src, "http://10.10.20.10")


@pytest.mark.parametrize("src", ["hq-pc-01", "br1-pc-01", "br2-pc-01"])
def test_users_reach_file_server(src: str) -> None:
    assert run(src, "nc -z -w 3 10.10.20.11 445").rc == 0


@pytest.mark.parametrize("src", ["hq-pc-01", "br1-pc-01", "br2-pc-01", "br1-guest-01"])
def test_internet_via_hq_nat(src: str) -> None:
    assert "the internet" in http(src, "http://198.51.100.10")


@pytest.mark.parametrize("src", ["hq-pc-01", "br2-pc-01", "br1-guest-01"])
def test_isp_only_sees_the_nat_address(src: str) -> None:
    # isp-srv-01:8080 echoes the source address it sees (like ifconfig.me).
    seen = run(src, "nc -w 3 198.51.100.10 8080 < /dev/null").out
    assert seen == "203.0.113.2"


def test_isp_has_no_route_to_company() -> None:
    assert run("isp-srv-01", "ping -c 1 -W 2 10.10.20.10").rc != 0


def test_branch_to_branch_goes_via_hub() -> None:
    path = hops("br1-pc-01", "10.30.10.100")
    assert "10.255.0.5" in path  # hq-core-01
    assert "10.255.0.14" not in path  # not the backup link


def test_failover_to_backup_link_and_back() -> None:
    """Acceptance test 6: HQ<->br2 down, br2 still reaches HQ via br1."""
    try:
        assert run("hq-core-01", "ip link set eth3 down").rc == 0
        assert wait_until(lambda: "10.255.0.13" in hops("br2-pc-01", "10.10.20.10"), timeout=60), (
            "traffic did not move to the backup link"
        )
        assert "cnops intranet" in http("br2-pc-01", "http://10.10.20.10")
    finally:
        run("hq-core-01", "ip link set eth3 up")
        assert wait_until(converged), "OSPF did not reconverge after restoring the link"
    assert wait_until(lambda: "10.255.0.13" not in hops("br2-pc-01", "10.10.20.10"), 60)
