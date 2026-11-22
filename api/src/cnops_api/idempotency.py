"""Idempotency keys for state-changing POSTs (STANDARDS §5).

Same key + same body  -> the stored response is replayed (header Idempotent-Replayed: true).
Same key + other body -> 422: the key was reused for a different request.
Keys are scoped per user and kept for 24 hours.
"""

from __future__ import annotations

import hashlib
import json
import time
from collections.abc import Callable
from typing import Annotated

from fastapi import Header, HTTPException, Request
from fastapi.responses import JSONResponse
from pydantic import BaseModel

from cnops_api.adapters.store import IdempotencyRecord, IdempotencyStore
from cnops_api.models import Principal

TTL_SECONDS = 24 * 3600

IdempotencyKey = Annotated[
    str,
    Header(
        alias="Idempotency-Key",
        min_length=8,
        max_length=128,
        pattern=r"^[A-Za-z0-9_.:-]+$",
        description="Unique per logical request, e.g. a UUID. Retries must reuse it.",
    ),
]


def _store(request: Request) -> IdempotencyStore:
    store: IdempotencyStore = request.app.state.container.idempotency
    return store


def idempotent(
    request: Request,
    principal: Principal,
    key: str,
    body: BaseModel,
    status_code: int,
    handler: Callable[[], BaseModel],
) -> JSONResponse:
    store = _store(request)
    scoped = f"{principal.subject}:{request.url.path}:{key}"
    fingerprint = hashlib.sha256(body.model_dump_json().encode()).hexdigest()
    existing = store.get(scoped)
    if existing is not None:
        if existing.fingerprint != fingerprint:
            raise HTTPException(
                422, "Idempotency-Key was already used with a different request body"
            )
        return JSONResponse(
            json.loads(existing.body),
            status_code=existing.status_code,
            headers={"Idempotent-Replayed": "true"},
        )
    result = handler()
    payload = result.model_dump_json()
    store.put(
        scoped,
        IdempotencyRecord(
            fingerprint=fingerprint,
            status_code=status_code,
            body=payload,
            expires_at=int(time.time()) + TTL_SECONDS,
        ),
    )
    return JSONResponse(json.loads(payload), status_code=status_code)
