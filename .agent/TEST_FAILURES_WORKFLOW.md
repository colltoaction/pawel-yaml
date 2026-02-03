# TEST_FAILURES.yaml Workflow

## Purpose
TEST_FAILURES.yaml tracks which test cases are currently failing. It evolves through each commit cycle.

## Format
Simple YAML list of failing test codes (four-letter identifiers).

## Workflow

### Initial State (f7da704)
All tests failing:
```yaml
failing_tests:
  - 229Q
  - 236B
  - 26DV
  - 27NA
```

### After each feat: commit
When a test passes, its code is removed from the list.
The commit message is `feat: XXXX, YYYY, ...` listing the newly passing tests.

Example:
- **GREEN 229Q commit** removes 229Q from list
  - Commit message: `feat: 229Q`
  - New list: `[236B, 26DV, 27NA]`

- **236B commit** removes 236B from list  
  - Commit message: `feat: 236B`
  - New list: `[26DV, 27NA]`

## Current Status
See TEST_FAILURES.yaml for the current list of failing tests.
