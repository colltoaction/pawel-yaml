# Agentic TDD Macro Cycle Playbook

This document describes the **Agentic TDD Macro Cycle** (also known as the "Future-Aware Refactoring" playbook).

## Overview

The Agentic TDD Macro Cycle is a systematic approach to refactoring a codebase by rebasing its history and applying future-known best practices at each step. This ensures that the entire project history remains clean, consistent, and "aware" of the architectural decisions made in later stages.

For the core TDD methodology used in individual steps, see [Agentic TDD Protocol].

## Protocol

1.  **Identify the Goal**: Define the architectural or stylistic change that should be applied across the history (e.g., "Use Named References in Bison grammar").
2.  **Locate the Baseline**: Find the first commit in the history where the change becomes relevant.
3.  **Initiate Rebase**: Start an interactive rebase (`git rebase -i <baseline>`) and set all relevant commits to `edit` (or `e`).
4.  **At Each Stop (The "Edit Stop" Cycle)**:
    -   **Synchronize Infrastructure**: Check out the latest versions of shared infrastructure files (test harnesses, documentation, build scripts) from the `growing-yaml` branch.
    -   **Apply Refactoring**: Implement the target refactoring for the current commit's scope.
    -   **TDD Verification**: 
        -   Build the project.
        -   Run tests using the [test_yaml_suite.py](test_yaml_suite.py) or [tdd_harness.sh](tdd_harness.sh).
        -   Ensure behavior is consistent with the current commit's intent.
    -   **Commit**: Amend the commit or create a new `refactor:` commit.
    -   **Continue**: `git rebase --continue`.
5.  **Final Polish**: Verify the final state against the original HEAD to ensure no regressions were introduced.

## Implementation Details

### Named References in Bison
When refactoring Bison grammars, replace positional arguments (e.g., `$1`, `$2`) with named references (e.g., `[name]`). This is part of the "Logic-to-Grammar" effort described in [.agent/ENGINEERING_PLAYBOOK.md](.agent/ENGINEERING_PLAYBOOK.md).

### Future Awareness
"Future Awareness" means that while working on an early commit, we use information from later commits to make better design decisions today. For example:
-   Declaring tokens that we know will be needed later.
-   Setting up data structures that can support future features.
-   Ensuring agent documentation (this playbook) is present throughout the history.

## Links
-   [Engineering Playbook](.agent/ENGINEERING_PLAYBOOK.md)
-   [Agentic TDD Protocol](.agent/AGENTIC_TDD.md)
-   [Theory Aligned Solution](.agent/THEORY_ALIGNED_SOLUTION.md)
