# DOD Implementation Guide: UNIX-Aligned Phase 2

**Purpose:** Bridge Definition of Done with UNIX first principles  
**Audience:** Developer implementing Phase 2  
**Duration:** 2-4 time units  

---

## The Path: From DOD to Completion

You have a complete Definition of Done. Now here's how to execute it using UNIX-aligned thinking.

---

## Phase 2 Implementation Walkthrough

### Step 1: Understand the Single Responsibility (15 smaller time units)

**UNIX Principle:** Each component does one thing well.

Your `validate_events()` function has **one job:**
- Walk the event tree
- Check that semantic constraints are satisfied
- Return 0 (invalid) or 1 (valid)

That's it. Nothing else. No side effects except error reporting.

**Verify Understanding:**
```
□ Can you explain validate_events() in one sentence?
  "It walks the YAML parse tree and checks semantic constraints."
□ Can you list its inputs? 
  "Pointer to root Event"
□ Can you list its outputs?
  "0 (invalid) or 1 (valid), plus yyerror() call on failure"
□ Can you describe 3 constraints it checks?
  "Flow indentation, block scalar indentation, mapping keys"
```

---

### Step 2: Review the YACC Pattern (20 smaller time units)

**Reference:** `.agent/YACC_INSIGHTS.md` Section 2 (Actions) and Appendix C

Read the interval arithmetic example from YACC paper:
```c
vexp : dexp ',' dexp
    {
        $$.lo = $2; $$.hi = $4;
        if ($$.lo > $$.hi) {
            printf("interval out of order\n");
            YYERROR;
        }
    }
```

**This is your pattern.** The constraint check happens **after parsing** in an **action**.

Your equivalent:
```c
documents : explicit_documents
    {
        $$ = $1;
        if (!validate_events($$)) {
            yyerror("Invalid YAML document");
            YYERROR;
        }
    }
```

**Verify Understanding:**
```
□ When does the constraint check execute?
  "After the documents rule is recognized (post-parse)"
□ What does YYERROR do?
  "Triggers error recovery, rejects the parse"
□ Where is error message set?
  "Via yyerror() call"
□ Is this modifying grammar?
  "No, this is an action on an existing rule"
```

---

### Step 3: Gather the Constraint List (15 smaller time units)

**Reference:** `.agent/NEXT_STEPS.md` - Lists all 36 false positives

Organize the 36 constraints into logical groups:

**Group 1: Flow Context Indentation (9 tests)**
- 9C9N: Flow sequence with unindented continuation
- 4CQQ: Similar flow indentation issue
- ... (7 more)

**Group 2: Block Scalar Indentation (8 tests)**
- 5LLU: Block scalar with invalid indentation
- 7ZZ5: Similar block scalar issue
- ... (6 more)

**Group 3: Mapping Values (7 tests)**
- 236B: Invalid mapping value placement
- 55WF: Similar mapping issue
- ... (5 more)

**Group 4: Tag/Anchor Placement (6 tests)**
- 9HCY: Tag in invalid position
- EW3V: Anchor issue
- ... (4 more)

**Group 5: Document Markers (6 tests)**
- 5TRB: Document marker positioning
- EB22: Similar document marker issue
- ... (4 more)

**Verify Understanding:**
```
□ How many constraint groups?
  "5 main categories"
□ How many tests per group on average?
  "36 / 5 = ~7 tests per group"
□ Which group do you start with?
  "Start with smallest/simplest group"
□ How do you know when a constraint is working?
  "Run test_correct.py and see +1 passing test"
```

---

### Step 4: Create validate_events() Function Structure (30 smaller time units)

**Pattern:** One check function per constraint group

