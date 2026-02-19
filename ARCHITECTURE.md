# ARCHITECTURE

This file consolidates the project documentation into one canonical reference for architecture, engineering workflow, and delivery constraints.

## Scope

Included:
- Root project docs: `README.md`, `TEST_FAILURES.yaml`, `COMPREHENSIVE_FAILURES.yaml`
- First-party docs under `.agent/` (architecture, playbooks, status, analysis, prompts)
- `.github/prompts/plan-lexerIndentationRefactorToRmgStackModel.prompt.md`

Explicitly excluded from consolidation:
- Vendored or mirrored external repositories under `.agent/lib*` and `.agent/yaml-reference-parser`
- Build artifacts under `build/`
- YAML test fixtures such as `test_5LLU*.yaml` (these are test inputs, not architecture docs)

## Canonical Goal

Build a YAML parser pipeline aligned with RML theory and Bison/Flex practice, with a strict architecture split:
- Syntax recognition in lexer/parser grammar
- Semantic constraint validation as a separate pass
- Ownership handled primarily through grammar semantic-type destructors (`%destructor`) and clear transfer boundaries

## Consolidated Architecture Model

### Pipeline (Current Program Shape)

The executable currently runs four stages (`src/main.c`):
1. `yaml_parse()` in `src/parsing.y`: presentation -> events (IR text stream)
2. `yaml_compose()` in `src/parsing.y` + `src/composition.y`: events -> representation
3. `yaml_serialize()` in `src/parsing.y` / `src/serialization.y`: representation -> events (currently placeholder)
4. `yaml_present()` in `src/parsing.y` / `src/presentation.l`: events -> presentation (currently placeholder)

Current practical status:
- Stage 1 and Stage 2 are implemented and active.
- Stage 3 and Stage 4 are structural stubs/placeholders.

### Stage 1: Scanner + Grammar

Scanner (`src/scanning.l`) responsibilities:
- Tokenization of YAML surface syntax
- Indentation tracking (`indent_stack`, pending dedents)
- Flow context tracking (`flow_level` and flow-indent checks)
- Scalar modes (quoted/plain/block)
- Directive and tag lexing

Parser (`src/parsing.y`) responsibilities:
- Structural grammar for stream/doc/node/sequence/mapping forms
- Error recovery with grammar-level synchronization
- Event emission into stage-boundary IR
- Semantic-value lifecycle controlled by `%destructor`:
  - `%destructor { destroy_string($$); } <string>`
  - `%destructor { destroy_props(&$$); } <props>`
  - `%destructor { destroy_scalar(&$$); } <scalar>`

### Stage 2: Composition

`src/composition.l` + `src/composition.y` parse emitted event-IR tokens (`+STR`, `+DOC`, `=VAL`, etc.) into an `EventStream` representation.

### Stage 3 and Stage 4

`src/serialization.y` and `src/presentation.l` define interfaces but are still placeholders.

## Core Boundary: Syntactic vs Semantic Validation

The strongest repeated result across RML, YACC, UNIX-principle, and empirical docs is this separation:

Syntactic validation (grammar-level):
- Token order and local structure
- Bracket/document/production conformance
- Recovery from malformed local syntax via `error` productions

Semantic validation (language-level):
- Cross-event and global constraints
- Indentation invariants spanning contexts
- Placement constraints that are not naturally local grammar properties
- Post-parse or post-event validation pass

This separation is treated as canonical project direction.

## Ownership and Memory Contract

Consolidated ownership rules from playbooks and current parser structure:

1. Grammar semantic values are grammar-owned by default.
2. `%destructor` is the default cleanup mechanism for semantic values.
3. Grammar actions should avoid ad-hoc manual `free()` calls, except explicit ownership-transfer boundaries.
4. Scanner/parser context lifecycle should be scanner/parser-owned, not stage-glue manual resource juggling.
5. Terminal faults (allocation failures/invariant breaks) should latch fatal status and stop pipeline progression.

Project direction in this area (from `rml.yaml` and session notes):
- Keep moving event-stream logic away from procedural C glue and toward grammar-defined behavior.
- Keep explicit C helpers transport-focused; keep acceptance/rejection logic in grammar + semantic validator boundaries.

## Error Handling Contract

Consolidated from `bison-flex-error-handling.md`, phase docs, and current grammar:

