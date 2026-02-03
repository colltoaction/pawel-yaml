# Design Theory: RML & Bison Strategy ⚛️

Explore the mathematical foundations and advanced Bison configurations driving `pawel-yaml`.

---

## 1. Map Theory to Code
Map implementation directly to RML concepts.

| RML Definition | Concept | Implementation |
| :--- | :--- | :--- |
| **Alphabet** $\Gamma$ | Tokens | `Alphabet` struct |
| **Grammar** $\Psi$ | Rules | `Grammar` struct |
| **Morphism** | Structure | `StringDiagram` struct |

### Implement Monoidal Product ($\otimes$)
Compose morphisms sequentially (`sd_compose`) or in parallel (`sd_tensor`). Treat YAML fragments as atomic units of meaning.

---

## 2. Rework Bison Strategy
Leverage **GLR (Generalized LR)** to resolve structural ambiguities.

### Configure Parser
- **Reentrancy**: Use `%define api.pure full` for thread-safety.
- **Tracking**: Use `%locations` for precise diagnostics.
- **Conflicts**: Document ~45 S/R and ~36 R/R conflicts using `%expect`.

### Enhance Diagnostics
Use `%define parse.error detailed` and `%define parse.lac full`. Suggest expected tokens to improve TDD cycles.

---

## 3. Lexical Strategy
Convert raw YAML text into the Monoidal Alphabet.

- **Track Indentation**: Emit `INDENT` and `DEDENT` tokens based on significant whitespace.
- **Accumulate Block Scalars**: Handle `|` and `>` strings by accumulating lines into a single `BSCALAR` token.
- **Manage Context**: Differentiate between Flow context (inside `[]`, `{}`) and Block context using a simple nesting counter.

---

## 4. Inspirations & Philosophical Roots
- **Guy Steele's "Growing a Language"**: Adopt designs that grow over time.
- **UNIX Philosophy**: Build modular components like YACC and Flex.
- **Instruction-Level Parallelism (ILP)**: Use GLR path exploration as speculative execution for parsing.
