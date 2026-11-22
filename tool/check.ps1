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

# Layer gates are added by the phase that creates the layer:
#   lab/    phase 2: containerlab deploy + lab/tests (runs in WSL)
#   infra/  phase 3: terraform fmt/validate, tflint, checkov, lstk plan
#   api/    phase 4: ruff, mypy --strict, pytest --cov (>= 80%)
#   app/    phase 5: flutter analyze, flutter test --coverage (>= 70%), web build

Write-Host "All checks passed." -ForegroundColor Green
