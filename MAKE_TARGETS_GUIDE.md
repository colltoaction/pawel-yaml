# Make Targets Guide - Quick Start

## One-Time Setup

```bash
make setup   # Clone yaml-test-suite, yaml-runtimes, yaml-play
```

## Daily Workflow

### Option 1: Safe Rebuild + Test

```bash
make clean && make tdd
```

This:
- ✓ Removes generated code
- ✓ Preserves yaml-test-suite (351 tests)
- ✓ Lists available tests (251 discovered)

### Option 2: Run Specific Test

```bash
make tdd
./tdd_harness.sh test 2XXW   # Run test 2XXW
```

### Option 3: Validate Architecture

```bash
make chaos    # Parser grammar validation (6 alternatives)
make lexing   # Lexer token validation (9 rules)
```

### Option 4: Full Validation Suite

```bash
make tdd chaos lexing   # Run all three
```

## Complete Commands

### Quick Development Cycle

```bash
# 1. Setup (once)
make setup

# 2. Make changes to src/parser.y or src/lexer.l
$EDITOR src/parser.y

# 3. Rebuild safely
make clean && make

# 4. Test changes
make tdd                           # See tests
./tdd_harness.sh test <TEST_ID>   # Run specific

# 5. Validate no regressions
make chaos                         # Parser health
make lexing                        # Lexer health

# 6. Commit
git add src/parser.y src/lexer.l
git commit -m "feat: ..."
```

### Full Reset (When Needed)

```bash
make deepclean           # Remove all build artifacts
make setup               # Re-clone test suites
make clean && make       # Rebuild from scratch
make tdd chaos lexing    # Validate everything
```

### Single Test Iteration

```bash
# Identify failing test
FAILING_TEST=$(make tdd 2>&1 | grep -o "^[A-Z0-9]*$" | head -1)

# Edit and rebuild
$EDITOR src/parser.y
make clean && make

# Test it
./tdd_harness.sh test $FAILING_TEST

# If passes, validate
make chaos && make lexing
```

## Target Summary

| Command | Purpose | Time |
|---------|---------|------|
| `make` | Build parser & lexer | ~2s |
| `make setup` | Clone test suites | ~10s |
| `make clean` | Safe rebuild (preserves tests) | ~1s |
| `make deepclean` | Full reset | ~1s |
| `make tdd` | List & discover tests | ~1s |
| `make chaos` | Parser validation | ~20s |
| `make lexing` | Lexer validation | ~20s |

## Example Full Workflow

```bash
$ make setup
Cloning yaml-test-suite...

$ make clean && make
Rebuilding parser and lexer...

$ make tdd
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  TDD Harness - Test Discovery and Execution
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
236B
2CMS
2G84
  ... (251 total tests available)

$ ./tdd_harness.sh test 2XXW
PASS: 2XXW

$ make chaos
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Parser Chaos Engineering - Grammar Rule Necessity Analysis
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
- ✓ ACTIVE: ALIAS in simple_node
- ✓ ACTIVE: ANCHOR node
  ... (6/6 active)

$ git add src/parser.y && git commit -m "feat: ..."
[history-v6 abc1234] feat: ...
```

## Key Points

✅ **Safe by Default**: `make clean` preserves test suite  
✅ **One-Liners**: `make tdd chaos lexing` runs all validation  
✅ **Reproducible**: Artifacts tracked in git  
✅ **Fast**: Incremental builds, no unnecessary recompilation  
✅ **Clear Feedback**: Pretty-printed output with progress  

## Artifacts Location

- Test cases: `build/lib/yaml-test-suite/src/` (351 tests)
- Reports: `build/log/` (chaos_dead_code.md, CHAOS_LEXING_RESULTS.md)
- Temp files: `build/tmp/` (test inputs during execution)

## Troubleshooting

**Tests not discovered?**
```bash
make setup              # Ensure yaml-test-suite cloned
make tdd                # Should show 251 tests
```

**Build failing?**
```bash
make deepclean          # Full reset
make setup              # Re-clone deps
make                    # Fresh build
```

**Chaos reports missing?**
```bash
make chaos lexing       # Regenerate reports
ls -la build/log/       # Verify created
```

---

**Status**: Ready for production
**Last Updated**: February 1, 2026
