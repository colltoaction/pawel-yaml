# Phase 11 Planning: Feature Implementation via Chaos-Guided TDD
**Start Date**: February 5, 2026 (after Phase 10 completion)  
**Baseline Pass Rate**: 23.4% (82/351 tests)  
**Target Pass Rate**: 50%+ (175+ tests)  
**Estimated Duration**: 2-3 sprints  

---

## Phase 11 Strategy

Build on Phase 10's chaos engineering baseline to **systematically implement missing features** using Test-Driven Development (TDD).

### Key Principle
Use chaos engineering insights to prioritize features that:
1. Have **verified grammar rules** (from chaos baseline)
2. Affect **large test count** (high impact)
3. Are **isolated enough** to implement incrementally
4. Can be **chaos-validated** after implementation

---

## Feature Roadmap (Priority Order)

### TIER 1: Critical (Most Impact)

#### Feature 1.1: Block Scalars (Literal/Folded Strings)
- **Grammar Status**: ✅ VERIFIED ACTIVE (BSCALAR token)
- **Tests Affected**: 25+ tests
- **Current Status**: Grammar parsing works, but IR generation incomplete
- **Missing**: Proper newline handling in multiline strings
- **Implementation Effort**: Medium
- **TDD Cycle**: 2-3 hours

**Scope**:
```yaml
# Literal scalar (preserve newlines)
description: |
  This is a
  multiline string
  
# Folded scalar (wrap lines)
summary: >
  This will be
  folded into
  a single line
```

**Known Failing Tests**: Check tests with `.literal` or `.folded` metadata

#### Feature 1.2: Type Tags (YAML Type System)
- **Grammar Status**: ✅ VERIFIED ACTIVE (TAG token)
- **Tests Affected**: 15+ tests
- **Current Status**: Tokens parsed, but type info not propagated
- **Missing**: Tag application to values
- **Implementation Effort**: Medium
- **TDD Cycle**: 2-3 hours

**Scope**:
```yaml
---
string: !!str 123        # Type: string
integer: !!int "0x1A"    # Type: integer
custom: !org/name value  # Custom tag
```

**Known Failing Tests**: Tests with `!!` prefix or `!tag` syntax

#### Feature 1.3: Anchors & Alias References
- **Grammar Status**: ✅ VERIFIED ACTIVE (ANCHOR, ALIAS tokens)
- **Tests Affected**: 18+ tests
- **Current Status**: Parser recognizes, but references not resolved
- **Missing**: Reference table and alias dereferencing
- **Implementation Effort**: Medium-High
- **TDD Cycle**: 3-4 hours

**Scope**:
```yaml
---
base: &anchor_name
  key: value
  
reference: *anchor_name    # Aliases to base
multiple: *anchor_name     # Can reference multiple times
```

**Known Failing Tests**: Tests with `&` (anchor def) and `*` (alias ref)

---

### TIER 2: High Value (Secondary Impact)

#### Feature 2.1: Flow Context Edge Cases
- **Grammar Status**: ✅ VERIFIED ACTIVE (flow_seq, flow_map rules)
- **Tests Affected**: 30+ tests
- **Current Status**: Basic flow parsing works
- **Missing**: Complex nesting, trailing commas, edge cases
- **Implementation Effort**: High
- **TDD Cycle**: 4-5 hours

**Scope**:
```yaml
# Flow sequences
items: [1, 2, 3, ]         # Trailing comma
nested: [[1, 2], [3, 4]]   # Nested arrays
mixed: [1, "two", {a: 3}]  # Mixed types

# Flow mappings
config: {key: value, nested: {a: 1}}
pairs: {a: 1, b: 2, c: 3}
```

#### Feature 2.2: Complex Key Handling
- **Grammar Status**: ✅ VERIFIED ACTIVE (explicit key syntax with QUESTION)
- **Tests Affected**: 20+ tests
- **Current Status**: Simple keys work
- **Missing**: Complex key expressions
- **Implementation Effort**: High
- **TDD Cycle**: 4-5 hours

**Scope**:
```yaml
# Complex keys (require explicit syntax)
? key expression as key
: value

? [list, as, key]
: value

? {map: as, key: too}
: value

# Implicit complex keys
{ "quoted key": value }
```

---

### TIER 3: Polish (Lower Priority)

#### Feature 3.1: Document Directives
- **Grammar Status**: ⚠️ PARTIAL (TAG_DIRECTIVE, YAML_DIRECTIVE tokens exist)
- **Tests Affected**: 10+ tests
- **Implementation Effort**: Low-Medium
- **TDD Cycle**: 2-3 hours

**Scope**:
```yaml
%YAML 1.2
%TAG ! tag:example.com,2014:
---
document: content
```

