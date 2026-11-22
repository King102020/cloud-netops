#!/usr/bin/env bash
# API quality gate (STANDARDS §5 and §7): ruff, mypy --strict, pytest >= 80%,
# OpenAPI drift, pip-audit. Used by tool/check.* and CI (.github/workflows/api.yml).
set -euo pipefail
cd "$(dirname "$0")"

PY=.venv/bin/python
[[ -x "$PY" ]] || PY=.venv/Scripts/python
if [[ ! -x "$PY" && ! -x "${PY}.exe" ]]; then
  echo "api: no virtualenv. Run: python -m venv api/.venv && api/.venv/bin/pip install -e 'api[dev]'" >&2
  exit 1
fi

step() { printf '\033[36m==> api: %s\033[0m\n' "$1"; }

step "ruff"
"$PY" -m ruff check src tests
"$PY" -m ruff format --check src tests

step "mypy --strict"
"$PY" -m mypy src tests

step "pytest (coverage >= 80%)"
"$PY" -m pytest

step "OpenAPI spec is committed and current"
"$PY" -m cnops_api.openapi_export --check

if "$PY" -m pip_audit --version >/dev/null 2>&1; then
  step "pip-audit"
  "$PY" -m pip_audit --skip-editable --progress-spinner off
fi