```c
// In mrl.y, in %{ %} section:

// Group 1: Flow context constraints
int check_flow_indentation(struct Event *doc) {
    // Walk event tree
    // Find flow sequences/mappings
    // Verify indentation within flow context
    // Return: 1 (valid) or 0 (invalid)
}

// Group 2: Block scalar constraints
int check_block_scalar_indentation(struct Event *doc) {
    // Walk event tree
    // Find block scalars
    // Verify indentation matches rules
    // Return: 1 (valid) or 0 (invalid)
}

// Group 3: Mapping constraints
int check_mapping_keys(struct Event *doc) {
    // Walk event tree
    // Verify mapping key validity
    // Return: 1 (valid) or 0 (invalid)
}

// Group 4: Tag/anchor constraints
int check_anchor_tags(struct Event *doc) {
    // Walk event tree
    // Verify tag/anchor placement
    // Return: 1 (valid) or 0 (invalid)
}

// Group 5: Document markers
int check_doc_markers(struct Event *doc) {
    // Walk event tree
    // Verify document marker positions
    // Return: 1 (valid) or 0 (invalid)
}

// Master validator
int validate_events(struct Event *root) {
    // Call all constraint checkers
    // Return 0 (invalid) if any constraint fails
    // Return 1 (valid) if all pass
    
    if (!check_flow_indentation(root)) return 0;
    if (!check_block_scalar_indentation(root)) return 0;
    if (!check_mapping_keys(root)) return 0;
    if (!check_anchor_tags(root)) return 0;
    if (!check_doc_markers(root)) return 0;
    
    return 1;  // All constraints satisfied
}
```

**UNIX Principle:** Each function has single responsibility + composable structure.

---

### Step 5: Test Incrementally (1-2 time units)

**Process:** Add one constraint, test, commit, move to next.

**Constraint 1 - Flow Indentation (test: 9C9N)**
```bash
1. Implement check_flow_indentation()
2. Run: make
3. Run: python3 build/tmp/test_single.py 9C9N
   Expected: FAIL (now correctly rejects invalid input)
4. Run: python3 test_correct.py
   Expected: Pass: 216/351 (was 215, now caught 9C9N)
5. git commit -m "feat: Add flow indentation validation"
```

**Constraint 2 - Block Scalars (test: 5LLU)**
```bash
1. Implement check_block_scalar_indentation()
2. Run: make
3. Test: 5LLU should now fail
4. Run: python3 test_correct.py
   Expected: Pass: 217/351 (caught 5LLU)
5. git commit -m "feat: Add block scalar validation"
```

Continue for all 36 constraints...

**Incremental Testing Benefits (UNIX Principle):**
- ✅ Know exactly which constraint caught which test
- ✅ Can rollback one constraint if needed
- ✅ Verify no regressions after each addition
- ✅ Clear git history showing progress

---

### Step 6: Verify Against DOD (30 smaller time units)

**Go through the Definition of Done checklist:**

```
CODE IMPLEMENTATION
□ validate_events() implemented? 
  Count lines: should be ~150-200
□ All 36 constraints? 
  Count checks: should be 36
□ Wired into parser?
  Check: documents rule has YYERROR call
□ Compiles?
  Run: make (should succeed)
□ No warnings?
  Check: make output (should have no -Wall warnings)
□ Style correct?
  Review: against existing code style in mrl.y

TESTING
□ All 215 tests still pass?
  Run: python3 test_correct.py
  Expected: at least "Pass: 215/351"
□ False positives converted?
  Count: should be 35+ new passing tests
□ Total tests?
  Expected: 250+/351
□ Regressions?
  Expected: 0 (compare to baseline)

CODE REVIEW
□ Follows RML theory?
  Semantic validation outside grammar ✓
□ Follows YACC pattern?
  Post-parse validation in actions ✓
□ Follows UNIX principles?
  Single responsibility, composable ✓
```

---

### Step 7: Document the Implementation (30 smaller time units)

**Add to code:**
```c
// In mrl.y, before validate_events():

/*
 * PHASE 2: SEMANTIC VALIDATION
 * 
 * These functions walk the parsed event tree and check semantic
 * constraints that cannot be expressed in the grammar.
 * 
 * Each constraint corresponds to YAML specification rules:
 * - Flow indentation: Elements cannot dedent below flow start
 * - Block scalars: Must maintain consistent indentation
 * - Mapping keys: Must follow mapping syntax rules
 * - Tags/anchors: Must appear in valid positions
 * - Document markers: Must follow document structure
 * 
 * Together, these 36 constraints convert false positives to 
 * true negatives, improving from 215/351 (61%) to 250+/351 (71%).
 */

// Implementation follows...
```

