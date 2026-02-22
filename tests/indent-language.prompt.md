---
description: Follow-up task to extract and document a standalone YAML indentation language
---

# Follow-Up Task: Extract the YAML "Indent Language"

## Goal

Extract YAML indentation behavior into a focused, explicit sub-language implemented by:

- `src/indent.l` (lexer)
- `src/indent.y` (grammar)

The objective is to model indentation structure as a first-class grammar artifact and remove remaining implicit indentation behavior from parser C logic.

## Why This Task Exists

The current parser evolved toward:

- grammar-first handling of structure,
- reduced side effects in actions,
- explicit `INDENT/DEDENT(count)` semantics,
- TDD-driven regression repair.

This task continues that methodology by isolating indentation into a dedicated language that can be tested, reasoned about, and documented independently.

## Architecture (Draft First)

### 1. System Boundary

Build a standalone indentation subsystem with two files:

- `src/indent.l`: line-oriented indentation lexer
- `src/indent.y`: indentation structure grammar

This subsystem is intentionally narrower than full YAML parsing. It only models block indentation structure and close/open transitions.

### 2. Layered Design

1. **Line Classifier Layer (`indent.l`)**
   - Classifies each physical line as:
     - blank,
     - comment-only,
     - content line with leading indentation width.
   - Maintains an indentation stack.
   - Emits transition tokens:
     - `INDENT(level)` when increasing depth,
     - `DEDENT(count)` when collapsing one or more levels,
     - line/content boundary tokens for grammar consumption,
     - trailing `DEDENT(count)` at EOF when needed.

2. **Indent Structure Layer (`indent.y`)**
   - Consumes transition tokens and builds a structural representation of nesting.
   - Encodes explicit open/close grammar for blocks.
   - Rejects invalid dedent transitions deterministically.

3. **Validation/Projection Layer**
   - Emits minimal, deterministic structure output (event stream or tree lines).
   - Output is optimized for diff-based tests, not end-user presentation.

### 3. Token Contract (Architecture-Level)

Minimum contract between lexer and parser:

- `INDENT(<level>)`: absolute indentation depth of newly opened level.
- `DEDENT(<count>)`: number of levels closed in one transition.
- `LINE`: marks a content-bearing logical line.
- `LINE_BLANK` / `LINE_COMMENT` (or equivalent): non-structural line categories.
- `EOF_CLOSE`: optional explicit end marker if needed by grammar.

Notes:

- `DEDENT(count)` is mandatory and first-class.
- Blank/comment lines must not mutate stack depth.
- Invalid dedent targets fail before or at grammar boundary with deterministic diagnostics.

### 4. Internal Data Model

In lexer state:

- `indent_stack[]` with base `0`.
- `sp` stack pointer.
- `pending_dedent_count` for multi-close emission.

In parser semantic values:

- `Indented` type representing matched indentation transitions.
- Named references for levels/counts (`indent[level]`, `dedent[count]` style).

Cleanup policy:

- Use `%destructor` for typed cleanup and close semantics on discarded symbols.
- Keep helper functions pure (input -> output, no hidden global effects).

### 5. Grammar Shape (High-Level)

Define an explicit hierarchy:

- stream/document indentation unit
- sequence of logical lines
- nested block opened by `INDENT(level)`
- block close via `DEDENT(count)` transitions

Grammar should express nesting declaratively, not through C control flow. Mid-actions are allowed only as single-call emit/record operations.

### 6. Error Model

Errors to model explicitly:

- dedent to non-existent indentation level,
- unexpected `DEDENT(count)` in current grammar context,
- malformed close-at-EOF behavior.

Error behavior requirements:

- deterministic failure mode,
- stable message class,
- reproducible in focused tests.

### 7. Integration Strategy

Phase integration to limit risk:

