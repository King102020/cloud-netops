from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Path, Query

from cnops_api.auth import Operator, Viewer
from cnops_api.errors import PROBLEM_RESPONSES
from cnops_api.models import (
    Alert,
    Device,
    DeviceHealth,
    DeviceRole,
    Link,
    LinkStateChange,
    Page,
    Topology,
)
from cnops_api.routers import Cursor, Deps, Limit

router = APIRouter(prefix="/v1", responses=PROBLEM_RESPONSES)
DeviceId = Annotated[str, Path(pattern=r"^[a-z0-9-]{3,32}$", examples=["hq-core-01"])]
LinkId = Annotated[str, Path(pattern=r"^[a-z0-9-]{3,32}$", examples=["hq-br2"])]


@router.get("/topology", tags=["topology"], summary="Sites, devices and links with live state")
def topology(c: Deps, _: Viewer) -> Topology:
    return c.network.topology()


@router.get("/devices", tags=["devices"], summary="List devices")
def list_devices(
    c: Deps,
    _: Viewer,
    limit: Limit = 50,
    cursor: Cursor = None,
    site: Annotated[str | None, Query(pattern=r"^[a-z0-9]{2,8}$")] = None,
    role: DeviceRole | None = None,
) -> Page[Device]:
    return c.network.devices(site, role, limit, cursor)


@router.get("/devices/{device_id}", tags=["devices"], summary="Device detail with live interfaces")
def get_device(device_id: DeviceId, c: Deps, _: Viewer) -> Device:
    return c.network.device(device_id)


@router.get(
    "/devices/{device_id}/health", tags=["devices"], summary="Reachability and OSPF neighbours"
)
def device_health(device_id: DeviceId, c: Deps, _: Viewer) -> DeviceHealth:
    return c.network.health(device_id)


@router.get("/links", tags=["links"], summary="List links with live state")
def list_links(c: Deps, _: Viewer) -> list[Link]:
    return c.network.links()


@router.get("/links/{link_id}", tags=["links"], summary="One link")
def get_link(link_id: LinkId, c: Deps, _: Viewer) -> Link:
    return c.network.link(link_id)


@router.patch(
    "/links/{link_id}",
    tags=["links"],
    summary="Take a link up or down (operator). OSPF reroutes around it.",
)
def set_link(link_id: LinkId, body: LinkStateChange, c: Deps, principal: Operator) -> Link:
    return c.network.set_link_state(link_id, body.state, principal)


@router.get("/alerts", tags=["alerts"], summary="Active alerts from live health checks")
def alerts(c: Deps, _: Viewer) -> list[Alert]:
    return c.network.alerts()
