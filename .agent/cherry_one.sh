#!/usr/bin/env bash
set -euo pipefail
if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <commit-sha> [base-branch]" >&2
  exit 2
fi
COMMIT=$1
BASE=${2:-HEAD}
SHORT=$(git rev-parse --short $COMMIT)
TS=$(date +%s)
BRANCH=cherry-${SHORT}-${TS}
OUTDIR=.agent
mkdir -p "$OUTDIR"

echo "Creating branch $BRANCH from $BASE"
git checkout -B "$BRANCH" "$BASE"

echo "Cherry-picking $COMMIT"
if ! git cherry-pick --allow-empty --keep-redundant-commits -x "$COMMIT" >/dev/null 2>&1; then
  echo "cherry-pick had conflicts for $COMMIT, attempting auto-resolve"
  if git ls-files -u | grep -q .; then
    files=$(git diff --name-only --diff-filter=U || true)
    for f in $files; do
      echo "Auto-resolving $f (theirs)"
      git checkout --theirs -- "$f" || true
      git add -- "$f" || true
    done
    git commit -m "auto-resolve conflicts for $COMMIT" >/dev/null 2>&1 || true
  else
    git cherry-pick --abort >/dev/null 2>&1 || true
    echo "Cherry-pick failed and no conflicts listed." >&2
    exit 3
  fi
else
  echo "Cherry-pick applied cleanly"
fi

SHORTMSG=$(git log -1 --pretty=format:%s HEAD | tr -d '\n')

# Build
echo "Building (make)..."
if ! make >/dev/null 2> "$OUTDIR/.build.err.${BRANCH}.${SHORT}"; then
  echo "Build failed; see $OUTDIR/.build.err.${BRANCH}.${SHORT}" >&2
  echo "${COMMIT},${SHORTMSG},BUILD_FAIL" >> "$OUTDIR/cherry_results.csv"
  exit 4
fi

# Run strict suite
echo "Running strict suite..."
bash .agent/consolidated_script.sh suite > /dev/null 2> "$OUTDIR/.suite.err.${BRANCH}.${SHORT}" || true

if [ -f TEST_FAILURES.yaml ]; then
  cp TEST_FAILURES.yaml "$OUTDIR/TEST_FAILURES.${BRANCH}.${SHORT}.yaml" || true
  git add TEST_FAILURES.yaml >/dev/null 2>&1 || true
  git commit --amend --no-edit >/dev/null 2>&1 || true
  # record basic meta
  total=$(python3 -c "import yaml,sys;d=yaml.safe_load(open('TEST_FAILURES.yaml'));print(d.get('meta',{}).get('total_tests',0))" 2>/dev/null || echo 0)
  passed=$(python3 -c "import yaml,sys;d=yaml.safe_load(open('TEST_FAILURES.yaml'));print(d.get('meta',{}).get('total_passes',0))" 2>/dev/null || echo 0)
  failed=$(python3 -c "import yaml,sys;d=yaml.safe_load(open('TEST_FAILURES.yaml'));print(d.get('meta',{}).get('total_failures',0))" 2>/dev/null || echo 0)
else
  total=0; passed=0; failed=0
fi

echo "Result: commit=$COMMIT branch=$BRANCH total=$total passed=$passed failed=$failed"
echo "${COMMIT},${SHORTMSG},${total},${passed},${failed},${BRANCH}" >> "$OUTDIR/cherry_results.csv"

echo "Done. Branch: $BRANCH. Artifacts in $OUTDIR/"
exit 0
