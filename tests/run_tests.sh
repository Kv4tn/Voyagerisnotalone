#!/bin/bash
# Runs headless tests and prints a summary.
#   tests/run_tests.sh                         all tests/**/test_*.gd
#   tests/run_tests.sh tests/unit/test_x.gd    selected files
# Set GODOT to override the default macOS binary path.
# Exit code 0 only when every test script passes.
set -u

GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RUNNER="res://tests/support/test_runner.tscn"
TIMEOUT_SECONDS=120
failed=0
total=0

cd "$PROJECT_DIR" || exit 1

if [ $# -gt 0 ]; then
    tests=("$@")
else
    tests=($(find tests -name 'test_*.gd' -not -path 'tests/support/*' | sort))
fi

# Register class_name scripts and import resources before running anything.
"$GODOT" --headless --path . --import >/dev/null 2>&1

for test_file in "${tests[@]}"; do
    total=$((total + 1))
    log="$(mktemp)"
    "$GODOT" --headless --path . "$RUNNER" -- "res://$test_file" >"$log" 2>&1 &
    pid=$!
    for _ in $(seq "$TIMEOUT_SECONDS"); do
        kill -0 "$pid" 2>/dev/null || break
        sleep 1
    done
    if kill -0 "$pid" 2>/dev/null; then
        kill "$pid"
        echo "TIMEOUT  $test_file"
        failed=$((failed + 1))
        rm -f "$log"
        continue
    fi
    wait "$pid"
    status=$?
    summary="$(grep 'checks passed' "$log" | tail -1)"
    # Tests fail themselves on unexpected errors (tests/support/base_test.gd);
    # a nonzero exit also covers scripts that did not compile or load.
    if [ "$status" -eq 0 ]; then
        echo "OK       $test_file  ($summary)"
    else
        echo "FAILED   $test_file  (exit $status; $summary)"
        grep -E "  FAIL |SCRIPT ERROR|^ERROR:" "$log" | sort -u | sed 's/^/         /'
        failed=$((failed + 1))
    fi
    if [ -n "${VERBOSE:-}" ]; then sed 's/^/    | /' "$log"; fi
    rm -f "$log"
done

echo ""
echo "$((total - failed))/$total test scripts passed"
[ "$failed" -eq 0 ]
