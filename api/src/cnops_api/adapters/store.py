"""Audit log and idempotency key storage: DynamoDB (LocalStack) or memory."""

from __future__ import annotations

import base64
import json
import threading
import time
from dataclasses import dataclass
from typing import TYPE_CHECKING, Any, Protocol

from cnops_api.models import AuditEvent

if TYPE_CHECKING:
    from mypy_boto3_dynamodb.service_resource import Table


@dataclass(frozen=True)
class IdempotencyRecord:
    fingerprint: str
    status_code: int
    body: str
    expires_at: int


class AuditStore(Protocol):
    def append(self, event: AuditEvent) -> None: ...
    def list(
        self, limit: int, cursor: str | None, actor: str | None, action: str | None
    ) -> tuple[list[AuditEvent], str | None]: ...
    def ping(self) -> bool: ...


class IdempotencyStore(Protocol):
    def get(self, key: str) -> IdempotencyRecord | None: ...
    def put(self, key: str, record: IdempotencyRecord) -> None: ...


def encode_cursor(value: dict[str, Any]) -> str:
    return base64.urlsafe_b64encode(json.dumps(value).encode()).decode()


def decode_cursor(cursor: str) -> dict[str, Any]:
    try:
        data = json.loads(base64.urlsafe_b64decode(cursor.encode()))
    except (ValueError, json.JSONDecodeError) as exc:
        msg = "invalid cursor"
        raise ValueError(msg) from exc
    if not isinstance(data, dict):
        msg = "invalid cursor"
        raise ValueError(msg)
    return data


# ---------------- In-memory ----------------
class MemoryAuditStore:
    def __init__(self) -> None:
        self._events: list[AuditEvent] = []
        self._lock = threading.Lock()

    def append(self, event: AuditEvent) -> None:
        with self._lock:
            self._events.append(event)

    def list(
        self, limit: int, cursor: str | None, actor: str | None, action: str | None
    ) -> tuple[list[AuditEvent], str | None]:
        with self._lock:
            events = sorted(self._events, key=lambda e: (e.at, e.id), reverse=True)
        events = [
            e
            for e in events
            if (actor is None or e.actor == actor) and (action is None or e.action == action)
        ]
        start = int(decode_cursor(cursor)["offset"]) if cursor else 0
        page = events[start : start + limit]
        nxt = encode_cursor({"offset": start + limit}) if start + limit < len(events) else None
        return page, nxt

    def ping(self) -> bool:
        return True


class MemoryIdempotencyStore:
    def __init__(self) -> None:
        self._items: dict[str, IdempotencyRecord] = {}

    def get(self, key: str) -> IdempotencyRecord | None:
        rec = self._items.get(key)
        if rec and rec.expires_at < time.time():
            self._items.pop(key, None)
            return None
        return rec

    def put(self, key: str, record: IdempotencyRecord) -> None:
        self._items[key] = record


# ---------------- DynamoDB ----------------
AUDIT_PK = "AUDIT"


class DynamoAuditStore:
    """pk = "AUDIT", sk = "<ISO time>#<id>": a single partition is plenty for
    a lab and keeps queries newest-first without a scan."""

    def __init__(self, table: Table) -> None:
        self._table = table

    def append(self, event: AuditEvent) -> None:
        item = json.loads(event.model_dump_json())
        item.update(pk=AUDIT_PK, sk=f"{event.at.isoformat()}#{event.id}")
        # DynamoDB rejects empty maps in some SDKs; store before/after as JSON strings.
        item["before"] = json.dumps(item.get("before"))
        item["after"] = json.dumps(item.get("after"))
        self._table.put_item(Item=item)

    def list(
        self, limit: int, cursor: str | None, actor: str | None, action: str | None
    ) -> tuple[list[AuditEvent], str | None]:
        from boto3.dynamodb.conditions import Attr, ConditionBase, Key

        kwargs: dict[str, Any] = {
            "KeyConditionExpression": Key("pk").eq(AUDIT_PK),
            "ScanIndexForward": False,
            "Limit": limit,
        }
        filters = []
        if actor:
            filters.append(Attr("actor").eq(actor))
        if action:
            filters.append(Attr("action").eq(action))
        if filters:
            expr: ConditionBase = filters[0]
            for f in filters[1:]:
                expr = expr & f
            kwargs["FilterExpression"] = expr
        if cursor:
            kwargs["ExclusiveStartKey"] = decode_cursor(cursor)
        resp = self._table.query(**kwargs)
        events = []
        for raw in resp.get("Items", []):
            item = dict(raw)
            item["before"] = json.loads(str(item.get("before", "null")))
            item["after"] = json.loads(str(item.get("after", "null")))
            events.append(AuditEvent.model_validate(item))
        last = resp.get("LastEvaluatedKey")
        return events, encode_cursor(dict(last)) if last else None

    def ping(self) -> bool:
        try:
            self._table.load()
        except Exception:
            return False
        return True


class DynamoIdempotencyStore:
    def __init__(self, table: Table) -> None:
        self._table = table

    def get(self, key: str) -> IdempotencyRecord | None:
        item = self._table.get_item(Key={"key": key}).get("Item")
        if not item or int(str(item["expires_at"])) < time.time():
            return None
        return IdempotencyRecord(
            fingerprint=str(item["fingerprint"]),
            status_code=int(str(item["status_code"])),
            body=str(item["body"]),
            expires_at=int(str(item["expires_at"])),
        )

    def put(self, key: str, record: IdempotencyRecord) -> None:
        self._table.put_item(
            Item={
                "key": key,
                "fingerprint": record.fingerprint,
                "status_code": record.status_code,
                "body": record.body,
                "expires_at": record.expires_at,
            }
        )
