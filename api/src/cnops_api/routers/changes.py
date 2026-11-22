from __future__ import annotations

from typing import Annotated, Any

from fastapi import APIRouter, Path, Query, Request
from fastapi.responses import JSONResponse

from cnops_api.auth import Admin, Operator, Viewer
from cnops_api.errors import PROBLEM_RESPONSES
from cnops_api.idempotency import IdempotencyKey, idempotent
from cnops_api.models import (
    AuditEvent,
    FirewallRule,
    FirewallRuleCreate,
    FirewallRulePatch,
    Job,
    Page,
    Subnet,
    SubnetCreate,
)
from cnops_api.routers import Cursor, Deps, Limit

router = APIRouter(prefix="/v1", responses=PROBLEM_RESPONSES)
RuleId = Annotated[str, Path(pattern=r"^fw-[0-9a-f]{8}$")]
SiteQ = Annotated[str | None, Query(pattern=r"^(hq|br1|br2)$")]
ACCEPTED: dict[int | str, dict[str, Any]] = {
    202: {"description": "Accepted: a Terraform job was queued"}
}


# ---------------- firewall rules ----------------
@router.get("/firewall-rules", tags=["firewall"], summary="List API-managed firewall rules")
def list_rules(
    c: Deps,
    _: Viewer,
    limit: Limit = 50,
    cursor: Cursor = None,
    site: SiteQ = None,
    tier: Annotated[str | None, Query(pattern=r"^(users|servers|mgmt)$")] = None,
) -> Page[FirewallRule]:
    return c.changes.list_rules(site, tier, limit, cursor)


@router.get("/firewall-rules/{rule_id}", tags=["firewall"], summary="One firewall rule")
def get_rule(rule_id: RuleId, c: Deps, _: Viewer) -> FirewallRule:
    return c.changes.get_rule(rule_id)


@router.post(
    "/firewall-rules",
    tags=["firewall"],
    status_code=202,
    response_model=FirewallRule,
    responses=ACCEPTED,
    summary="Add a security-group rule (operator). Applied through Terraform.",
)
def create_rule(
    request: Request,
    body: FirewallRuleCreate,
    key: IdempotencyKey,
    c: Deps,
    principal: Operator,
) -> JSONResponse:
    return idempotent(
        request, principal, key, body, 202, lambda: c.changes.create_rule(body, principal)
    )


@router.patch(
    "/firewall-rules/{rule_id}",
    tags=["firewall"],
    status_code=202,
    responses=ACCEPTED,
    summary="Enable or disable a rule (operator). Applied through Terraform.",
)
def patch_rule(
    rule_id: RuleId, body: FirewallRulePatch, c: Deps, principal: Operator
) -> FirewallRule:
    return c.changes.set_rule_enabled(rule_id, body.enabled, principal)


@router.delete(
    "/firewall-rules/{rule_id}",
    tags=["firewall"],
    status_code=202,
    responses=ACCEPTED,
    summary="Remove a rule (operator). Applied through Terraform.",
)
def delete_rule(rule_id: RuleId, c: Deps, principal: Operator) -> Job:
    return c.changes.delete_rule(rule_id, principal)


# ---------------- subnets ----------------
@router.get("/subnets", tags=["subnets"], summary="Cloud subnets: base design + API-managed")
def list_subnets(
    c: Deps, _: Viewer, limit: Limit = 50, cursor: Cursor = None, site: SiteQ = None
) -> Page[Subnet]:
    return c.changes.list_subnets(site, limit, cursor)


@router.post(
    "/subnets",
    tags=["subnets"],
    status_code=202,
    response_model=Subnet,
    responses=ACCEPTED,
    summary="Create a subnet in a site's VPC (admin). Applied through Terraform.",
)
def create_subnet(
    request: Request, body: SubnetCreate, key: IdempotencyKey, c: Deps, principal: Admin
) -> JSONResponse:
    return idempotent(
        request, principal, key, body, 202, lambda: c.changes.create_subnet(body, principal)
    )


# ---------------- jobs + audit ----------------
@router.get("/jobs/{job_id}", tags=["jobs"], summary="Terraform job status")
def get_job(job_id: Annotated[str, Path(pattern=r"^job-[0-9a-f]{8}$")], c: Deps, _: Viewer) -> Job:
    return c.jobs.get(job_id)


@router.get("/audit-events", tags=["audit"], summary="Audit log, newest first")
def audit_events(
    c: Deps,
    _: Viewer,
    limit: Limit = 50,
    cursor: Cursor = None,
    actor: Annotated[str | None, Query(max_length=64)] = None,
    action: Annotated[str | None, Query(max_length=64)] = None,
) -> Page[AuditEvent]:
    try:
        return c.audit.list(limit, cursor, actor, action)
    except ValueError as exc:
        from cnops_api.errors import ApiError

        raise ApiError(400, "bad-cursor", "cursor is invalid; omit it to start again") from exc
