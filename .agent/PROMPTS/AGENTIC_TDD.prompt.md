# Agentic TDD Protocol: The 5-Phase Cycle

Enforce the Agentic TDD Protocol to ensure every mutation is tool-verifiable.

```
Start
  ╥
  ╠═════════════════════╦═══════════════╡No
  ║                     ║                 ║  
 🔴 RED ╞═ 🟢 GREEN   🔵 REFACTOR       ║
            ╥           ╥                 ║
            ╠═══════════╝                 ║
            ║                             ╨
           🟡 VERIFY ╞═ ⚫ COMMIT ╞═ Definition Met?
                                          ╥
                                         Yes ╞═ ✅ DONE
```

---

---

## Phase 1: RED (Establish Failure)
- **Identify**: Pinpoint a failing test from your test suite.
- **Verify Baseline**: Run the test harness to confirm the failure.
- **Analyze**: Use debugging tools to uncover the root cause.

---

## Phase 2: GREEN (Localize Fix)
- **Mutate**: Write the *simplest possible code* to pass the test.
- **Verify**: Run the harness; see the PASS (✅).

---

## Phase 3: REFACTOR (Align Theory)
- **Rework**: Generalize the quick fix into proper abstractions.
- **Map**: Replace the hack with properly structured code.

1. Inspect the implementation.
2. Identify the correct abstraction.
3. Rewrite using the abstraction layer.

---

## Phase 4: VERIFY (Protect History)
- **Test Full Suite**: Run complete test suite to guard against regressions.
- **Revert**: Eliminate regressions by reverting to the stable Green state.

---

## Phase 5: ATOMIC COMMIT
- **Checkpoint**: Commit referencing the Test ID.

---

## Continuous Cycling Until Definition of Done

**Critical**: Do not stop after a single cycle. Continue cycling through RED → GREEN → REFACTOR → VERIFY → COMMIT until the work matches the user's supplied Definition of Done.

### When to Continue
- If failing tests remain, return to Phase 1 (RED) with the next failing test.
- If regressions appear in Phase 4 (VERIFY), return to Phase 3 (REFACTOR) to fix root causes.
- If code structure doesn't align with architecture, the Refactor phase was incomplete—return to Phase 3.
- If additional edge cases or requirements emerge, start a new RED phase.

### When to Stop
Only when:
1. **100% Pass Rate**: All target tests pass.
2. **Zero Regressions**: Full test suite remains green.
3. **Zero Leaks**: Instrumentation confirms no resource leaks.
4. **Theory Alignment**: Code structure reflects architectural specifications.

This aligns with the **Definition of Done** in the Engineering Handbook. One cycle is rarely sufficient for production-ready code.

---

## Benefits

- **Tool-Verifiable**: Each phase produces measurable outcomes (test results, code diffs).
- **Theory Alignment**: Refactor phase ensures code structure matches architectural intent.
- **Regression Protection**: Verify phase maintains historical baselines.
- **Atomic History**: Commits preserve clear decision points and can be bisected for debugging.
