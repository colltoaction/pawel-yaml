# Definition of Done: YAML Parser Phase 2 Implementation

**Document Purpose:** Specify exact completion criteria for Phase 2 (semantic validation layer)  
**Status:** Ready for implementation  
**Target State:** 250+/351 tests passing (71%+)  
**Baseline:** 215/351 tests passing (61.3%)  

---

## Overview

Phase 2 is complete when the YAML parser can validate semantic constraints that cannot be expressed in grammar. This document defines "done" with measurable, verifiable criteria.

---

## I. Code Implementation Requirements

### ✅ Must Have

#### 1.1 validate_events() Function
```
□ Function signature: int validate_events(struct Event *root)
□ Location: src/mrl.y (in %{ %} declarations section)
□ Return value: 0 (invalid) or 1 (valid)
□ Called from: documents rule (before YYERROR)
□ Error handling: Sets appropriate error message via yyerror()
```

#### 1.2 Constraint Implementation
```
□ Flow context indentation (check_flow_indentation)
□ Block scalar indentation (check_block_scalar_indentation)
□ Mapping key validity (check_mapping_keys)
□ Tag/anchor placement (check_anchor_tags)
□ Document marker positioning (check_doc_markers)
□ All 36 false positive patterns addressed
```

#### 1.3 Integration in Grammar
```
□ Wire validate_events() into parser flow:
  documents : explicit_documents
    {
        $$ = $1;
        if (!validate_events($$)) {
            yyerror("Invalid YAML document");
            YYERROR;
        }
    }
□ No grammar rule modifications
□ No new shift/reduce conflicts introduced
□ No change to existing token definitions
```

#### 1.4 Code Quality
```
□ No memory leaks in validate_events()
□ Clear, readable constraint checks
□ Comments explaining each constraint
□ Following existing code style
□ No C warnings when compiled
```

---

## II. Testing Requirements

### ✅ Must Pass

#### 2.1 Regression Testing
```
□ All 215 existing passing tests still pass
□ 0 regressions from Phase 1
□ Test run: python3 test_correct.py
□ Expected result: Pass: 215/351 minimum
```

#### 2.2 False Positive Conversion
```
□ All 36 identified false positives now fail correctly
□ Test cases identified:
  ├─ Flow indentation (9C9N, 4CQQ, ...)
  ├─ Block scalars (5LLU, 7ZZ5, ...)
  ├─ Mapping values (236B, 55WF, ...)
  ├─ Tags/anchors (9HCY, EW3V, ...)
  └─ Document markers (5TRB, EB22, ...)
□ Each constraint tested individually
□ Expected improvement: +25-35 passing tests
□ Final target: 250+/351 (71%+)
```

#### 2.3 Test Coverage Verification
```
□ Run: make && python3 test_correct.py
□ Run: Individual test checks for each constraint category
□ Document: Which false positives are now caught
□ Verify: No unexpected failures
```

#### 2.4 Edge Cases
```
□ Nested flow sequences in flow sequences
□ Block scalars with various indentation patterns
□ Mixed block and flow in same document
□ Multiple documents in one stream
□ Complex mapping key combinations
```

---

## III. Code Review Checklist

### ✅ Before Merge

#### 3.1 Architectural Compliance
```
□ Follows two-phase model (syntax then validation)
□ Uses YACC Appendix C pattern
□ Respects grammar/validation boundary
□ No custom state tracking in Flex
□ No additional Bison grammar rules
□ No code smells (per UNIX principles)
```

#### 3.2 Documentation
```
□ Each constraint has clear purpose documented
□ Comments explain why constraint exists
□ Links to YAML specification when applicable
□ References to false positive test cases
□ Explains relationship to RML theory (optional but good)
```

#### 3.3 Maintainability
```
□ Function is modular (can add constraints later)
□ Each constraint check is independent
□ Error messages are clear and actionable
□ Code is understandable without RML background
□ Follows existing code conventions
```

#### 3.4 Completeness
```
□ All 36 constraint categories implemented
□ No TODOs or FIXMEs left
□ All placeholder code removed
□ All test cases pass
□ No commented-out code remains
```

---

## IV. Documentation Requirements

### ✅ Must Include

#### 4.1 Code Comments
```
□ validate_events() function header comment
□ Each constraint function documented
□ Inline comments for non-obvious logic
□ Example of what each constraint catches
```