1. Build and validate `indent.l` + `indent.y` standalone.
2. Lock behavior with dedicated indentation test corpus.
3. Bridge indentation events into existing YAML pipeline.
4. Remove overlapping indentation logic from `src/scanning.l`/`src/parsing.y` only after parity tests pass.

No compatibility wrappers should remain after migration completes.

### 8. Test Architecture

Add `tests/indent/` with:

- case fixtures (`input` + expected structural `tree`/events),
- positive and negative expectations,
- regression set for known indentation failures.

Validation style:

- event/tree diffing as primary oracle,
- accept/reject as secondary oracle,
- keep deterministic outputs for CI comparability.

### 9. Non-Goals (Architectural)

- Do not solve full YAML flow grammar here.
- Do not attach scalar semantics beyond what indentation structure needs.
- Do not refactor unrelated parser domains in the same batch.

### 10. Functorial Semantics (Primary Focus)

Define the indentation subsystem as a semantics-preserving map from syntax to state transitions.

#### 10.1 Syntax Category (`IndentSyn`)

Use a free category generated by indentation tokens and sequential composition.

Generators:

- `line`
- `line_blank`
- `line_comment`
- `indent(level)`
- `dedent(count)`
- `eof_close`

Composition:

- token stream concatenation (`;`)

Identity:

- empty stream (`id`)

#### 10.2 Semantic Category (`IndentSem`)

Use deterministic stack transformers with explicit failure:

- Objects: indentation stack states
- Morphisms: total functions `Stack -> Result(Stack, Error)`
- Composition: function composition in `Result` context
- Identity: no-op transformer

`Result` keeps failures first-class (invalid dedent, invalid indent target, malformed EOF close).

#### 10.3 Functor Definition (`F : IndentSyn -> IndentSem`)

Map syntax generators to semantic transformers:

- `F(line) = id`
- `F(line_blank) = id`
- `F(line_comment) = id`
- `F(indent(level)) = push(level)` with guard `level > top(stack)`
- `F(dedent(count)) = pop(count)` with guard `1 <= count <= depth(stack)`
- `F(eof_close) = pop_to_root`

Functor laws required by design:

- `F(id) = id`
- `F(a ; b) = F(a) ; F(b)` (composition preservation)

#### 10.4 Derived Equivalences (Must Be Tested)

- `F(dedent(k))` is observationally equivalent to `F(dedent(1)^k)` when both are defined.
- Any sequence of only `line_blank` and `line_comment` is semantically identity.
- `F(eof_close)` is equivalent to dedenting exactly to root depth.

#### 10.5 Parser/Lexer Contract Under the Functor

- `src/indent.l` must emit tokens that are valid generators of `IndentSyn`.
- `src/indent.y` must compose generators without hidden side effects.
- Any imperative helper used in lexer/parser must implement one generator mapping only (single responsibility).
- Mid-rule actions cannot encode extra semantics outside `F`.

#### 10.6 Documentation Requirements for Semantics

`src/INDENT_LANGUAGE.md` must include:

- formal definition of `IndentSyn`,
- formal definition of `IndentSem`,
- explicit definition of `F`,
- law checks and counterexample format.

## Methodology Constraints (Carry Forward)

1. Grammar-oriented implementation first.
2. Mid-rule actions are rare and limited to single-statement, single-call actions.
3. Helpers are functional/pure (no hidden state mutation).
4. Prefer Bison named references for readability.
5. Ambiguity is acceptable only when tests pass.
6. No compatibility wrappers; raw migration to the new model.
7. `DEDENT(count)` remains explicit and testable.
8. Functor laws (`identity`, `composition`) are mandatory acceptance gates.

## Scope

### In Scope

- Define indentation tokenization in `src/indent.l`.
- Define indentation grammar in `src/indent.y`.
- Represent nested block structure using explicit indent transitions.
- Support multi-level close in one step (`DEDENT(count)`).
- Document the indentation language comprehensively.
- Add dedicated tests for indentation language behavior.

### Out of Scope

