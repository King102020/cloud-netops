"""API-managed Terraform inputs: infra/envs/local/.cnops/{firewall_rules,subnets}.json.

These files are the source of truth for what the API added. Terraform reads
the fields it needs and ignores the rest (status, job_id, created_by)."""

from __future__ import annotations

import json
import threading
from pathlib import Path
from typing import Any

from cnops_api.adapters.terraform import write_json_atomic
from cnops_api.models import FirewallRule, Subnet


class ManagedInputs:
    def __init__(self, managed_dir: Path) -> None:
        self._dir = managed_dir
        self.lock = threading.RLock()

    @property
    def rules_file(self) -> Path:
        return self._dir / "firewall_rules.json"

    @property
    def subnets_file(self) -> Path:
        return self._dir / "subnets.json"

    @staticmethod
    def _read(path: Path) -> list[dict[str, Any]]:
        if not path.exists():
            return []
        data = json.loads(path.read_text(encoding="utf-8") or "[]")
        return data if isinstance(data, list) else []

    def rules(self) -> list[FirewallRule]:
        with self.lock:
            return [FirewallRule.model_validate(r) for r in self._read(self.rules_file)]

    def save_rules(self, rules: list[FirewallRule]) -> None:
        with self.lock:
            write_json_atomic(self.rules_file, [r.model_dump(mode="json") for r in rules])

    def subnets(self) -> list[Subnet]:
        with self.lock:
            return [Subnet.model_validate(s) for s in self._read(self.subnets_file)]

    def save_subnets(self, subnets: list[Subnet]) -> None:
        with self.lock:
            write_json_atomic(
                self.subnets_file,
                [s.model_dump(mode="json", exclude={"managed"}) for s in subnets],
            )
