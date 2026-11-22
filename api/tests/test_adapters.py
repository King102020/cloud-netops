"""Adapter unit tests: parsers, safe Terraform env, async job runner, DynamoDB (moto)."""

from __future__ import annotations

import json
import subprocess
import time
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

import boto3
import pytest
from moto import mock_aws

from cnops_api.adapters.lab import DockerLab, LabError, parse_ip_json, parse_ospf_neighbors
from cnops_api.adapters.store import (
    DynamoAuditStore,
    DynamoIdempotencyStore,
    IdempotencyRecord,
    MemoryIdempotencyStore,
)
from cnops_api.adapters.terraform import CliTerraform, FakeTerraform, safe_env
from cnops_api.models import AuditEvent, ChangeStatus, Job, Role
from cnops_api.services.jobs import JobRunner
from cnops_api.settings import TerraformMode

IP_JSON = json.dumps(
    [
        {"ifname": "lo", "operstate": "UNKNOWN", "flags": ["LOOPBACK", "UP"], "addr_info": []},
        {"ifname": "eth0", "operstate": "UP", "flags": ["UP"], "addr_info": []},
        {
            "ifname": "eth1@if12",
            "operstate": "UP",
            "flags": ["UP", "LOWER_UP"],
            "addr_info": [{"family": "inet", "local": "10.255.0.2", "prefixlen": 30}],
        },
        {"ifname": "eth3", "operstate": "DOWN", "flags": ["BROADCAST"], "addr_info": []},
        {"ifname": "mgmt99", "operstate": "UNKNOWN", "flags": ["UP", "LOWER_UP"], "addr_info": []},
    ]
)


def test_parse_ip_json() -> None:
    ifaces = {i.name: i for i in parse_ip_json(IP_JSON)}
    assert set(ifaces) == {"eth1", "eth3", "mgmt99"}  # lo and eth0 (mgmt) hidden
    assert ifaces["eth1"].address == "10.255.0.2/30"
    assert ifaces["eth1"].state == "up"
    assert ifaces["eth3"].state == "down"
    assert ifaces["mgmt99"].state == "up"  # dummy interfaces report UNKNOWN


def test_parse_ospf_neighbors() -> None:
    raw = json.dumps(
        {
            "neighbors": {
                "10.255.255.3": [
                    {
                        "nbrState": "Full/-",
                        "ifaceName": "eth2:10.255.0.5",
                        "ifaceAddress": "10.255.0.6",
                    }
                ]
            }
        }
    )
    [n] = parse_ospf_neighbors(raw)
    assert (n.router_id, n.state, n.interface, n.address) == (
        "10.255.255.3",
        "Full/-",
        "eth2",
        "10.255.0.6",
    )


class FakeRun:
    def __init__(self, outputs: dict[str, tuple[int, str]]) -> None:
        self.outputs = outputs
        self.calls: list[list[str]] = []

    def __call__(self, cmd: list[str], **_: Any) -> subprocess.CompletedProcess[str]:
        self.calls.append(cmd)
        for needle, (rc, out) in self.outputs.items():
            if needle in " ".join(cmd):
                return subprocess.CompletedProcess(cmd, rc, out, "boom" if rc else "")
        return subprocess.CompletedProcess(cmd, 0, "", "")


def test_docker_lab_commands(monkeypatch: pytest.MonkeyPatch) -> None:
    started = datetime.now(UTC).isoformat()
    fake = FakeRun(
        {
            "{{.State.Running}}": (0, "true\n"),
            "{{.State.StartedAt}}": (0, started),
            "vtysh": (0, '{"neighbors": {}}'),
            "ip -j addr show": (0, IP_JSON),
        }
    )
    monkeypatch.setattr(subprocess, "run", fake)
    lab = DockerLab("clab-cnops-")
    assert lab.is_running("hq-core-01")
    uptime = lab.uptime_seconds("hq-core-01")
    assert uptime is not None
    assert uptime < 5
    assert lab.ospf_neighbors("hq-core-01") == []
    assert lab.link_state("hq-core-01", "eth1") == "up"
    lab.set_interface("hq-core-01", "eth3", up=False)
    assert fake.calls[-1] == [
        "docker", "exec", "clab-cnops-hq-core-01", "ip", "link", "set", "eth3", "down",
    ]  # fmt: skip
    # No shell anywhere: every call is an argument list.
    assert all(isinstance(c, list) for c in fake.calls)


