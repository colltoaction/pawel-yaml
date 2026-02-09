# Playbook: Future-Aware Refactoring

Use future-aware rebasing to keep each historical commit aligned with the final architecture.
The default and required commit-selection method is the cost-based `O(log n)` running-total bisect strategy.
No non-bisect commit selection is allowed.

## Core Strategy (Default)

### Cost Model
1. Set baseline commit `B` to branch root by default:
`B=$(git rev-list --max-parents=0 HEAD | tail -n1)`.
2. List commits `C[1..n]` from `B..HEAD` in chronological order.
3. For each commit `C[i]`, compute `commit_total[i]` as total changed lines for that commit.
4. Compute running totals:
`running_total[i] = running_total[i-1] + commit_total[i]`, with `running_total[0] = 0`.

### Heavy-Path Bisect (Log-Scale Selection)
1. Start with interval `[1, n]`.
2. Split at `mid = floor((start + end) / 2)`.
3. Compute interval growth:
`left_growth = running_total[mid] - running_total[start-1]`
`right_growth = running_total[end] - running_total[mid]`
4. Select the heavier side:
if `left_growth >= right_growth`, recurse to `[start, mid]`; otherwise recurse to `[mid+1, end]`.
5. Stop at leaf interval size `1`; that commit is a cleanup target.
6. Repeat until the selected heavy path is exhausted.

Expected target count: approximately `O(log n)` commits.

### Command Reference (Cost Model)
Use these commands to generate deterministic commit weights from branch root.

```bash
B=$(git rev-list --max-parents=0 HEAD | tail -n1)
mkdir -p build/tmp

git rev-list --reverse --topo-order HEAD | awk '
BEGIN { OFS="\t"; running=0; i=0; print "idx","sha","commit_total","running_total" }
{
  sha=$0
  cmd="git show --numstat --format=\"\" " sha
  total=0
  while ((cmd | getline line) > 0) {
    n=split(line,a,"\t")
    if (n >= 2 && a[1] ~ /^[0-9]+$/ && a[2] ~ /^[0-9]+$/) total += a[1] + a[2]
  }
  close(cmd)
  i += 1
  running += total
  print i, sha, total, running
}' > build/tmp/running_totals.tsv
```
Optional override when using a non-root baseline:
`BASE_PARENT=$(git rev-parse --verify <baseline>^)`
then replace `git rev-list --reverse --topo-order HEAD` with
`git rev-list --reverse "$BASE_PARENT..HEAD"`.

## Prerequisites (Run First)
1. Ensure parser builds:
`make clean && make`
2. Prepare harness prerequisites (automated):
`make setup`
   - On first run this may clone from GitHub.

## Divide Report (Required)
Record one entry for each split decision during divide stage.

Required fields:
- Step index
- Interval bounds (`start`, `end`)
- Midpoint (`mid`)
- `left_growth`
- `right_growth`
- Selected side
- Rationale: "higher running-total growth"

## Rebase Execution Flow

### 1. Plan
1. Define refactoring goal.
2. Identify baseline `B` (default: branch root).
3. Run cost model and heavy-path bisect.
4. Produce the divide report before editing commits.
5. Capture immutable refs for rebase:
`TIP_REF=$(git rev-parse --verify HEAD)`
`B=$(git rev-list --max-parents=0 HEAD | tail -n1)`
`BASE_PARENT=$(git rev-parse --verify <baseline>^)` (only if using non-root baseline override)

### 2. Rebase
1. Start interactive rebase:
`git rebase -i --root`
   - Non-root baseline override: `git rebase -i "$BASE_PARENT"`
2. Mark selected target commits as `edit`.
3. Leave non-target commits as `pick`.

### 3. Stop Protocol (At Each Edited Commit, Mandatory TDD Cycle)
1. Sync infrastructure:
`git checkout "$TIP_REF" -- .agent/tooling.sh`
2. Run one full TDD cycle for this stop:
- RED: run target test and capture failing evidence.
- GREEN: implement minimal change to satisfy target behavior.
- REFACTOR: clean structure while preserving GREEN behavior.
3. Verify:
`make clean && make`
`make check`
`./.agent/tooling.sh tdd:test <ID>`
4. Continue:
`git add <files>`
`git rebase --continue`

### 4. Per-Stop TDD Record (Required)
For each `edit` stop, record:
- Stop index
- Commit SHA
- Test ID
- RED evidence (failing command/result)
- GREEN evidence (passing command/result)
- Refactor scope (files/functions)
- Final gate status: `pass` or `blocked`

If blocked (e.g., fixture/network unavailable), record exact blocker and still continue with build verification.

## Conflict Protocol: Inspect-Align-Continue
Use this only when conflicts occur.

1. Inspect future implementation:
`git show <future_commit>:<file>`
2. Align current commit to future architecture:
- Prefer named references over positional placeholders.
- Prefer declarative grammar rules over procedural hacks.
- Adopt updated tooling files immediately.
3. Verify build and tests:
`make clean && make`
`make check`
`./.agent/tooling.sh tdd:test <ID>`
4. Continue rebase:
`git add <files>`
`git rebase --continue`

After conflict resolution, still complete the per-stop TDD cycle record for that stop.

## Bounded-Work Constraints (Mandatory)
- No unbounded work: each stage must have explicit input, output, and stop condition.
- No thought-only tasks: do not add open-ended "analyze/think/brainstorm" items.
- No full-history linear cleanup by default.
- No unbounded recursion: recurse only on one heavier side per split.
- Terminate selection at leaf commits only.

## Done Criteria
- Selected commits were chosen by the running-total heavy-path bisect strategy.
- Baseline starts at branch root unless a non-root override is explicitly documented.
- Divide report exists with one entry per split.
- Each edited commit has one RED/GREEN/REFACTOR TDD cycle record.
- Each edited commit passes build and targeted harness verification (or is explicitly marked blocked with reason).
- Rebase completes with clean, architecture-aligned history.
