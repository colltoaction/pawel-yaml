description: How to detect YAML parsing issues via grammar-loop checks and tree comparison
---

# YAML Grammar + Tree Workflow

This workflow gates on grammar-driven stream closure first, then runs high-fidelity event comparison.
Any interactive behavior must come from grammar alternatives (monoidal stream/document composition), not CLI protocol.

## Prerequisites

- The parser must be built: `make`
- The YAML Test Suite must be initialized: `make yaml-test-suite`

## Steps

1. **Run Grammar-Loop Conformance**
   Validate loop semantics via grammar alternatives (`stream -> monoid YYEOF` and document alternatives).
   This verifies acceptance/rejection boundaries for open vs closed streams.
   Expectations are file-based under `tests/grammar-loops/expected/`.

   ```bash
   make -C tests grammar-loops
   ```

   To refresh one expectation from current parser output:
   ```bash
   make -C tests grammar-loops-expect CASE=<case-id>
   ```

2. **Run the Detection Script**
   Execute issue detection to find mismatches between parser events and canonical `tree` expectations.

   ```bash
   python3 tests/legacy/scripts/detect_issues.py
   ```

3. **Analyze Diffs**
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

4. **Targeted Debugging**
   Run the detection script for a single test case to focus on a specific failure:
   ```bash
   python3 tests/legacy/scripts/detect_issues.py --test 5WE3
   ```

5. **Verify Fixes**
   After modifying the lexer or parser, re-run the script to verify the diff is resolved.
