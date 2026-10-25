#!/usr/bin/env bash
# List the open GitHub issues with their labels, so the next piece of work is
# one call away. The old issues under .scratch/ are history.
# Usage: dev/issues.sh
set -euo pipefail
cd "$(dirname "$0")/.."

gh issue list --state open \
  --json number,title,labels \
  --jq '.[] | [([.labels[].name] | join(",")), "#\(.number)", .title] | @tsv'
