"""Firewall rules and subnets: validate, write the Terraform inputs, queue a
Terraform job, audit everything. Never calls the AWS SDK (STANDARDS §5)."""

from __future__ import annotations

import ipaddress
import uuid
from datetime import UTC, datetime
from typing import Any

from cnops_api.errors import ConflictError, NotFoundError
from cnops_api.models import (
    ChangeStatus,
    FirewallRule,
    FirewallRuleCreate,
    Job,
    Page,
    Principal,
    Subnet,
    SubnetCreate,
)
from cnops_api.services.audit import AuditService
from cnops_api.services.jobs import JobRunner
from cnops_api.services.network import paginate
from cnops_api.services.repository import ManagedInputs


class ChangeService:
    def __init__(
        self,
        inputs: ManagedInputs,
        jobs: JobRunner,
        audit: AuditService,
        design: dict[str, Any],
    ) -> None:
        self._inputs = inputs
        self._jobs = jobs
        self._audit = audit
        self._vpc_cidrs = {s["id"]: s["cloud_cidr"] for s in design["sites"] if s["cloud_cidr"]}
        self._base_subnets = [
            Subnet.model_validate({**s, "status": ChangeStatus.APPLIED, "managed": False})
            for s in design["base_subnets"]
        ]
        self._reserved = [ipaddress.ip_network(c) for c in design["reserved_cidrs"]]

    # ---------------- shared ----------------
    def _apply(self, reason: str, principal: Principal, action: str, target: str) -> Job:
        def done(job: Job, outcome: ChangeStatus) -> None:
            self._set_status(job.id, outcome)
            self._audit.record(
                principal,
                f"{action}.terraform",
                target,
                None,
                {"job_id": job.id, "mode": job.mode, "status": outcome.value},
                "succeeded" if outcome is not ChangeStatus.FAILED else "failed",
            )

        return self._jobs.submit(reason, done)

    def _set_status(self, job_id: str, status: ChangeStatus) -> None:
        with self._inputs.lock:
            rules = self._inputs.rules()
            if any(r.job_id == job_id for r in rules):
                self._inputs.save_rules(
                    [
                        r.model_copy(update={"status": status}) if r.job_id == job_id else r
                        for r in rules
                    ]
                )
            subnets = self._inputs.subnets()
            if any(s.job_id == job_id for s in subnets):
                self._inputs.save_subnets(
                    [
                        s.model_copy(update={"status": status}) if s.job_id == job_id else s
                        for s in subnets
                    ]
                )

    # ---------------- firewall rules ----------------
    def list_rules(
        self, site: str | None, tier: str | None, limit: int, cursor: str | None
    ) -> Page[FirewallRule]:
        rules = [
            r
            for r in self._inputs.rules()
            if (site is None or r.site == site) and (tier is None or r.tier == tier)
        ]
        return paginate(rules, limit, cursor)

    def get_rule(self, rule_id: str) -> FirewallRule:
        for r in self._inputs.rules():
            if r.id == rule_id:
                return r
        raise NotFoundError("firewall rule", rule_id)

    def create_rule(self, body: FirewallRuleCreate, principal: Principal) -> FirewallRule:
        with self._inputs.lock:
            rules = self._inputs.rules()
            same = [
                r
                for r in rules
                if (r.site, r.tier, r.protocol, r.from_port, r.to_port, r.cidr)
                == (body.site, body.tier, body.protocol, body.from_port, body.to_port, body.cidr)
            ]
            if same:
                raise ConflictError(f"an identical rule already exists: {same[0].id}")
            rule = FirewallRule(
                **body.model_dump(),
                id=f"fw-{uuid.uuid4().hex[:8]}",
                created_at=datetime.now(UTC),
                created_by=principal.subject,
            )
            self._inputs.save_rules([*rules, rule])
        self._audit.record(
            principal,
            "firewall_rule.create",
            rule.id,
            None,
            rule.model_dump(mode="json"),
            "accepted",
        )
        # Hold the lock across submit + attach: the job's completion callback
        # needs the same lock, so it cannot run before the job ID is attached.
        with self._inputs.lock:
            job = self._apply(
                f"create firewall rule {rule.id}", principal, "firewall_rule.create", rule.id
            )
            return self._attach_job(rule.id, job)

    def set_rule_enabled(self, rule_id: str, enabled: bool, principal: Principal) -> FirewallRule:
        before = self.get_rule(rule_id)
        with self._inputs.lock:
            rules = [
                r.model_copy(update={"enabled": enabled, "status": ChangeStatus.PENDING})
                if r.id == rule_id
                else r
                for r in self._inputs.rules()
            ]
            self._inputs.save_rules(rules)
        self._audit.record(
            principal,
            "firewall_rule.update",
            rule_id,
            {"enabled": before.enabled},
            {"enabled": enabled},
            "accepted",
        )
        with self._inputs.lock:
            job = self._apply(
                f"{'enable' if enabled else 'disable'} firewall rule {rule_id}",
                principal,
                "firewall_rule.update",
                rule_id,
            )
            return self._attach_job(rule_id, job)

    def delete_rule(self, rule_id: str, principal: Principal) -> Job:
        before = self.get_rule(rule_id)
        with self._inputs.lock:
            self._inputs.save_rules([r for r in self._inputs.rules() if r.id != rule_id])
        self._audit.record(
            principal,
            "firewall_rule.delete",
            rule_id,
            before.model_dump(mode="json"),
            None,
            "accepted",
        )
        return self._apply(
            f"delete firewall rule {rule_id}", principal, "firewall_rule.delete", rule_id
        )

    def _attach_job(self, rule_id: str, job: Job) -> FirewallRule:
        with self._inputs.lock:
            rules = self._inputs.rules()
            for i, r in enumerate(rules):
                # The job may already have finished (synchronous mode) and set status.
                if r.id == rule_id and r.job_id != job.id:
                    rules[i] = r.model_copy(update={"job_id": job.id})
            self._inputs.save_rules(rules)
        if job.finished_at is not None:
            self._set_status(job.id, self._outcome(job))
        return self.get_rule(rule_id)

    def _outcome(self, job: Job) -> ChangeStatus:
        if job.state.value == "failed":
            return ChangeStatus.FAILED
        return ChangeStatus.PLANNED if job.mode == "plan" else ChangeStatus.APPLIED

    # ---------------- subnets ----------------
    def list_subnets(self, site: str | None, limit: int, cursor: str | None) -> Page[Subnet]:
        items = [*self._base_subnets, *self._inputs.subnets()]
        items = [s for s in items if site is None or s.site == site]
        return paginate(items, limit, cursor)

    def create_subnet(self, body: SubnetCreate, principal: Principal) -> Subnet:
        net = ipaddress.ip_network(body.cidr_block)
        vpc = ipaddress.ip_network(self._vpc_cidrs[body.site])
        if not net.subnet_of(vpc):  # type: ignore[arg-type]
            raise ConflictError(f"{net} is outside the {body.site} VPC {vpc}")
        if not 16 <= net.prefixlen <= 28:
            raise ConflictError("AWS subnets must be between /16 and /28")
        with self._inputs.lock:
            existing = [*self._base_subnets, *self._inputs.subnets()]
            for s in existing:
                if s.site == body.site and s.name == body.name:
                    raise ConflictError(f"{body.site} already has a subnet named {body.name}")
                if net.overlaps(ipaddress.ip_network(s.cidr_block)):
                    raise ConflictError(f"{net} overlaps {s.site} {s.name} ({s.cidr_block})")
            for r in self._reserved:
                if net.overlaps(r):
                    raise ConflictError(f"{net} overlaps reserved range {r}")
            subnet = Subnet(**body.model_dump())
            self._inputs.save_subnets([*self._inputs.subnets(), subnet])
        target = f"{body.site}/{body.name}"
        self._audit.record(
            principal, "subnet.create", target, None, subnet.model_dump(mode="json"), "accepted"
        )
        with self._inputs.lock:
            job = self._apply(f"create subnet {target}", principal, "subnet.create", target)
            subnets = self._inputs.subnets()
            for i, s in enumerate(subnets):
                if s.site == body.site and s.name == body.name and s.job_id != job.id:
                    subnets[i] = s.model_copy(update={"job_id": job.id})
            self._inputs.save_subnets(subnets)
            if job.finished_at is not None:
                self._set_status(job.id, self._outcome(job))
        return next(
            s for s in self._inputs.subnets() if s.site == body.site and s.name == body.name
        )
