#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BREWVM_BIN="${REPO_ROOT}/zig-out/bin/brewvm"
PERF_BIN="perf"
PERF_DATA="${REPO_ROOT}/perf.data"
PERF_SCRIPT="${REPO_ROOT}/perf.script"
PERF_FOLDED="${REPO_ROOT}/perf.folded"
PERF_SVG="${REPO_ROOT}/perf.svg"
STACKCOLLAPSE_BIN="stackcollapse-perf.pl"
FLAMEGRAPH_BIN="flamegraph.pl"

if [[ ! -x "${BREWVM_BIN}" ]]; then
  echo "brewvm binary not found at ${BREWVM_BIN}. Build it first (e.g. 'zig build')." >&2
  exit 1
fi

if ! command -v "${PERF_BIN}" >/dev/null 2>&1; then
  echo "perf not found; please install perf (linux-tools) and re-run." >&2
  exit 1
fi

echo "Recording perf profile..."
"${PERF_BIN}" record \
  --freq 999 \
  --call-graph dwarf \
  --output "${PERF_DATA}" \
  -- "${BREWVM_BIN}"

echo
echo "perf.data stored at ${PERF_DATA}"
echo
if command -v "${STACKCOLLAPSE_BIN}" >/dev/null 2>&1 && command -v "${FLAMEGRAPH_BIN}" >/dev/null 2>&1; then
  echo "Generating flamegraph..."
  "${PERF_BIN}" script --input "${PERF_DATA}" > "${PERF_SCRIPT}"
  "${STACKCOLLAPSE_BIN}" "${PERF_SCRIPT}" > "${PERF_FOLDED}"
  "${FLAMEGRAPH_BIN}" "${PERF_FOLDED}" > "${PERF_SVG}"
  echo "Flamegraph written to ${PERF_SVG}"
else
  echo "FlameGraph tools not found (stackcollapse-perf.pl / flamegraph.pl). Skipping SVG generation." >&2
fi
echo
echo "Top hot spots:"
"${PERF_BIN}" report \
  --input "${PERF_DATA}" \
  --stdio \
  --percent-limit 1 \
  --sort overhead_children,overhead,symbol,dso \
  --children

echo
echo "For interactive view run: perf report --input ${PERF_DATA}"
