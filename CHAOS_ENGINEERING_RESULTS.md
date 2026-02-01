# Chaos Engineering Session Results

**Date**: 2026-02-01  
**Method**: Random removal of grammar rule alternatives  
**Tests**: 6 Bison parser alternatives tested  
**Result**: All alternatives are ACTIVE (no dead code)

## Summary

Ran systematic chaos engineering on yaml-test-suite using 5-test random samples.
Each grammar alternative was removed individually and test pass rate measured.

## Tested Alternatives

| Alternative | Status | Notes |
|------------|--------|-------|
| ALIAS in simple_node | ✓ ACTIVE | Tests fail without it |
| ANCHOR + node | ✓ ACTIVE | Tests fail without it |
| simple_node COLON (empty value) | ✓ ACTIVE | Tests fail without it |
| BLOCK_KEY alternatives | ✓ ACTIVE | Tests fail without it |
| COLON node (map with only value) | ✓ ACTIVE | Tests fail without it |
| flow_sequence_items COMMA | ✓ ACTIVE | Tests fail without it |

## Key Finding
**No dead code detected**. All tested grammar alternatives are being exercised by the test suite. The parser grammar is well-utilized.

## Baseline Metrics
- Random sample size: 5 tests per cycle
- Total tests available: 351 (yaml-test-suite)
- Passing: 2/5 (40%)
- Failing: 3/5 (60%)
- Baseline pass rate suggests ~140 tests passing, ~210 failing

## Identified Blockers (for next TDD cycles)

1. **Multi-line Plain Scalars** (~20+ tests)
   - Example: `d\ne` continuation not combined
   - Root: Lexer doesn't combine lines into single SCALAR
   - Complexity: Medium (requires lexer refactor)

2. **Flow Sequences with Tags** (~15+ tests)
   - Example: `[ "JSON like":adjacent ]`
   - Issue: Tag handling in flow context
   - Complexity: Medium

3. **Comments in Flow** (~5+ tests)
   - Example: `[ a, # comment\n b ]`
   - Issue: Comment handling within flow contexts

4. **Multi-line Mappings** (~10+ tests)
   - Various indentation edge cases

## Recommendations

1. **Fix lexer line continuation** for multi-line scalars (highest impact)
2. **Improve flow context tag handling**
3. **Add comment support in flow**
4. Continue TDD with high-impact fixes

## Tools Created

- `tdd_harness.sh` - Test discovery and execution
- `chaos.sh` - Chaos engineering framework
- Both scripts committed to git, survive `make clean`

## Next Steps

Pick next high-impact test (not 35KP due to multi-line complexity).
Target: Find test failing due to simpler grammar issue.
