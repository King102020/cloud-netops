"""Composition root: builds adapters and services from Settings."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from cnops_api.adapters.lab import DockerLab, FakeLab, LabAdapter
from cnops_api.adapters.store import (
    AuditStore,
    DynamoAuditStore,
    DynamoIdempotencyStore,
    IdempotencyStore,
    MemoryAuditStore,
    MemoryIdempotencyStore,
)
from cnops_api.adapters.terraform import CliTerraform, FakeTerraform, TerraformRunner
from cnops_api.auth import Authenticator
from cnops_api.services.audit import AuditService
from cnops_api.services.changes import ChangeService
from cnops_api.services.jobs import JobRunner
from cnops_api.services.network import NetworkService, load_design
from cnops_api.services.repository import ManagedInputs
from cnops_api.settings import AdapterMode, Settings, TerraformMode


def fake_lab(design: dict[str, Any]) -> FakeLab:
    ospf_kinds = {"wan", "backup", "transit"}
    links = [
        (x["a"]["device"], x["a"]["interface"], x["b"]["device"], x["b"]["interface"])
        for x in design["links"]
        if x["kind"] in ospf_kinds
    ]
    router_ids = {d["id"]: d["router_id"] for d in design["devices"] if d.get("router_id")}
    return FakeLab(links, router_ids)


@dataclass
class Container:
    settings: Settings
    auth: Authenticator
    lab: LabAdapter
    terraform: TerraformRunner
    audit_store: AuditStore
    idempotency: IdempotencyStore
    jobs: JobRunner
    audit: AuditService
    network: NetworkService
    changes: ChangeService

    @classmethod
    def build(
        cls,
        settings: Settings,
        lab: LabAdapter | None = None,
        terraform: TerraformRunner | None = None,
        synchronous_jobs: bool = False,
    ) -> Container:
        design = load_design()
        if lab is None:
            lab = (
                DockerLab(settings.lab_prefix)
                if settings.lab_mode is AdapterMode.REAL
                else fake_lab(design)
            )
        if terraform is None:
            terraform = (
                FakeTerraform()
                if settings.terraform_mode is TerraformMode.FAKE
                else CliTerraform(
                    settings.terraform_dir,
                    settings.terraform_mode,
                    settings.terraform_bin,
                    settings.terraform_timeout_seconds,
                )
            )
        audit_store: AuditStore
        idem: IdempotencyStore
        if settings.store_mode is AdapterMode.REAL:
            import boto3

            ddb = boto3.resource(
                "dynamodb",
                endpoint_url=settings.aws_endpoint_url,
                region_name=settings.aws_region,
                aws_access_key_id="test",
                aws_secret_access_key="test",  # noqa: S106 - LocalStack dummy value
            )
            audit_store = DynamoAuditStore(ddb.Table(settings.audit_table))
            idem = DynamoIdempotencyStore(ddb.Table(settings.idempotency_table))
        else:
            audit_store, idem = MemoryAuditStore(), MemoryIdempotencyStore()
        audit = AuditService(audit_store)
        jobs = JobRunner(terraform, synchronous=synchronous_jobs)
        return cls(
            settings=settings,
            auth=Authenticator(settings),
            lab=lab,
            terraform=terraform,
            audit_store=audit_store,
            idempotency=idem,
            jobs=jobs,
            audit=audit,
            network=NetworkService(lab, audit, design),
            changes=ChangeService(ManagedInputs(settings.managed_dir), jobs, audit, design),
        )
