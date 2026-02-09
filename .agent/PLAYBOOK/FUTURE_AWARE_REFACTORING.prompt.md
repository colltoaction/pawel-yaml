# Playbook: Future-Aware Refactoring

Use future-aware rebasing to keep each historical commit aligned with the final architecture.
The default and required commit-selection method is the cost-based `O(log n)` running-total bisect strategy.

## Core Strategy (Default)

### Cost Model
1. Choose a baseline commit `B` and list commits `C[1..n]` from `B..HEAD` in chronological order.
2. For each commit `C[i]`, compute `commit_total[i]` as total changed lines for that commit.
3. Compute running totals:
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

## Prerequisites (Run First)
1. Ensure parser builds:
`make clean && make`
2. Prepare harness prerequisites (automated):
`make setup`

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
2. Identify baseline `B`.
3. Run cost model and heavy-path bisect.
4. Produce the divide report before editing commits.
5. Capture immutable refs for rebase:
`TIP_REF=$(git rev-parse --verify HEAD)`
`BASE_PARENT=$(git rev-parse --verify <baseline>^)`

### 2. Rebase
1. Start interactive rebase from the parent of the first target commit:
`git rebase -i "$BASE_PARENT"`
2. Mark selected target commits as `edit`.
3. Leave non-target commits as `pick`.

### 3. Stop Protocol (At Each Edited Commit)
1. Sync infrastructure:
`git checkout "$TIP_REF" -- .agent/tooling.sh`
2. Apply refactor scoped to this commit.
3. Verify:
`make clean && make`
`./.agent/tooling.sh tdd:test <ID>`
4. Continue:
`git add <files>`
`git rebase --continue`

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
`./.agent/tooling.sh tdd:test <ID>`
4. Continue rebase:
`git add <files>`
`git rebase --continue`

## Bounded-Work Constraints (Mandatory)
- No unbounded work: each stage must have explicit input, output, and stop condition.
- No thought-only tasks: do not add open-ended "analyze/think/brainstorm" items.
- No full-history linear cleanup by default.
- No unbounded recursion: recurse only on one heavier side per split.
- Terminate selection at leaf commits only.

## Done Criteria
- Selected commits were chosen by the running-total heavy-path bisect strategy.
- Divide report exists with one entry per split.
- Each edited commit passes build and targeted harness verification.
- Rebase completes with clean, architecture-aligned history.
