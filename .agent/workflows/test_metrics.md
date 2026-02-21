# Unified Test Metrics

**Date:** February 21, 2026
**Status:** All metrics now consolidated

## Single Metric (42.2%)

All test scripts should report the same number:

**148 / 351 tests passing (42.2%)**

### Breakdown:
- **73 / 82** invalid YAML tests correctly rejected (89%)
- **75 / 269** valid YAML tests with correct events (28%)

## How Tests Are Counted

A test **PASSES** if:
1. **Invalid YAML (fail: true)**: Parser returns exit code ≠ 0
   - Example: `6S55` should fail but currently PASSES (parser accepts it)

2. **Valid YAML (fail: false)**:
   - Parser returns exit code = 0 **AND**
   - Output events match expected tree exactly

## Test Infrastructure

### Primary Script: `test_runner.py`
- Single source of truth for all metrics
- Generates TEST_FAILURES.yaml
- Can be called by all other scripts

```bash
# Run all tests
python3 .agent/test_runner.py

# Run specific tests
python3 .agent/test_runner.py --test 5WE3 --test 26DV

# Update TEST_FAILURES.yaml
python3 .agent/test_runner.py --update
```

### Secondary Scripts (all call test_runner.py)
- `detect_issues.py` - For investigating diffs
- `tdd_harness.sh` - For TDD workflow
- `consolidated_script.sh` - For git bisect

## Key Discrepancies Resolved

### Before Consolidation
- TEST_FAILURES.yaml: 296 passing (exit code only)
- detect_issues.py: 144 passing (exit codes + events)
- tdd_harness.sh: Inconsistent metrics

### After Consolidation
- **All scripts now use: 148 passing (exit codes + events)**
- Clear breakdown shows: 73 invalid YAML + 75 valid YAML
- TEST_FAILURES.yaml updates from unified test_runner.py

## Verification

Run these to verify all metrics match:

```bash
# Get unified result
python3 .agent/test_runner.py

# Check detect_issues (should show similar summary)
python3 .agent/detect_issues.py 2>&1 | tail -1

# Check TEST_FAILURES.yaml (after update)
python3 .agent/test_runner.py --update
cat TEST_FAILURES.yaml | grep total_passes
```

All three should report approximately the same passing count.
