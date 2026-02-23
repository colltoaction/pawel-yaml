# Agentic TDD Protocol: Autonomous Red-Green-Refactor

This document defines the specialized Test-Driven Development (TDD) protocol for agentic AI workflows. It prioritizes tool-verifiable state changes, architectural purity, and atomic progress.

## Phase 0: Environment Discovery & Tool Sync
Before mutation, the agent must synchronize its internal model with the project's testing capabilities.
- **Action**: Locate test suites via `find` or `ls`. Identify execution scripts (e.g., `Makefile`, `test.sh`).
- **Goal**: Establish a baseline command for "Run All" and "Run Specific".

---

## Phase 1: RED (Failure Establishment)
Identify a specific, reproducible failure. Never proceed without a verified baseline.
- **Protocol**:
    1. Create a failing case or target feature.
    2. Run the specific test command.
    3. Capture and analyze the diff/error.
- **Success Condition**: The agent can explain *exactly* why the test is failing and what output is expected.

---

## Phase 2: GREEN (Minimal Functional Mutation)
Implement the simplest possible change to satisfy the test. Prioritize correctness over elegance at this stage.
- **Protocol**:
    1. Modify the target file(s).
    2. Use simple logic (even hardcoded values) to bridge the gap.
    3. Rerun the specific test.
- **Success Condition**: The test passes (✅). Do not worry about technical debt yet.

---

## Phase 3: REFACTOR (Structural Refinement)
Elevate the "Green" implementation to meet project standards and theoretical constraints.
1. **Generalize**: Replace hardcoded logic.
2. **Align**: Ensure the code follows the project's core patterns.
3. **Cleanup**: Remove redundant code, temporary logs, hacks.
- **Success Condition**: The specific test still passes, but the code is now "architecturally sound".

---

## Phase 4: VERIFY (Regression Guard)
Verify that the refinement did not introduce regressions elsewhere in the system.
- **Protocol**:
    1. Run the **full** test suite.
    2. Analyze any new failures.
    3. If regressions occur, revert to the last stable "Green" state and re-evaluate the refactor.
- **Success Condition**: Zero regressions; full suite status is known and tracked.

---

## Phase 5: ATOMIC COMMIT (State Finalization)
Finalize the work and update tracking artifacts.

1. Update project tracking.
2. Commit with a message specifying the transition: `feat: ...`.

- **Goal**: Maintain a repository state where every commit is functional and compliant with the "Baby Steps" philosophy.

---

## Macro Cycle: History & Debt Management
For large-scale shifts (e.g., purging history, global refactors):
1. **Identify**: Use `git rev-list` to find technical debt/junk.
2. **Purge**: Apply macro tools (`git filter-repo`) globally.
3. **Reset**: Update `.gitignore` to prevent re-introduction of debt.
4. **Resync**: Verify the current HEAD remains compliant.
