# TDD Strategy: Pawel-YAML False Negative Recovery (Phase 8+)

## Current Baseline (Phase 8 Consolidation - February 5, 2026)
- **Passing**: 82/351 (23.4%) [Honest baseline with strict RML validation]
- **Failing**: 269/351 (76.6%) [False negatives under stricter validation]
- **False Negatives**: 126+ potential recovery targets (per .agent/TDD_STRATEGY_ANALYSIS.md)
- **Previous Baseline**: 218/351 (62.1%) [Pre-consolidation, permissive validation]

## Consolidation Philosophy

Phase 8 **intentionally** dropped pass rate from 62% to 23% by unifying Stage 2 (IR generation) and Stage 3 (Event stream validation) into a single, RML-aligned validator. This prioritizes **correctness** over coverage.

**The 136 "lost" tests** are now false negatives—tests that should pass under YAML spec, but aren't handled by our current implementation. They represent genuine gaps, not bugs in validation.

## Strategic Decision

**Focus on False Negatives** (126 potential +points)  
- **Hypothesis**: Many are simple cases we can unlock quickly via TDD
- **Approach**: Agentic TDD Protocol (RED-GREEN-REFACTOR-VERIFY-COMMIT)
- **Target**: Recover to 100% pass rate through systematic cycles
- **Measurement**: Each cycle yields 1-5+ tests, measurable progress

## TDD Discipline (Strict 5-Phase Protocol per .agent/PLAYBOOK/AGENTIC_TDD.prompt.md)

For EACH cycle:

1. **RED**: Failure Establishment
   - Pick ONE failing test (prioritize ease per TDD_STRATEGY_ANALYSIS)
   - Verify it fails repeatedly, deterministically
   - Root cause analysis via debug infrastructure

2. **GREEN**: Minimal Mutation
   - Implement the **simplest possible** fix
   - Not optimized, not generalized—just passing
   - Test must pass, no other changes

3. **REFACTOR**: Theoretical Alignment
   - Generalize the quick fix into proper abstractions
   - Align code with RML morphism for the feature
   - Maintain test pass, improve code structure

4. **VERIFY**: Regression Guard
   - Run full 351-test suite
   - Ensure pass count >= baseline (82+)
   - If regression, return to GREEN or revert

5. **COMMIT**: Atomic Checkpoint
   - Descriptive commit message with test ID
   - Includes TDD cycle documentation
   - Clean working directory

## No Exploration Phase
- ❌ NO analyzing multiple tests before RED
- ❌ NO attempting parser rewrites without GREEN first
- ❌ NO debugging individual cases outside the cycle
- ✅ Each cycle is: 1 test → fail → fix → pass → verify → commit

## Prioritization: Easier Tests First (Per TDD_STRATEGY_ANALYSIS)

### Current Focus: Cycle 1 (In Progress - February 5, 2026)

**Test**: 26DV - Anchors on Map Keys
- **Issue**: `&anchor key: value` syntax hangs parser
- **Status**: RED ✓, GREEN ✓ (grammar conflicts resolved)
- **Next**: Verify no hang on simple anchor input
- **Complexity**: Medium (grammar changes, but isolated to node_props)
- **Expected Duration**: 1-2 TDD cycles

### Planned Cycles 2-10 (Queued)

Prioritized by ease/complexity (from analysis):
1. **2LFX** - Special chars in unquoted scalars
2. **4EJS** - Block scalar edge cases
3. **6CK3** - Tag handling
4. **5T43** - Explicit key syntax
5. **8G76** - Flow context delimiters
6. ... (120+ more in queue)

## Success Metrics per Cycle

| Phase | Success Criteria | Measurement |
|:---:|:---|:---|
| **RED** | Test clearly failing | Exit code != 0 |
| **GREEN** | Target test passing | Exit code = 0 for test ID |
| **REFACTOR** | Code quality meets standards | LGTM via code review checklist |
| **VERIFY** | No regressions | Pass rate >= 82 (or better) |
| **COMMIT** | Atomic + documented | Clean git status, imperative message |

## Definition of Done (Cycle Complete)

✅ All 5 phases completed  
✅ Test now passes (GREEN verified)  
✅ No regressions in 82 baseline tests  
✅ Code aligns with RML pattern for feature  
✅ Atomic commit with clear message  

## Monthly Targets

- **Week 1** (Feb 1-7): 26DV + similar (5-10 tests) → 25% pass rate
- **Week 2** (Feb 8-14): Batch 2 (10-15 tests) → 30-35% pass rate
- **Week 3** (Feb 15-21): Batch 3 (15-20 tests) → 40-45% pass rate
- **Week 4** (Feb 22-28): Scaling via pattern discovery → 50%+ pass rate

## Agentic TDD Best Practices

**From Definition of Done (.agent/PLAYBOOK/definition-of-done.prompt.md)**:

1. **Minimize Yielding**: Complete full cycle before reporting status
2. **Handle Errors Internally**: Use git revert, make clean, etc.
3. **3-Attempt Rule**: Try 3 distinct fixes before escalating
4. **Persistence**: Regressions = fix root cause, don't revert
5. **Macro Cycle**: Future-aware refactoring via interactive rebase

**Tools**:
- `make test` or `.agent/stage4_full_verification.sh` for regression check
- `git diff` to validate atomic changes
- Debug prints in lexer/parser for problem diagnosis


## Rules for This Session
1. Do NOT investigate more than 1 test during RED phase
2. Do NOT consider parser rewrites (only lexer/action changes)
3. Do NOT skip REFACTOR phase
4. Do NOT commit without VERIFY phase showing result
5. Do NOT move to next cycle until previous is fully committed
