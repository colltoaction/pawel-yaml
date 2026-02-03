# TDD Strategy: Pawel-YAML Test Pass Rate Improvement

## Current Baseline
- **Passing**: 195/351 (55.6%)
- **False Positives**: 36 (reject required, but accepting)
- **False Negatives**: 120 (accept required, but rejecting)

## Strategic Decision

**Focus on False Negatives** (120 potential +points)
- Larger opportunity than false positives (36 points)
- False negatives = we're being too strict
- False positives = we're being too permissive
- **Hypothesis**: Many false negatives are simple cases we can unlock quickly

## TDD Discipline (Strict 5-Phase Protocol)

For EACH cycle:

1. **RED**: Pick ONE failing test, understand why it fails
2. **GREEN**: Implement minimal fix (even if "ugly")
3. **REFACTOR**: Extract clean helper, document assumptions
4. **VERIFY**: Full test suite pass (no regressions)
5. **COMMIT**: With complete TDD documentation

## No Exploration Phase
- NO analyzing multiple tests before RED
- NO attempting parser rewrites without GREEN first
- NO debugging individual cases outside the cycle
- Each cycle is: 1 test → fix → verify → commit

## Next 3 Cycles (Planned)

### Cycle 4: Find easiest false negative
- **Constraint**: Must be rejectable in 5-10 lines of code change
- **Exit criteria**: Test now passes, no regressions

### Cycle 5: Batch similar false negatives
- **After** Cycle 4 succeeds, find 2-3 similar failures
- **Pattern**: Fix class of issues, not individual tests

### Cycle 6: Refactor for quality
- **After** 2-3 cycles, clean up accumulated technical debt

## Success Metrics per Cycle
- ✅ RED: Test clearly identified and failing
- ✅ GREEN: Minimal change, test passes
- ✅ REFACTOR: Code is clean, documented
- ✅ VERIFY: No regressions (still 195+ or better)
- ✅ COMMIT: Descriptive message with phase documentation

## Rules for This Session
1. Do NOT investigate more than 1 test during RED phase
2. Do NOT consider parser rewrites (only lexer/action changes)
3. Do NOT skip REFACTOR phase
4. Do NOT commit without VERIFY phase showing result
5. Do NOT move to next cycle until previous is fully committed
