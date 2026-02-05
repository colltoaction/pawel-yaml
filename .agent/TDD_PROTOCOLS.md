# Pawel-YAML TDD Protocol (The 5-Phase Cycle)

All development in this project MUST follow this 5-phase Test-Driven Development protocol.

## Phase 1: RED (Failure Establishment)
> *"Prove the problem exists."*

1. Identify a failing test case or create a new one.
2. Verify the failure using the `tdd_harness.sh` or `make test`.
3. Understand the root cause *before* changing code.

## Phase 2: GREEN (Minimal Mutation)
> *"Make it work immediately."*

1. Implement the simplest code possible to fix the test.
2. Hardcoding and "ugly" logic are permitted here to localize the fix.
3. Goal is to confirm your understanding of the fix location.

## Phase 3: REFACTOR (Theoretical Alignment)
> *"Pay the technical debt immediately."*

1. Replace hardcoded/ugly logic with clean, RML-aligned patterns.
2. Ensure grammar rules and morphisms are correctly implemented.
3. The test MUST remain GREEN throughout this phase.

## Phase 4: VERIFY (Regression Guard)
> *"Don't break the past."*

1. Run the full test suite (`make test-full`).
2. Ensure the pass rate has improved or stayed stable.
3. No new regressions are permitted.

## Phase 5: COMMIT (Atomic Checkpoint)
> *"Save the game."*

1. Commit with a descriptive message referencing the test ID.
2. Keep commits atomic—one cycle per commit.
3. Include standard TDD documentation in the commit message or log.