- Full YAML scalar parsing.
- Full flow-style semantic validation.
- Rewriting all YAML grammar rules in one batch.

## Deliverables

1. **Lexer**: `src/indent.l`
   - Emits indentation-focused tokens (at minimum: newline boundaries, indent open, dedent close, EOF close).
   - Emits `DEDENT(count)` for collapsed close operations.
   - Keeps token semantics deterministic and line-oriented.

2. **Grammar**: `src/indent.y`
   - Defines structural productions for indentation nesting.
   - Makes indentation transitions explicit (`indent[level]`, `dedent[count]` style).
   - Produces a minimal structural IR or event stream suitable for diff-based validation.

3. **Documentation**: `src/INDENT_LANGUAGE.md`
   - Formal grammar (tokens + productions).
   - Operational semantics for indent stack transitions.
   - Edge-case rules:
     - blank/comment lines,
     - trailing dedents at EOF,
     - invalid dedent level detection,
     - multi-level dedent collapse.
   - Worked examples with input and emitted structure.
   - Known ambiguities and why they are acceptable.
   - Functorial section: `IndentSyn`, `IndentSem`, `F`, and verified laws.

4. **Tests**: `tests/indent/`
   - Focused positive/negative cases for indentation only.
   - Fixtures for multi-level dedent and mixed blank/comment lines.
   - Event/tree comparison outputs for deterministic verification.

## TDD Plan

1. **Red (Seed failures)**
   - Create initial `tests/indent/` failing cases from known indentation regressions.
   - Include at least one case each for:
     - single indent/dedent,
     - nested indent with `DEDENT(count>1)`,
     - invalid dedent level,
     - EOF-triggered close.
   - Add at least two law-oriented failing tests:
     - composition law fixture (`F(a;b)` vs `F(a)∘F(b)`),
     - dedent-collapse equivalence (`dedent(k)` vs `k * dedent(1)`).

2. **Green (Minimal implementation)**
   - Implement minimal `indent.l` + `indent.y` to satisfy seeded failures.
   - Avoid adding non-essential YAML features.

3. **Refactor**
   - Remove duplicated alternatives in indentation productions.
   - Replace stateful helpers with pure helper calls.
   - Keep grammar readable with named references.
   - Remove semantic duplication by routing behavior through functor generator mappings.

4. **Integrate**
   - Wire the indent language checks into existing build/test flow.
   - Ensure no regressions in targeted YAML cases.
   - Keep semantic-law checks as a separate make target so regressions are explicit.

## Acceptance Criteria

1. `src/indent.l` and `src/indent.y` exist and build cleanly.
2. Dedicated indentation tests are executable and passing.
3. `DEDENT(count)` behavior is covered by tests (including `count > 1`).
4. Invalid dedent level is detected with deterministic failure.
5. Functor laws are tested and passing:
   - identity preservation,
   - composition preservation,
   - dedent-collapse equivalence.
6. `src/INDENT_LANGUAGE.md` fully documents syntax + semantics + examples.
7. Existing targeted YAML regression checks still pass:
   - `make -C tests test TEST=G9HC`
   - `make -C tests test TEST=Q9WF`
   - `make -C tests test TEST=9FMG`

## Suggested Execution Order

1. Add minimal `indent.l` tokenizer with indent stack + `DEDENT(count)` emission.
2. Add minimal `indent.y` grammar for nested indentation blocks.
3. Add `tests/indent/` fixtures and red tests.
4. Make tests pass with smallest grammar/lexer changes.
5. Write/expand `src/INDENT_LANGUAGE.md` from implementation truth.
6. Run targeted YAML regressions to confirm no backslide.

## Reporting Requirements

For each batch, record:

- what failed,
- what grammar/lexer rule changed,
- which tests moved from fail -> pass,
- any new ambiguity introduced and why it is safe.

Use existing test tooling patterns (`make -C tests ...`) and keep artifacts under `tests/`.
