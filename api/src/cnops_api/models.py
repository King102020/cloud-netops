"""API schemas (Pydantic v2). Boundary validation mirrors the Terraform
validation blocks, so bad input is rejected twice (STANDARDS §2)."""

from __future__ import annotations

import ipaddress
from datetime import datetime
from enum import StrEnum
from typing import Annotated, Any, Generic, Literal, TypeVar

from pydantic import AfterValidator, BaseModel, ConfigDict, Field, model_validator

T = TypeVar("T")

Site = Literal["hq", "br1", "br2"]
Tier = Literal["users", "servers", "mgmt"]


class Role(StrEnum):
    VIEWER = "viewer"
    OPERATOR = "operator"
    ADMIN = "admin"


class Strict(BaseModel):
    model_config = ConfigDict(extra="forbid")


class Page(BaseModel, Generic[T]):
    """Cursor pagination: pass next_cursor back as ?cursor= until it is null."""

    items: list[T]
    next_cursor: str | None = None


# ---------------- Auth ----------------
class TokenRequest(Strict):
    username: Annotated[str, Field(min_length=1, max_length=64)]
    password: Annotated[str, Field(min_length=1, max_length=256)]


class Token(BaseModel):
    access_token: str
    token_type: Literal["bearer"] = "bearer"  # noqa: S105 - OAuth token type, not a secret
    expires_in: int
    role: Role


class Principal(BaseModel):
    subject: str
    role: Role


# ---------------- Topology ----------------
class DeviceRole(StrEnum):
    ROUTER = "router"
    SERVER = "server"
    HOST = "host"
    ISP = "isp"


class Interface(BaseModel):
    name: str
    address: str | None = None
    description: str | None = None
    state: Literal["up", "down", "unknown"] = "unknown"


class Device(BaseModel):
    id: str = Field(examples=["hq-core-01"])
    site: str
    role: DeviceRole
    model: str = Field(description="Packet Tracer model / lab image")
    mgmt_ip: str | None = None
    router_id: str | None = None
    interfaces: list[Interface] = []


class LinkKind(StrEnum):
    WAN = "wan"
    BACKUP = "backup"
    TRANSIT = "transit"
    ISP = "isp"
    LAN = "lan"


class LinkEnd(BaseModel):
    device: str
    interface: str
    address: str | None = None


class Link(BaseModel):
    id: str = Field(examples=["hq-br2"])
    kind: LinkKind
    a: LinkEnd
    b: LinkEnd
    subnet: str
    ospf_cost: int | None = None
    state: Literal["up", "down", "unknown"] = "unknown"
    controllable: bool = Field(description="Can be taken up/down through the API")


class SiteInfo(BaseModel):
    id: str
    name: str
    cidr: str
    cloud_cidr: str | None
    ospf_area: int | None


class Topology(BaseModel):
    sites: list[SiteInfo]
    devices: list[Device]
    links: list[Link]


class LinkStateChange(Strict):
    state: Literal["up", "down"]


# ---------------- Health ----------------
class OspfNeighbor(BaseModel):
    router_id: str
    state: str
    interface: str | None = None
    address: str | None = None


class DeviceHealth(BaseModel):
    device_id: str
    reachable: bool
    status: Literal["healthy", "degraded", "down"]
    uptime_seconds: float | None = None
    ospf_neighbors: list[OspfNeighbor] = []
    expected_neighbors: list[str] = []
    interfaces: list[Interface] = []
    checked_at: datetime


class Alert(BaseModel):
    id: str
    severity: Literal["critical", "warning"]
    kind: Literal["device_down", "link_down", "ospf_neighbor_missing"]
    target: str
    message: str
    since: datetime


# ---------------- Firewall rules ----------------
class ChangeStatus(StrEnum):
    PENDING = "pending"  # written to Terraform inputs, apply queued
    APPLIED = "applied"
    PLANNED = "planned"  # terraform_mode=plan: validated by a plan, not applied
    FAILED = "failed"


def _check_cidr(v: str) -> str:
    net = ipaddress.ip_network(v, strict=True)  # raises ValueError on host bits
    if net.version != 4:
        msg = "only IPv4 is supported"
        raise ValueError(msg)
    if net.prefixlen == 0:
        msg = "0.0.0.0/0 is not allowed (default deny)"
        raise ValueError(msg)
    if not net.is_private:
        msg = "source must be a private (RFC 1918) network"
        raise ValueError(msg)
    return str(net)


PrivateCidr = Annotated[str, AfterValidator(_check_cidr)]


class FirewallRuleCreate(Strict):
    site: Site
    tier: Tier
    protocol: Literal["tcp", "udp", "icmp"]
    from_port: Annotated[int, Field(ge=-1, le=65535)] = Field(description="ICMP: type (8 = echo)")
    to_port: Annotated[int, Field(ge=-1, le=65535)] = Field(description="ICMP: code (0)")
    cidr: PrivateCidr = Field(examples=["10.20.10.0/24"])
    description: Annotated[str, Field(min_length=3, max_length=200, pattern=r"^[\w .,:/()+-]+$")]
    enabled: bool = True

    @model_validator(mode="after")
    def _ports(self) -> FirewallRuleCreate:
        if self.protocol != "icmp" and not (1 <= self.from_port <= self.to_port <= 65535):
            msg = "ports must be 1-65535 with from_port <= to_port"
            raise ValueError(msg)
        return self


class FirewallRule(FirewallRuleCreate):
    model_config = ConfigDict(extra="ignore")

    id: str = Field(examples=["fw-3f2a9c1b"])
    status: ChangeStatus = ChangeStatus.PENDING
    job_id: str | None = None
    created_at: datetime
    created_by: str


class FirewallRulePatch(Strict):
    enabled: bool


# ---------------- Subnets ----------------
class SubnetCreate(Strict):
    site: Site
    name: Annotated[str, Field(pattern=r"^(users|servers|mgmt)-[ab]$")] = Field(
        examples=["servers-a"]
    )
    cidr_block: PrivateCidr = Field(examples=["10.120.20.0/24"])
    az: Literal["a", "b"]
    tier: Tier

    @model_validator(mode="after")
    def _consistent(self) -> SubnetCreate:
        if not self.name.startswith(self.tier) or not self.name.endswith(self.az):
            msg = "name must be <tier>-<az>"
            raise ValueError(msg)
        return self


class Subnet(SubnetCreate):
    model_config = ConfigDict(extra="ignore")

    status: ChangeStatus = ChangeStatus.PENDING
    job_id: str | None = None
    managed: bool = Field(default=True, description="false = part of the base design")


# ---------------- Jobs ----------------
class JobState(StrEnum):
    QUEUED = "queued"
    RUNNING = "running"
    SUCCEEDED = "succeeded"
    FAILED = "failed"


class Job(BaseModel):
    id: str
    kind: Literal["terraform"]
    mode: str
    state: JobState
    reason: str
    created_at: datetime
    finished_at: datetime | None = None
    summary: str | None = Field(
        default=None, examples=["Plan: 1 to add, 0 to change, 0 to destroy."]
    )
    output_tail: str | None = None


# ---------------- Audit ----------------
class AuditEvent(BaseModel):
    id: str
    at: datetime
    actor: str
    role: Role
    action: str = Field(examples=["firewall_rule.create"])
    target: str
    before: dict[str, Any] | None = None
    after: dict[str, Any] | None = None
    request_id: str
    result: Literal["accepted", "succeeded", "failed"]


class HealthStatus(BaseModel):
    status: Literal["ok", "degraded"]
    checks: dict[str, str] = {}
