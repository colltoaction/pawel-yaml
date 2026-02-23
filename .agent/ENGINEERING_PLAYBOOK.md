# Pawel-YAML: Engineering Playbook & Architectural Reference

This document consolidates the technical wisdom, refactoring cycles, and architectural strategies developed during the Pawel-YAML project. It serves as a master reference for the "Growing a Language" macro cycles.

---

## 1. Core Engineering Principles

### RML Alignment (Theory-First)
- **Direct Mapping**: Code structures (Alphabet, Grammar, StringDiagram) must map 1-to-1 to RML textbook definitions.
- **Morphisms**: Every parsed YAML construct is a morphism in the free monoidal category.
- **Composition**: Prefer vertical composition (`sd_compose`) over manual state coupling.

### TDD Macro Cycle (Safe Evolution)
- **Agentic TDD Protocol**: Follow the Red-Green-Refactor-Verify-Commit cycle.
- **Atomic Commits**: One commit per feature or per code-smell resolution.
- **Zero Regressions**: Maintain a 100% pass rate on previously green tests.
- **Definition of Done**: 100% pass rate on `TEST_FAILURES.yaml`, clean history, and zero regressions.

### Unified Architecture (Simplification)
- **Single-Module Design**: Consolidate grammar, RML API, and the binary entry point into `mrl.y` and `mrl.l`.
- **Minimal Driver**: The binary lives inside the grammar definition; avoid external drivers like `pawel-yaml.c`.
- **Logical Purity**: Use Bison's `%code` blocks to separate implementation (`%code`) from requirements (`%code requires`).

---

## 2. Lexer Architecture

### State Management
- **Inlined State**: `lexer_context.h` is obsolete. All state (indentation, flow, block scalars) resides in static variables within `src/mrl.l`.
- **Reentrancy**: Use Flex's `%option reentrant` and pass `ParserContext` via `yyextra` if needed.
- **Initialization**: Implement `reset_lexer_state()` to ensure clean starts for multi-document streams.

### Indentation & Collections
- **Indentation Stack**: Tracked via `indent_stack` array. Use `push_indent_safe()` with bounds checking (limit: 100).
- **Flow Control**: `flow_level` counter handles nested `[]` and `{}`.
- **Block Scalars**: Use `init_block_scalar()` with dynamic allocation and `try_grow_block_scalar()` for memory safety.

---

## 3. Unified RML Implementation (`mrl.y`, `mrl.l`)

The project has transitioned to a **Single-Module Design** where the grammar definition and the program driver are unified.

### Core Components
- **`src/mrl.l`**: The **Monoidal Alphabet**. Defines the atoms $(\Gamma)$ of YAML.
- **`src/mrl.y`**: The **Monoidal Grammar**.
  - Implements the RML API: `Alphabet`, `Grammar`, `StringDiagram`.
  - Entry Point: `mrl_entry(int argc, char **argv)` handles CLI logic.
  - Presentation: `mrl_present()` converts the StringDiagram morphism into an event stream.

### Bison Best Practices
- **Logical Purity**: Implementation logic lives in `%code`, while external declarations live in `%code requires`.
- **Location Tracking**: Use `%locations` to provide column-accurate error messages.
- **Detailed Errors**: Use `%define parse.error detailed` to suggest expected tokens on failure.
- **Conflict Management**: Use `%expect` and `%expect-rr` to document and lock in intentional ambiguities.

---

## 4. Code Smell Resolutions (Standard Patterns)

| Smell Type | Resolution Pattern |
|:---|:---|
| **Magic Numbers** | Centralize in `mrl.y` / `%code requires`. |
| **High Complexity** | Replace large switches with **Lookup Tables** (e.g., `escape_lut[256]`). |
| **DRY Violations** | Extract common init (e.g., `init_string_diagram`) into static inline helpers. |
| **Long Lines** | Break using intermediate boolean or size variables for readability. |
| **Redundant Comments** | Remove comments that restate the code. Focus on the *Why*. |

---

## 5. Agentic TDD Protocol

This protocol ensures tool-verifiable progress and architectural stability.

### Phase 1: RED (Failure Establishment)
1. **Reproduce**: Create or identify a failing test case (e.g., from `build/lib/yaml-test-suite`).
2. **Baseline**: Run `./tdd_harness.sh test <ID>` and verify it fails.
3. **Analyze**: Use `-dump-tokens` or debug logs to understand the failure.

### Phase 2: GREEN (Minimal Mutation)
1. **Implement**: Apply the simplest change to `mrl.y` or `mrl.l` to pass the test.
2. **Hardcode**: Temporary hardcoding or simple logic (Approach C) is acceptable to reach green.
3. **Verify**: Run the harness again to see PASS (✅).

### Phase 3: REFACTOR (Theoretical Alignment)
1. **Align**: Generalize the "Green" hack into proper RML constructs.
2. **Cleanup**: Remove temporary logs, simplify grammar rules, and resolve Bison conflicts.
3. **Dry Run**: Ensure the specific test STILL passes.

### Phase 4: VERIFY (Regression Guard)
1. **Full Suite**: Run `make test` or the full `tdd_harness.sh discover` list.
2. **Revert**: If regressions found, revert to the last stable "Green" state.

### Phase 5: ATOMIC COMMIT
1. **Finalize**: Commit with the test ID in the message: `fix(735Y): resolve tag nesting`.

---

## 6. Macro Cycle: Debt & History Management

For large-scale shifts (e.g., global refactors or purging history):
1. **Identify**: Use `git filter-repo` or `git rev-list` to target technical debt.
2. **Global Refactor**: Rotate the architecture (e.g., moving `main` into the grammar) as a single atomic macro cycle.
3. **Resync**: Immediately verify that the "Definition of Done" still holds at HEAD.

---

## 7. Standard Constants & Token Status

- `EXIT_SUCCESS` / `YYEOF` (0): Success.
- `EXIT_FAILURE` (1): Failure.
- `YYerror` (256): Syntax error marker.
- `YYUNDEF` (257): Undefined token.

---

## 8. Definition of Done

The project is considered "Done" for a specific growth cycle when:
1. **100% Pass Rate**: The `TEST_FAILURES.yaml` file is **empty**.
2. **Zero Regressions**: All focus tests (`tdd_harness.sh discover`) pass.
3. **Clean History**: No temporary artifacts or debt remain in the repository.
4. **Theory Alignment**: Code strictly maps to RML monoidal category definitions.

---

> [!IMPORTANT]
> **Always verify passing test IDs** against the `yaml-test-suite` before moving to the next growth cycle. Use the `tdd_harness.sh` for atomic verification.