Recoverable errors:
- Use grammar `error` token at explicit synchronization points.
- Use `yyerrok` only after consuming a valid sync boundary.
- Continue parse where possible to gather diagnostics.

Terminal errors:
- Allocation failure
- Internal invariant failure
- Fatal scanner/parser state corruption

Current parser implementation already tracks parse errors (`parse_error_count`) and converts recovered parse-with-errors into non-zero status.

## Practical Engineering Workflow

### Build and Run

Canonical commands from docs and Makefile:
- `make`
- `make setup`
- `make validate-suite-full`
- `make validate-suite`
- `make valgrind`, `make valgrind-summary`, `make valgrind-full`, `make valgrind-suite` (documented in README)

### Test Infrastructure

- yaml-test-suite expected at `build/lib/yaml-test-suite/src`
- Primary status files:
  - `TEST_FAILURES.yaml` (current fail list snapshot)
  - `COMPREHENSIVE_FAILURES.yaml` (taxonomy: correct fail/pass, false negatives)

### TDD Operating Discipline

Consolidated from `life-is-fair.yaml`, `AGENTIC_TDD.prompt.md`, and handbook:
1. RED: capture failing behavior
2. GREEN: minimal fix
3. REFACTOR: structural cleanup to architectural model
4. VERIFY: regression and suite checks
5. COMMIT: atomic, evidence-backed

### Chaos Engineering Discipline

Consolidated from `CHAOS_ENGINEERING_*` docs:
- Remove one token/rule in isolation
- Rebuild and run controlled sample/full suite
- Measure delta from baseline
- Restore and record verdict (active vs dead)

Use chaos testing as a verification tool before large refactors, not as a replacement for design.

## Current Quality Snapshot

Authoritative short snapshot from `TEST_FAILURES.yaml` (generated_at `2026-02-18`):
- Total suite size: 351
- Reported failures: 121
- Implied passes: 230
- Implied pass rate: 65.5%

Important context:
- Historical docs report different baselines (196, 203, 215, 257, etc.) from earlier sessions.
- Treat `TEST_FAILURES.yaml` and fresh suite runs as current truth; treat session docs as historical context.

## Consolidated Roadmap

### Near-Term (architecture-consistent)

1. Continue replacing procedural event-stream C logic with grammar-driven reductions.
2. Keep ownership cleanup declarative through `%destructor` and explicit transfer points.
3. Preserve local grammar recovery; avoid global hacks in scanner states for semantic-only constraints.

### Compatibility push toward 100%

1. Complete semantic-validation layer for language-level constraints that should not be forced into grammar.
2. Maintain strict no-regression policy against existing passes.
3. Finish Stage 3 and Stage 4 pipeline implementation so full round-trip architecture is complete.

## Anti-Patterns (Consolidated)

Avoid:
- Duplicated custom stacks that re-implement scanner/parser machinery without clear necessity
- Large semantic policy encoded as lexer-state duplication
- Grammar actions with unmanaged manual allocation/free patterns
- Mixing historical metrics with current status without timestamping

Prefer:
- Grammar-first structure
- Semantic-pass checks for non-local constraints
- `%destructor`-driven lifecycle
- Explicit fatal vs recoverable error paths

## Canonical File Mapping Notes

Many historical docs refer to older filenames (`src/mrl.y`, `src/mrl.l`, `src/yaml.y`, `src/yaml.l`).
Use this practical mapping when applying those documents to current code:
- `src/mrl.y` / `src/yaml.y` -> `src/parsing.y`
- `src/mrl.l` / `src/yaml.l` -> `src/scanning.l`

## Documentation Index (Consolidated)

The table below maps every first-party documentation file into the consolidated structure in this file.

