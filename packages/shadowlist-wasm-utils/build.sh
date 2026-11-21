#!/usr/bin/env bash
set -uo pipefail
# Builds the utility binary and the TypeScript into dist/. Prints only errors and the result.
#   ./build.sh [Release|Debug]
# Emscripten comes from the PATH or from emsdk at $EMSDK (default ~/emsdk).
# The engine checkout is $SHADOWLIST_ROOT (default ../shadowlist next to this repository).
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
CONFIG="${1:-Release}"
SHADOWLIST_ROOT="${SHADOWLIST_ROOT:-$REPO/../shadowlist}"
[[ -d "$SHADOWLIST_ROOT/packages/shadowlist-core" ]] || {
  echo "BUILD FAILED: no shadowlist engine checkout at $SHADOWLIST_ROOT, set SHADOWLIST_ROOT"
  exit 1
}
SHADOWLIST_ROOT="$(cd "$SHADOWLIST_ROOT" && pwd)"
if ! command -v emcmake >/dev/null; then
  # shellcheck disable=SC1091
  source "${EMSDK:-$HOME/emsdk}/emsdk_env.sh" >/dev/null 2>&1
fi
command -v emcmake >/dev/null || { echo "BUILD FAILED: emcmake not found, install emsdk"; exit 1; }
# TypeScript from this repository, or from the engine checkout before yarn install ran here.
TSC="$REPO/node_modules/.bin/tsc"
[[ -x "$TSC" ]] || TSC="$SHADOWLIST_ROOT/node_modules/.bin/tsc"
[[ -x "$TSC" ]] || { echo "BUILD FAILED: tsc not found, run yarn install"; exit 1; }
mkdir -p "$HERE/build" "$HERE/dist"
{
  emcmake cmake -S "$HERE/cpp" -B "$HERE/build/$CONFIG" -DCMAKE_BUILD_TYPE="$CONFIG" -DSHADOWLIST_ROOT="$SHADOWLIST_ROOT" &&
    cmake --build "$HERE/build/$CONFIG" -j 8
} > "$HERE/build/log.txt" 2>&1
STATUS=$?
if [[ $STATUS == 0 ]]; then
  cp "$HERE/build/$CONFIG/shadowlistutils.mjs" "$HERE/build/$CONFIG/shadowlistutils.wasm" "$HERE/src/shadowlistutils.d.mts" "$HERE/dist/"
  "$TSC" -b "$HERE/tsconfig.json" >> "$HERE/build/log.txt" 2>&1
  STATUS=$?
fi
grep -E "error" "$HERE/build/log.txt" | sort -u | cut -c1-260 | head -40
[[ $STATUS == 0 ]] && echo "BUILD OK: $HERE/dist" || echo "BUILD FAILED ($STATUS)"
exit $STATUS
