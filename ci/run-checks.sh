#!/usr/bin/env bash
# Single source of truth for CI checks. Runs shellcheck + bats.
# Used both by the justfile (via podman) and by GitHub Actions.
set -euo pipefail

cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."

echo "==> shellcheck"
shellcheck \
  translate.sh \
  render.sh \
  helpers.sh \
  engines/*.sh \
  tests/stubs/herdr tests/stubs/trans tests/stubs/curl \
  tests/stubs/pbpaste tests/stubs/less \
  ci/run-checks.sh

echo "==> bats"
bats tests