def test_docker_lab_errors(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(subprocess, "run", FakeRun({"docker": (1, "")}))
    lab = DockerLab("clab-cnops-")
    assert lab.is_running("x") is False
    assert lab.uptime_seconds("x") is None
    assert lab.link_state("x", "eth1") == "unknown"
    with pytest.raises(LabError):
        lab.interfaces("x")

    def boom(*_: Any, **__: Any) -> None:
        raise subprocess.TimeoutExpired("docker", 1)

    monkeypatch.setattr(subprocess, "run", boom)
    with pytest.raises(LabError, match="failed"):
        lab.ospf_neighbors("x")


def test_safe_env_strips_real_aws(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("AWS_PROFILE", "prod")
    monkeypatch.setenv("AWS_SESSION_TOKEN", "real-token")
    monkeypatch.setenv("AWS_ACCESS_KEY_ID", "AKIAREALKEY")
    env = safe_env()
    assert "AWS_PROFILE" not in env
    assert "AWS_SESSION_TOKEN" not in env
    assert env["AWS_ACCESS_KEY_ID"] == "test"


@pytest.mark.parametrize(
    ("mode", "rc", "ok"),
    [
        (TerraformMode.APPLY, 0, True),
        (TerraformMode.APPLY, 1, False),
        (TerraformMode.PLAN, 2, True),  # -detailed-exitcode: changes present
        (TerraformMode.PLAN, 1, False),
    ],
)
def test_cli_terraform(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path, mode: TerraformMode, rc: int, ok: bool
) -> None:
    fake = FakeRun({"init": (0, "ok"), "apply": (rc, "applied"), "plan": (rc, "planned")})
    monkeypatch.setattr(subprocess, "run", fake)
    tf = CliTerraform(tmp_path, mode, "terraform", 60)
    assert tf.mode == mode.value
    assert tf.run().ok is ok
    tf.run()
    assert sum(1 for c in fake.calls if "init" in c) == 1  # init only once
    verb = "apply" if mode is TerraformMode.APPLY else "plan"
    assert any(verb in c for c in fake.calls)


def test_cli_terraform_init_failure_and_missing_binary(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    monkeypatch.setattr(subprocess, "run", FakeRun({"init": (1, "no provider")}))
    assert CliTerraform(tmp_path, TerraformMode.PLAN, "terraform", 60).run().ok is False

    def missing(*_: Any, **__: Any) -> None:
        raise FileNotFoundError("terraform")

    monkeypatch.setattr(subprocess, "run", missing)
    res = CliTerraform(tmp_path, TerraformMode.PLAN, "terraform", 60).run()
    assert res.ok is False
    assert "could not run" in res.output
    with pytest.raises(ValueError, match="fake"):
        CliTerraform(tmp_path, TerraformMode.FAKE, "terraform", 60)


def test_async_job_runner_runs_in_background() -> None:
    runner = JobRunner(FakeTerraform())
    done: list[tuple[Job, ChangeStatus]] = []
    runner.start()
    try:
        job = runner.submit("test", lambda j, s: done.append((j, s)))
        deadline = time.monotonic() + 5
        while not done and time.monotonic() < deadline:
            time.sleep(0.01)
        assert done
        assert done[0][1] is ChangeStatus.APPLIED
        assert runner.get(job.id).state == "succeeded"
    finally:
        runner.stop()


def test_memory_idempotency_expiry() -> None:
    store = MemoryIdempotencyStore()
    store.put("k", IdempotencyRecord("f", 202, "{}", expires_at=int(time.time()) - 1))
    assert store.get("k") is None


@mock_aws
def test_dynamodb_stores() -> None:
    ddb = boto3.resource("dynamodb", region_name="ap-south-1")
    audit_t = ddb.create_table(
        TableName="audit",
        KeySchema=[
            {"AttributeName": "pk", "KeyType": "HASH"},
            {"AttributeName": "sk", "KeyType": "RANGE"},
        ],
        AttributeDefinitions=[
            {"AttributeName": "pk", "AttributeType": "S"},
            {"AttributeName": "sk", "AttributeType": "S"},
        ],
        BillingMode="PAY_PER_REQUEST",
    )
    idem_t = ddb.create_table(
        TableName="idem",
        KeySchema=[{"AttributeName": "key", "KeyType": "HASH"}],
        AttributeDefinitions=[{"AttributeName": "key", "AttributeType": "S"}],
        BillingMode="PAY_PER_REQUEST",
    )
    audit = DynamoAuditStore(audit_t)
    assert audit.ping()
    for i, actor in enumerate(["alice", "bob", "alice"]):
        audit.append(
            AuditEvent(
                id=f"evt-{i}",
                at=datetime(2026, 11, 22, 10, i, tzinfo=UTC),
                actor=actor,
                role=Role.OPERATOR,
                action="link.down",
                target="hq-br2",
                before={"state": "up"},
                after={"state": "down"},
                request_id="r",
                result="succeeded",
            )
        )
    page, nxt = audit.list(2, None, None, None)
    assert [e.id for e in page] == ["evt-2", "evt-1"]  # newest first
    assert page[0].before == {"state": "up"}
    rest, _ = audit.list(2, nxt, None, None)
    assert [e.id for e in rest] == ["evt-0"]
    alice, _ = audit.list(10, None, "alice", "link.down")
    assert {e.actor for e in alice} == {"alice"}

    idem = DynamoIdempotencyStore(idem_t)
    assert idem.get("missing") is None
    idem.put("k", IdempotencyRecord("fp", 202, '{"a": 1}', int(time.time()) + 60))
    assert idem.get("k") == IdempotencyRecord("fp", 202, '{"a": 1}', idem.get("k").expires_at)  # type: ignore[union-attr]
    assert DynamoAuditStore(ddb.Table("does-not-exist")).ping() is False
