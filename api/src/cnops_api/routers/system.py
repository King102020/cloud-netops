from __future__ import annotations

import shutil

from fastapi import APIRouter
from fastapi.responses import JSONResponse

from cnops_api.models import HealthStatus, Token, TokenRequest
from cnops_api.routers import Deps

router = APIRouter()


@router.get("/healthz", tags=["system"], summary="Liveness: the process is up")
def healthz() -> HealthStatus:
    return HealthStatus(status="ok")


@router.get(
    "/readyz",
    tags=["system"],
    summary="Readiness: dependencies are reachable",
    response_model=HealthStatus,
    responses={503: {"model": HealthStatus}},
)
def readyz(c: Deps) -> HealthStatus | JSONResponse:
    checks = {
        "audit_store": "ok" if c.audit_store.ping() else "unreachable",
        "lab": "ok" if c.lab.is_running("hq-core-01") else "unreachable",
        "terraform": "ok"
        if c.terraform.mode == "fake" or shutil.which(c.settings.terraform_bin)
        else "missing",
    }
    if all(v == "ok" for v in checks.values()):
        return HealthStatus(status="ok", checks=checks)
    body = HealthStatus(status="degraded", checks=checks)
    return JSONResponse(body.model_dump(), status_code=503)


@router.post(
    "/v1/auth/token",
    tags=["auth"],
    summary="Log in (local issuer) and get a JWT",
    responses={401: {"description": "Bad credentials"}, 429: {"description": "Too many attempts"}},
)
def login(body: TokenRequest, c: Deps) -> Token:
    return c.auth.login(body.username, body.password)