#### 4.2 Design Documentation
```
□ Add section to ARCHITECTURAL_BOUNDARY.md describing Phase 2
□ Document the 36 constraints with examples
□ Explain how Phase 2 completes the two-phase model
□ Show before/after test results
```

#### 4.3 Commit Messages
```
□ Main commit: "feat: Implement Phase 2 semantic validation"
□ Detail: What constraints were added
□ Reference: Which test cases now pass
□ Example commit:
  "feat: Implement Phase 2 semantic validation
  
  Adds validate_events() function to check semantic constraints:
  - Flow context indentation bounds
  - Block scalar indentation
  - Mapping key validity
  - Tag/anchor placement
  - Document marker positioning
  
  Converts 36 false positives to true negatives.
  Tests: 215→250+ (61%→71%)
  
  Fixes: [false positive test IDs]"
```

---

## V. Build & Compilation

### ✅ Success Criteria

#### 5.1 Clean Compilation
```
make clean && make
□ No compilation errors
□ No compilation warnings
□ Executable produced: build/bin/pawel-yaml
□ Successful build with: gcc, clang (if available)
```

#### 5.2 No New Conflicts
```
□ %expect 31 shift/reduce conflicts (unchanged)
□ No new reduce/reduce conflicts introduced
□ No parser states increased unnecessarily
□ Parser generation deterministic
```

#### 5.3 Functional Executable
```
□ build/bin/pawel-yaml runs without crashing
□ Can parse valid YAML files
□ Can reject invalid YAML files
□ Returns appropriate exit codes
□ No memory leaks (valgrind check optional)
```

---

## VI. Performance Requirements

### ✅ Acceptable

#### 6.1 Runtime Performance
```
□ Validation adds <10% overhead to parse time
□ Test suite runs in <2 minutes
□ No exponential algorithms (e.g., backtracking)
□ Memory usage remains reasonable
```

#### 6.2 Scaling
```
□ Works with deeply nested documents
□ Works with large numbers of keys
□ Works with long scalar values
□ No stack overflow on valid inputs
```

---

## VII. Integration Checklist

### ✅ Before Release

#### 7.1 Backward Compatibility
```
□ Phase 1 (syntax) unchanged
□ Existing APIs unchanged
□ Event stream format unchanged
□ Command-line interface unchanged
□ No breaking changes
```

#### 7.2 Git State
```
□ All changes committed
□ Commit history is clean
□ No merge conflicts
□ Branch ready for merge
□ No uncommitted changes
```

#### 7.3 Version Management
```
□ Update version number if applicable
□ Update CHANGELOG with Phase 2 completion
□ Document improvement from 61% to 71%
□ Note: 36 false positives fixed
```

---

## VIII. Verification Checklist

### ✅ Final Verification (Before "Done")

#### 8.1 Test Results
```
□ Run: make && timeout 120 python3 test_correct.py
□ Expected: Pass: 250+/351 (71%+)
□ Record: Exact pass/fail count
□ Verify: No regressions from 215
□ Document: Which constraints contributed to improvement
```

#### 8.2 Specific False Positives Converted
```
□ Count: At least 35 of the 36 are now true negatives
□ Example conversions verified:
  - 9C9N (flow indentation): Now fails ✓
  - 5LLU (block scalar): Now fails ✓
  - 236B (mapping value): Now fails ✓
  - 9HCY (tag placement): Now fails ✓
  - 5TRB (doc marker): Now fails ✓
  - ... (all 36 checked)
```

#### 8.3 Code Quality
```
□ Passes style checks
□ No compiler warnings
□ No undefined behavior
□ Memory safe (no buffer overflows, UAF, etc.)
□ Clear and maintainable code
```

#### 8.4 Documentation Complete
```
□ Code comments added
□ Architecture updated
□ Commit message clear
□ README updated (if applicable)
□ NEXT_STEPS.md marked complete
```

---

## IX. Validation Against Frameworks

### ✅ Confirm Alignment

#### 9.1 RML Theory Validation
```
□ Semantic constraints properly separated from grammar
□ Event tree validation respects monoidal language model
□ No attempts to push semantics into grammar
□ Clean two-phase separation achieved
```

#### 9.2 YACC Design Compliance
```
□ Follows Appendix C pattern (interval arithmetic example)
□ Uses YYERROR for semantic rejection
□ Actions work on complete parse tree
□ No attempt to mix semantic validation into grammar
```

#### 9.3 UNIX Principles
```
□ validate_events() has single responsibility
□ Can be called independently (tools principle)
□ Clear interface with event stream
□ Modular and composable
□ UNIX score remains 9/10 (or higher)
```

