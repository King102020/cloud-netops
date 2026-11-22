from __future__ import annotations

import uuid
from collections.abc import Iterator
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from cnops_api.adapters.lab import FakeLab
from cnops_api.adapters.terraform import FakeTerraform
from cnops_api.container import Container, fake_lab
from cnops_api.main import create_app
from cnops_api.models import Role
from cnops_api.services.network import load_design
from cnops_api.settings import AdapterMode, Settings, TerraformMode


@pytest.fixture
def settings(tmp_path: Path) -> Settings:
    return Settings(
        _env_file=None,
        lab_mode=AdapterMode.FAKE,
        store_mode=AdapterMode.FAKE,
        terraform_mode=TerraformMode.FAKE,
        terraform_dir=tmp_path / "envs-local",
        jwt_secret="test-secret-at-least-32-bytes-long!!",
    )


@pytest.fixture
def lab() -> FakeLab:
    return fake_lab(load_design())


@pytest.fixture
def terraform() -> FakeTerraform:
    return FakeTerraform()


@pytest.fixture
def container(settings: Settings, lab: FakeLab, terraform: FakeTerraform) -> Container:
    return Container.build(settings, lab=lab, terraform=terraform, synchronous_jobs=True)


@pytest.fixture
def client(settings: Settings, container: Container) -> Iterator[TestClient]:
    with TestClient(create_app(settings, container)) as c:
        yield c


def bearer(container: Container, role: Role, subject: str | None = None) -> dict[str, str]:
    token = container.auth.issue(subject or role.value, role)
    return {"Authorization": f"Bearer {token.access_token}"}


@pytest.fixture
def viewer(container: Container) -> dict[str, str]:
    return bearer(container, Role.VIEWER)


@pytest.fixture
def operator(container: Container) -> dict[str, str]:
    return bearer(container, Role.OPERATOR)


@pytest.fixture
def admin(container: Container) -> dict[str, str]:
    return bearer(container, Role.ADMIN)


def idem() -> dict[str, str]:
    return {"Idempotency-Key": uuid.uuid4().hex}


RULE = {
    "site": "hq",
    "tier": "servers",
    "protocol": "tcp",
    "from_port": 8443,
    "to_port": 8443,
    "cidr": "10.20.10.0/24",
    "description": "br1 users to app port",
}
