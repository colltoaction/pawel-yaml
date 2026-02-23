# RML Insight: Why Semantic Validation Belongs Outside the Grammar

## The RML Framework Applied to YAML

From "Regular Monoidal Languages" (Earnshaw & Sobociński), we learned that:

**Definition (RML):** 
- A **monoidal grammar** is a finite specification for constructing string diagrams (morphisms in free monoidal categories)
- A **monoidal language** is a subset of scalar string diagrams accepted by a monoidal automaton
- **Recognition** happens through automaton transition functions $\Delta_\gamma$ for each generator $\gamma$

**YAML as a Monoidal System:**

The YAML parser implements:
1. **Generators** (alphabet): scalars, brackets `[` `]`, colons `:`, dedent markers, etc.
2. **Monoidal structure**: Nesting of flow contexts creates parallel composition (like wires in a string diagram)
3. **Automaton transitions**: 
   - Lexer states (INITIAL, INDENT_CHECK, BLOCK_SCALAR, etc.)
   - Parser rules that compose events into trees
4. **Constraints on morphisms**: "Flow context spans must maintain indentation bounds"

## Why Custom State Tracking Fails (in RML Terms)

When we tried custom `flow_indent_stack[]`:
- We were trying to augment the automaton's **generator transition functions** with extra context
- This violates RML's principle: generators should have uniform, stateless transition rules
- The **stack state** is not a generator - it's metadata about the current morphism's structure

In RML: **Generators don't carry history - morphisms do.**

## Why Flex State Stacking Fails (in RML Terms)

When we tried `yy_push_state(FLOW_CONTEXT)`:
- We created a new lexer state with different rules
- This required duplicating ALL generator definitions in both states
- We created exponential state complexity: one state per context depth × one state for FLOW vs BLOCK

In RML: **Changing the generator alphabet changes the entire language.** You can't partially redefine generators.

## Why DEDENT-in-Grammar Fails (in RML Terms)

When we tried emitting DEDENT in flow context and rejecting it via grammar:
- The grammar rule `flow_seq_entries DEDENT` clashed with other rules
- The parser couldn't decide when to reduce vs shift (GLR conflicts)
- We violated the monoidal structure: DEDENT and flow items don't compose cleanly

In RML: **Constraints must respect the monoidal composition.** You can't add arbitrary token rejection mid-composition.

## The Correct Approach: Two-Phase Parsing

**Phase 1: Syntactic Parsing (Grammar-Level)**
- Input: YAML token stream
- Process: Bison/Flex parsing with fixed grammar
- Output: Event tree representing the string diagram
- Principle: Accept all structurally valid generator sequences

**Phase 2: Semantic Validation (Language-Level)**
- Input: Event tree from Phase 1
- Process: Constraint checker on the monoidal language properties
- Output: Accept/reject based on semantic rules
- Principle: Filter the language $L \subseteq \mathscr{F}\Gamma(0,0)$

In RML: Phase 1 generates `$\mathscr{F}\Gamma$` (all possible morphisms), Phase 2 extracts `$L$` (the accepted language).

## Why `validate_events()` Was Correct

The original `validate_events()` function was doing **exactly** what Phase 2 should do:
```c
/* Traverse the event tree looking for constraint violations */
/* e.g., "bare dash in flow sequence" */
```

It was rejected because:
1. The team thought "all validation should be in the grammar"
2. But RML theory shows: not all constraints are syntactic

The fix: Restore `validate_events()` and expand it to cover all 36 failing semantic constraints.

## Mapping YAML Constraints to RML Categories

**Syntactic (Grammar-Level):** ✓ Already implemented
- Bracket matching: `[...]`, `{...}`
- Colon/dash positioning: must have whitespace following
- String escaping: valid escape sequences

**Semantic (Language-Level):** ✗ Missing
- Indentation bounds in flow context (the 9C9N case)
- Block scalar indentation (5LLU case)
- Mapping value validity (236B case)
- Tag/anchor placement (9HCY case)

## Implementation Path

1. **Restore validate_events()**
2. **Expand it to check all 36 failing patterns:**
   - Flow context indentation constraints
   - Block scalar indentation rules
   - Mapping structure validity
   - Directive/anchor placement rules
3. **Call it in documents/document_body rules** (Phase 2 validation)

This aligns perfectly with RML theory: syntax ⊂ semantics.
