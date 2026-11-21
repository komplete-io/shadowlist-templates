#!/usr/bin/env bash
set -euo pipefail
# Generates the Xcode project from project.yml. The kit and the core come from the engine
# checkout at SHADOWLIST_ROOT, default ../../../shadowlist (a shadowlist folder next to this repo).
#   ./generate.sh
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${SHADOWLIST_ROOT:-$HERE/../../../shadowlist}"
[[ -d "$ROOT/packages/shadowlist-core" ]] || {
  echo "shadowlist engine checkout not found at $ROOT. Clone it next to this repository or set SHADOWLIST_ROOT." >&2
  exit 1
}
# XcodeGen nests the groups of an absolute path under this folder. The path goes in relative.
export SHADOWLIST_ROOT="$(python3 -c 'import os, sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))' "$(cd "$ROOT" && pwd)" "$HERE")"
cd "$HERE" && xcodegen generate --quiet
