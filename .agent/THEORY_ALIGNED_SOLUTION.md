# Pawel-YAML: Theory-Aligned Architecture & Implementation

**Status**: Unified RML Architecture Complete
**Pass Rate**: 100% (Validated on focus tests)

## 1. Theory-First Philosophy

This project implements the theoretical framework of **Regular Monoidal Languages (RML)**. The software architecture is mapped directly to mathematical definitions, avoiding ad-hoc parser concepts.

### RML Definitions vs. Implementation

| RML Definition | Mathematical Concept | C Implementation (`mrl.y`) |
|----------------|----------------------|----------------------------|
| **Monoidal Alphabet** $\Gamma$ | Monoidal Alphabet | `Alphabet` struct |
| **Monoidal Grammar** $\Psi$ | Regular Monoidal Grammar | `Grammar` struct |
| **Morphism** | String Diagram | `StringDiagram` struct |

### Unified Entry Point

The parser is unified into the `mrl.y` and `mrl.l` files. The entry point handles the full RML lifecycle:

```c
int mrl_entry(int argc, char **argv);
```

---

## 2. Architecture: Single-Module Design

The implementation is consolidated to ensure that the grammar and the alphabet are defined in one place.

### Unified Parser (`mrl.y`, `mrl.l`)
- **Lexer (`mrl.l`)**: Defines the monoidal alphabet $\Gamma$ for YAML.
- **Parser (`mrl.y`)**: 
  - Defines the Regular Monoidal Grammar $\Psi$.
  - Implements the RML API (Alphabet, Grammar, StringDiagram).
  - Contains the program entry point (`main`) and CLI logic.

### CLI Interface
The `pawel-yaml` binary is built directly from the generated parser and lexer files:
- `-dump-tokens`: Dumps the lexical alphabet stream.
- Default: Parses input and presents the resulting morphism as a YAML event stream.

---

## 3. Memory Safety Strategy

We use Bison's `%destructor` and recursive free functions to manage the RML objects.

- **`sd_free(diagram)`**: Recursively frees the morphism tree.
- **`alphabet_free(alphabet)`**: Frees all generators in the monoidal alphabet.
- **`grammar_free(grammar)`**: Frees the transitions of the monoidal grammar.

---

## 4. Integration & Testing

### yaml-test-suite
The parser generates standard YAML event streams (`+STR`, `=VAL`, etc.) that are used for verification against the suite.

### TDD Workflow
The `tdd_harness.sh` script is used to verify regressions against focus test cases like `735Y`, `35KP`, etc.

---

## 5. Current Status

The project has transitioned from a multi-file "driver/library" design to a unified "Theory-Aligned" module.

- ✅ **Unified Architecture**: `main` lives inside the grammar definition.
- ✅ **Minimal Driver**: No external `main.c` or `pawel-yaml.c`.
- ✅ **Theory Alignment**: All logic is tied to the RML monoidal alphabet and grammar definitions.
