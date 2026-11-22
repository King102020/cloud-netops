#!/usr/bin/env bash
# Local quality gate (STANDARDS section 7). Runs the gates for every layer
# that exists. Keep in sync with tool/check.ps1 and the CI workflows.
set -euo pipefail
cd "$(dirname "$0")/.."

step() {
  printf '\033[36m==> %s\033[0m\n' "$1"
  shift
  "$@"
}

if command -v pre-commit >/dev/null 2>&1; then
  PRE_COMMIT=(pre-commit)
else
  PRE_COMMIT=(python3 -m pre_commit)
fi
step "pre-commit (format, YAML/JSON, gitleaks)" "${PRE_COMMIT[@]}" run --all-files

# ---- lab/ (phase 2) ----
# Lab tests need a deployed lab; deploying takes ~30 s, so the gate only runs
# them when the lab is up and says so clearly otherwise.
LAB_PY=lab/.venv/bin/python
[[ -x "$LAB_PY" ]] || LAB_PY=lab/.venv/Scripts/python
if [[ "$(docker inspect -f '{{.State.Running}}' clab-cnops-hq-core-01 2>/dev/null)" == "true" ]]; then
  step "lab: pytest lab/tests" "$LAB_PY" -m pytest lab/tests -q -p no:cacheprovider
else
  printf '\033[33m==> lab: SKIPPED (not deployed). Run: ./lab/clab.sh deploy\033[0m\n'
fi

# ---- infra/ (phase 3) ---- offline: fmt, validate, terraform test, tflint, checkov
step "infra" bash infra/check.sh

# ---- api/ (phase 4) ---- ruff, mypy --strict, pytest >= 80%, OpenAPI drift, pip-audit
step "api" bash api/check.sh

# ---- app/ (phase 5) ---- format, analyze, tests + coverage >= 70%, client drift, web build
step "app" bash app/check.sh

printf '\033[32mAll checks passed.\033[0m\n'
