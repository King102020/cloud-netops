"""Shared helpers for the lab acceptance tests (docs/network-design.md §10).

The tests drive the running Containerlab lab with `docker exec`, so they
work the same from Windows, WSL, macOS and CI. Deploy first:
`./lab/clab.sh deploy`.
"""

from __future__ import annotations

import json
import os
import subprocess
import time
from collections.abc import Callable
from dataclasses import dataclass
from typing import Any

import pytest

LAB_PREFIX = "clab-cnops-"
ROUTERS = ["hq-edge-01", "hq-core-01", "br1-edge-01", "br2-edge-01"]
CONVERGE_TIMEOUT_S = 90


@dataclass(frozen=True)
class Result:
    rc: int
    out: str


def run(node: str, cmd: str, timeout: float = 30) -> Result:
    """Run a shell command inside a lab node."""
    env = {**os.environ, "MSYS_NO_PATHCONV": "1"}  # Git Bash: keep /paths as-is
    proc = subprocess.run(
        ["docker", "exec", f"{LAB_PREFIX}{node}", "sh", "-c", cmd],
        capture_output=True,
        text=True,
        timeout=timeout,
        env=env,
        check=False,
    )
    return Result(proc.returncode, (proc.stdout + proc.stderr).strip())


def vtysh_json(router: str, command: str) -> Any:
    res = run(router, f"vtysh -c '{command} json'")
    assert res.rc == 0, res.out
    return json.loads(res.out)


def ospf_full_neighbors(router: str) -> set[str]:
    """Router IDs of neighbours in state Full."""
    data = vtysh_json(router, "show ip ospf neighbor")
    full: set[str] = set()
    for rid, entries in data.get("neighbors", {}).items():
        for entry in entries:
            if str(entry.get("nbrState", "")).startswith("Full"):
                full.add(rid)
    return full


def wait_until(check: Callable[[], bool], timeout: float = CONVERGE_TIMEOUT_S) -> bool:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        try:
            if check():
                return True
        except (AssertionError, json.JSONDecodeError):
            pass
        time.sleep(2)
    return False


EXPECTED_NEIGHBORS = {
    "hq-edge-01": {"10.255.255.2"},
    "hq-core-01": {"10.255.255.1", "10.255.255.3", "10.255.255.4"},
    "br1-edge-01": {"10.255.255.2", "10.255.255.4"},
    "br2-edge-01": {"10.255.255.2", "10.255.255.3"},
}


def converged() -> bool:
    return all(ospf_full_neighbors(r) == n for r, n in EXPECTED_NEIGHBORS.items())


@pytest.fixture(scope="session", autouse=True)
def lab_converged() -> None:
    """Fail fast with a clear message if the lab is not up or not converged."""
    probe = subprocess.run(
        ["docker", "inspect", "-f", "{{.State.Running}}", f"{LAB_PREFIX}hq-core-01"],
        capture_output=True,
        text=True,
        check=False,
    )
    if probe.stdout.strip() != "true":
        pytest.fail("Lab is not running. Deploy it first: ./lab/clab.sh deploy")
    if not wait_until(converged):
        got = {r: sorted(ospf_full_neighbors(r)) for r in EXPECTED_NEIGHBORS}
        pytest.fail(f"OSPF did not converge in {CONVERGE_TIMEOUT_S}s: {got}")
