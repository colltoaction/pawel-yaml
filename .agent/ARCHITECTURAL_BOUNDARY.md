# Architectural Boundary: Grammar vs Semantic Validation

## Problem Statement

The YAML parser currently has 36 false positive tests (tests marked `fail: true` but incorrectly parsing as valid). Attempts to fix these using pure Bison/Flex mechanisms cause regressions or architectural code smells.

**Example Test (9C9N):**
```yaml
---
flow: [a,
b,
c]
```
Should fail because `b` at column 0 would be a dedent, which is invalid inside flow sequences.

## Attempted Solutions & Lessons

### 1. Custom Stack in Lexer ❌ CODE SMELL
**Approach:** Track flow indentation with custom `flow_indent_stack[]`
**Issue:** Custom C arrays parallel Flex built-in state stack - violates DRY principle
**Lesson:** "Custom stacks are a code smell in Bison/Flex" - user feedback was correct

### 2. Flex Built-in State Stack ❌ INCOMPLETE
**Approach:** Use `%option stack`, `yy_push_state(FLOW_CONTEXT)` on `[` `{`, pop on `]` `}`
**Issue:** Changing lexer state requires ALL tokens to be defined in both states
**Result:** 30-test regression because FLOW_CONTEXT state rules were incomplete

### 3. DEDENT Token in Flow Context ❌ PARSER DEADLOCK
**Approach:** Emit DEDENT in flow context, add grammar rule `flow_seq_entries DEDENT` to reject
**Issue:** DEDENT tokens in unexpected positions cause parser shift/reduce conflicts and hangs
**Lesson:** Token ordering matters deeply in GLR parsing

## Architectural Insight

The fundamental constraint is **semantic**: "Indentation that would cause a dedent below a flow collection's starting indent is invalid."

This constraint cannot be cleanly expressed as:
- ✗ Lexer state (requires duplicating all rules in FLOW_CONTEXT)
- ✗ Token stream (would require lookahead to know if next char is at column 0)
- ✗ Grammar rules alone (would need to track context in grammar state)

## Proper Architecture

According to Bison/Flex design principles, the proper approach for constraints that don't fit clean grammar would be:

### Option 1: Grammar-Only (Cleanest if possible)
If the constraint can be expressed in grammar rules, do it there. ✓ This is what we've done for bare dash validation.

### Option 2: Two-Phase Parsing
1. **Phase 1 (Lexer/Parser):** Accept broader syntax, generate events
2. **Phase 2 (Validation):** Semantic validation of event trees (what `validate_events()` was doing)

The previous `validate_events()` function was actually the RIGHT approach for these constraints that transcend grammar.

### Option 3: Reentrant Lexer State
For true state-dependent lexing, create separate start conditions but ensure ALL necessary rules exist in each state. This is extensive but architecturally correct.

## Current Status

- **215/351 tests passing (61.3%)**
- **0 false negatives** (no valid YAML incorrectly rejected)
- **~36 false positives** (invalid YAML incorrectly accepted)

These 36 cases likely fall into categories that need semantic validation:
- Invalid indentation continuations in flow contexts
- Invalid block scalar indentation
- Invalid mapping value structures
- Tag/anchor placement violations

## Recommendation

The proper fix for the remaining 36 tests requires choosing one of:

1. **Restore selective validation layer**: Add targeted semantic checks for the specific ~36 failing patterns
2. **Full two-phase parsing**: Create proper validation pass for all semantic constraints
3. **Accept 61% as the grammar-expressible limit**: Document that some YAML constraints are semantic, not syntactic

The key learning: **Custom C state tracking is a code smell ONLY if it duplicates what Flex can do cleanly.** Using Flex's native `%option stack` correctly is the proper solution - it just requires disciplined use of start conditions.
