"""Terraform: the only way the API changes cloud infrastructure (STANDARDS §5).

The API writes the managed inputs (JSON) that infra/envs/local reads, then
runs plan or apply. The child process gets LocalStack dummy credentials and
no AWS profile, on top of the endpoint guard inside the Terraform env.
"""

from __future__ import annotations

import json
import os
import subprocess
import threading
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Protocol

from cnops_api.settings import TerraformMode

# Variables that could point a child process at a real AWS account.
_AWS_ENV_BLOCKLIST = (
    "AWS_PROFILE",
    "AWS_DEFAULT_PROFILE",
    "AWS_SESSION_TOKEN",
    "AWS_SECURITY_TOKEN",
    "AWS_ROLE_ARN",
    "AWS_WEB_IDENTITY_TOKEN_FILE",
    "AWS_CONFIG_FILE",
    "AWS_SHARED_CREDENTIALS_FILE",
)


@dataclass(frozen=True)
class TerraformResult:
    ok: bool
    output: str


class TerraformRunner(Protocol):
    @property
    def mode(self) -> str: ...
    def run(self) -> TerraformResult: ...


def write_json_atomic(path: Path, data: list[dict[str, Any]]) -> None:
    """Write via a temp file + rename so Terraform never reads half a file."""
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(data, indent=2, default=str) + "\n", encoding="utf-8")
    os.replace(tmp, path)


def safe_env() -> dict[str, str]:
    env = {k: v for k, v in os.environ.items() if k not in _AWS_ENV_BLOCKLIST}
    env.update(
        AWS_ACCESS_KEY_ID="test",
        AWS_SECRET_ACCESS_KEY="test",  # noqa: S106 - LocalStack dummy value
        AWS_EC2_METADATA_DISABLED="true",
        TF_IN_AUTOMATION="1",
        TF_INPUT="0",
    )
    return env


class CliTerraform:
    def __init__(self, workdir: Path, mode: TerraformMode, binary: str, timeout: int) -> None:
        if mode is TerraformMode.FAKE:
            msg = "use FakeTerraform for fake mode"
            raise ValueError(msg)
        self._workdir = workdir
        self._mode = mode
        self._binary = binary
        self._timeout = timeout
        self._initialised = False
        self._lock = threading.Lock()

    @property
    def mode(self) -> str:
        return self._mode.value

    def _cmd(self, *args: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [self._binary, f"-chdir={self._workdir}", *args],
            capture_output=True,
            text=True,
            timeout=self._timeout,
            env=safe_env(),
            check=False,
        )

    def run(self) -> TerraformResult:
        with self._lock:  # one terraform at a time (state lock is local)
            try:
                if not self._initialised:
                    init = self._cmd("init", "-input=false", "-no-color")
                    if init.returncode != 0:
                        return TerraformResult(False, init.stdout + init.stderr)
                    self._initialised = True
                if self._mode is TerraformMode.APPLY:
                    proc = self._cmd("apply", "-auto-approve", "-input=false", "-no-color")
                else:
                    proc = self._cmd("plan", "-input=false", "-no-color", "-detailed-exitcode")
            except (OSError, subprocess.TimeoutExpired) as exc:
                return TerraformResult(False, f"terraform could not run: {exc}")
        # plan -detailed-exitcode: 0 = no changes, 2 = changes present (both fine)
        ok = proc.returncode == 0 or (self._mode is TerraformMode.PLAN and proc.returncode == 2)
        return TerraformResult(ok, proc.stdout + proc.stderr)


@dataclass
class FakeTerraform:
    """Records runs; set `fail_next` to simulate a failed apply."""

    runs: int = 0
    fail_next: bool = False
    outputs: list[str] = field(default_factory=list)

    @property
    def mode(self) -> str:
        return TerraformMode.FAKE.value

    def run(self) -> TerraformResult:
        self.runs += 1
        if self.fail_next:
            self.fail_next = False
            return TerraformResult(False, "Error: simulated failure")
        return TerraformResult(True, "Apply complete! (fake)")
