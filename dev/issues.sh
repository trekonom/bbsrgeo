#!/usr/bin/env bash
# List the open issues under .scratch/: every issue whose Status line is not
# done or wontfix, sorted by status, so the next piece of work is one call away.
# Usage: dev/issues.sh
set -euo pipefail
cd "$(dirname "$0")/.."

grep -H -m1 '^Status:' .scratch/*/issues/*.md \
  | grep -v -E 'Status: (done|wontfix)$' \
  | sed -E 's#^\.scratch/([^:]+)/issues/([^:]+)\.md:Status: (.*)$#\3\t\1/\2#' \
  | sort
