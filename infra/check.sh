#!/usr/bin/env bash
# Terraform quality gate (STANDARDS §4 and §7). Offline: no LocalStack needed.
# Used by tool/check.sh, tool/check.ps1 and CI (.github/workflows/infra.yml).
set -euo pipefail
cd "$(dirname "$0")"

TFLINT_IMAGE="ghcr.io/terraform-linters/tflint:v0.60.0"
CHECKOV_IMAGE="bridgecrew/checkov:3.4.6"

# Docker on Windows (Git Bash) needs a Windows-style path for bind mounts.
if command -v cygpath >/dev/null 2>&1; then HERE="$(cygpath -m "$PWD")"; else HERE="$PWD"; fi
export MSYS_NO_PATHCONV=1

step() { printf '\033[36m==> infra: %s\033[0m\n' "$1"; }

step "terraform fmt -check"
terraform fmt -check -recursive

step "terraform init + validate (envs/local)"
terraform -chdir=envs/local init -input=false -no-color >/dev/null
terraform -chdir=envs/local validate -no-color

step "terraform test (mocked provider)"
terraform -chdir=envs/local test -no-color

step "tflint"
docker run --rm -v "$HERE:/data" -w /data --entrypoint sh "$TFLINT_IMAGE" \
  -c 'tflint --init >/dev/null && tflint --recursive --config /data/.tflint.hcl'

step "checkov"
docker run --rm -v "$HERE:/data" "$CHECKOV_IMAGE" \
  -d /data --framework terraform --quiet --compact
