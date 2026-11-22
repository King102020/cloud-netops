#!/usr/bin/env bash
# App quality gate (STANDARDS §6 and §7). Used by tool/check.* and CI (app.yml).
set -euo pipefail
cd "$(dirname "$0")"

step() { printf '\033[36m==> app: %s\033[0m\n' "$1"; }

step "pub get"
flutter pub get >/dev/null

step "generated client matches api/openapi.json"
dart run swagger_parser >/dev/null
dart run build_runner build --delete-conflicting-outputs >/dev/null 2>&1
git diff --exit-code --stat -- lib/generated || {
  echo "lib/generated is stale: commit the regenerated client" >&2
  exit 1
}

step "dart format"
# Generated code (API client, *.g.dart, l10n) is left exactly as generated.
find lib test integration_test tool -name '*.dart'   -not -path 'lib/generated/*' -not -path 'lib/l10n/gen/*' -not -name '*.g.dart' -print0 |
  xargs -0 dart format --output=none --set-exit-if-changed

step "flutter analyze"
flutter analyze

step "tests + coverage (>= 70% of hand-written code)"
flutter test --coverage --exclude-tags live
dart run tool/coverage_check.dart 70

step "web build"
flutter build web --dart-define-from-file=config/local.json >/dev/null
