"""Write the OpenAPI spec that is committed as api/openapi.json (STANDARDS §5).

    python -m cnops_api.openapi_export            # rewrite api/openapi.json
    python -m cnops_api.openapi_export --check    # exit 1 if it is out of date (CI)

The Flutter client is generated from that file.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any

from cnops_api.adapters.terraform import FakeTerraform
from cnops_api.container import Container
from cnops_api.main import create_app
from cnops_api.settings import AdapterMode, Settings, TerraformMode

SPEC_PATH = Path(__file__).resolve().parents[2] / "openapi.json"


def build_spec() -> dict[str, Any]:
    settings = Settings(
        _env_file=None,
        lab_mode=AdapterMode.FAKE,
        store_mode=AdapterMode.FAKE,
        terraform_mode=TerraformMode.FAKE,
    )
    container = Container.build(settings, terraform=FakeTerraform())
    spec: dict[str, Any] = create_app(settings, container).openapi()
    spec["servers"] = [{"url": "http://localhost:8000", "description": "local"}]
    return spec


def render(spec: dict[str, Any]) -> str:
    return json.dumps(spec, indent=2, sort_keys=False, ensure_ascii=False) + "\n"


def main(argv: list[str]) -> int:
    text = render(build_spec())
    if "--check" in argv:
        current = SPEC_PATH.read_text(encoding="utf-8") if SPEC_PATH.exists() else ""
        if current != text:
            print("api/openapi.json is out of date: run python -m cnops_api.openapi_export")
            return 1
        print("api/openapi.json is up to date")
        return 0
    SPEC_PATH.write_text(text, encoding="utf-8", newline="\n")
    print(f"wrote {SPEC_PATH}")
    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main(sys.argv[1:]))
