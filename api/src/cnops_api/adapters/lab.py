"""Router management for the Containerlab lab.

Locally the management path is `docker exec` over the out-of-band network
(see lab/README.md). Commands are argument lists and device/interface names
only ever come from the topology file, never from user input, so there is
no shell injection surface.
"""

from __future__ import annotations

import json
import logging
import os
import subprocess
import threading
from datetime import UTC, datetime
from typing import Literal, Protocol

from cnops_api.models import Interface, OspfNeighbor

log = logging.getLogger(__name__)
LinkState = Literal["up", "down", "unknown"]


class LabError(RuntimeError):
    """A lab command failed or timed out."""


class LabAdapter(Protocol):
    def is_running(self, device: str) -> bool: ...
    def uptime_seconds(self, device: str) -> float | None: ...
    def interfaces(self, device: str) -> list[Interface]: ...
    def ospf_neighbors(self, router: str) -> list[OspfNeighbor]: ...
    def link_state(self, device: str, interface: str) -> LinkState: ...
    def set_interface(self, device: str, interface: str, up: bool) -> None: ...


def parse_ip_json(raw: str) -> list[Interface]:
    """Parse `ip -j addr show` output."""
    result: list[Interface] = []
    for item in json.loads(raw or "[]"):
        name = str(item.get("ifname", ""))
        if not name or name == "lo" or name.startswith("eth0"):
            continue  # loopback / Docker management interface
        address = next(
            (
                f"{a['local']}/{a['prefixlen']}"
                for a in item.get("addr_info", [])
                if a.get("family") == "inet"
            ),
            None,
        )
        oper = str(item.get("operstate", "UNKNOWN")).upper()
        flags = item.get("flags", [])
        state: LinkState
        if oper == "UP" or (oper == "UNKNOWN" and "UP" in flags and "LOWER_UP" in flags):
            state = "up"
        elif oper in {"DOWN", "LOWERLAYERDOWN"} or "UP" not in flags:
            state = "down"
        else:
            state = "unknown"
        result.append(Interface(name=name.split("@")[0], address=address, state=state))
    return result


def parse_ospf_neighbors(raw: str) -> list[OspfNeighbor]:
    """Parse FRR `show ip ospf neighbor json`."""
    data = json.loads(raw or "{}")
    neighbors: list[OspfNeighbor] = []
    for rid, entries in data.get("neighbors", {}).items():
        for e in entries:
            iface = str(e.get("ifaceName", "")).split(":")[0] or None
            neighbors.append(
                OspfNeighbor(
                    router_id=rid,
                    state=str(e.get("nbrState", "unknown")),
                    interface=iface,
                    address=e.get("ifaceAddress"),
                )
            )
    return neighbors


class DockerLab:
    """Talks to the running lab with `docker exec`."""

    def __init__(self, prefix: str, timeout: float = 10.0) -> None:
        self._prefix = prefix
        self._timeout = timeout

    def _docker(self, *args: str) -> str:
        env = {**os.environ, "MSYS_NO_PATHCONV": "1"}
        try:
            proc = subprocess.run(
                ["docker", *args],
                capture_output=True,
                text=True,
                timeout=self._timeout,
                env=env,
                check=False,
            )
        except (OSError, subprocess.TimeoutExpired) as exc:
            raise LabError(f"docker {args[0]} failed: {exc}") from exc
        if proc.returncode != 0:
            raise LabError(proc.stderr.strip() or f"docker exited {proc.returncode}")
        return proc.stdout

    def _exec(self, device: str, *cmd: str) -> str:
        return self._docker("exec", f"{self._prefix}{device}", *cmd)

    def is_running(self, device: str) -> bool:
        try:
            out = self._docker("inspect", "-f", "{{.State.Running}}", f"{self._prefix}{device}")
        except LabError:
            return False
        return out.strip() == "true"

    def uptime_seconds(self, device: str) -> float | None:
        try:
            out = self._docker("inspect", "-f", "{{.State.StartedAt}}", f"{self._prefix}{device}")
            started = datetime.fromisoformat(out.strip().replace("Z", "+00:00")[:32])
        except (LabError, ValueError):
            return None
        return max(0.0, (datetime.now(UTC) - started).total_seconds())

    def interfaces(self, device: str) -> list[Interface]:
        return parse_ip_json(self._exec(device, "ip", "-j", "addr", "show"))

    def ospf_neighbors(self, router: str) -> list[OspfNeighbor]:
        return parse_ospf_neighbors(self._exec(router, "vtysh", "-c", "show ip ospf neighbor json"))

    def link_state(self, device: str, interface: str) -> LinkState:
        try:
            ifaces = parse_ip_json(self._exec(device, "ip", "-j", "addr", "show", "dev", interface))
        except (LabError, json.JSONDecodeError):
            return "unknown"
        return ifaces[0].state if ifaces else "unknown"

    def set_interface(self, device: str, interface: str, up: bool) -> None:
        self._exec(device, "ip", "link", "set", interface, "up" if up else "down")
        log.info(
            "interface changed",
            extra={"fields": {"device": device, "interface": interface, "up": up}},
        )


class FakeLab:
    """In-memory lab: OSPF neighbours disappear when their link is down, so
    the API (and the app) behave like the real thing without Docker."""

    def __init__(self, links: list[tuple[str, str, str, str]], router_ids: dict[str, str]) -> None:
        # links: (device_a, iface_a, device_b, iface_b) for OSPF-enabled links
        self._links = links
        self._router_ids = router_ids
        self._down: set[tuple[str, str]] = set()
        self._stopped: set[str] = set()
        self._lock = threading.Lock()

    def stop_device(self, device: str) -> None:
        self._stopped.add(device)

    def is_running(self, device: str) -> bool:
        return device not in self._stopped

    def uptime_seconds(self, device: str) -> float | None:
        return 3600.0 if self.is_running(device) else None

    def interfaces(self, device: str) -> list[Interface]:
        names = {i for d, i, _, _ in self._links if d == device}
        names |= {i for _, _, d, i in self._links if d == device}
        return [Interface(name=n, state=self.link_state(device, n)) for n in sorted(names)]

    def _link_up(self, a: str, ia: str, b: str, ib: str) -> bool:
        return (
            (a, ia) not in self._down
            and (b, ib) not in self._down
            and self.is_running(a)
            and self.is_running(b)
        )

    def ospf_neighbors(self, router: str) -> list[OspfNeighbor]:
        if not self.is_running(router):
            raise LabError(f"{router} is not running")
        result = []
        for a, ia, b, ib in self._links:
            if router not in (a, b) or not self._link_up(a, ia, b, ib):
                continue
            peer, iface = (b, ia) if router == a else (a, ib)
            if peer in self._router_ids:
                result.append(
                    OspfNeighbor(router_id=self._router_ids[peer], state="Full/-", interface=iface)
                )
        return result

    def link_state(self, device: str, interface: str) -> LinkState:
        for a, ia, b, ib in self._links:
            if (device, interface) in {(a, ia), (b, ib)}:
                return "up" if self._link_up(a, ia, b, ib) else "down"
        return "unknown"

    def set_interface(self, device: str, interface: str, up: bool) -> None:
        with self._lock:
            if up:
                self._down.discard((device, interface))
            else:
                self._down.add((device, interface))
