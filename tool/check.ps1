$ErrorActionPreference = "Stop"
Set-Location (Split-Path -Parent $PSScriptRoot)

# Local quality gate (STANDARDS section 7). Runs the gates for every layer
# that exists. Keep in sync with tool/check.sh and the CI workflows.

function Invoke-Step([string]$Name, [scriptblock]$Command) {
    Write-Host "==> $Name" -ForegroundColor Cyan
    & $Command
    if ($LASTEXITCODE -ne 0) { throw "$Name failed (exit $LASTEXITCODE)" }
}

# Prefer pre-commit on PATH; fall back to the module (pip --user installs
# often leave the Scripts folder off PATH on Windows).
if (Get-Command pre-commit -ErrorAction SilentlyContinue) {
    Invoke-Step "pre-commit (format, YAML/JSON, gitleaks)" { pre-commit run --all-files }
} else {
    Invoke-Step "pre-commit (format, YAML/JSON, gitleaks)" { python -m pre_commit run --all-files }
}

# ---- lab/ (phase 2) ----
# Lab tests need a deployed lab; deploying takes ~30 s, so the gate only runs
# them when the lab is up and says so clearly otherwise.
$running = docker inspect -f '{{.State.Running}}' clab-cnops-hq-core-01 2>$null
if ($running -eq 'true') {
    Invoke-Step "lab: pytest lab/tests" { lab\.venv\Scripts\python -m pytest lab/tests -q -p no:cacheprovider }
} else {
    Write-Host "==> lab: SKIPPED (not deployed). Run: bash lab/clab.sh deploy" -ForegroundColor Yellow
}

# Layer gates still to come:
#   infra/  phase 3: terraform fmt/validate, tflint, checkov, lstk plan
#   api/    phase 4: ruff, mypy --strict, pytest --cov (>= 80%)
#   app/    phase 5: flutter analyze, flutter test --coverage (>= 70%), web build

Write-Host "All checks passed." -ForegroundColor Green
