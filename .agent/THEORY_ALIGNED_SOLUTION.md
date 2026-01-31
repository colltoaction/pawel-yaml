# Pawel-YAML: Theory-Aligned Architecture & Implementation

**Status**: Phase 1 Complete (January 30, 2026)
**Pass Rate**: Partial (Verification pending full compliance)

## 1. Theory-First Philosophy

This project implements the theoretical framework of **Regular Monoidal Languages (RML)** as defined in the associated textbook. Instead of inventing ad-hoc parser concepts, we map the software architecture directly to mathematical definitions.

### RML Definitions vs. Implementation

| RML Definition (main.tex) | Mathematical Concept | C Implementation (`mrl.h`) |
|---------------------------|----------------------|----------------------------|
| **Definition 2.1** | Monoidal Alphabet $\Gamma$ | `Alphabet` struct (Array of `Generator`*) |
| **Definition 2.2** | Regular Monoidal Grammar $\Psi : M \to \Gamma$ | `Grammar` struct (Array of `Transition`*) |
| **Definition 2.3** | Non-deterministic Monoidal Automaton | `StateList` + Transition Logic |
| **Free Pro $F(\Gamma)$** | String Diagram (Morphism) | `StringDiagram` recursive struct |

### Key Insight: The "ParseOutput"
Early iterations attempted to invent a "ParserContext" concept. The theory-aligned solution is simpler: the parser should just build and return the three fundamental RML objects.

```c
typedef struct {
    Alphabet *alphabet;       /* $\Gamma$ */
    Grammar *grammar;         /* $\Psi$ */
    StringDiagram *diagram;   /* Input Morphism */
} ParseOutput;
```

---

## 2. Architecture: Three-Tier Design

The implementation is layered to separate concerns:

### Tier 1: Public API (`yaml_parser.h`)
The external interface is minimal and clean. It initializes the parser, runs it, and returns the RML objects.

```c
int yaml_parse(Alphabet **out_alphabet, Grammar **out_grammar, StringDiagram **out_diagram);
```

*   **Returns**: `0` (Success), `1` (Syntax Error), `2` (Memory Error).
*   **Ownership**: Caller owns the returned structures.

### Tier 2: Bison/Flex Integration (`parser.y`, `lexer.l`)
*   **Reentrant**: Uses `%define api.pure full` to avoid global state.
*   **Context Passing**: Uses `%parse-param {ParseOutput *output}` to populate results.
*   **Cleanup**: Uses `%destructor` to automatically free partial structures on error.

### Tier 3: Core RML Structures (`mrl.c`)
Defines the `create_*` and `free_*` functions for the underlying types.

---

## 3. Memory Safety Strategy

We employ **Strategy C (Selective Tracking)** combined with Bison's **YYNOMEM** feature.

### The Problem
Bison actions execute immediately. If a `malloc` fails halfway through parsing:
1.  We must signal failure immediately (`YYNOMEM`).
2.  We must clean up everything allocated so far.

### The Solution
*   **YYNOMEM**: Returns error code `2` from `yyparse`.
*   **Recursive Free**: Top-level "cleanup functions" recursively free the complex tree structures.
    *   `free_stringdiagram(sd)`: Frees the diagram tree.
    *   `free_grammar(g)`: Frees transitions and states.
    *   `free_alphabet(a)`: Frees generators.

### Context-Based Cleanup
The `ParserContext` (hidden in `yaml_parser.c`) tracks the top-level pointers. On error, we simply call `parser_context_free(ctx)`, which invokes the recursive free functions on whatever has been built so far.

---

## 4. Integration Plan

Pawel-YAML is designed to integrate into the broader YAML ecosystem.

### yaml-runtimes
*   **Docker Location**: `yaml-runtimes/docker/c-pawel/`
*   **Build**: Multi-stage `alpine-builder.dockerfile`.
*   **Execution**: `alpine-runtime.dockerfile` runs the `pawel-yaml` binary.
*   **Event Output**: Generates standard YAML event streams (e.g., `+STR`, `+DOC`) for compatibility.

### yaml-test-suite
*   **Submodule**: Included in the repo.
*   **Status**: Partial pass rate (Verification pending).
*   **Mechanism**: The parser outputs an event stream which is compared against the reference output.

---

## 5. Current Status (Phase 1 Complete)

Phase 1 (Cleanup & Theory Alignment) is finished.

*   ✅ **Global State Removed**: Parser is fully reentrant.
*   ✅ **Theory Alignment**: All structures map to `main.tex` definitions.
*   ✅ **Memory Safety**: No leaks, robust error handling with `YYNOMEM`.
*   ✅ **Backward Compatibility**: Existing tests pass without modification.

### Next Steps (Phase 2)
1.  **Parser Completeness**: Extend to cover full YAML 1.2 spec edge cases.
2.  **Recognition Logic**: Implement `mrl_accepts` fully to test diagram validity against grammars.
3.  **Performance**: Profile and optimize memory usage for large diagrams.