---

## X. Success Metrics

### ✅ Measurable Goals

| Metric | Current | Target | Verification |
|--------|---------|--------|---|
| Tests passing | 215/351 | 250+/351 | `python3 test_correct.py` |
| Pass percentage | 61.3% | 71%+ | Calculate from count |
| False positives | 36 | 0-1 | Review test results |
| False negatives | 0 | 0 | Verify no regressions |
| Code quality | N/A | Zero warnings | `make` output |
| Compilation | N/A | Success | Build succeeds |
| Runtime | <2min | <2min | Total test time |

---

## XI. Definition of Done Checklist

### ✅ Final Approval

Use this checklist before marking Phase 2 "Done":

```
CODE IMPLEMENTATION
□ validate_events() function implemented
□ All 36 constraint checks implemented
□ Wire into parser (documents rule)
□ Code compiles without errors
□ No new compiler warnings
□ Code follows style conventions

TESTING
□ All 215 existing tests pass
□ 25+ false positives converted to true negatives
□ Total tests passing: 250+/351
□ No regressions detected
□ Edge cases tested

CODE REVIEW
□ Follows RML theory (semantic separation)
□ Follows YACC pattern (Appendix C)
□ Follows UNIX principles (single responsibility)
□ Architecture decisions documented
□ Code is clear and maintainable

DOCUMENTATION
□ Code comments complete
□ Design documentation updated
□ Commit message describes changes
□ CHANGELOG updated
□ Architecture alignment confirmed

INTEGRATION
□ No backward compatibility issues
□ Git history clean
□ Ready for merge
□ Version tracking updated

VERIFICATION
□ Test results recorded
□ All metrics achieved
□ False positives specifically verified
□ Performance acceptable
□ Memory safe

SIGN-OFF
□ Code reviewed and approved
□ Tests verified passing
□ Documentation complete
□ Ready for release
```

---

## XII. Acceptance Criteria

### ✅ Phase 2 is "Done" When:

1. **Code:** validate_events() function implemented with all 36 constraint checks
2. **Tests:** 250+/351 tests passing (71%+) with zero regressions
3. **Quality:** Clean compilation, no warnings, follows coding standards
4. **Documentation:** Code commented, architecture updated, commit message clear
5. **Verification:** All false positives explicitly checked and failing correctly
6. **Integration:** No breaking changes, git history clean, ready to merge

---

## XIII. Rollback Criteria

If Phase 2 implementation fails one of these, rollback immediately:

```
ROLLBACK IF:
□ More than 5 regressions in existing tests
□ Cannot reach 240+/351 target
□ Introduces new compiler warnings
□ Creates new shift/reduce conflicts
□ Breaks grammar (existing tests fail)
□ Memory leaks introduced
□ Causes infinite loops or crashes

RECOVERY:
1. git revert [commit]
2. Document failure reason
3. Schedule postmortem
4. Plan revised approach
```

---

## XIV. Timeline & Effort

### ✅ Realistic Expectations

| Phase | Effort | Timeline |
|-------|--------|----------|
| **Implement** | 2-4 hours | 1 day |
| **Test** | 1-2 hours | 0.5 day |
| **Review** | 1 hour | 0.5 day |
| **Documentation** | 1 hour | 0.5 day |
| **Total** | 5-8 hours | 2-3 days |

---

## XV. Post-Implementation

### ✅ After "Done"

1. **Celebrate:** Phase 1 + Phase 2 = 71% YAML compliance ✓
2. **Document:** Record success in project history
3. **Analyze:** Remaining 29% (100 tests) for next phase
4. **Archive:** Move Phase 2 analysis docs to completed section
5. **Plan:** Phase 3 (if desired) for remaining constraints

---

## Summary

**Phase 2 is "Done" when:**

- ✅ validate_events() implemented (150 lines estimated)
- ✅ All 36 constraints checked
- ✅ 250+/351 tests passing (71%+)
- ✅ 0 regressions from existing 215 tests
- ✅ Code compiles cleanly
- ✅ Architecture confirmed
- ✅ Fully documented
- ✅ Ready to merge

**Success probability: ~95%** (four frameworks validated the approach)

**Confidence: High** (proven pattern, clear requirements, identified test cases)

---

**This Definition of Done is binding. When all items are checked, Phase 2 is complete and ready for production.**

Last Updated: February 3, 2026  
Status: Ready for implementation  
Next: Start Phase 2 per NEXT_STEPS.md
