"""App factory. Run: `uvicorn --factory cnops_api.main:create_app --port 8000`."""

from __future__ import annotations

import logging
import time
import uuid
from collections.abc import AsyncIterator, Awaitable, Callable
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request, Response
from fastapi.middleware.cors import CORSMiddleware

from cnops_api import __version__, errors
from cnops_api.container import Container
from cnops_api.logging_setup import configure_logging, request_id_var
from cnops_api.routers import changes, network, system
from cnops_api.settings import Settings, get_settings

log = logging.getLogger("cnops_api.access")

DESCRIPTION = """
Control API for the Cloud NetOps network (docs/network-design.md).

* **Read:** topology, devices, health, links, alerts, subnets, firewall rules, audit log.
* **Change:** firewall rules and subnets go through **Terraform** (202 + job);
  links are taken up/down on the lab routers.
* **Auth:** `POST /v1/auth/token`, then `Authorization: Bearer <jwt>`.
  Roles: viewer < operator < admin.
* **Errors:** RFC 9457 `application/problem+json`.
"""


def create_app(settings: Settings | None = None, container: Container | None = None) -> FastAPI:
    settings = settings or get_settings()
    configure_logging(settings.log_level)
    container = container or Container.build(settings)

    @asynccontextmanager
    async def lifespan(_: FastAPI) -> AsyncIterator[None]:
        container.jobs.start()
        yield
        container.jobs.stop()

    app = FastAPI(
        title="Cloud NetOps API",
        version=__version__,
        description=DESCRIPTION,
        lifespan=lifespan,
        openapi_tags=[
            {"name": "system"},
            {"name": "auth"},
            {"name": "topology"},
            {"name": "devices"},
            {"name": "links"},
            {"name": "alerts"},
            {"name": "firewall"},
            {"name": "subnets"},
            {"name": "jobs"},
            {"name": "audit"},
        ],
    )
    app.state.container = container
    errors.install(app)

    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins,
        allow_methods=["GET", "POST", "PATCH", "DELETE"],
        allow_headers=["Authorization", "Content-Type", "Idempotency-Key", "X-Request-ID"],
        expose_headers=["X-Request-ID", "Idempotent-Replayed"],
    )

    @app.middleware("http")
    async def request_context(
        request: Request, call_next: Callable[[Request], Awaitable[Response]]
    ) -> Response:
        incoming = request.headers.get("X-Request-ID", "")
        rid = incoming if 8 <= len(incoming) <= 64 and incoming.isascii() else uuid.uuid4().hex
        token = request_id_var.set(rid)
        start = time.perf_counter()
        try:
            response = await call_next(request)
        finally:
            request_id_var.reset(token)
        response.headers["X-Request-ID"] = rid
        response.headers["Cache-Control"] = "no-store"
        response.headers["X-Content-Type-Options"] = "nosniff"
        log.info(
            "request",
            extra={
                "fields": {
                    "request_id": rid,
                    "method": request.method,
                    "path": request.url.path,
                    "status": response.status_code,
                    "ms": round((time.perf_counter() - start) * 1000, 1),
                }
            },
        )
        return response

    app.include_router(system.router)
    app.include_router(network.router)
    app.include_router(changes.router)
    return app


def run() -> None:  # pragma: no cover - thin CLI wrapper
    import uvicorn

    s = get_settings()
    uvicorn.run(create_app(s), host="127.0.0.1", port=8000, log_config=None)
