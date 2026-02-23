# Engineering Handbook: Development Protocol ⚛️

Adopt this guide for contributing to `pawel-yaml` internal services. Consolidate technical wisdom into tool-verifiable patterns.

---

## 1. Principles

### Align Theory (Theory-First)
- **Map Directly**: Ensure Alphabet, Grammar, and StringDiagram map 1-to-1 to RML definitions.
- **Use Morphisms**: Treat every parsed YAML construct as a morphism in the free monoidal category.
- **Compose Vertically**: Prefer `sd_compose` over manual state coupling.

### Unify Architecture (Simplification)
- **Consolidate Modules**: Implement grammar, RML API, and entry point in `mrl.y` and `mrl.l`.
- **Minimize Drivers**: Keep the binary inside the grammar; get rid of external drivers.
- **Maintain Purity**: Use Bison's `%code` and `%code requires` to segregate implementation from declarations.

---

## 2. Agentic TDD Protocol: The 5-Phase Cycle

Enforce the Agentic TDD Protocol to ensure every mutation is tool-verifiable.

### Phase 1: RED (Establish Failure)
- **Identify**: Pinpoint a failing test from `yaml-test-suite`.
- **Verify Baseline**: Run `./.agent/tooling.sh tdd:test <ID>`.
- **Analyze**: Use `-dump-tokens` to uncover the failure root cause.

### Phase 2: GREEN (Localize Fix)
- **Mutate**: Write the *simplest possible code* to pass the test.
- **Verify**: Run the harness; see the PASS (✅).

### Phase 3: REFACTOR (Align Theory)
- **Rework**: Generalize the "Green" hack into RML constructs.
- **Map**: Replace the hack with a proper Monoidal Morphism or Grammar Rule.
1. Inspect the hack.
2. Link to RML equivalent.
3. Rewrite using `mrl.y` Internal Services.

### Phase 4: VERIFY (Protect History)
- **Test Full Suite**: Run `./.agent/tooling.sh` to guard against regressions.
- **Revert**: Get rid of regressions by reverting to the stable Green state.

### Phase 5: ATOMIC COMMIT
- **Checkpoint**: Commit referencing the Test ID.

---

## 3. Build System & Directory Structure

Preserve test artifacts while allowing rapid rebuilds.

### Directory Map
```
build/
├── src/          ← Generated parser/lexer (CLEANED by make clean)
├── inc/          ← Generated headers (CLEANED by make clean)
├── bin/          ← Compiled binary (CLEANED by make clean)
├── lib/          ← External deps (yaml-test-suite) (PRESERVED)
├── tmp/          ← Test artifacts, scratchpad (PRESERVED)
└── log/          ← Build logs, chaos results (PRESERVED)
```

### Effective Make Targets
- **`make`**: Build parser and lexer via rapid incremental compilation.
- **`make setup`**: Initialize official YAML test suites.
- **`make clean`**: **TDD-Safe.** Remove generated binaries but preserve `build/tmp/` test results.
- **`make deepclean`**: Full reset. Delete entire `build/` directory.

---

## 4. Quick Reference: Common Workflows

### Daily Developer Workflow
1. `make` to ensure binary is fresh.
2. `./.agent/tooling.sh tdd:test <ID>` to verify current failure.
3. Apply fix -> `make` -> `./.agent/tooling.sh tdd:test <ID>` (Green).
4. Refactor -> `make` -> `./.agent/tooling.sh tdd:test <ID>` (Refactored Green).
5. `./.agent/tooling.sh check` to verify against recent history.

### Lexer State Management
- **Indentation Stack**: Use `push_indent_safe()` for nested block structures.
- **Flow Control**: `flow_level` handles nested `[]` and `{}`.
- **Block Scalars**: Use `init_block_scalar()` for multi-line string accumulation.

---

# 5. Definition of Done
A growth cycle is complete when:
- **100% Pass Rate**: Target tests pass and are removed from `TEST_FAILURES.yaml`.
- **Zero Regressions**: All previously green tests remain green.
- **Zero Memory Leaks**: Verified with `valgrind`.
- **Theory Alignment**: Code strictly maps to RML monoidal category definitions.
