#!/usr/bin/env bash
# Usage: scripts/coverage_check.sh <min-percent>
# Fails if line coverage of lib/features/** in coverage/lcov.info is below
# the threshold. Used by CI and by the /pr-ready skill.
set -euo pipefail
# The floor is fixed here, not by the caller: passing a lower number (e.g.
# an agent trying `coverage_check.sh 50` to get green) fails the gate.
FLOOR=80
min=${1:-$FLOOR}
if ! [[ "$min" =~ ^[0-9]+$ ]] || ((min < FLOOR)); then
  echo "Coverage threshold '$min' is below the project floor of $FLOOR% — not allowed."
  exit 1
fi
file=coverage/lcov.info
[[ -f $file ]] || { echo "No $file — run: fvm flutter test --coverage"; exit 1; }

awk -v min="$min" '
  /^SF:/ { inFeature = ($0 ~ /lib\/(features|core\/widgets)\//) }
  inFeature && /^LF:/ { split($0, a, ":"); lf += a[2] }
  inFeature && /^LH:/ { split($0, a, ":"); lh += a[2] }
  END {
    pct = (lf == 0) ? 0 : lh * 100 / lf
    printf "lib/features + lib/core/widgets coverage: %.1f%% (%d/%d lines), min %d%%\n", pct, lh, lf, min
    exit (pct + 0.0001 < min) ? 1 : 0
  }' "$file"