**Document in ARCHITECTURAL_BOUNDARY.md:**
```
Add section: "Phase 2 Implementation: Semantic Validation"
- Explain that validate_events() checks 36 constraints
- List constraint categories
- Show before/after test count
- Reference DOD for completion criteria
```

---

### Step 8: Final Verification (20 smaller time units)

**Run the definitive test:**
```bash
make clean && make
timeout 120 python3 test_correct.py
git log --oneline -10
```

**Expected output:**
```
[Build succeeds without warnings]
Pass: 250+/351 (71%+)
[Recent commits showing constraint additions]
```

**Spot-check specific false positives:**
```bash
# These should all FAIL (correctly):
python3 build/tmp/test_single.py 9C9N   # Flow indentation
python3 build/tmp/test_single.py 5LLU   # Block scalar
python3 build/tmp/test_single.py 236B   # Mapping value
python3 build/tmp/test_single.py 9HCY   # Tag placement
python3 build/tmp/test_single.py 5TRB   # Document marker
```

---

## UNIX Alignment Checklist

As you implement, verify UNIX principles:

```
□ Single Responsibility
  Each check function does ONE thing
  validate_events() only calls, doesn't compute
  
□ Composability
  Can call constraints independently
  Can extend with new constraints easily
  Can disable constraints for testing

□ Universality
  Works on any event tree (not just from this parser)
  Doesn't assume source of events
  
□ Modularity
  Each constraint is independent
  Can modify one without affecting others
  Clear interface (Event tree → 0/1)

□ Transparency
  Code comments explain constraints
  Clear error messages
  Can understand flow by reading mrl.y

□ Constraints as Strengths
  Grammar limitation (can't validate semantics)
  Led to clean separation (Phase 2)
  More elegant than forcing into grammar
```

---

## Troubleshooting Guide

**Problem:** Some tests still pass that should fail

**Solution:**
1. Identify which constraint is missing
2. Implement that specific check
3. Test: `python3 build/tmp/test_single.py [failing_test]`
4. Verify: `make && python3 test_correct.py`
5. Commit: `git commit -m "fix: Complete [constraint] validation"`

**Problem:** Test count decreases (regression)

**Solution:**
1. Identify which constraint caused regression
2. Review logic (likely too strict)
3. Fix constraint check
4. Test: `python3 test_correct.py`
5. If still broken: `git revert [commit]` and rethink approach

**Problem:** Compilation warnings

**Solution:**
1. Fix warnings (use -Wall, -Wextra)
2. Common issues: unused variables, signed/unsigned mismatches
3. Don't suppress warnings, fix root cause
4. Verify: `make` produces no -Wall output

---

## Success Verification

You're done when:

```
✅ validate_events() implemented (~150-200 lines)
✅ All 36 constraints checked
✅ 250+/351 tests passing
✅ No regressions from 215 baseline
✅ Clean compilation (no warnings)
✅ Code documented
✅ Commits are clear and atomic
✅ DOD checklist complete
```

---

## The Prize

When you finish Phase 2, you'll have:

- ✅ **61.3% → 71%+** test pass rate
- ✅ **36 false positives** converted to true negatives
- ✅ **UNIX-idiomatic** architecture
- ✅ **RML-justified** separation of concerns
- ✅ **YACC-proven** pattern
- ✅ **Clean, maintainable** codebase
- ✅ **Complete documentation** of design

**That's a solid YAML parser.**

---

## Remember

This isn't experimental. You're implementing a pattern:
- Proven by YACC (50+ years)
- Justified by RML (mathematics)
- Validated by UNIX (architecture)
- Measured by tests (215 → 250+)

**You've got this.** Follow the DOD, test incrementally, commit often.

**Expected duration:** 2-4 time units for a developer familiar with C and Bison.

**Success probability:** ~95% (if you follow the pattern and test incrementally).

---

**Good luck. You're implementing elegance.**

Start with `.agent/NEXT_STEPS.md` for the constraint list.
Reference `.agent/YACC_INSIGHTS.md` for the pattern.
Check `.agent/DEFINITION_OF_DONE.md` for completion criteria.

The path is clear. The requirements are specific. The frameworks validate the approach.

**Now go build Phase 2.**
