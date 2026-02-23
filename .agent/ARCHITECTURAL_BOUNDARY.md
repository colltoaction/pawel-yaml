# Architectural Boundary: Grammar vs Semantic Validation
## A Regular Monoidal Language Perspective

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

## Theoretical Framework: Regular Monoidal Languages

From RML theory (Earnshaw & Sobociński), we understand that:

- **Monoidal Grammar** (Bison rules): Defines what structures are *syntactically constructible* from an alphabet
- **Monoidal Automaton** (Lexer tokenization): Recognizes morphisms by transitioning through states
- **Monoidal Language** (Semantic constraints): Imposes additional requirements on accepted structures

Classical formal language theory (words, trees) conflates syntax and semantics. YAML's complexity makes this distinction explicit.

### YAML as a Monoidal Language

YAML has:
- **Generators** (tokens): scalars, brackets, colons, indentation markers
- **Monoidal structure**: nesting of flow contexts (composition of string diagrams)
- **Type constraints**: indentation levels form a partially-ordered set
- **Semantic constraints**: "flow context spans cannot be interrupted by dedents below their entry level"

The last constraint is **not syntactic** - it's a monoidal language property that transcends the grammar.

## Attempted Solutions & Lessons

### 1. Custom Stack in Lexer ❌ CODE SMELL
**Approach:** Track flow indentation with custom `flow_indent_stack[]`
**Issue:** Custom C arrays parallel Flex built-in state stack - violates DRY principle
**Lesson:** "Custom stacks are a code smell in Bison/Flex" - user feedback was correct

### 2. Flex Built-in State Stack ❌ INCOMPLETE AUTOMATON
**Approach:** Use `%option stack`, `yy_push_state(FLOW_CONTEXT)` on `[` `{`, pop on `]` `}`
**Issue:** Changing lexer state requires ALL tokens to be defined in both states. In RML terms: the automaton's transition functions must be complete for all generators in all states.
**Result:** 30-test regression because FLOW_CONTEXT state rules were incomplete

### 3. DEDENT Token in Flow Context ❌ PARSER DEADLOCK
**Approach:** Emit DEDENT in flow context, add grammar rule `flow_seq_entries DEDENT` to reject
**Issue:** DEDENT tokens in unexpected positions cause parser shift/reduce conflicts and hangs. In RML terms: the grammar transitions create inconsistent derivation paths.
**Lesson:** Token ordering is deeply encoded in the monoidal structure

## Architectural Insight: Why Grammar Alone is Insufficient

The fundamental constraint is **semantic**: 
> "Indentation that would cause a dedent below a flow collection's starting indent is invalid."

In RML terms: This is a constraint on the **language** $L \subseteq \mathscr{F}\Gamma(0,0)$, not on the generators $\Gamma$.

This constraint cannot be cleanly expressed in the monoidal grammar because:

1. **Lexer state** (requires duplicating all rules in new start conditions)
   - Violates the principle that generators should have uniform behavior
   - Creates exponential state complexity for nested contexts

2. **Token stream** (would require lookahead predicates)
   - YAML generators don't encode their structural role in advance
   - Lookahead violates Flex's streaming model

3. **Grammar rules alone** (would need context-dependent acceptance)
   - Bison rules don't have access to lexer state variables
   - GLR parser's lookahead buffer can't track arbitrary monoidal properties

The issue is that YAML's indentation constraint is a **global property** of the token stream that cannot be localized to individual grammar rules.

## Proper Architecture: Two-Phase Validation

According to RML principles, when a constraint doesn't fit the grammar, it belongs in a **validation phase**:

### Phase 1: Syntactic Parsing (Lexer/Parser)
- Generate event trees using monoidal grammar
- Goal: Accept all structurally valid tokens
- Produces: Event list representing the string diagram

### Phase 2: Semantic Validation
- Check constraints on the event tree structure
- Goal: Reject invalid monoidal languages
- In RML terms: Filter $L$ from the broader language $\mathscr{F}\Gamma(0,0)$

The previous `validate_events()` function was architecturally **correct** - it performed Phase 2 validation.

## Current Status

- **215/351 tests passing (61.3%)**
- **0 false negatives** (Phase 1 correctly accepts valid YAML)
- **~36 false positives** (Phase 2 missing - no semantic validation)

These 36 cases represent monoidal language constraints:
- Invalid indentation continuations in flow contexts (monoidal composition constraints)
- Invalid block scalar indentation (type constraints on the monoidal structure)
- Invalid mapping value structures (generator ordering constraints)
- Tag/anchor placement violations (auxiliary constraint tracking)

## Recommendation

The proper fix requires implementing **Phase 2 semantic validation**. Options:

1. **Restore selective validation layer** (Minimal): Re-add `validate_events()` for the 36 failing patterns
   - Cleanest architecturally
   - Aligns with RML two-phase parsing model
   - Minimal code footprint

2. **Full semantic validation** (Comprehensive): Create a proper constraint checker for all monoidal language properties
   - More maintainable long-term
   - Allows incremental constraint addition
   - Better documents YAML's semantic layer

3. **Accept 61% as grammar-only ceiling** (Minimal effort): Document that flow indentation constraints are semantic, not syntactic
   - Works if semantic validation is truly out of scope
   - Still architecturally honest

## Key Insight from RML

**Custom C state tracking is a code smell ONLY when it duplicates what the automaton should do.** In RML's framework, the problem isn't tracking state - it's that the state being tracked (flow indentation) is **orthogonal to the parsing state** and belongs in a **post-parsing validation phase**, not in the lexer/parser state machine.

The lesson: Use Bison/Flex for syntactic parsing (what they excel at), and semantic validation (where automata theory reaches its limits).
