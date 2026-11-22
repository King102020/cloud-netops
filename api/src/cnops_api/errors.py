"""RFC 9457 Problem Details for every error (STANDARDS §5)."""

from __future__ import annotations

import logging
from http import HTTPStatus
from typing import Any

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field
from starlette.exceptions import HTTPException as StarletteHTTPException

from cnops_api.logging_setup import request_id_var

PROBLEM_JSON = "application/problem+json"
log = logging.getLogger(__name__)


class Problem(BaseModel):
    """RFC 9457 problem details."""

    type: str = Field(default="about:blank", examples=["https://cnops.dev/problems/not-found"])
    title: str
    status: int
    detail: str | None = None
    instance: str | None = None
    request_id: str | None = None
    errors: list[dict[str, Any]] | None = None


class ApiError(Exception):
    """Raise from services; becomes a Problem response."""

    def __init__(self, status: int, slug: str, detail: str) -> None:
        super().__init__(detail)
        self.status = status
        self.slug = slug
        self.detail = detail


class NotFoundError(ApiError):
    def __init__(self, what: str, ident: str) -> None:
        super().__init__(404, "not-found", f"{what} '{ident}' does not exist")


class ConflictError(ApiError):
    def __init__(self, detail: str) -> None:
        super().__init__(409, "conflict", detail)


def problem_response(
    request: Request,
    status: int,
    slug: str,
    detail: str | None,
    errors: list[dict[str, Any]] | None = None,
    headers: dict[str, str] | None = None,
) -> JSONResponse:
    body = Problem(
        type=f"https://cnops.dev/problems/{slug}" if slug != "about:blank" else "about:blank",
        title=HTTPStatus(status).phrase,
        status=status,
        detail=detail,
        instance=request.url.path,
        request_id=request_id_var.get(),
        errors=errors,
    )
    return JSONResponse(
        body.model_dump(exclude_none=True),
        status_code=status,
        media_type=PROBLEM_JSON,
        headers=headers,
    )


PROBLEM_RESPONSES: dict[int | str, dict[str, Any]] = {
    code: {"model": Problem, "content": {PROBLEM_JSON: {}}, "description": HTTPStatus(code).phrase}
    for code in (400, 401, 403, 404, 409, 422)
}


def install(app: FastAPI) -> None:
    @app.exception_handler(ApiError)
    async def _api_error(request: Request, exc: ApiError) -> JSONResponse:
        return problem_response(request, exc.status, exc.slug, exc.detail)

    @app.exception_handler(StarletteHTTPException)
    async def _http_error(request: Request, exc: StarletteHTTPException) -> JSONResponse:
        headers = dict(exc.headers) if exc.headers else None
        return problem_response(
            request, exc.status_code, "about:blank", str(exc.detail), headers=headers
        )

    @app.exception_handler(RequestValidationError)
    async def _validation(request: Request, exc: RequestValidationError) -> JSONResponse:
        errors = [
            {"loc": list(e.get("loc", ())), "msg": e.get("msg", ""), "type": e.get("type", "")}
            for e in exc.errors()
        ]
        return problem_response(request, 422, "validation", "Request validation failed", errors)

    @app.exception_handler(Exception)
    async def _unhandled(request: Request, exc: Exception) -> JSONResponse:
        log.exception("unhandled error")
        return problem_response(
            request, 500, "internal", "Unexpected error; see logs with the request_id"
        )