#### Feature 3.2: Comment Handling
- **Grammar Status**: ✅ VERIFIED (lexer recognizes but ignores)
- **Tests Affected**: 5+ tests
- **Implementation Effort**: Low
- **TDD Cycle**: 1-2 hours

**Scope**:
```yaml
# This is a comment
key: value  # Inline comment
```

---

## Implementation Pattern (Per Feature)

### Step 1: RED - Write Failing Test
```bash
# Pick a test that should pass but doesn't
TEST_ID="6BFJ"  # Example test case
TEST_FILE="build/lib/yaml-test-suite/src/${TEST_ID}.yaml"

# Verify it fails
timeout 1 ./build/bin/pawel-yaml < "$TEST_FILE"
# Expected: Exit code 1 (currently fails)
```

### Step 2: Analyze Feature Gap
```bash
# Read the test file
cat "$TEST_FILE"

# Understand what it needs
# (block scalars? tags? aliases?)

# Check which grammar rule applies
grep -n "BSCALAR\|TAG\|ALIAS" src/yaml.y | head -5
```

### Step 3: GREEN - Minimal Implementation
```bash
# Find what's missing:
# Option A: IR generation incomplete
grep -n "case EVT_" src/ir_builder.c | head -10

# Option B: Validation too strict
grep -n "if.*invalid\|if.*unsupported" src/pipeline.c | head -10

# Option C: Semantic action incomplete
grep -n "yylval->" src/yaml.y | head -10
```

### Step 4: Implement & Test
```bash
# Edit relevant file (ir_builder.c, pipeline.c, or yaml.y)
# Rebuild
make clean && make

# Test single case
timeout 1 ./build/bin/pawel-yaml < "$TEST_FILE"

# Run sampling of related tests
python3 << 'EOF'
import subprocess, os
test_dir = "build/lib/yaml-test-suite/src"
related_tests = [
    "6BFJ", "6CA3", "73JZ", "ADD2", ...  # Known block scalar tests
]
for test in related_tests[:5]:
    result = subprocess.run([...], stdin=open(f"{test_dir}/{test}.yaml"))
    print(f"{test}: {'PASS' if result.returncode == 0 else 'FAIL'}")
EOF
```

### Step 5: REFACTOR - Clean Up Code
```bash
# Review implementation for:
# - Dead code paths
# - Redundant checks
# - Improved clarity

# Run tests again to ensure no regressions
make test-full | tail -10
```

### Step 6: CHAOS - Verify No Dead Code
```bash
# Original code was clean (chaos baseline shows it)
# If we added new rules, verify they're used:

# Temporarily remove new code
git diff src/yaml.y | head -20

# Check if removing it breaks new tests
make clean && make
python3 test_50_random.py

# Result should be: New failures appear (proving code necessary)
```

### Step 7: VERIFY - Measure Improvement
```bash
# Run full suite
make test-full | grep "Pass Rate"

# Expected: Pass rate increased
# Example: 23.4% → 25.2% (added 1 feature = ~5-6 tests fixed)
```

### Step 8: COMMIT - Record Progress
```bash
git add -A && git commit -m \
  "feature: Implement block scalar support (BSCALAR token)

Tests fixed: 6BFJ, 6CA3, 73JZ, ... (5 tests)
Pass rate: 23.4% → 24.8%
Effort: 2.5 hours
Method: Chaos-guided TDD per Phase 11 plan

Grammar rule: BSCALAR token (verified active)
Implementation: Extended ir_builder.c for multiline text
Validation: Chaos test confirms no dead code paths"
```

---

## Feature Implementation Order (Recommended)

### Week 1: Foundations
- **Focus**: High-impact individual features
- **Target**: Features 1.1, 1.2
- **Expected Gain**: +8-10% (28-35 more tests)

**Timeline**:
```
Day 1: Feature 1.1 (Block Scalars) - 2-3 hours
Day 2: Feature 1.2 (Type Tags) - 2-3 hours
Day 3: Bug fixes & edge cases - 2 hours
Total: 6-8 hours for +8-10%
```

### Week 2: Complex Features
- **Focus**: More involved features with dependencies
- **Target**: Features 1.3, 2.1
- **Expected Gain**: +10-15% (35-52 more tests)

**Timeline**:
```
Day 1: Feature 1.3 (Anchors/Aliases) - 3-4 hours
Day 2: Feature 2.1 (Flow Context) - 3-4 hours
Day 3: Integration & testing - 2 hours
Total: 8-10 hours for +10-15%
```

### Week 3: Consolidation
- **Focus**: Remaining high-priority features
- **Target**: Feature 2.2, 3.x
- **Expected Gain**: +5-10% (17-35 more tests)

**Timeline**:
```
Day 1: Feature 2.2 (Complex Keys) - 3-4 hours
Day 2: Features 3.1, 3.2 (Directives, Comments) - 2 hours
Day 3: Full suite testing & bug fixes - 2 hours
Total: 7-8 hours for +5-10%
```

