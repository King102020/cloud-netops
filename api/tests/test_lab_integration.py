"""Real DockerLab against the running Containerlab lab.

Runs only when the lab is up (`./lab/clab.sh deploy`); skipped otherwise so
the unit suite stays fast and Docker-free.
"""

from __future__ import annotations

import subprocess
import time
from collections.abc import Iterator

import pytest
from fastapi.testclient import TestClient

from cnops_api.adapters.lab import DockerLab
from cnops_api.adapters.terraform import FakeTerraform
from cnops_api.container import Container
from cnops_api.main import create_app
from cnops_api.models import Role
from cnops_api.settings import AdapterMode, Settings, TerraformMode


def _lab_running() -> bool:
    try:
        out = subprocess.run(
            ["docker", "inspect", "-f", "{{.State.Running}}", "clab-cnops-hq-core-01"],
            capture_output=True,
            text=True,
            timeout=10,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        return False
    return out.stdout.strip() == "true"


pytestmark = [
    pytest.mark.lab,
    pytest.mark.skipif(not _lab_running(), reason="lab not deployed (./lab/clab.sh deploy)"),
]


@pytest.fixture
def real_client(settings: Settings) -> Iterator[tuple[TestClient, dict[str, str]]]:
    s = settings.model_copy(
        update={"lab_mode": AdapterMode.REAL, "terraform_mode": TerraformMode.FAKE}
    )
    container = Container.build(
        s, lab=DockerLab(s.lab_prefix), terraform=FakeTerraform(), synchronous_jobs=True
    )
    token = container.auth.issue("it-operator", Role.OPERATOR).access_token
    with TestClient(create_app(s, container)) as c:
        yield c, {"Authorization": f"Bearer {token}"}


def _wait(check: object, timeout: float = 60) -> bool:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if check():  # type: ignore[operator]
            return True
        time.sleep(2)
    return False


def test_real_topology_and_health(real_client: tuple[TestClient, dict[str, str]]) -> None:
    client, auth = real_client
    topo = client.get("/v1/topology", headers=auth).json()
    states = {link["id"]: link["state"] for link in topo["links"] if link["controllable"]}
    assert set(states.values()) == {"up"}
    health = client.get("/v1/devices/hq-core-01/health", headers=auth).json()
    assert health["status"] == "healthy"
    assert len(health["ospf_neighbors"]) == 3
    assert client.get("/v1/alerts", headers=auth).json() == []


def test_real_link_down_and_up(real_client: tuple[TestClient, dict[str, str]]) -> None:
    client, auth = real_client
    try:
        down = client.patch("/v1/links/hq-br2", json={"state": "down"}, headers=auth)
        assert down.status_code == 200
        assert down.json()["state"] == "down"
        assert _wait(
            lambda: any(
                a["kind"] == "ospf_neighbor_missing"
                for a in client.get("/v1/alerts", headers=auth).json()
            )
        )
    finally:
        client.patch("/v1/links/hq-br2", json={"state": "up"}, headers=auth)
    assert _wait(lambda: client.get("/v1/alerts", headers=auth).json() == [], timeout=90)
