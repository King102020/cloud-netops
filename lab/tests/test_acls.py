"""Default-deny ACLs (docs/network-design.md §6, acceptance test 9)."""

from __future__ import annotations

import pytest

from conftest import run

GUESTS = ["hq-guest-01", "br1-guest-01", "br2-guest-01"]


@pytest.mark.parametrize("guest", GUESTS)
@pytest.mark.parametrize("target", ["10.10.20.10", "10.10.10.100", "10.20.10.100"])
def test_guest_cannot_reach_internal(guest: str, target: str) -> None:
    assert run(guest, f"ping -c 1 -W 2 {target}").rc != 0
    assert run(guest, f"nc -z -w 2 {target} 80").rc != 0


def test_guest_drops_are_counted() -> None:
    run("br1-guest-01", "ping -c 1 -W 1 10.10.20.10")
    rules = run("br1-edge-01", "iptables -L GUEST-IN -v -n -x").out
    drop_line = next(line for line in rules.splitlines() if "nothing internal" in line)
    assert int(drop_line.split()[0]) > 0


def test_guest_spoofed_source_is_dropped() -> None:
    # A guest pretending to be a staff address must not get out (line 50).
    out = run(
        "br1-guest-01",
        "ip addr add 10.20.30.250/24 dev eth1 && "
        "curl -s -m 3 --interface 10.20.30.250 http://198.51.100.10; "
        "ip addr del 10.20.30.250/24 dev eth1",
    ).out
    assert "the internet" in out  # still inside the guest subnet: allowed
    spoof = run(
        "br1-guest-01",
        "ip addr add 10.20.10.250/32 dev eth1 && "
        "curl -s -m 3 --interface 10.20.10.250 http://198.51.100.10; "
        "ip addr del 10.20.10.250/32 dev eth1",
    ).out
    assert "the internet" not in spoof


@pytest.mark.parametrize("port", [22, 8080, 3389])
def test_users_blocked_from_other_server_ports(port: int) -> None:
    assert run("hq-pc-01", f"nc -z -w 2 10.10.20.10 {port}").rc != 0


def test_users_cannot_reach_smb_on_web_server() -> None:
    # 445 is allowed only to the file server (10.10.20.11).
    assert run("br1-pc-01", "nc -z -w 2 10.10.20.10 445").rc != 0


def test_mgmt_can_ssh_port_to_servers() -> None:
    # Line 90: MGMT may reach tcp/22 on servers. Nothing listens in the lab,
    # so "connection refused" (fast RST) proves the ACL let it through,
    # while a drop would time out.
    res = run("hq-admin-01", "nc -z -v -w 3 10.10.20.10 22")
    assert "refused" in res.out.lower()


def test_users_ssh_to_servers_is_dropped_not_refused() -> None:
    res = run("hq-pc-01", "nc -z -v -w 3 10.10.20.10 22")
    assert "refused" not in res.out.lower()
