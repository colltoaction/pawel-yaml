# Pawel-YAML: Engineering Playbook & Architectural Reference

This document consolidates the technical wisdom, refactoring cycles, and architectural strategies developed during the Pawel-YAML project. It serves as a master reference for the "Growing a Language" macro cycles.

---

## 1. Core Engineering Principles

### RML Alignment (Theory-First)
- **Direct Mapping**: Code structures (Alphabet, Grammar, StringDiagram) must map 1-to-1 to RML textbook definitions.
- **Morphisms**: Every parsed YAML construct is a morphism in the free monoidal category.
- **Composition**: Prefer vertical composition (`sd_compose`) over manual state coupling.

### TDD Macro Cycle (Safe Evolution)
- **Red-Green-Refactor**: NEVER commit a feature without a passing test identifier in the title.
- **Atomic Commits**: One commit per feature or per code-smell resolution.
- **Zero Regressions**: Baseline pass rates must be maintained or improved in every cycle.

### IR Design Principles (Simplification)
- **Explicit Dependencies**: Use helper functions to make data/control flow visible.
- **Syntactic Noise Reduction**: Factor out boilerplate (e.g., repeated `strcmp` or switch fallthroughs).
- **Structured Control Flow**: Maintain single entry/exit patterns for all functions.

---

## 2. Lexer Architecture

### State Management
- **Inlined State**: `lexer_context.h` is obsolete. All state (indentation, flow, block scalars) resides in static variables within `src/lexer.l`.
- **Reentrancy**: Use Flex's `%option reentrant` and pass `ParserContext` via `yyextra` if needed (currently global statics for simplicity, but ready for TLS).
- **Initialization**: Implement `reset_lexer_state()` to ensure clean starts for multi-document streams.

### Indentation & Collections
- **Indentation Stack**: Tracked via `indent_stack` array. Use `push_indent_safe()` with bounds checking (limit: 100).
- **Flow Control**: `flow_level` counter handles nested `[]` and `{}`. Switch to `FLOW_CONTENT` states accordingly.
- **Block Scalars**: Use `init_block_scalar()` with dynamic allocation and `try_grow_block_scalar()` for memory safety.

---

## 3. Grammar & Parser Strategies

### Multi-line Scalars
- **Approach D**: Include indented continuation lines directly in the SCALAR regex pattern using `(\n[ ]+(plain_scalar_content))*`.
- **Impact**: Removes the need for complex "unexpected INDENT" handling in the parser.

### Grammar Acceptance (Future)
- **Hybrid Approach**: Use Flex start conditions for state orchestration and C helpers for structural verification.
- **Transition Matching**: Prefer O(1) lookups or declarative rules over nested `if/else` ladders.

---

## 4. Code Smell Resolutions (Standard Patterns)

| Smell Type | Resolution Pattern |
|:---|:---|
| **Magic Numbers** | Centralize in `mrl.h` (e.g., `ESC_CHAR`, `YAML_TAG_PREFIX`). |
| **High Complexity** | Replace large switches with **Lookup Tables** (e.g., `escape_lut[256]`). |
| **DRY Violations** | Extract common init (e.g., `init_string_diagram`) into static inline helpers. |
| **Long Lines** | Break using intermediate boolean or size variables for readability. |
| **Redundant Comments** | Remove comments that restate the code. Focus on the *Why*. |

---

## 5. Standard Error Codes
- `EXIT_SUCCESS` (0): Success.
- `EXIT_FAILURE` (1): General error.
- `YAML_PARSE_SYNTAX_ERROR` (2): Grammar violation.
- `YAML_PARSE_ERR_LEX_INIT` (3): Lexer initialization failure.

---

> [!IMPORTANT]
> **Always verify passing test IDs** against the `yaml-test-suite` before moving to the next growth cycle. Use the `tdd_harness.sh` for atomic verification.
