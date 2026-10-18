#!/usr/bin/env bash
# Static checks: Lua formatting and the install scripts. Run via `make lint`.
# A missing tool is skipped with a warning locally; STRICT=1 (set in CI) makes it a failure.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1

status=0

run() {
  local tool="$1"
  shift
  if ! command -v "$tool" >/dev/null 2>&1; then
    if [[ -n "${STRICT:-}" ]]; then
      echo "FAIL  $tool not installed" >&2
      status=1
    else
      echo "SKIP  $tool not installed"
    fi
    return
  fi
  if "$@"; then
    echo "OK    $*"
  else
    echo "FAIL  $*" >&2
    status=1
  fi
}

run stylua stylua --check .
run shellcheck shellcheck install.sh tests/env.sh tests/lint.sh
run bash bash -n install.sh
run zsh zsh -n install.zsh
run fish fish -n install.fish

exit "$status"
