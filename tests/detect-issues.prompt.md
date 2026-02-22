---
description: How to detect YAML parsing issues via tree comparison
---

# YAML Tree Comparison Workflow

This workflow uses high-fidelity event comparison to detect subtle parsing issues that simple success/fail checks might miss.

## Prerequisites

- The parser must be built: `make`
- The YAML Test Suite must be initialized: `make yaml-test-suite`

## Steps

1. **Run the Detection Script**
   Execute the issue detection script to find mismatches between the parser's internal events and the canonical test tree.

   // turbo
   ```bash
   python3 tests/legacy/scripts/detect_issues.py
   ```

2. **Analyze Diffs**
   If the script reports `DIFF` for a test case, inspect the unified diff output.
   Example:
   ```
   DIFF: 5WE3
         --- EXPECTED
         +++ ACTUAL
         @@ -10,5 +10,4 @@
          =VAL |block key\n
          +SEQ
           =VAL :one
          - =VAL :two
          - -SEQ
   ```

3. **Targeted Debugging**
   Run the detection script for a single test case to focus on a specific failure:
   ```bash
   python3 tests/legacy/scripts/detect_issues.py --test 5WE3
   ```

4. **Verify Fixes**
   After modifying the lexer or parser, re-run the script to verify the diff is resolved.
