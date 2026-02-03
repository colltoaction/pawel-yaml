# Playbook: Future-Aware History Refactoring

## Overview
Future-Aware History Refactoring is an advanced **Agentic TDD** technique used during interactive rebases to resolve complex architectural conflicts. Instead of solving conflicts based solely on the current "HEAD" and the incoming "PATCH", the agent looks ahead to the **future state** of the branch (the target commits of the rebase) to align the resolution with the ultimate architectural direction.

## The Macro Cycle: INSPECT-ALIGN-CONTINUE

### 1. INSPECT (The Future)
When a rebase conflict occurs:
- Identify the commit hash that successfully implemented the feature you are currently rebasing over (the "future").
- Use `git show <future_commit>:<file>` or `git checkout <future_commit> -- <file>` to examine how the future solved the problem.
- **Goal**: Understand the final architecture (e.g., named references, GLR parser structure) so the intermediate conflict resolution doesn't become "dead work".

### 2. ALIGN (The Present)
Resolve the conflict by adopting the future's architectural patterns immediately, even if the current commit is "early" in the history.
- **Named References**: If the future uses `[doc]` instead of `$1`, resolve current conflicts using `[doc]`.
- **Infrastructure Sync**: If the future updated the `Makefile` or `.agent/tooling.sh`, sync those changes into the current conflict resolution to ensure the harness is "GREEN" at every step.
- **Named Refactoring**: Apply the **Refactor phase** of TDD during the conflict resolution itself.

### 3. VERIFY (The Harness)
Before continuing the rebase:
- Rebuild the binary (`make clean && make`).
- Run the localized test harness (`./.agent/tooling.sh tdd:test <ID>`).
- Ensure that the "intermediate" commit is functional (passes at the expected level) before moving to the next step of the rebase.

### 4. CONTINUE
Once the commit is "Future-Aligned" and "Harness-Green":
- `git add <files>`
- `git rebase --continue`

## Strategic Benefits
- **Zero Regressions**: By aligning with the future, you avoid "ping-pong" refactoring where you fix a conflict one way only to have to change it again three commits later.
- **Clean History**: Every commit in the history becomes architecturalically consistent with the final result.
- **Agentic Efficiency**: The agent doesn't "struggle" with old positional references because it has already transcended them by "looking ahead".

## Checklist for Conflicts
- [ ] Is this file modified later in the rebase?
- [ ] Does the future version use Named References?
- [ ] Has the `Event` list or AST changed in the future?
- [ ] Is the Harness (`tooling.sh`) synced with the latest implementation?
- [ ] Does `make` pass?
