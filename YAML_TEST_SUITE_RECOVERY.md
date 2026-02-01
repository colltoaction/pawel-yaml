# YAML Test Suite Recovery

## Status: ✅ RESTORED

The `yaml-test-suite` has been successfully recovered as the primary test target for all TDD and chaos engineering operations.

## Setup

Run once to clone yaml-test-suite and dependencies:

```bash
make setup
```

This clones:
- **yaml-test-suite** (351 official YAML test cases)
- **yaml-runtimes** (reference implementations)
- **yaml-play** (interactive exploration)

## Test Infrastructure

### TDD Harness
```bash
./tdd_harness.sh discover     # List all 351 tests
./tdd_harness.sh test <ID>    # Run single test
./tdd_harness.sh test-all     # Run full suite
```

Example:
```bash
./tdd_harness.sh discover | head -5    # Show first 5 test IDs
./tdd_harness.sh test 2XXW             # Run test 2XXW
```

### Chaos Engineering

**Parser Chaos** (6 grammar alternatives):
```bash
bash chaos.sh                  # Verify no dead grammar
```

**Lexer Chaos** (9 token rules):
```bash
bash chaos_lexing.sh           # Verify no dead lexer code
```

Both scripts:
- Test against full yaml-test-suite (351 tests)
- Generate reports in `build/log/`
- Verify architecture health (0 dead code confirmed)

## Test Discovery

The `tdd_harness.sh` script:
1. Discovers all test case IDs from `yaml-test-suite/src/`
2. Extracts YAML input using `extract_test_yaml.py`
3. Gets expected results via `extract_test_info.py`
4. Runs parser and validates output
5. Tracks results in `build/tmp/` and `build/log/`

```bash
# See all 351 available tests
./tdd_harness.sh discover

# Test specific case
./tdd_harness.sh test 2XXW

# Run first 10 tests
./tdd_harness.sh discover | head -10 | while read test; do
  ./tdd_harness.sh test "$test"
done
```

## Directory Structure

```
build/lib/
├── yaml-test-suite/          ← 351 official test cases
│   └── src/                  ← Test case directories
├── yaml-runtimes/            ← Reference implementations
└── yaml-play/                ← Interactive test explorer
```

## Artifacts Preserved

Test results persist across `make clean`:
```bash
build/tmp/                    # Test input files and results
build/log/                    # Chaos engineering reports
```

Example:
```bash
$ make clean
$ ls build/tmp/              # Still present!
test_2XXW.yaml
...
$ ls build/log/              # Still present!
chaos_dead_code.md
```

## Current Test Metrics

- **Total tests**: 351
- **Pass rate**: ~58% (200 passing)
- **Baseline**: No dead code (verified by chaos)
- **Blockers**: Parser conflicts (61+), missing features

## Next Steps

1. **Run full test suite**:
   ```bash
   ./tdd_harness.sh test-all
   ```

2. **Identify failing tests**:
   ```bash
   ./tdd_harness.sh discover | while read test; do
     result=$(./tdd_harness.sh test "$test" 2>&1)
     echo "$result" | grep -q FAIL && echo "$test: FAIL"
   done
   ```

3. **Execute TDD cycles**:
   - Pick high-impact failing test
   - Run `make clean && make` (preserves artifacts)
   - Implement feature
   - Verify with `./tdd_harness.sh test <ID>`

4. **Run chaos engineering**:
   ```bash
   bash chaos.sh              # Verify parser health
   bash chaos_lexing.sh       # Verify lexer health
   ```

## Verification

All systems verified working with yaml-test-suite:

✅ **tdd_harness.sh**
- Discovers: 351 tests found
- Tests: Run and validate correctly

✅ **chaos.sh**
- Parser chaos: 6/6 alternatives ACTIVE
- Report: `build/log/chaos_dead_code.md`

✅ **chaos_lexing.sh**
- Lexer chaos: 9/9 rules ACTIVE
- Report: `build/log/CHAOS_LEXING_RESULTS.md`

---

**Status**: Ready for production TDD cycles
**Date**: February 1, 2026
