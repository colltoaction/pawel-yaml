# Next Steps: Implementing Two-Phase Validation

## Current State
- **Grammar Phase (Bison/Flex):** 215/351 tests (61.3%) ✓ Working
- **Validation Phase:** Missing ✗ Needed for remaining 136 tests

## The 36 Most Impactful False Positives

From `find_false_positives.py`:

1. **4EJS** - Invalid tabs in indentation
2. **5LLU** - Block scalar indentation after spaces
3. **5TRB** - Document marker in quoted string
4. **62EZ** - Block key on flow end line  
5. **7LBH** - Multiline quoted implicit keys
6. **9C9N** - Wrong indented flow sequence ← HIGH PRIORITY
7. **9HCY** - Document footer before directive
8. **9JBA** - Comment after flow sequence end
9. **C2SP** - Flow key on two lines
10. **CTN5** - Flow seq invalid comma
...and 26 more patterns

## RML Theory Says...

These are **Language-Level Constraints** (Phase 2):
- Cannot be expressed in the grammar (Phase 1)
- Require inspection of the full event tree
- Belong in a validation/semantic analysis pass

## Implementation: Restore validate_events()

**Location:** [src/mrl.y](src/mrl.y) - add back the function and calls

**Function Signature:**
```c
/* Traverse event tree and check semantic constraints */
int validate_events(struct Event *doc);
```

**Constraints to Check:**

### 1. Flow Context Indentation (9C9N)
```c
/* Check if any element in flow seq is at invalid indentation */
/* Flow_seq_entries inside [...] cannot dedent below flow start */
```

### 2. Block Scalar Indentation (5LLU)  
```c
/* Block scalars | > must maintain indentation */
/* All content lines must be at flow_indent or greater */
```

### 3. Invalid Mapping Values (236B)
```c
/* After key:, value must be valid block collection or quoted */
/* Bare scalar after dedent is invalid */
```

### 4. Document Markers (5TRB, EB22)
```c
/* --- inside quoted string is allowed */
/* But --- at statement level requires proper positioning */
```

### 5. Tag/Anchor Placement
```c
/* Tags and anchors must precede values */
/* Cannot attach to document markers */
```

## Integration Points

1. **In `documents` rule** (line ~96):
```bison
documents:
    implicit_document[doc] { 
        if (!validate_events($doc)) exit(1);  /* ADD THIS */
        emit_events($doc); 
    }
```

2. **In `explicit_documents` rule** (line ~107):
```bison
explicit_documents:
    ...
        if (!validate_events($doc)) exit(1);  /* ADD THIS */
        ...
```

## Expected Outcomes

- **Fixes high-impact patterns:** Flow indentation, block scalars, mapping values
- **Maintains 215/351 baseline:** No regressions (pure addition)
- **Target:** 240-250/351 (68-71%) with comprehensive validation

## Why This Approach Wins

1. ✓ **Architecturally sound**: Aligns with RML two-phase parsing
2. ✓ **No code smells**: No custom stacks or state duplication
3. ✓ **Easy to maintain**: Validation logic is separate from grammar
4. ✓ **Incrementally extensible**: Each constraint is one function
5. ✓ **Reversible**: Can disable validation for debugging

## Next Task

Implement `validate_events()` function covering the 10-15 highest-impact patterns.
This should get us from 215 → 240+ tests without any grammar changes.