**Cumulative Result After Phase 11**: 
- **Expected**: 45-50%+ (158-175+ tests passing)
- **Timeline**: 3 weeks of focused TDD

---

## Tools & Resources Available

### For Each TDD Cycle

**Chaos Analysis Tool** (from Phase 10):
```bash
# Verify grammar rule is active
python3 << 'EOF'
import subprocess, os, random
test_dir = "build/lib/yaml-test-suite/src"
tests = [f.replace('.yaml', '') for f in os.listdir(test_dir)]
sample = random.sample(tests, 50)
baseline = sum(1 for t in sample if subprocess.run(
    ["timeout", "1", "./build/bin/pawel-yaml"],
    stdin=open(f"{test_dir}/{t}.yaml"), capture_output=True).returncode == 0)
print(f"Baseline: {baseline}/50 pass")
EOF
```

**Grep Pattern Finder**:
```bash
# Find tests using specific feature
grep -l "literal\|folded" build/lib/yaml-test-suite/*.meta | \
  xargs -I {} basename {} .meta | head -10
```

**Quick Rebuild**:
```bash
make clean && make -j4  # Parallel build if available
```

### Documentation References
- `.agent/CHAOS_ENGINEERING_BASELINE.md` - Which rules are active
- `.agent/CHAOS_ENGINEERING_PROCEDURES.md` - How to test them
- `src/GRAMMAR.md` - Grammar documentation
- `PROGRESS.md` - Historical context

---

## Success Criteria

### For Each Feature
- ✅ TDD RED phase: At least 3 failing tests identified
- ✅ TDD GREEN phase: All 3+ tests now pass
- ✅ TDD REFACTOR: Code is clean and maintainable
- ✅ Chaos test: No dead code paths
- ✅ No regressions: All previously-passing tests still pass

### For Phase 11 Overall
- ✅ Pass rate: ≥50% (175+ tests)
- ✅ Completion: All tests complete in <5 seconds total
- ✅ Stability: Zero timeouts, zero crashes
- ✅ Code quality: Consistent error code handling
- ✅ Documentation: Each feature has TDD cycle record

---

## Risk Mitigation

### Common Pitfalls

**Pitfall**: Feature implementation breaks other features
- **Prevention**: Run full test suite after each feature
- **Recovery**: `git revert` last commit and re-approach

**Pitfall**: Feature seems to add dead code
- **Prevention**: Run chaos test immediately after
- **Recovery**: Simplify implementation or document why dead

**Pitfall**: Feature takes longer than estimated
- **Prevention**: Time-box each TDD cycle
- **Recovery**: Break feature into smaller sub-features

### Checkpoint Plan
- **After Feature 1.1**: Check pass rate (should be >24%)
- **After Feature 1.2**: Check pass rate (should be >25%)
- **After Feature 1.3**: Check pass rate (should be >27%)
- **Midpoint review**: After 10-12 hours of work, evaluate pace

---

## Expected Outcomes

### By End of Week 1
```
Pass Rate: 23.4% → ~32%
Tests Fixed: +39 tests
Key Features: Block scalars, basic type tags
Status: On track
```

### By End of Week 2
```
Pass Rate: ~32% → ~42%
Tests Fixed: +48 tests
Key Features: Anchors, aliases, flow improvements
Status: Approaching 50% target
```

### By End of Week 3 (Phase 11 Complete)
```
Pass Rate: ~42% → 50%+
Tests Fixed: ~69 tests total (82 → 151+)
Key Features: Complex keys, directives, polish
Status: Ready for Phase 12
```

---

## Phase 12 Preview (After Phase 11)

Once Phase 11 reaches 50%+ pass rate:

1. **Phase 12: Consolidation** - Fix remaining edge cases (50% → 70%)
2. **Phase 13: Validation** - Strengthen RML verification (70% → 85%)
3. **Phase 14: Polish** - Optimize and document (85% → 95%+)

Each phase will use the same chaos-guided TDD methodology.

---

## Getting Started (Next Steps)

When Phase 11 is ready to begin:

1. **Pick first test**: `make test-full | grep "^[A-Z0-9]" | head -1` → get failing test ID
2. **Analyze test**: `cat build/lib/yaml-test-suite/src/<ID>.yaml`
3. **Identify missing feature**: Which Token/Rule is not working?
4. **Follow TDD cycle**: RED → GREEN → REFACTOR → CHAOS → VERIFY → COMMIT
5. **Repeat**: Pick next test until 50%+ reached

---

**Status**: READY FOR PHASE 11 START  
**Baseline**: 23.4% (82/351 tests)  
**Target**: 50%+ (175+ tests)  
**Methodology**: Chaos-Guided TDD  
**Duration**: 3 weeks estimated  

**Maintained By**: Agentic TDD System  
**Last Updated**: February 5, 2026
