# Playbook: Future-Aware Refactoring ⚛️

Adopt the **Agentic TDD Macro Cycle** to align project history with architectural goals. Combining interactive rebasing with "look-ahead" design decisions ensures every commit is consistent with the project's final state.

## 🔄 Macro Cycle: Plan-Rebase-Polish

### 1. Identify Goal
Define the structural or stylistic rework (e.g., "Use Named References").

### 2. Locate Baseline
Find the first relevant commit in history.

### 3. Initiate Rebase
Start interactive rebase (`git rebase -i <baseline>`) and mark targets for `edit`.

### 4. Stop Protocol (At Each Commit)
- **Sync Infrastructure**: Check out the latest versions of shared infrastructure (e.g., `.agent/tooling.sh`).
- **Apply Rework**: Implement the target change for the current scope.
- **Verify**: Rebuild and run the test harness (`./.agent/tooling.sh tdd:test <ID>`).
- **Continue**: `git add` and `git rebase --continue`.

---

## 🛡 Conflict Protocol: INSPECT-ALIGN-CONTINUE
Apply this protocol when architectural conflicts occur during rebase.

### 1. INSPECT (The Future)
- Identify the "future" commit that successfully implemented the feature.
- Use `git show <future_commit>:<file>` to examine the final architecture.
- **Goal**: Understand the destination to ensure the current resolution aligns with it.

### 2. ALIGN (The Present)
Resolve conflicts by adopting future architectural patterns immediately.
- **Use Named References**: Adopt `[name]` instead of `$1`.
- **Merge Logic**: Prefer declarative grammar rules over procedural hacks.
- **Sync Tooling**: Immediately adopt upgraded `Makefile` or scripts.

### 3. VERIFY (The Harness)
Ensure the intermediate commit is functional.
- Rebuild via `make clean && make`.
- Verify with `./.agent/tooling.sh tdd:test <ID>`.

### 4. CONTINUE
- `git add <files>`
- `git rebase --continue`

---

## 🎯 Strategic Benefits
- **Zero Regressions**: Conflicts are solved once in the correct direction.
- **Clean History**: Every commit is stylistically and architecturally consistent.
- **Efficiency**: Transcend positional debt by looking ahead to the destination.
