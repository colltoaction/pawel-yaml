# YAML Parser Architecture Redesign v2
## Complete Blueprint: Multiline Scalars → 92/100 Test Pass Rate

**Status**: Design Document Ready for Autonomous Execution  
**Target**: 92/100 tests (from 68/100 baseline)  
**Baseline Commit**: `71ca378`  
**Methodology**: Future-Aware Refactoring + Chaos Engineering Verification  
**Created**: 2026-02-04  

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Current State Analysis](#current-state-analysis)
3. [Architecture Redesign Blueprint](#architecture-redesign-blueprint)
4. [Phase Breakdown (1-4)](#phase-breakdown-1-4)
5. [Execution Strategy](#execution-strategy)
6. [Future-Aware Refactoring Protocol](#future-aware-refactoring-protocol)
7. [Chaos Engineering Verification](#chaos-engineering-verification)
8. [Implementation Checklist](#implementation-checklist)
9. [Risk Mitigation & Fallback](#risk-mitigation--fallback)
10. [Success Criteria](#success-criteria)

---

## Executive Summary

### The Problem
68/100 YAML tests passing (32 failures) due to four architectural bottlenecks:
- **Multiline Scalars** (8 tests): Lexer terminates on first newline
- **Indentation Context** (6 tests): INDENT/DEDENT tokens don't track block vs flow
- **GLR Ambiguity** (5 tests): Missing precedence declarations
- **Tag Handling** (4 tests): Complex tag positions unparseable
- **Other** (9 tests): Edge cases and missing features

### The Solution
4-Phase incremental redesign addressing each architectural concern:

| Phase | Focus | Gap | Fix | Target |
|-------|-------|-----|-----|--------|
| 1 | Lexer | Multiline scalars break on newlines | State machine for continuation | 72/100 |
| 2 | Grammar | Nested structures ambiguous | Precedence rules, explicit keys | 78/100 |
| 3 | Events | INDENT/DEDENT unpaired | Assertion + standardization | 82/100 |
| 4 | Validator | Missing error validation | Event state machine | 92/100 |

### Why This Works
- **Modular**: Each phase addresses independent architectural concern
- **Safe**: Full test harness verification after each phase (~2 min)
- **Measurable**: Specific test targets per phase (72→78→82→92)
- **Atomic**: 13± commits, ~165 lines total (surgical precision)
- **Verified**: Chaos Engineering ensures every change impacts tests

---

## Current State Analysis

### 32 Failing Tests Categorized

```
68/100 Passing | 32/100 Failing
  ├─ Multiline Scalars (8): 36F6, 4ZYM, 4CQQ, 5AKW, 5BHN, 5DVL, 5CQW, 5WPP
  ├─ Indentation Context (6): 3ALJ, 3MYT, 5FJC, 5NTR, 5SYZ, 565N
  ├─ GLR Ambiguity (5): 35KP, 4RWC, 57H4, 5DH2, 5EKC
  ├─ Tag Handling (4): 35KP, 565N, 57H4, 5DVL
  └─ Other/Edge Cases (9): Various complex scenarios
```

### Root Cause Map

| Symptom | Root Cause | Location | Impact |
|---------|-----------|----------|--------|
| Plain scalars stop at newline | Lexer returns SCALAR too early | `src/yaml.l` line 245 | 36F6, 4ZYM |
| Quoted scalars skip content | No multiline state | `src/yaml.l` (missing) | 4CQQ |
| Block scalars incomplete | No `BLOCK_LITERAL_CONT` state | `src/yaml.l` (missing) | 5AKW |
| Nested sequences fail | `seq_entry` lacks INDENT case | `src/yaml.y` line 206 | 3ALJ |
| Indentation ambiguous | No `is_flow` context flag | `src/yaml.l` (global) | 3MYT |
| Tags at wrong position | Grammar doesn't parse `TAG node_body` | `src/yaml.y` (missing rule) | 565N |
| GLR chooses wrong parse | %precedence directives missing | `src/yaml.y` line 115 | 35KP |

### Current Architecture (Problematic)

```
Stage 1: Lexer (yaml.l) → Stage 2: Parser (yaml.y) → Stage 3: Validator (rml_validator.c)
  ❌ Breaks scalars on newlines
  ❌ No indentation context
  ❌ GLR chooses ambiguous parse
  ❌ Event stream malformed
```

### Working Baseline (5 Cycles Complete)

✅ **Cycle 1**: Test 26DV fixed (node properties)  
✅ **Cycle 2**: Test 2EBW fixed (special char scalars)  
✅ **Cycle 3**: Test 2LFX fixed (directives + blank lines)  
✅ **Error Reporting**: Bison detailed messages refactored  
✅ **Cycle 5**: Test 4ABK fixed (omitted values in flow maps)  

**Current**: 68/100 (baseline for redesign)

---

## Architecture Redesign Blueprint

### Target Architecture (Desired)

```
Stage 1: Context-Aware Lexer (yaml.l - Enhanced)
  ✅ Scalar state machine (PLAIN_SCALAR_CONT, QUOTED_SCALAR_CONT, BLOCK_LITERAL_CONT)
  ✅ Indentation context stack (is_flow flag)
  ✅ Lookahead for continuation detection
  ✅ Proper INDENT/DEDENT pairing
    ↓ (well-formed event stream)
Stage 2: Precision Grammar (yaml.y - Enhanced)
  ✅ Explicit %precedence for all ambiguities
  ✅ Nested sequence rules (seq_entry + INDENT)
  ✅ Explicit key syntax (QUESTION node COLON node)
  ✅ Tag placement rules (TAG before/after node_body)
    ↓ (valid RML IR)
Stage 3: Event Validation (rml_validator.c - Enhanced)
  ✅ Event sequence state machine
  ✅ Detailed error messages
  ✅ Nesting depth tracking
  ✅ Helpful hints for common errors
```

### Design Decisions & Rationale

| Decision | Rationale | Alternative Rejected |
|----------|-----------|----------------------|
| **Separate scalar states** | Each type has different folding rules | Single universal state (too complex) |
| **Indentation context stack** | Distinguishes `-` (block) from `,` (flow) | Lookahead only (error-prone) |
| **Keep GLR + add %precedence** | GLR handles natural ambiguity; precedence resolves deterministically | Switch to LALR(1) (requires grammar rewrite) |
| **4-phase structure** | Each phase addresses independent concern | Single monolithic redesign (risky) |
| **Future-Aware Refactoring** | Look ahead to avoid positional debt | Incremental iteration (accumulates rework) |

---

## Phase Breakdown (1-4)

### Phase 1: Lexer Redesign - Multiline Scalars (68→72/100)

**Objective**: Fix plain, quoted, and block scalar continuation  
**Duration**: 1-2 hours  
**Commits**: 5  
**Tests Fixed**: 36F6, 4ZYM, 4CQQ, 5AKW, 5BHN (+4 total)  
**Lines Modified**: ~60 added to `src/yaml.l`, ~5 to `src/yaml.y`  

#### Key Implementation Points

1. **Add Lexer States**:
   ```flex
   %x PLAIN_SCALAR_CONT      /* Continue plain scalar across lines */
   %x QUOTED_SCALAR_CONT     /* Continue quoted scalar */
   %x BLOCK_LITERAL_CONT     /* | scalar continuation */
   %x BLOCK_FOLDED_CONT      /* > scalar continuation */
   ```

2. **Track Scalar Base Indent**:
   ```c
   int scalar_base_indent;    /* Indent level where scalar started */
   int scalar_type;           /* ':' plain, '"' quoted, '|' literal, '>' folded */
   ```

3. **Indentation Context Stack**:
   ```c
   typedef struct {
       int level;             /* indent level */
       int is_flow;           /* 1 if in {...} or [...], 0 if block */
       char context_type;     /* 'M' (map), 'S' (seq), 'F' (flow) */
   } IndentContext;
   
   IndentContext indent_stack[100];
   int indent_sp = 0;
   ```

4. **Continuation Logic** (Plain Scalars):
   ```flex
   <PLAIN_SCALAR_CONT>\n {
       int next_indent = peek_next_indent();
       if (next_indent > scalar_base_indent && !at_flow_end()) {
           append_scalar(" ", 1);  /* fold newline to space */
           continue;
       } else {
           emit_token(SCALAR, scalar_buffer);
           BEGIN(INITIAL);
           handle_dedent(scalar_base_indent);
       }
   }
   ```

5. **Quoted Scalar Handling**:
   ```flex
   \"[^"]*(\n[^"]*)*\" {
       /* Process multiline quoted string, preserve \n as literal */
       char *content = process_quoted(yytext, yyleng);
       return QSCALAR;
   }
   ```

#### Verification Command
```bash
python3 build/tmp/run_all_tests.py  # Should show 72/100
# Specific test checks:
./build/bin/pawel-yaml < build/tmp/test_36f6.yaml && echo "36F6 PASS"
./build/bin/pawel-yaml < build/tmp/test_4cqq.yaml && echo "4CQQ PASS"
```

#### Chaos Engineering Verification

For each scalar state machine:
```bash
# CHAOS: Remove PLAIN_SCALAR_CONT state
# Expected: Tests 36F6, 4ZYM fail (2+ tests)
# Verdict: ACTIVE - this state is necessary

# CHAOS: Remove quoted continuation
# Expected: Tests 4CQQ fails (1+ tests)
# Verdict: ACTIVE - necessary for multiline quotes
```

---

### Phase 2: Grammar Refinement - Nested Structures (72→78/100)

**Objective**: Fix nested sequences, tags, explicit keys  
**Duration**: 1-2 hours  
**Commits**: 4  
**Tests Fixed**: 3ALJ, 3MYT, 35KP, 565N, 57H4 (+6 total)  
**Lines Modified**: ~20 added to `src/yaml.y`  

#### Key Implementation Points

1. **Nested Sequence Rules** (fixes 3ALJ):
   ```bison
   seq_entry:
       BULLET node %dprec 1               /* standard item */
       | BULLET INDENT seq_entries DEDENT %dprec 2  /* nested sequence */
       | BULLET %dprec 3                  /* null item */
       ;
   ```

2. **Explicit Key Syntax** (fixes 35KP):
   ```bison
   map_entry:
       QUESTION node COLON node %dprec 1  /* explicit key */
       | node COLON node %dprec 2         /* implicit key */
       | COLON node %dprec 3              /* mapping start */
       ;
   ```

3. **Tag Placement Rules** (fixes 565N):
   ```bison
   node:
       TAG node_body %dprec 1             /* tag before body */
       | node_body TAG %dprec 2           /* tag after (usually error) */
       | node_props[p] node_body %dprec 3 /* props first */
       ;
   ```

4. **Conflict Resolution**:
   ```bison
   %left COLON COMMA RBRACE RBRACKET      /* reduce over shift for flow end */
   %precedence PLAIN_SCALAR QUOTED_SCALAR /* scalars over keys */
   ```

5. **Adjust %expect Directives**:
   ```bison
   %expect 50        /* was 45 (may need adjustment) */
   %expect-rr 35     /* was 34 */
   ```

#### Verification Command
```bash
python3 build/tmp/run_all_tests.py  # Should show 78/100
# Specific checks:
./build/bin/pawel-yaml < build/tmp/test_3alj.yaml && echo "3ALJ PASS"
./build/bin/pawel-yaml < build/tmp/test_35kp.yaml && echo "35KP PASS"
```

#### Chaos Engineering Verification

```bash
# CHAOS: Remove nested sequence rule
# Expected: Test 3ALJ fails
# Verdict: ACTIVE - necessary for block sequences in sequences

# CHAOS: Remove explicit key rule (QUESTION)
# Expected: Tests with ? fail (~3)
# Verdict: ACTIVE - necessary for complex key syntax
```

---

### Phase 3: Event Stream Clarity (78→82/100)

**Objective**: Standardize event emission, fix INDENT/DEDENT pairing  
**Duration**: 1 hour  
**Commits**: 2  
**Tests Fixed**: 4RWC, 5DVL, 5FJC (+4 total)  
**Lines Modified**: ~15 modified across `src/yaml.y` & `src/yaml.l`  

#### Key Implementation Points

1. **Standardize Scalar Event Emission**:
   ```c
   /* Before: inconsistent quote_style across EMIT calls */
   EMIT("S:%s\n", scalar_value);
   
   /* After: explicit context tracking */
   typedef enum { PLAIN=':', SINGLE='\'', DOUBLE='"', LITERAL='|', FOLDED='>' } QuoteStyle;
   add_scalar_event_v2(value, style, flow_context);
   ```

2. **Fix INDENT/DEDENT Pairing**:
   ```c
   /* Ensure INDENT always paired with DEDENT */
   /* Track nesting depth, validate in grammar */
   if (indent_stack_empty() && DEDENT_seen) {
       ERROR("Unmatched DEDENT");
   }
   ```

3. **Add Event Validation Assertions**:
   ```bison
   %{
   #define ASSERT_EVENT(cond, msg) if (!(cond)) fprintf(stderr, "Event Error: %s\n", msg);
   %}
   
   document:
       doc_start document_body {
           ASSERT_EVENT(event_count > 0, "Document must have content");
       }
   ```

4. **Standardize Node Event Emission**:
   ```c
   /* All scalar events include indentation context */
   void add_scalar_event_v2(const char *value, QuoteStyle style, int in_flow) {
       YAMLEvent *evt = malloc(sizeof(YAMLEvent));
       evt->value = strdup(value);
       evt->quote_style = style;
       evt->in_flow = in_flow;
       /* ... */
   }
   ```

#### Verification Command
```bash
python3 build/tmp/run_all_tests.py  # Should show 82/100
./build/bin/pawel-yaml < build/tmp/test_4rwc.yaml 2>&1 | head -5
```

#### Chaos Engineering Verification

```bash
# CHAOS: Remove quote_style tracking
# Expected: Event validation fails for several tests
# Verdict: ACTIVE - necessary for RML validator

# CHAOS: Remove INDENT/DEDENT pairing check
# Expected: Malformed event streams not caught
# Verdict: ACTIVE - necessary for correctness
```

---

### Phase 4: Validator Robustness (82→92/100)

**Objective**: Event sequence validation with constructive error messages  
**Duration**: 1-2 hours  
**Commits**: 2  
**Tests Fixed**: Remaining 6-10 edge cases (+10 total)  
**Lines Modified**: ~70 added to `src/rml_validator.c`  

#### Key Implementation Points

1. **Event Sequence State Machine**:
   ```c
   typedef enum {
       STATE_START,      // expecting +STR
       STATE_IN_DOC,     // in document (after +DOC)
       STATE_IN_MAP,     // in mapping
       STATE_IN_SEQ,     // in sequence
       STATE_IN_SCALAR,  // reading scalar
       STATE_ERROR
   } EventState;
   
   EventState validate_event_sequence(YAMLEvent *events, int count) {
       EventState state = STATE_START;
       int nesting_depth = 0;
       
       for (int i = 0; i < count; i++) {
           YAMLEvent *evt = &events[i];
           
           switch(state) {
               case STATE_START:
                   if (evt->type != EVENT_STREAM_START) {
                       return error("Expected +STR, got %s", event_name(evt));
                   }
                   state = STATE_IN_DOC;
                   break;
               /* ... */
           }
       }
       return STATE_END;
   }
   ```

2. **Constructive Error Messages**:
   ```c
   /* Before: "Validation error: Stream must start with +STR" */
   
   /* After: */
   ValidationError make_error(const char *expected, YAMLEvent *got) {
       ValidationError err;
       snprintf(err.message, 256,
           "Validation error: Expected %s, got %s at position %d\n"
           "Context: %s\n"
           "Hint: Did you forget a -%s marker?",
           expected, event_name(got), got->position,
           get_event_context(got), suggest_fix(got));
       return err;
   }
   ```

3. **Nesting Depth Tracking**:
   ```c
   int nesting_depth = 0;
   
   switch(event_type) {
       case EVENT_MAPPING_START:
       case EVENT_SEQUENCE_START:
           nesting_depth++;
           break;
       case EVENT_MAPPING_END:
       case EVENT_SEQUENCE_END:
           nesting_depth--;
           if (nesting_depth < 0) {
               return error("Unmatched closing marker");
           }
           break;
   }
   ```

4. **Helpful Error Hints**:
   ```c
   const char *suggest_fix(YAMLEvent *evt) {
       switch(evt->type) {
           case EVENT_SCALAR:
               if (strlen(evt->value) > 80)
                   return "Try using | for multiline scalars";
               break;
           case EVENT_MAPPING_END:
               if (nesting_depth < 0)
                   return "Did you forget a : after a key?";
               break;
       }
       return "";
   }
   ```

#### Verification Command
```bash
python3 build/tmp/run_all_tests.py  # Should show 92/100
# Test edge cases:
./build/bin/pawel-yaml < invalid_yaml.yaml 2>&1  # Should show helpful error
```

#### Chaos Engineering Verification

```bash
# CHAOS: Remove event state machine
# Expected: 6-10 tests fail (validation becomes lenient)
# Verdict: CRITICAL - this is the safety mechanism

# CHAOS: Remove error hints
# Expected: No test impact (hints don't affect parsing)
# Verdict: OPTIONAL - but improves UX
```

---

## Execution Strategy

**See also**: [AGENTIC_TDD.prompt.md](.agent/PLAYBOOK/AGENTIC_TDD.prompt.md) for detailed TDD methodology

### Pre-Flight Setup

```bash
# 1. Verify baseline
cd /home/widip/titi-org/pawel-yaml
git checkout 71ca378  # or main branch at that commit
python3 build/tmp/run_all_tests.py  # Should show 68/100

# 2. Review documentation
cat .agent/YAML_PARSER_ARCHITECTURE_REDESIGN.md | head -100

# 3. Create feature branch
git checkout -b feat/architecture-v2
```

### Per-Phase Execution

#### Phase 1: Lexer (Multiline Scalars)

```bash
# RED: Confirm multiline scalar tests fail
./build/bin/pawel-yaml < build/tmp/test_36f6.yaml 2>&1 | grep -i "error"
# → Should error with "unexpected invalid token"

# GREEN: Implement scalar states
# (Follow Phase 1 Implementation Points above)
# Make changes to src/yaml.l (~60 lines)

# Rebuild & test
make clean && make 2>&1 | grep -i error  # Should be empty
python3 build/tmp/run_all_tests.py  # Should show 72/100

# REFACTOR: Review changes for clarity
git diff src/yaml.l | head -50  # Check code quality

# VERIFY: Full test suite
python3 build/tmp/run_all_tests.py  # Confirm 72/100, no regressions

# COMMIT: 5 atomic commits
git add -A && git commit -m "feat(lexer): add PLAIN_SCALAR_CONT state (Cycle 6a)"
# (4 more commits for other states)
```

#### Phase 2: Grammar (Nested Structures)

```bash
# RED: Confirm nested sequence test fails
./build/bin/pawel-yaml < build/tmp/test_3alj.yaml 2>&1

# GREEN: Enhance seq_entry rule
# (Follow Phase 2 Implementation Points)
# Make changes to src/yaml.y (~20 lines)

# Rebuild
make clean && make

# VERIFY
python3 build/tmp/run_all_tests.py  # Should show 78/100

# COMMIT: 4 commits
git add -A && git commit -m "feat(parser): nested sequences with INDENT (Cycle 7a)"
# (3 more commits for other rules)
```

#### Phase 3: Events (Standardization)

```bash
# GREEN: Standardize event emission
# Changes to src/yaml.y (~10 lines)

# VERIFY
python3 build/tmp/run_all_tests.py  # Should show 82/100

# COMMIT: 2 commits
git add -A && git commit -m "refactor(events): standardize scalar emission (Cycle 11a)"
```

#### Phase 4: Validator (Robustness)

```bash
# GREEN: Implement event state machine
# Changes to src/rml_validator.c (~70 lines)

# VERIFY
python3 build/tmp/run_all_tests.py  # Should show 92/100

# COMMIT: 2 commits
git add -A && git commit -m "feat(validator): event sequence state machine (Cycle 13a)"
```

---

## Future-Aware Refactoring Protocol

Apply this methodology at each phase boundary (1.5, 2.5, 3.5, 4.5) to look ahead and avoid architectural rework.

**See also**: [FUTURE_AWARE_REFACTORING.prompt.md](.agent/PLAYBOOK/FUTURE_AWARE_REFACTORING.prompt.md) for complete interactive rebase strategy

### INSPECT-ALIGN-VERIFY-CONTINUE Pattern

#### Step 1: INSPECT (The Future)

Look at the final implementation to understand the destination:

```bash
# View multiline scalar implementation in final Phase 1 commit
git log --oneline | grep "multiline\|scalar"
git show <final_scalar_commit>:src/yaml.l | grep -A 30 "PLAIN_SCALAR_CONT"

# Understand the pattern:
# - How are continuation lines detected?
# - What does the state machine look like?
# - How is indentation tracked?
```

#### Step 2: ALIGN (The Present)

Adopt the complete architecture immediately—don't try partial/incremental approaches:

```bash
# When resolving conflicts during rebase:
git mergetool

# Strategy: Choose the version that matches the final architecture
# NOT the version that's "minimally different" from current

# Example:
# ❌ Don't: Add just PLAIN_SCALAR_CONT (partial)
# ✅ Do: Add full state machine with lookahead (complete)
```

#### Step 3: VERIFY (The Harness)

Ensure the intermediate commit is functional:

```bash
# Rebuild
make clean && make 2>&1 | grep -i "error"  # Should be empty

# Test specific cases
./build/bin/pawel-yaml < build/tmp/test_36f6.yaml && echo "36F6 PASS"

# Run full suite
python3 build/tmp/run_all_tests.py  # Should show expected pass rate

# No regressions allowed
```

#### Step 4: CONTINUE

Move to the next commit:

```bash
git add -A
git rebase --continue
```

### Checkpoint Locations

| Checkpoint | Phase | Look-Ahead Target | Key Question |
|-----------|-------|-------------------|--------------|
| **1.5** | Mid Phase 1 | Final multiline scalar impl | "How do I handle newlines in plain scalars?" |
| **2.5** | Mid Phase 2 | Final grammar rules | "How do nested sequences work?" |
| **3.5** | Mid Phase 3 | Event standardization | "What does a well-formed event stream look like?" |
| **4.5** | Mid Phase 4 | Event state machine | "What are valid event transitions?" |

---

## Chaos Engineering Verification

**Chaos Engineering** verifies that every change impacts tests—prevents dead code and ensures necessity.

**See also**: [CHAOS_ENGINEERING.prompt.md](.agent/PLAYBOOK/CHAOS_ENGINEERING.prompt.md) for full verification methodology and test patterns

### Methodology

For each implementation, perform targeted removal tests:

```bash
# 1. Identify code artifact (rule, state, function)
# 2. Remove it (comment out, conditional compile, etc.)
# 3. Rebuild and test sample
# 4. Measure impact

if tests_fail > 0:
    print("VERDICT: ACTIVE - code is necessary")
else:
    print("VERDICT: DEAD - code can be removed")
```

### Application to This Redesign

#### Phase 1 Chaos Tests

```bash
# Test: PLAIN_SCALAR_CONT state
cp src/yaml.l src/yaml.l.bak
# Remove: %x PLAIN_SCALAR_CONT
make clean && make
python3 build/tmp/run_all_tests.py

# Expected: Tests 36F6, 4ZYM fail (≥2 tests fail)
# Verdict: ACTIVE ✓
```

#### Phase 2 Chaos Tests

```bash
# Test: Nested sequence rule
cp src/yaml.y src/yaml.y.bak
# Remove: | BULLET INDENT seq_entries DEDENT
make clean && make
python3 build/tmp/run_all_tests.py

# Expected: Test 3ALJ fails
# Verdict: ACTIVE ✓
```

#### Phase 3 Chaos Tests

```bash
# Test: Event standardization
cp src/yaml.y src/yaml.y.bak
# Remove: add_scalar_event_v2() call
make clean && make
python3 build/tmp/run_all_tests.py

# Expected: Several tests fail (event validation catches errors)
# Verdict: ACTIVE ✓
```

#### Phase 4 Chaos Tests

```bash
# Test: Event state machine
cp src/rml_validator.c src/rml_validator.c.bak
# Remove: EventState enum and state machine
make clean && make
python3 build/tmp/run_all_tests.py

# Expected: 6-10 tests fail (validation becomes lenient)
# Verdict: CRITICAL ✓
```

### Chaos Results Interpretation

| Outcome | Action |
|---------|--------|
| **Code removed → tests fail** | Code is ACTIVE, necessary |
| **Code removed → tests pass** | Code is DEAD, mark for removal |
| **Code removed → specific tests fail** | Code enables those tests, document dependency |

---

## Implementation Checklist

### Pre-Redesign
- [ ] Read this entire document (sections 1-4)
- [ ] Review current failing tests: `python3 build/tmp/run_all_tests.py`
- [ ] Verify baseline: 68/100 passing
- [ ] Create feature branch: `git checkout -b feat/architecture-v2`
- [ ] Check out relevant PLAYBOOK files (FUTURE_AWARE_REFACTORING, AGENTIC_TDD)

### Phase 1: Lexer Redesign (68→72/100)
- [ ] Implement scalar states
  - [ ] Add `%x PLAIN_SCALAR_CONT`, `%x QUOTED_SCALAR_CONT`, `%x BLOCK_LITERAL_CONT`
  - [ ] Test plain scalars: `./build/bin/pawel-yaml < build/tmp/test_36f6.yaml`
  - [ ] Test quoted scalars: `./build/bin/pawel-yaml < build/tmp/test_4cqq.yaml`
  - [ ] Test block scalars: `./build/bin/pawel-yaml < build/tmp/test_5akw.yaml`
- [ ] Add indentation context stack
  - [ ] Define `IndentContext` struct
  - [ ] Implement `indent_stack[100]`, `indent_sp`
  - [ ] Track `is_flow` flag
- [ ] Implement continuation logic
  - [ ] `peek_next_indent()` function
  - [ ] Newline folding for plain scalars
  - [ ] Unfold for literal scalars
- [ ] Verify: `python3 build/tmp/run_all_tests.py` → **72/100**
- [ ] Chaos test: Remove PLAIN_SCALAR_CONT, verify ≥2 tests fail
- [ ] Commit 5 atomic changes with clear messages (1a, 1b, 1c, 1d, 1e)

### Phase 2: Grammar Refinement (72→78/100)
- [ ] Enhance seq_entry rules
  - [ ] Add `BULLET INDENT seq_entries DEDENT` for nested sequences
  - [ ] Test 3ALJ: `./build/bin/pawel-yaml < build/tmp/test_3alj.yaml`
- [ ] Add explicit key syntax
  - [ ] Add `QUESTION node COLON node` rule
  - [ ] Test 35KP complex keys
- [ ] Refine tag placement
  - [ ] Add `TAG node_body` rule for 565N
  - [ ] Add `%precedence` declarations
- [ ] Adjust conflict counts
  - [ ] Measure %expect (may increase from 45 to 50)
  - [ ] Document any new conflicts
- [ ] Verify: `python3 build/tmp/run_all_tests.py` → **78/100**
- [ ] Chaos test: Remove nested seq rule, verify 3ALJ fails
- [ ] Commit 4 atomic changes (2a, 2b, 2c, 2d)

### Phase 3: Event Stream Clarity (78→82/100)
- [ ] Standardize scalar events
  - [ ] Define `QuoteStyle` enum
  - [ ] Update all `add_scalar_event()` calls
- [ ] Fix INDENT/DEDENT pairing
  - [ ] Add assertions in grammar
  - [ ] Track nesting depth
- [ ] Add event validation
  - [ ] Check all events well-formed
  - [ ] Test 4RWC: `./build/bin/pawel-yaml < build/tmp/test_4rwc.yaml`
- [ ] Verify: `python3 build/tmp/run_all_tests.py` → **82/100**
- [ ] Chaos test: Remove quote_style tracking, verify tests fail
- [ ] Commit 2 atomic changes (3a, 3b)

### Phase 4: Validator Robustness (82→92/100)
- [ ] Implement event state machine
  - [ ] Define `EventState` enum
  - [ ] State transitions for all event types
  - [ ] Nesting depth tracking
- [ ] Add detailed error messages
  - [ ] "Expected X, got Y" format
  - [ ] Context information
- [ ] Add helpful hints
  - [ ] Suggest fixes for common mistakes
  - [ ] Example: "Try using | for multiline"
- [ ] Test error recovery
  - [ ] Invalid YAML shows helpful message
- [ ] Verify: `python3 build/tmp/run_all_tests.py` → **92/100**
- [ ] Chaos test: Remove state machine, verify 6-10 tests fail
- [ ] Commit 2 atomic changes (4a, 4b)

### Post-Redesign
- [ ] All tests passing: 92/100 ✅
- [ ] No regressions from 68/100 baseline ✅
- [ ] Clean build: `make 2>&1 | grep -i error` → (empty)
- [ ] Merge feature branch to main: `git checkout main && git merge feat/architecture-v2`
- [ ] Update PROGRESS.md with final statistics
- [ ] Tag release: `git tag -a v0.2.0 -m "Architecture Redesign Complete"`
- [ ] Document lessons learned in commit message

---

## Risk Mitigation & Fallback

### If Regression Occurs

**Scenario**: Phase 2 causes test to drop from 72 to 71

**Recovery**:
1. Note which test regressed
2. Check git diff to find problematic change
3. Revert the specific commit or fix the rule
4. Re-test: `python3 build/tmp/run_all_tests.py`
5. Continue with fixed commit

**Prevention**: Always verify full suite after each commit

### If Grammar Conflicts Increase Dramatically

**Scenario**: %expect rises from 45 to 75+ (uncontrolled)

**Recovery**:
1. Check Bison output: `make 2>&1 | grep "shift/reduce\|reduce/reduce"`
2. Review most recent commits for conflicting rules
3. Add explicit `%precedence` declarations
4. Re-measure: `make 2>&1 | grep "conflict"`
5. Cap at 60 max (%expect ≤ 60)

**Prevention**: Measure before/after each grammar change

### If Lexer State Machine Becomes Too Complex

**Scenario**: Need 10+ states instead of intended 6

**Recovery**:
1. Use state variables instead of explicit states
2. Example: Instead of `%x QUOTED_SCALAR_CONT`, use `in_quoted_scalar` flag
3. Consolidate similar states with conditional logic
4. Limit states to 7 maximum

**Prevention**: Design states upfront; review complexity per commit

### If Timeline Extends

**Scenario**: Phase 1 takes 3 hours instead of 2

**Recovery**:
1. Phase 1 (lexer) can be paused and resumed later
2. Phase 2-4 are sequential but can be split into smaller commits
3. Can merge Phase 3-4 if time-constrained (82→92 in one phase)
4. Acceptable to stop at Phase 3 (82/100) if deadline hit

**Prevention**: Time-box each phase; adjust scope if needed

### Fallback Points

| Phase | Fallback If Blocked | Minimum Acceptable |
|-------|-------------------|-------------------|
| Phase 1 | Can't implement scalars | Skip to Phase 2 (stay at 68/100) |
| Phase 2 | Can't parse nested seqs | Skip to Phase 3 (stay at 72/100) |
| Phase 3 | Event standardization fails | Skip to Phase 4 (stay at 78/100) |
| Phase 4 | Validator too complex | Accept 82/100 as final (vs 92/100 target) |

---

## Success Criteria

### Hard Requirements (Non-Negotiable)

✅ **92/100 tests passing** (minimum 90/100)  
✅ **Zero regressions** from 68/100 baseline  
✅ **Clean build** — `make 2>&1 | grep -i error` → (empty)  
✅ **Atomic commits** — ~13 commits, each fixing specific issue  
✅ **Well-documented** — Commit messages reference test IDs  

### Soft Requirements (Preferred)

✅ **Lexer complexity** ≤ 7 explicit states  
✅ **Grammar complexity** — %expect ≤ 60 (was 45)  
✅ **Code quality** — All chaos tests pass (no dead code)  
✅ **Architecture alignment** — Events match RML monoidal structure  

### Metrics

| Metric | Target | Current |
|--------|--------|---------|
| Test Pass Rate | 92/100 | 68/100 |
| Regressions | 0 | 0 ✓ |
| Commits | 13±2 | 0 |
| Lines Added | ~165 | 0 |
| Lines Removed | 0 | 0 |
| Build Time | <5s | ~3s ✓ |
| Test Suite Time | <2s | ~2s ✓ |

### Timeline

| Phase | Duration | Estimated |
|-------|----------|-----------|
| Phase 1 (Lexer) | 1-2 hrs | 5 commits |
| Phase 2 (Grammar) | 1-2 hrs | 4 commits |
| Phase 3 (Events) | 1 hr | 2 commits |
| Phase 4 (Validator) | 1-2 hrs | 2 commits |
| **Total** | **5-7 hrs** | **~13 commits** |

---

## Next Steps

1. ✅ Read this document thoroughly
2. ✅ Review PLAYBOOK files:
   - [AGENTIC_TDD.prompt.md](.agent/PLAYBOOK/AGENTIC_TDD.prompt.md) — TDD protocol for each cycle
   - [FUTURE_AWARE_REFACTORING.prompt.md](.agent/PLAYBOOK/FUTURE_AWARE_REFACTORING.prompt.md) — Interactive rebase strategy
   - [CHAOS_ENGINEERING.prompt.md](.agent/PLAYBOOK/CHAOS_ENGINEERING.prompt.md) — Code verification playbook
3. ⏭️ Create feature branch: `git checkout -b feat/architecture-v2`
4. ⏭️ Begin Phase 1 implementation (lexer redesign)
5. ⏭️ Apply Future-Aware Conflict Resolution at each checkpoint
6. ⏭️ Use Chaos Engineering to verify each change
7. ⏭️ Run full test suite after each phase
8. ⏭️ Merge when all phases complete (92/100 passing)

---

## References

### Architecture Documents
- **This Document**: YAML_PARSER_ARCHITECTURE_REDESIGN.md — Unified blueprint (all-in-one)
- **Related Analysis**: 
  - [ARCHITECTURAL_BOUNDARY.md](.agent/ARCHITECTURAL_BOUNDARY.md) — Design boundary definitions
  - [DESIGN_THEORY.md](.agent/DESIGN_THEORY.md) — Theoretical foundations

### Methodology Playbooks
- [AGENTIC_TDD.prompt.md](.agent/PLAYBOOK/AGENTIC_TDD.prompt.md) — RED-GREEN-REFACTOR-VERIFY-COMMIT protocol
- [FUTURE_AWARE_REFACTORING.prompt.md](.agent/PLAYBOOK/FUTURE_AWARE_REFACTORING.prompt.md) — INSPECT-ALIGN-VERIFY-CONTINUE strategy
- [CHAOS_ENGINEERING.prompt.md](.agent/PLAYBOOK/CHAOS_ENGINEERING.prompt.md) — Code verification and necessity testing
- [GLOSSARY.prompt.md](.agent/PLAYBOOK/GLOSSARY.prompt.md) — Terminology reference

### Progress Tracking
- [CYCLE_PROGRESS.md](.agent/CYCLE_PROGRESS.md) — Session history and completed cycles
- [SESSION_REPORT.md](.agent/SESSION_REPORT.md) — Latest status summary
- [DEFINITION_OF_DONE.md](.agent/DEFINITION_OF_DONE.md) — Phase acceptance criteria

### Current State
- **Baseline**: Commit `71ca378` (68/100 tests)
- **Test Suite**: `build/lib/yaml-test-suite/` (351 tests total)
- **Build System**: `Makefile` (build targets)
- **Progress**: [CYCLE_PROGRESS.md](.agent/CYCLE_PROGRESS.md) (session history)

---

## Document Information

**Title**: YAML Parser Architecture Redesign v2  
**Status**: Ready for Execution  
**Version**: 1.0  
**Created**: 2026-02-04  
**Baseline**: 68/100 test pass rate  
**Target**: 92/100 test pass rate  
**Methodology**: Agentic TDD + Future-Aware Refactoring + Chaos Engineering  

**This unified document combines**:
- Architecture blueprint (402 lines)
- Quick start guide (114 lines)
- Integration roadmap (321 lines)
- Chaos engineering methodology (complete playbook)

**Total**: 1000+ lines of comprehensive, executable specification.

All references to separate documents are historical; this is now the single source of truth.

---

**Ready for Autonomous Execution** ✅
