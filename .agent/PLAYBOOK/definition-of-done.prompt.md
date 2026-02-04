# Definition of Done: Comprehensive Playbook for Test-Driven Development

**Purpose:** Establish clear, measurable acceptance criteria for TDD cycles across any project  
**Framework:** Agentic TDD Protocol (RED → GREEN → REFACTOR → VERIFY → COMMIT)  
**Status:** Reusable playbook, project-agnostic  

---

## Table of Contents

1. [Overview](#overview)
2. [The Five Phases](#the-five-phases)
3. [Code Implementation Requirements](#code-implementation-requirements)
4. [Testing Strategy](#testing-strategy)
5. [Code Review & Quality](#code-review--quality)
6. [Documentation & Communication](#documentation--communication)
7. [Verification Checklist](#verification-checklist)
8. [Success Metrics](#success-metrics)
9. [Definition of Done Checkpoint](#definition-of-done-checkpoint)
10. [Rollback Criteria](#rollback-criteria)

---

## Overview

A feature, refactor, or bugfix is "Done" when it has successfully completed the full TDD cycle:

```
RED        → GREEN      → REFACTOR    → VERIFY       → COMMIT
Establish   Implement    Clean code    Confirm no     Atomic
failure     minimal fix   & design      regressions    history
```

This playbook defines measurable acceptance criteria for each phase.

---

## The Five Phases

### Phase 1: RED (Establish Failure)

**Goal:** Establish a clear, reproducible failing test

**Requirements:**
```
□ Identify specific failing test case(s)
□ Verify baseline: Run test suite, confirm failure
□ Document expected behavior vs. actual behavior
□ Reproduce failure consistently
□ Understand root cause via debugging
□ Have clear path to success defined
```

**Verification:**
- Test fails consistently before any code changes
- Failure is reproducible on any machine
- Test is isolated (doesn't depend on other failures)
- Expected behavior is clearly documented

**Exit Criteria:**
- ✅ One or more failing tests identified
- ✅ Baseline established (test suite run, results recorded)
- ✅ Root cause analyzed
- ✅ Clear acceptance criteria defined

---

### Phase 2: GREEN (Localize Fix)

**Goal:** Write minimal code to pass the failing test

**Requirements:**
```
□ Implement simplest possible solution
□ Focus on passing the test, not perfect design
□ Avoid over-engineering
□ Make changes in isolation (single concern)
□ No major refactoring yet
□ Test passes after changes
```

**Anti-Patterns to Avoid:**
- ❌ Refactoring while fixing (save for Phase 3)
- ❌ Implementing multiple features at once
- ❌ Adding new tests (done in RED phase)
- ❌ Major design decisions (save for REFACTOR)

**Exit Criteria:**
- ✅ Previously failing test(s) now pass
- ✅ Code is minimal and focused
- ✅ Changes are isolated to specific concern

---

### Phase 3: REFACTOR (Align Theory)

**Goal:** Clean up and generalize code; improve design without changing behavior

**Requirements:**
```
□ Inspect current implementation
□ Identify correct abstraction(s)
□ Extract common patterns
□ Remove duplication
□ Improve naming and clarity
□ Align with architecture/design patterns
□ All tests still pass (unchanged behavior)
```

**Refactoring Activities:**
- Extract methods or functions
- Consolidate duplicated code
- Rename variables/functions for clarity
- Move code to appropriate modules
- Improve code organization
- Add inline documentation
- Simplify complex logic

**Important:** ⚠️ **No behavior changes during REFACTOR**
- If you need to fix more functionality, return to RED phase
- If tests fail during refactoring, revert and diagnose

**Exit Criteria:**
- ✅ Code is cleaner and better organized
- ✅ All tests still pass (same tests as after GREEN)
- ✅ Code aligns with project architecture
- ✅ Design decisions are documented

---

### Phase 4: VERIFY (Protect History)

**Goal:** Confirm no regressions; full test suite passes

**Requirements:**

#### 4.1 Full Test Execution
```
□ Run ALL unit tests
□ Run ALL integration tests
□ Run FULL test suite (if available)
□ Capture baseline metrics (pass/fail counts, coverage)
□ Compare against previous baseline
□ Document any changes
```

**Critical:** This is NOT optional. If you skip full test suite verification:
- ❌ You cannot claim phase is "verified"
- ❌ You may have introduced hidden regressions
- ❌ You cannot safely commit

#### 4.2 Regression Analysis
```
□ Count baseline passing tests from before changes
□ Count current passing tests after changes
□ Calculate: new_passing_count >= baseline_passing_count
□ If new_passing_count < baseline: REGRESSION DETECTED
  → Go back to REFACTOR phase
  → Diagnose and fix
  → Re-run verification
```

#### 4.3 Performance & Stability
```
□ Test suite completes within reasonable time
□ No new warnings during compilation
□ No memory leaks (if applicable)
□ No crashes or hangs
□ Consistent results on multiple runs
```

**Exit Criteria:**
- ✅ Unit tests: 100% pass rate (same as before + new passing tests)
- ✅ Integration tests: 100% pass rate (no regressions)
- ✅ Full test suite: 100% pass rate (no regressions)
- ✅ All baseline tests still pass
- ✅ Zero new failures introduced
- ✅ Performance acceptable

**If Tests Fail in VERIFY:**
```
WORKFLOW:
1. Identify which test(s) failed
2. Determine if it's a regression (was passing before)
3. If regression:
   → Revert to Green phase
   → Re-examine REFACTOR changes
   → Fix root cause
   → Re-run VERIFY
4. If new failure (not regression):
   → This may indicate test coverage gap
   → Return to RED phase for the new failure
```

---

### Phase 5: COMMIT (Atomic Checkpoint)

**Goal:** Record changes in version control with clear history

**Requirements:**

#### 5.1 Commit Message Quality
```
□ One clear, focused commit per feature/fix
□ Subject line: <50 characters, imperative mood
□ Body: Explain WHY (not WHAT - code shows that)
□ Reference: Test IDs, issue numbers
□ Example:
  "feat: Add email validation to user signup
  
  Prevents invalid email addresses from creating accounts.
  Validates format using RFC 5322 standard.
  
  Fixes: #1234 (invalid emails accepted)
  Tests: test_invalid_email_formats (36 cases)
  Baseline: 215→251 tests passing"
```

#### 5.2 Code State
```
□ All changes staged (git add)
□ No uncommitted changes remain
□ No accidentally added files
□ Clean working directory
□ Ready for: git push
```

#### 5.3 History Quality
```
□ Commit history is linear and clear
□ Each commit represents one logical unit
□ Can revert safely if needed
□ Bisectable (each commit is in good state)
□ Follows project conventions
```

**Exit Criteria:**
- ✅ Changes committed with clear message
- ✅ Working directory clean
- ✅ All tests verified passing
- ✅ Ready for code review and merge
- ✅ History is clear and traceable

---

## Code Implementation Requirements

### 1. Scope & Isolation

```
✅ DO:
□ Make changes related to ONE issue/feature
□ Fix one problem per commit
□ Change as little code as possible
□ Keep commits focused and reviewable

❌ DON'T:
□ Mix multiple features in one commit
□ Perform unrelated refactoring
□ Change other parts of the system
□ Include dead code or debugging statements
```

### 2. Code Quality Standards

```
□ Follows project code style
□ No compiler warnings
□ No linting errors
□ No code smells (identified by tools)
□ Clear variable/function names
□ Proper error handling
□ No magic numbers
□ Comments explain WHY (not WHAT)
```

### 3. Design & Architecture

```
□ Aligns with project architecture
□ Respects module boundaries
□ Doesn't duplicate existing functionality
□ Uses existing abstractions where applicable
□ Introduces new abstractions only if justified
□ Follows SOLID principles (where applicable)
□ Documentation updated if architecture changed
```

### 4. Safety & Reliability

```
□ No buffer overflows or memory leaks
□ Proper null/bounds checking
□ Consistent error handling
□ No race conditions (if concurrent)
□ Defensive programming (validate inputs)
□ No assumptions about invariants
□ Handles edge cases explicitly
```

---

## Testing Strategy

### 1. Unit Test Baseline

**Purpose:** Test individual functions/components in isolation

```
□ Tests exist for new functionality
□ Edge cases covered
□ Error conditions tested
□ Tests are independent (no ordering required)
□ Tests run quickly (<1s per test typical)
□ Tests are deterministic (same result every run)
```

**Verification:**
```
make test-unit
# Expected: 100% pass rate
# Time: seconds to minutes
# New tests: All passing
# Existing tests: All still passing
```

### 2. Integration Test Baseline

**Purpose:** Test multiple components working together

```
□ Tests exercise real workflows
□ Tests use actual data/files (or realistic mocks)
□ Tests verify end-to-end scenarios
□ Tests may be slower than unit tests
□ Tests catch interface/contract violations
```

**Verification:**
```
make test-integration
# Expected: 100% pass rate
# Time: minutes (acceptable for integration tests)
# New tests: All passing
# Existing tests: All still passing
```

### 3. Full Test Suite (CRITICAL in VERIFY Phase)

**Purpose:** Verify NO regressions across entire project

```
ESSENTIAL VERIFICATION STEP:
□ Run complete test suite
□ Record pass/fail counts BEFORE changes
□ Record pass/fail counts AFTER changes
□ Compare: new_count >= old_count
□ If regression: Stop, fix, re-test
```

**Workflow:**

```bash
# Step 1: Establish baseline (before changes)
make clean
make
make test      # or: make test-unit && make test-integration
BASELINE_COUNT=$(grep "passed" test_output.txt)

# Step 2: Make changes
# ... implement feature ...

# Step 3: Verify (FULL suite - cannot be skipped)
make clean
make
make test      # MUST RUN FULL SUITE, not just new tests
NEW_COUNT=$(grep "passed" test_output.txt)

# Step 4: Regression check
if [ NEW_COUNT -lt BASELINE_COUNT ]; then
    echo "REGRESSION: Tests decreased!"
    git revert HEAD
    exit 1
fi
```

### 4. Test Categories

**Ensure all categories are covered:**

```
UNIT TESTS (fast, isolated)
□ Individual functions
□ Data structures
□ Error conditions
□ Boundary cases
Time: < 1 second total

INTEGRATION TESTS (moderate speed, real workflows)
□ Component interactions
□ Actual I/O operations
□ Configuration handling
□ Multi-step operations
Time: 1-10 seconds typical

FULL SUITE (comprehensive, all tests)
□ Includes all unit tests
□ Includes all integration tests
□ May include performance tests
□ May include stress tests
Time: Varies, but typically < 2 minutes for reasonable projects

SANITY CHECKS (quick smoke test)
□ Build succeeds
□ Executable runs
□ Basic functionality works
Time: < 10 seconds
```

### 5. Test Automation

**Tests must be automated and runnable with single command:**

```
REQUIRED:
□ make test              (runs full suite)
□ make test-unit        (runs only unit tests)
□ make test-integration (runs only integration tests)
□ CI/CD pipeline runs tests automatically

No manual testing allowed for phase verification.
All verification must be tool-verifiable.
```

---

## Code Review & Quality

### 1. Static Analysis

```
□ Compiler warnings: Zero
□ Linting errors: Zero
□ Complexity checks: Pass
□ Security scans: Pass (if used)
□ Code coverage: Meets threshold
```

### 2. Design Review

```
□ Follows architectural guidelines
□ Respects module interfaces
□ Doesn't violate layer boundaries
□ Uses project patterns consistently
□ No architectural regressions
□ Improvement justifies changes
```

### 3. Peer Review

```
□ Code is understandable
□ Comments are clear
□ Design decisions are explained
□ No obvious bugs or issues
□ Follows team conventions
□ Reviewers approve changes
```

### 4. Self-Review Checklist

**Before asking for review, verify:**

```
□ All tests pass
□ No compiler warnings
□ Code follows style
□ Comments are clear
□ Changes are minimal
□ Commit message is good
□ No debug code remains
□ CHANGELOG updated (if applicable)
```

---

## Documentation & Communication

### 1. Code Comments

```
GOOD COMMENTS EXPLAIN:
✅ Why (design decision)
✅ What (non-obvious purpose)
✅ How (algorithm, if complex)
✅ Constraints (assumptions, preconditions)
✅ Related code (cross-references)

BAD COMMENTS:
❌ Restate what code obviously does
❌ Out-of-date (worse than none)
❌ TODO without context
❌ Commented-out code
```

### 2. Commit Messages

```
FORMAT:
<type>(<scope>): <subject>

<body>

<footer>

TYPES: feat, fix, refactor, docs, test, perf, chore

EXAMPLE:
feat(validation): Add email format checking

Validates email addresses against RFC 5322 standard
before saving to database. Prevents invalid entries
and improves data quality.

Fixes: #1234
Tests: test_email_validation (15 cases)
```

### 3. Architecture Documentation

```
If changes affect architecture:
□ Update design documents
□ Add diagrams if appropriate
□ Explain rationale
□ Document assumptions
□ Link to related code
□ Update API documentation
```

### 4. Change Tracking

```
□ Reference issue numbers
□ Note test case identifiers
□ Document metrics (before/after)
□ List affected modules
□ Note breaking changes (if any)
```

---

## Verification Checklist

### Pre-Commit Verification

```
CODE QUALITY
□ No compiler warnings
□ No linting errors
□ Code style consistent
□ Variable names clear
□ Comments present (where needed)
□ No dead code
□ No magic numbers

FUNCTIONALITY
□ Red phase test fails before changes
□ Green phase test passes after changes
□ REFACTOR: All tests still pass
□ No new behavior introduced
□ No breaking changes
□ Edge cases handled

TESTING
□ Unit tests: 100% pass
□ Integration tests: 100% pass
□ Full test suite: 100% pass
□ No regressions from baseline
□ New tests pass
□ Existing tests unchanged

DOCUMENTATION
□ Code comments clear
□ Commit message written
□ Architecture updated (if needed)
□ No TODOs in code
□ CHANGELOG entry (if applicable)

SAFETY
□ Error handling present
□ No memory leaks
□ No race conditions
□ Input validation
□ Boundary checks
```

### Post-Commit Verification

```
GIT STATE
□ Commit recorded in history
□ Working directory clean
□ No uncommitted changes
□ Ready for git push

CODE STATE
□ Changes still passing tests
□ No merge conflicts
□ Integration with main stable
□ Ready for code review

TEAM COMMUNICATION
□ Team informed of changes
□ PR created (if applicable)
□ Reviewers assigned
□ Dependencies noted (if any)
```

---

## Success Metrics

### Quantitative Measures

| Metric | Target | Verification |
|--------|--------|---|
| Test pass rate | 100% | `make test` output |
| Unit test pass rate | 100% | `make test-unit` output |
| Integration test pass rate | 100% | `make test-integration` output |
| Regressions | 0 | Baseline comparison |
| Compiler warnings | 0 | Build output |
| Linting errors | 0 | Linter output |
| Code coverage | Project-defined | Coverage tool |
| Cyclomatic complexity | Project-defined | Complexity analyzer |

### Qualitative Measures

```
CODE QUALITY
□ Clear and understandable
□ Follows project patterns
□ Properly commented
□ Minimal and focused

DESIGN QUALITY
□ Solves the problem
□ Aligns with architecture
□ Respects boundaries
□ Is maintainable

COMMUNICATION QUALITY
□ Commit message is clear
□ Comments explain intent
□ Changes are easy to review
□ Impact is obvious
```

---

## Definition of Done Checkpoint

### Requirements Checklist

A feature/fix/refactor is "Done" when ALL of the following are true:

#### RED Phase ✅
```
□ Failing test(s) identified
□ Baseline established
□ Root cause understood
□ Success criteria defined
```

#### GREEN Phase ✅
```
□ Minimal code implemented
□ Previously failing test(s) pass
□ No over-engineering
□ Focused on single issue
```

#### REFACTOR Phase ✅
```
□ Code cleaned and generalized
□ Duplication removed
□ Design aligned with architecture
□ All previous tests still pass
```

#### VERIFY Phase ✅ (CRITICAL)
```
□ Unit tests: 100% pass rate
□ Integration tests: 100% pass rate
□ FULL TEST SUITE: 100% pass rate
□ Baseline tests >= previous count
□ Zero regressions detected
□ No new warnings introduced
□ Performance acceptable
```

#### COMMIT Phase ✅
```
□ Changes committed with clear message
□ Working directory clean
□ Git history is clean
□ Ready for code review
□ Ready for merge
```

#### CODE QUALITY ✅
```
□ No compiler warnings
□ No linting errors
□ Code style consistent
□ Comments present (where needed)
□ No dead code
□ Error handling complete
```

#### DOCUMENTATION ✅
```
□ Code comments clear
□ Architecture documented
□ Commit message explains why
□ Related issues referenced
□ CHANGELOG updated (if applicable)
```

### Sign-Off Criteria

**Only after ALL above items are checked can you declare "Done":**

```
SIGN-OFF STATEMENT:

"The implementation is complete, tested, and verified.
 All baseline tests pass without regression.
 Code meets quality standards.
 Documentation is clear.
 Ready for review and merge."
```

---

## Rollback Criteria

### When to Rollback Immediately

**If ANY of these occur, rollback and investigate:**

```
CRITICAL FAILURES:
□ More than 5 regressions in passing tests
□ Cannot reach baseline test count
□ Compiler errors or new warnings
□ Segfault, crash, or hang
□ Infinite loop or deadlock
□ Memory leak or corruption

ARCHITECTURAL VIOLATIONS:
□ Violates project architecture
□ Breaks module boundaries
□ Introduces circular dependency
□ Creates security vulnerability

UNMAINTAINABLE CODE:
□ Code is incomprehensible
□ Cannot be reviewed
□ Violates all project standards
□ Introduces major technical debt
```

### Rollback Procedure

```
1. STOP: Do not make more changes
2. REVERT: git revert [commit]
3. VERIFY: Confirm all tests pass again
4. INVESTIGATE: Understand what went wrong
5. DOCUMENT: Record failure and cause
6. RESTART: Begin again from RED phase

WARNING: If you cannot complete Phase 4 (VERIFY) 
         successfully, do not commit.
```

---

## Special Cases

### Hotfixes

For urgent production fixes:

```
PROCESS:
1. RED phase: Establish failing test for bug
2. GREEN phase: Implement minimal fix
3. VERIFY phase: FULL test suite (critical for hotfixes)
4. COMMIT: Clear message referencing the issue
5. Fast-track review (but still required)

NOTE: Do NOT skip VERIFY phase for hotfixes.
      Risk of introducing regressions is higher.
      Verification is more critical, not less.
```

### Refactoring

For code cleanup without new features:

```
PROCESS:
1. RED phase: "Tests should pass before refactoring"
              - Establish baseline of all tests passing
2. GREEN phase: Not applicable (no failing test)
3. REFACTOR phase: Perform refactoring
4. VERIFY phase: FULL test suite (must match baseline exactly)
5. COMMIT: Clear refactoring message

RULE: Refactoring cannot add new behavior.
      If it does, follow normal feature process.
```

### Documentation Changes

For docs-only updates:

```
PROCESS:
1. RED phase: "Documentation is unclear"
              - Establish that docs need improvement
2. GREEN phase: Not applicable
3. REFACTOR phase: Improve documentation
4. VERIFY phase: Docs reviewed for clarity
5. COMMIT: Clear message about docs improvement

NOTE: Can be faster than code changes.
      Code review still recommended.
```

---

## Project Integration

### Customization Points

This playbook is intentionally project-agnostic. Customize:

```
[] Test command: Replace "make test" with project's test runner
[] Test coverage threshold: Define for your project
[] Code style standard: Reference your linting config
[] Architecture rules: Define your module structure
[] Performance targets: Set acceptable test duration
[] Complexity limits: Define cyclomatic complexity threshold
[] Issue tracking: Reference your issue tracker (Jira, GitHub, etc.)
```

### Example Customizations

```
PYTHON PROJECT:
□ Test command: pytest
□ Linter: flake8, black
□ Coverage: 85% minimum
□ Types: mypy

GO PROJECT:
□ Test command: go test ./...
□ Linter: golangci-lint
□ Coverage: 70% minimum
□ Format: gofmt

C/C++ PROJECT:
□ Test command: ./run_tests.sh
□ Linter: clang-tidy
□ Coverage: valgrind, gcov
□ Format: clang-format
```

---

## Summary

### The Core Principle

**"Done" means the change is:**

1. ✅ **Correct** - Tests verify it works
2. ✅ **Safe** - No regressions, verified against full suite
3. ✅ **Clean** - Code is well-organized and understandable
4. ✅ **Complete** - All requirements met, documented, tested
5. ✅ **Ready** - Can be safely merged and deployed

### The Non-Negotiable Requirement

**Phase 4 (VERIFY) with FULL test suite execution is mandatory.**

- ❌ Cannot skip integration tests
- ❌ Cannot skip full test suite
- ❌ Cannot claim "Done" without verifying all tests pass
- ❌ Cannot commit if tests fail

### The Rule

```
"Done" ≠ "Code compiles"
"Done" ≠ "New test passes"
"Done" ≠ "I think it works"

"Done" = All requirements met + Full test suite verified
        + No regressions + Code reviewed + Documented
```

---

**Last Updated:** February 4, 2026  
**Version:** 1.0  
**Status:** Ready for use in all TDD cycles  
**Maintenance:** Update when process improves or new patterns emerge
