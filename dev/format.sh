#!/usr/bin/env bash
# Format the package's R code with air. Falls back to the copy bundled with
# Positron when air is not on the PATH.
# Usage: dev/format.sh [--check]
set -euo pipefail
cd "$(dirname "$0")/.."

if command -v air >/dev/null 2>&1; then
  air_bin=air
else
  air_bin=$(ls ~/.positron/extensions/posit.air-vscode-*/bundled/bin/air 2>/dev/null | tail -n 1 || true)
  if [ -z "$air_bin" ]; then
    echo "air not found on PATH or in the Positron extensions folder." >&2
    exit 1
  fi
fi

"$air_bin" format "$@" R tests dev data-raw
