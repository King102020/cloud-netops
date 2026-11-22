from __future__ import annotations

import time

import jwt
import pytest
from fastapi.testclient import TestClient
from pydantic import ValidationError

from cnops_api.container import Container
from cnops_api.models import Role
from cnops_api.settings import Settings


def test_healthz(client: TestClient) -> None:
    r = client.get("/healthz")
    assert r.status_code == 200
    assert r.json() == {"status": "ok", "checks": {}}
    assert len(r.headers["X-Request-ID"]) >= 8


def test_request_id_is_echoed(client: TestClient) -> None:
    r = client.get("/healthz", headers={"X-Request-ID": "trace-abc-123"})
    assert r.headers["X-Request-ID"] == "trace-abc-123"


def test_readyz_ok_with_fakes(client: TestClient) -> None:
    r = client.get("/readyz")
    assert r.status_code == 200
    assert r.json()["checks"] == {"audit_store": "ok", "lab": "ok", "terraform": "ok"}


def test_readyz_degraded_when_lab_down(client: TestClient, lab: object) -> None:
    lab.stop_device("hq-core-01")  # type: ignore[attr-defined]
    r = client.get("/readyz")
    assert r.status_code == 503
    assert r.json()["checks"]["lab"] == "unreachable"


@pytest.mark.parametrize(
    ("user", "password", "role"),
    [
        ("viewer", "viewer-local", "viewer"),
        ("operator", "operator-local", "operator"),
        ("admin", "admin-local", "admin"),
    ],
)
def test_login_issues_role_token(client: TestClient, user: str, password: str, role: str) -> None:
    r = client.post("/v1/auth/token", json={"username": user, "password": password})
    assert r.status_code == 200
    body = r.json()
    assert body["role"] == role
    assert body["token_type"] == "bearer"
    me = client.get("/v1/topology", headers={"Authorization": f"Bearer {body['access_token']}"})
    assert me.status_code == 200


def test_login_rejects_bad_password(client: TestClient) -> None:
    r = client.post("/v1/auth/token", json={"username": "admin", "password": "nope"})
    assert r.status_code == 401
    assert r.headers["content-type"].startswith("application/problem+json")
    assert r.headers["WWW-Authenticate"].startswith("Bearer")


def test_login_rejects_unknown_user(client: TestClient) -> None:
    r = client.post("/v1/auth/token", json={"username": "mallory", "password": "x"})
    assert r.status_code == 401


def test_login_is_rate_limited(client: TestClient) -> None:
    for _ in range(5):
        client.post("/v1/auth/token", json={"username": "admin", "password": "wrong"})
    r = client.post("/v1/auth/token", json={"username": "admin", "password": "admin-local"})
    assert r.status_code == 429
    assert r.headers["Retry-After"] == "60"


def test_missing_token_is_401_problem(client: TestClient) -> None:
    r = client.get("/v1/topology")
    assert r.status_code == 401
    body = r.json()
    assert body["status"] == 401
    assert body["instance"] == "/v1/topology"
    assert "request_id" in body


def test_expired_token_is_rejected(client: TestClient, container: Container) -> None:
    token = container.auth.issue("old", Role.ADMIN, ttl=-10).access_token
    r = client.get("/v1/topology", headers={"Authorization": f"Bearer {token}"})
    assert r.status_code == 401
    assert "expired" in r.json()["detail"].lower()


def test_token_with_wrong_secret_is_rejected(client: TestClient) -> None:
    forged = jwt.encode(
        {
            "sub": "x",
            "role": "admin",
            "iss": "cnops-local",
            "aud": "cnops-api",
            "iat": int(time.time()),
            "exp": int(time.time()) + 60,
        },
        "a-different-secret-of-sufficient-length",
        algorithm="HS256",
    )
    r = client.get("/v1/topology", headers={"Authorization": f"Bearer {forged}"})
    assert r.status_code == 401


def test_alg_none_token_is_rejected(client: TestClient) -> None:
    unsigned = jwt.encode(
        {
            "sub": "x",
            "role": "admin",
            "iss": "cnops-local",
            "aud": "cnops-api",
            "iat": int(time.time()),
            "exp": int(time.time()) + 60,
        },
        key=None,  # type: ignore[arg-type]  # alg=none needs no key: that is the attack
        algorithm="none",
    )
    r = client.get("/v1/topology", headers={"Authorization": f"Bearer {unsigned}"})
    assert r.status_code == 401


def test_settings_refuse_real_aws_endpoint() -> None:
    with pytest.raises(ValidationError, match="local address"):
        Settings(_env_file=None, aws_endpoint_url="https://dynamodb.ap-south-1.amazonaws.com")


def test_unknown_route_is_problem_json(client: TestClient) -> None:
    r = client.get("/nope")
    assert r.status_code == 404
    assert r.headers["content-type"].startswith("application/problem+json")
