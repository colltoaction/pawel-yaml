#!/bin/bash
# Consolidated TDD harness for pawel-yaml
# Scoring is ALWAYS fail:true-aware: a test passes iff parser behaviour
# matches the test's expected outcome (fail:true -> RC!=0, else RC==0).
# Raw exit-code counting is intentionally absent to avoid false baselines.

set -e

PARSER="./build/bin/pawel-yaml"
SUITE_DIR="build/lib/yaml-test-suite/src"

# ---------------------------------------------------------------------------
# bisect: sanity-check that the build succeeds and the parser runs at all.
# Accepts RC 0 (clean) or 1 (semantic violations) as both valid outcomes.
# ---------------------------------------------------------------------------
bisect_test() {
    echo "Running bisect test..."
    make >/dev/null 2>&1

    if [ ! -f "$PARSER" ]; then
        echo "Build failed"
        exit 1
    fi

    echo "key: value" | "$PARSER" >/dev/null 2>&1
    rc=$?

    if [ $rc -le 1 ]; then
        echo "Bisect test passed"
    else
        echo "Bisect test failed (RC=$rc)"
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# suite: run all 351 tests with fail:true-aware scoring and update
# TEST_FAILURES.yaml.  This is the canonical way to measure progress.
# ---------------------------------------------------------------------------
run_suite() {
    echo "Running full suite (fail:true-aware)..."
    python3 - <<'PYEOF'
import subprocess, os, yaml as pyyaml
from datetime import datetime, timezone

suite_dir = "build/lib/yaml-test-suite/src"
parser    = "./build/bin/pawel-yaml"

passing, failing = [], []
MARKERS = {'\u2423':' ','\u00bb':'\t','\u21b5':'\n','\u220e':'','\u2193':''}

for fn in sorted(os.listdir(suite_dir)):
    if not fn.endswith(".yaml"):
        continue
    tid = fn[:-5]
    try:
        with open(f"{suite_dir}/{fn}") as f:
            data = pyyaml.safe_load(f)
        if isinstance(data, list):
            data = data[0]
        inp = data.get("yaml", "")
        for src, dst in MARKERS.items():
            inp = inp.replace(src, dst)
        should_fail = bool(data.get("fail", False))
    except Exception:
        continue

    res = subprocess.run([parser], input=inp, capture_output=True,
                         text=True, timeout=5)
    ok = res.returncode == 0
    correct = (ok and not should_fail) or (not ok and should_fail)
    (passing if correct else failing).append(tid)

total = len(passing) + len(failing)
rate  = len(passing) / total * 100 if total else 0
print(f"Total: {total}  Passed: {len(passing)}  Failed: {len(failing)}  "
      f"Rate: {rate:.1f}%")

out = {
    "meta": {
        "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "suite_dir": suite_dir,
        "total_tests": total,
        "total_passes": len(passing),
        "total_failures": len(failing),
        "scoring": "fail-true-aware",
    },
    "failing": failing,
}
with open("TEST_FAILURES.yaml", "w") as f:
    pyyaml.dump(out, f, default_flow_style=False, sort_keys=False,
                allow_unicode=True)
print("TEST_FAILURES.yaml updated.")
PYEOF
}

# ---------------------------------------------------------------------------
# Main dispatch
# ---------------------------------------------------------------------------
case ${1:-} in
    bisect) bisect_test ;;
    suite)  run_suite   ;;
    *)
        echo "Usage: $0 {bisect|suite}"
        exit 1
        ;;
esac