| File | Type | Consolidated Section |
|---|---|---|
| `.agent/ANALYSIS/LEXER_CHAOS_REPORT.md` | Historical/Status | Execution History and Roadmap |
| `.agent/ANALYSIS/SESSION_SUMMARY_LEXER_CHAOS.md` | Historical/Status | Execution History and Roadmap |
| `.agent/ARCHITECTURAL_BOUNDARY.md` | Architecture/Theory | Core Architecture and Theory |
| `.agent/CHAOS_ENGINEERING_BASELINE.md` | Historical/Status | Execution History and Roadmap |
| `.agent/CHAOS_ENGINEERING_PROCEDURES.md` | Historical/Status | Execution History and Roadmap |
| `.agent/CHAOS_ENGINEERING_TEST_RESULTS.md` | Historical/Status | Execution History and Roadmap |
| `.agent/COMPUTING_INSPIRATION.md` | Architecture/Theory | Core Architecture and Theory |
| `.agent/COMPUTING_INSPIRATION/01_Mother_of_All_Demos.md` | Reference Note | Inspiration and Historical Reference |
| `.agent/COMPUTING_INSPIRATION/02_Distributed_Systems.md` | Reference Note | Inspiration and Historical Reference |
| `.agent/COMPUTING_INSPIRATION/03_UNIX_Operating_System.md` | Reference Note | Inspiration and Historical Reference |
| `.agent/COMPUTING_INSPIRATION/04_Artificial_Intelligence.md` | Reference Note | Inspiration and Historical Reference |
| `.agent/COMPUTING_INSPIRATION/05_Teaching_Computer_Science.md` | Reference Note | Inspiration and Historical Reference |
| `.agent/COMPUTING_INSPIRATION/06_Smalltalk_Alto_System.md` | Reference Note | Inspiration and Historical Reference |
| `.agent/COMPUTING_INSPIRATION/07_Programming_1950s.md` | Reference Note | Inspiration and Historical Reference |
| `.agent/COMPUTING_INSPIRATION/08_Feynman_Computing.md` | Reference Note | Inspiration and Historical Reference |
| `.agent/COMPUTING_INSPIRATION/09_FORTRAN_Beginnings.md` | Reference Note | Inspiration and Historical Reference |
| `.agent/COMPUTING_INSPIRATION/10_Growing_Language.md` | Reference Note | Inspiration and Historical Reference |
| `.agent/COMPUTING_INSPIRATION/11_Rethinking_CS_Education.md` | Reference Note | Inspiration and Historical Reference |
| `.agent/COMPUTING_INSPIRATION/12_Sketchpad_Demo.md` | Reference Note | Inspiration and Historical Reference |
| `.agent/COMPUTING_INSPIRATION/13_Ed_Fredkin.md` | Reference Note | Inspiration and Historical Reference |
| `.agent/COMPUTING_INSPIRATION/14_Simple_Made_Easy.md` | Reference Note | Inspiration and Historical Reference |
| `.agent/COMPUTING_INSPIRATION/15_JSON_Discovery.md` | Reference Note | Inspiration and Historical Reference |
| `.agent/COMPUTING_INSPIRATION/16_Bell_Labs_Languages.md` | Reference Note | Inspiration and Historical Reference |
| `.agent/COMPUTING_INSPIRATION/17_Bell_Labs_Spirit.md` | Reference Note | Inspiration and Historical Reference |
| `.agent/COMPUTING_INSPIRATION/18_Holmdel_Facility.md` | Reference Note | Inspiration and Historical Reference |
| `.agent/COMPUTING_INSPIRATION/19_Shannon_Limit.md` | Reference Note | Inspiration and Historical Reference |
| `.agent/COMPUTING_INSPIRATION/20_Bell_Labs_Pixar.md` | Reference Note | Inspiration and Historical Reference |
| `.agent/COMPUTING_INSPIRATION/21_SELF_Implementation.md` | Reference Note | Inspiration and Historical Reference |
| `.agent/COMPUTING_INSPIRATION/22_Instruction_Level_Parallelism.md` | Reference Note | Inspiration and Historical Reference |
| `.agent/CYCLE_PROGRESS.md` | Historical/Status | Execution History and Roadmap |
| `.agent/DESIGN_THEORY.md` | Architecture/Theory | Core Architecture and Theory |
| `.agent/ENGINEERING_HANDBOOK.md` | Operational Guide | Engineering Workflow and Operations |
| `.agent/ENGINEERING_HANDBOOK.prompt.md` | Prompt | Prompt Assets and Assistant Guidance |
| `.agent/NEXT_STEPS.md` | Historical/Status | Execution History and Roadmap |
| `.agent/PHASE10_11_TRANSITION.md` | Historical/Status | Execution History and Roadmap |
| `.agent/PHASE10_GLR_FIX_ANALYSIS.md` | Historical/Status | Execution History and Roadmap |
| `.agent/PHASE10_GREEN_ERROR_HANDLING_ANALYSIS.md` | Historical/Status | Execution History and Roadmap |
| `.agent/PHASE10_SUMMARY.md` | Historical/Status | Execution History and Roadmap |
| `.agent/PHASE11_BLOCK_SCALARS_ANALYSIS.md` | Historical/Status | Execution History and Roadmap |
| `.agent/PHASE11_STATUS.md` | Historical/Status | Execution History and Roadmap |
| `.agent/PILLARS_OF_FORMAL_GRAMMAR.yaml` | Architecture/Theory | Core Architecture and Theory |
| `.agent/PLAYBOOK/AGENTIC_TDD.prompt.md` | Playbook | Playbooks and Operating Protocols |
| `.agent/PLAYBOOK/CHAOS_ENGINEERING.prompt.md` | Playbook | Playbooks and Operating Protocols |
| `.agent/PLAYBOOK/FUTURE_AWARE_REFACTORING.prompt.md` | Playbook | Playbooks and Operating Protocols |
| `.agent/PLAYBOOK/FUTURE_AWARE_REFACTORING_ENGINEERING_GUIDE.md` | Playbook | Playbooks and Operating Protocols |
| `.agent/PLAYBOOK/GLOSSARY.prompt.md` | Playbook | Playbooks and Operating Protocols |
| `.agent/PLAYBOOK/INDEX.md` | Playbook | Playbooks and Operating Protocols |
| `.agent/PLAYBOOK/QUICK_REFERENCE.md` | Playbook | Playbooks and Operating Protocols |
| `.agent/PLAYBOOK/bison-flex-error-handling.md` | Playbook | Playbooks and Operating Protocols |
| `.agent/PLAYBOOK/lex-yacc-make.yaml` | Playbook | Playbooks and Operating Protocols |
| `.agent/PLAYBOOK/libfyaml.yaml` | Playbook | Playbooks and Operating Protocols |
| `.agent/PLAYBOOK/life-is-fair.yaml` | Playbook | Playbooks and Operating Protocols |
| `.agent/PLAYBOOK/rml.yaml` | Playbook | Playbooks and Operating Protocols |
| `.agent/PROMPTS/COMPUTING_INSPIRATION.prompt.md` | Prompt | Prompt Assets and Assistant Guidance |
| `.agent/PROMPTS/YACC.prompt.md` | Prompt | Prompt Assets and Assistant Guidance |
| `.agent/README.md` | Operational Guide | Engineering Workflow and Operations |
| `.agent/RML_INSIGHT.md` | Architecture/Theory | Core Architecture and Theory |
| `.agent/SESSION_COMPLETE.md` | Historical/Status | Execution History and Roadmap |
| `.agent/SESSION_REPORT.md` | Historical/Status | Execution History and Roadmap |
| `.agent/SESSION_STATUS_2026-02-10.md` | Historical/Status | Execution History and Roadmap |
| `.agent/SESSION_SYNTHESIS.md` | Historical/Status | Execution History and Roadmap |
| `.agent/SETUP_TEST_SUITE.md` | Operational Guide | Engineering Workflow and Operations |
| `.agent/THEORETICAL_CONVERGENCE.md` | Architecture/Theory | Core Architecture and Theory |
| `.agent/UNIX_FIRST_PRINCIPLES.md` | Architecture/Theory | Core Architecture and Theory |
| `.agent/YACC_INSIGHTS.md` | Architecture/Theory | Core Architecture and Theory |
| `.agent/YAML_PARSER_ARCHITECTURE_REDESIGN.md` | Architecture/Theory | Core Architecture and Theory |
| `.agent/handoff.md` | Historical/Status | Execution History and Roadmap |
| `.github/prompts/plan-lexerIndentationRefactorToRmgStackModel.prompt.md` | Prompt | Prompt Assets and Assistant Guidance |
| `COMPREHENSIVE_FAILURES.yaml` | Status Data | Quality Baselines and Test Taxonomy |
| `README.md` | Project README | Project Overview and Build |
| `TEST_FAILURES.yaml` | Status Data | Quality Baselines and Test Taxonomy |

## Maintenance Rules

1. Treat this file as the primary architectural source of truth.
2. When adding docs under `.agent/`, update this file first, then add supporting deep-dive docs.
3. When metrics change, update dates and source-of-truth references (`TEST_FAILURES.yaml`, suite logs).
4. Keep architectural boundaries explicit: syntax in grammar, semantics in validation, ownership by contract.
