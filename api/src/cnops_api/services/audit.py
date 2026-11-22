"""Audit log: every state-changing action records who, what, when and
before/after (STANDARDS §2)."""

from __future__ import annotations

import uuid
from datetime import UTC, datetime
from typing import Any, Literal

from cnops_api.adapters.store import AuditStore
from cnops_api.logging_setup import request_id_var
from cnops_api.models import AuditEvent, Page, Principal


class AuditService:
    def __init__(self, store: AuditStore) -> None:
        self._store = store

    def record(
        self,
        principal: Principal,
        action: str,
        target: str,
        before: dict[str, Any] | None,
        after: dict[str, Any] | None,
        result: Literal["accepted", "succeeded", "failed"],
    ) -> AuditEvent:
        event = AuditEvent(
            id=f"evt-{uuid.uuid4().hex[:12]}",
            at=datetime.now(UTC),
            actor=principal.subject,
            role=principal.role,
            action=action,
            target=target,
            before=before,
            after=after,
            request_id=request_id_var.get(),
            result=result,
        )
        self._store.append(event)
        return event

    def list(
        self, limit: int, cursor: str | None, actor: str | None, action: str | None
    ) -> Page[AuditEvent]:
        items, nxt = self._store.list(limit, cursor, actor, action)
        return Page[AuditEvent](items=items, next_cursor=nxt)
