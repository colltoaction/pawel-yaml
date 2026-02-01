# Make Clean Strategy: TDD-Aware Build System

## Problem Statement

The original `make clean` deleted ALL of `build/` with `rm -rf $(BUILD_DIR)`. This interfered with TDD operations:

1. **VERIFY Phase Disruption**: During `make clean && make`, test artifacts in `build/tmp/` vanished
2. **Test Tracking Loss**: TEST_FAILURES.yaml references stored in `build/tmp/` were deleted
3. **TDD Infrastructure Deleted**: Scripts, logs, and intermediate results lost
4. **No Granular Control**: No way to clean just parsers or lexers without full rebuild

**Impact**: TDD cycles in RED-GREEN-REFACTOR-VERIFY protocol couldn't safely clean between iterations.

## New Architecture

### Strategy: Preserve Test Artifacts, Clean Only Build Products

```
build/
├── src/          ← Generated parser/lexer (CLEANED)
├── inc/          ← Generated headers (CLEANED)
├── bin/          ← Compiled binary (CLEANED)
├── lib/          ← External deps (CLEANED)
├── tmp/          ← Test artifacts (PRESERVED)
└── log/          ← Build logs (PRESERVED)

*.o files        ← Object files (CLEANED)
```

### Make Targets

#### `make clean` (default, TDD-safe)
**Purpose**: Prepare for rebuild without losing test state
```bash
# Removes:
- Generated sources: build/src/
- Headers: build/inc/
- Binaries: build/bin/
- Libraries: build/lib/
- Object files: build/*.o

# Preserves:
- build/tmp/ → Test artifacts, chaos results, TDD logs
- build/log/ → Build session logs
```

**Usage**: 
```bash
make clean && make  # Safe during TDD VERIFY phase
./build/bin/pawel-yaml < test.yaml  # Artifacts still exist
```

#### `make deepclean` (full reset)
**Purpose**: Complete rebuild from scratch
```bash
# Removes everything in build/
```

**Usage**:
```bash
make deepclean && make  # Start completely fresh
```

#### `make clean-parser` (targeted)
**Purpose**: Rebuild just the parser
```bash
# Removes:
- src/parser.tab.c
- inc/parser.tab.h
- build/parser.tab.o
```

#### `make clean-lexer` (targeted)
**Purpose**: Rebuild just the lexer
```bash
# Removes:
- src/lex.yy.c
- build/lex.yy.o
```

### Updated .gitignore

**Before**: `build/` (ignored everything)

**After**: Selective ignoring
```gitignore
!build/tmp/      # Preserve test artifacts
!build/log/      # Preserve build logs
build/src/       # Ignore generated sources
build/inc/       # Ignore generated headers
build/bin/       # Ignore binaries
build/lib/       # Ignore external deps
```

## TDD Protocol Integration

Aligns with **Agentic TDD Protocol** phases:

### Phase 1: RED
```bash
./tdd_harness.sh TEST_5T43          # Test discovery
make clean && make                  # Build (preserves artifacts)
./chaos_lexing.sh                   # Artifacts survive
```

### Phase 2: GREEN
```bash
make clean && make                  # Rebuild with changes
./build/bin/pawel-yaml < test.yaml  # Verify
```

### Phase 4: VERIFY
```bash
make clean && make                  # Full rebuild
./chaos.sh                          # Test suite (results in build/tmp/)
# build/tmp/ preserved → can analyze results
```

### Phase 5: COMMIT
```bash
git add -A
git commit -m "feat: TEST_5T43"     # Changes + build/tmp artifacts
```

## Benefits

| Aspect | Before | After |
|--------|--------|-------|
| TDD Safety | ❌ Lost artifacts | ✅ Preserved across clean |
| Test Tracking | ❌ Deleted | ✅ Survives clean |
| Rebuild Speed | ⚠️ Full every time | ✅ Full or targeted |
| Granularity | ❌ All or nothing | ✅ Parser/lexer/deep options |
| Git Integration | ⚠️ Ignored build/ | ✅ Selective tracking of tmp/ |

## Migration Notes

### Existing Workflows
```bash
# OLD: make clean && make → deletes everything
# NEW: make clean && make → preserves artifacts

# OLD: Full reset needed
# NEW: make deepclean && make → same as before
```

### Preserving Build History
```bash
# Build artifacts stay in git if tracked
cd build/tmp/
git status  # Shows preserved files
```

### .gitignore Correctness
```bash
# Verify structure
git check-ignore -v build/src/lex.yy.c   # Should be ignored
git check-ignore -v build/tmp/chaos.log  # Should NOT be ignored
```

## Troubleshooting

**Problem**: Parser/lexer not updating after `make clean`
```bash
# Solution: Use targeted clean
make clean-parser && make
```

**Problem**: Too many artifacts accumulating in build/tmp
```bash
# Solution: Use deep clean periodically
make deepclean && make
```

**Problem**: Git tracking unexpected files
```bash
# Solution: Verify .gitignore patterns
git clean -fdxn build/  # Dry run
git clean -fdx build/   # Actually clean untracked
```

## Future Improvements

1. **Per-rule artifact tracking**: Track which rule generated which artifact
2. **Artifact expiration**: Auto-clean old artifacts after N days
3. **Incremental chaos**: Resume interrupted chaos testing
4. **Build cache**: Store intermediate artifacts for faster rebuilds
5. **CI/CD integration**: Preserve logs for analysis

## Implementation Details

### Makefile Variables
```makefile
TMP_DIR = $(BUILD_DIR)/tmp    # Test artifacts
LOG_DIR = $(BUILD_DIR)/log    # Build logs

# Created automatically by:
directories:
    mkdir -p $(TMP_DIR) $(LOG_DIR)
```

### Clean Strategy
```makefile
clean-build:
    # Remove generated code and binaries
    rm -rf $(GEN_SRC_DIR) $(GEN_INC_DIR) $(BIN_DIR) $(LIB_DIR)
    # Remove object files but keep directories
    rm -f $(BUILD_DIR)/*.o
```

## Verification

Test the new approach:
```bash
# Build
make clean && make

# Verify binary exists
./build/bin/pawel-yaml --version

# Create test artifact
echo "test" > build/tmp/test.txt

# Clean
make clean

# Verify artifact survives
cat build/tmp/test.txt  # Should work

# Deep clean
make deepclean

# Verify directory gone
ls build/tmp/  # Should fail
```

## References

- **TDD Protocol**: `.agent/TDD.md` (Phase 4: VERIFY)
- **Test Workflow**: `.agent/TEST_FAILURES_WORKFLOW.md`
- **Related**: `SESSION_SUMMARY.md` (Build system issues section)
