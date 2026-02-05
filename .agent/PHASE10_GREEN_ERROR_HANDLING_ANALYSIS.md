# Error Handling Refactoring Analysis: Phase 10 GREEN

## Current State Analysis

### Issue: Parser Hang on All Input

**Symptom**: Exit code 124 (timeout) on all YAML input, including simple cases like "test: value"

**Root Cause Identified**: Defective error recovery rule in `src/yaml.y` line 160

### The Problematic Rule

```bison
explicit_document:
    DOC_START { ... } node { ... }
    | error { yyerrok; yyclearin; }  /* ← PROBLEM HERE */
    ;
```

**Why This Causes Hangs**:

Per Bison/Flex Error Handling Playbook Section 3 - "When NOT to use `yyerrok`":

```
❌ WRONG: Calling yyerrok without consuming error recovery tokens
statement : expression
          | error
            {
                yyerrok;    /* WRONG: no tokens consumed */
            }
```

**What's happening:**

1. Parser encounters unexpected token (e.g., SCALAR "test")
2. Matches `error` production → calls `yyerrok` and `yyclearin`
3. Parser state unchanged, lookahead still invalid
4. Error production matches again → infinite loop
5. Lookahead cycle: parser keeps matching same error rule without consuming input
6. Timeout after 2 seconds (exit code 124)

### GLR Complication

Since this is a GLR parser:
- Multiple parse paths may exist
- Error recovery ambiguous across branches
- Conflicts (140 shift/reduce, 63 reduce/reduce) multiply the paths
- Error rule loops in all branches simultaneously
- Creates exponential backtracking → hang

### Playbook Reference

From `.agent/PLAYBOOK/bison-flex-error-handling.md`:

**Section 7: Debugging Parser Hangs**
- Symptom: "Parser never completes, waits indefinitely"
- Common Cause #1: "Error recovery creates lookahead cycle"
- Common Cause #2: "GLR conflict forces multiple parse paths with error rules"
- Common Cause #3: "`yyerrok` called without sufficient token consumption"

All three apply here.

## Solution Strategy

### Option A: Remove Error Recovery (Simplest)

```bison
explicit_document:
    DOC_START { ir_doc_start(ir); add_event(EVENT_DOCUMENT_START); }
    node
    { ir_doc_end(ir); add_event(EVENT_DOCUMENT_END); }
    ;
```

**Rationale:**
- Current error rule serves no purpose (loops infinitely)
- Better to fail cleanly than hang
- Return YYABORT (exit code 1) instead of timeout
- Aligns with Phase 10 goal: proper error codes

**Trade-off:** Parser will reject invalid input immediately, no recovery

### Option B: Proper Error Recovery (Per Playbook)

```bison
explicit_document:
    DOC_START { ... } node { ... }
    | DOC_END                           /* Sync to next document */
      { yyerror("Missing node in document"); yyerrok; }
    | error DOC_START                   /* Sync to NEXT document marker */
      { yyerror("Skipping to next document"); yyerrok; }
    ;
```

**Rationale:**
- `error` MUST be followed by synchronization token(s)
- `DOC_START` or `DOC_END` provides clear boundary
- Playbook Pattern A (Statement-Level Recovery)
- Parser continues processing next document after error

**Trade-off:** More complex, requires token availability

### Option C: Hybrid (Document Boundary Recovery)

```bison
explicit_document:
    DOC_START { ... } node { ... }
    | error                             /* Placeholder for future fancy recovery */
      {
          yyerror("Malformed document");
          /* Manually consume tokens until EOF or next DOC_START */
          while (yylex() != EOF) {
              if (yytext && strcmp(yytext, "---") == 0) break;
          }
          yyerrok;
      }
    ;
```

**Rationale:**
- Manual token consumption in error handler (Playbook Pattern C)
- Guarantees progress (always consumes at least one token)
- Exit condition prevents infinite loop

**Trade-off:** Manual loop; requires care

## Recommendation: Phased Approach

**Phase 10.GREEN.1 (Immediate)**
- Apply **Option A**: Remove error recovery rule
- Goal: Stop the hang, enable parser to fail cleanly
- Expected: Exit code changes from 124 to 1 (error) on invalid input
- Verifiable: Parser completes on all input within timeout

**Phase 10.GREEN.2 (After GREEN Verification)**
- If tests now pass: investigate why parser was hanging → was it just this rule?
- If tests still fail: understand _where_ parser hangs (different productions?)
- Apply selective error recovery (Option B or C) only where needed

**Phase 10.GREEN.3 (Stabilization)**
- Once parser completes all input, implement proper error recovery
- Add error rules at strategic points (expr, sequence, mapping)
- Use Playbook patterns (A, B, D) with clear synchronizers

## Implementation Checklist

- [ ] Phase 10.GREEN.1: Remove bare error recovery rule
- [ ] Rebuild and verify compilation
- [ ] Test with `echo "test: value" | timeout 2 ./build/bin/pawel-yaml`
- [ ] Verify exit code is 1 (error) not 124 (timeout)
- [ ] Run full test suite (check if ANY tests pass now)
- [ ] If hang persists, search for other `error` rules
- [ ] Document findings in PROGRESS.md
- [ ] Commit: "GREEN: Remove defective error recovery to stop parser hang"

## Expected Test Results After FIX

**Before Fix:**
- Exit code: 124 (timeout)
- Behavior: Hangs indefinitely
- Tests passing: 0/351

**After Fix (Phase 10.GREEN.1):**
- Exit code: 1 (parse error)
- Behavior: Completes, rejects as invalid
- Tests passing: Still low, but parser completes
- Key: Parser no longer hangs

**After Fix (Phase 10.GREEN.3):**
- Exit code: 0 (success) when valid YAML
- Behavior: Completes and produces output
- Tests passing: Will begin increasing via TDD cycles
- Key: Proper error recovery enables incremental fixes
