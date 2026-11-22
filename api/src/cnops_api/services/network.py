"""Topology, device health, alerts and link control (read side + lab)."""

from __future__ import annotations

import json
from datetime import UTC, datetime
from importlib import resources
from typing import Any, TypeVar

from cnops_api.adapters.lab import LabAdapter, LabError
from cnops_api.adapters.store import decode_cursor, encode_cursor
from cnops_api.errors import ApiError, ConflictError, NotFoundError
from cnops_api.models import (
    Alert,
    Device,
    DeviceHealth,
    DeviceRole,
    Link,
    Page,
    Principal,
    SiteInfo,
    Topology,
)
from cnops_api.services.audit import AuditService


def load_design() -> dict[str, Any]:
    raw = resources.files("cnops_api").joinpath("data/topology.json").read_text(encoding="utf-8")
    data: dict[str, Any] = json.loads(raw)
    return data


T = TypeVar("T")


def paginate(items: list[T], limit: int, cursor: str | None) -> Page[T]:
    try:
        start = int(decode_cursor(cursor)["offset"]) if cursor else 0
    except (ValueError, KeyError) as exc:
        raise ApiError(400, "bad-cursor", "cursor is invalid; omit it to start again") from exc
    page = items[start : start + limit]
    nxt = encode_cursor({"offset": start + limit}) if start + limit < len(items) else None
    return Page[T](items=page, next_cursor=nxt)


class NetworkService:
    def __init__(
        self, lab: LabAdapter, audit: AuditService, design: dict[str, Any] | None = None
    ) -> None:
        self._lab = lab
        self._audit = audit
        d = design or load_design()
        self._sites = [SiteInfo.model_validate(s) for s in d["sites"]]
        self._devices = {x["id"]: Device.model_validate(x) for x in d["devices"]}
        self._links = {x["id"]: Link.model_validate(x) for x in d["links"]}
        self._expected: dict[str, list[str]] = d["expected_ospf_neighbors"]
        self._since: dict[str, datetime] = {}

    # ---------------- links ----------------
    def _link_live(self, link: Link) -> Link:
        try:
            a = self._lab.link_state(link.a.device, link.a.interface)
            b = self._lab.link_state(link.b.device, link.b.interface)
        except LabError:
            return link.model_copy(update={"state": "unknown"})
        if "down" in (a, b):
            state = "down"
        elif a == b == "up":
            state = "up"
        else:
            state = "unknown"
        return link.model_copy(update={"state": state})

    def links(self) -> list[Link]:
        return [self._link_live(link) for link in self._links.values()]

    def link(self, link_id: str) -> Link:
        if link_id not in self._links:
            raise NotFoundError("link", link_id)
        return self._link_live(self._links[link_id])

    def set_link_state(self, link_id: str, state: str, principal: Principal) -> Link:
        before = self.link(link_id)
        if not before.controllable:
            raise ConflictError(f"link '{link_id}' cannot be controlled through the API")
        up = state == "up"
        try:
            # Both ends, like "shutdown" on each side: OSPF drops immediately.
            self._lab.set_interface(before.a.device, before.a.interface, up)
            self._lab.set_interface(before.b.device, before.b.interface, up)
        except LabError as exc:
            self._audit.record(
                principal, f"link.{state}", link_id, before.model_dump(mode="json"), None, "failed"
            )
            raise ApiError(502, "lab-unavailable", f"lab command failed: {exc}") from exc
        after = self.link(link_id)
        self._audit.record(
            principal,
            f"link.{state}",
            link_id,
            {"state": before.state},
            {"state": after.state},
            "succeeded",
        )
        return after

    # ---------------- devices ----------------
    def device(self, device_id: str) -> Device:
        dev = self._devices.get(device_id)
        if dev is None:
            raise NotFoundError("device", device_id)
        try:
            live = {i.name: i for i in self._lab.interfaces(device_id)}
        except LabError:
            live = {}
        ifaces = [
            i.model_copy(update={"state": live[i.name].state}) if i.name in live else i
            for i in dev.interfaces
        ]
        return dev.model_copy(update={"interfaces": ifaces})

    def devices(
        self, site: str | None, role: DeviceRole | None, limit: int, cursor: str | None
    ) -> Page[Device]:
        items = [
            d
            for d in self._devices.values()
            if (site is None or d.site == site) and (role is None or d.role == role)
        ]
        return paginate(items, limit, cursor)

    def health(self, device_id: str) -> DeviceHealth:
        dev = self.device(device_id)
        now = datetime.now(UTC)
        running = self._lab.is_running(device_id)
        expected = self._expected.get(device_id, [])
        if not running:
            return DeviceHealth(
                device_id=device_id,
                reachable=False,
                status="down",
                expected_neighbors=expected,
                interfaces=dev.interfaces,
                checked_at=now,
            )
        neighbors = []
        if dev.role is DeviceRole.ROUTER:
            try:
                neighbors = self._lab.ospf_neighbors(device_id)
            except LabError:
                neighbors = []
        full = {n.router_id for n in neighbors if n.state.startswith("Full")}
        ifaces_down = any(i.state == "down" for i in dev.interfaces)
        status = "healthy" if set(expected) <= full and not ifaces_down else "degraded"
        return DeviceHealth(
            device_id=device_id,
            reachable=True,
            status=status,
            uptime_seconds=self._lab.uptime_seconds(device_id),
            ospf_neighbors=neighbors,
            expected_neighbors=expected,
            interfaces=dev.interfaces,
            checked_at=now,
        )

    # ---------------- topology + alerts ----------------
    def topology(self) -> Topology:
        devices = [self.device(d) for d in self._devices]
        return Topology(sites=self._sites, devices=devices, links=self.links())

    def _first_seen(self, key: str, now: datetime) -> datetime:
        return self._since.setdefault(key, now)

    def alerts(self) -> list[Alert]:
        now = datetime.now(UTC)
        alerts: list[Alert] = []
        for dev_id, dev in self._devices.items():
            if dev.role not in (DeviceRole.ROUTER, DeviceRole.SERVER):
                continue
            if not self._lab.is_running(dev_id):
                key = f"device_down:{dev_id}"
                alerts.append(
                    Alert(
                        id=key,
                        severity="critical",
                        kind="device_down",
                        target=dev_id,
                        message=f"{dev_id} is not reachable",
                        since=self._first_seen(key, now),
                    )
                )
        for link in self.links():
            if link.controllable and link.state == "down":
                key = f"link_down:{link.id}"
                sev = "warning" if link.kind == "backup" else "critical"
                alerts.append(
                    Alert(
                        id=key,
                        severity=sev,
                        kind="link_down",
                        target=link.id,
                        message=f"link {link.id} ({link.subnet}) is down",
                        since=self._first_seen(key, now),
                    )
                )
        for router, expected in self._expected.items():
            if not self._lab.is_running(router):
                continue
            try:
                full = {
                    n.router_id
                    for n in self._lab.ospf_neighbors(router)
                    if n.state.startswith("Full")
                }
            except LabError:
                continue
            for missing in sorted(set(expected) - full):
                key = f"ospf:{router}:{missing}"
                alerts.append(
                    Alert(
                        id=key,
                        severity="warning",
                        kind="ospf_neighbor_missing",
                        target=router,
                        message=f"{router} has no OSPF adjacency with {missing}",
                        since=self._first_seen(key, now),
                    )
                )
        active = {a.id for a in alerts}
        for key in list(self._since):
            if key not in active:
                del self._since[key]  # cleared: next occurrence gets a new "since"
        return alerts
