# Phase 11 Block Scalars: Implementation Analysis

## Current Status: Infrastructure Working, Feature Implementation Identified

### Session Summary
- ✅ Fixed critical IR format and event lexer bugs
- ✅ Validated Stage 1→2 pipeline for plain scalars, lists, documents  
- ✅ Identified block scalar implementation requirements
- 🔄 Block scalar parsing works end-to-end (Stage 1 completes)
- ❌ Block scalar event parsing fails (Stage 2 can't tokenize `|` and `>` in scalar context)

### Technical Analysis

#### What Works Now ✅
- Parser fully support `BSCALAR` token from lexer
- Stage 1 (YAML parsing) successfully parse `- |\n hello` structures
- IR builder correctly generates `=VAL |:content` format
- Plain scalars with all quote styles work through full pipeline

#### What's Blocking Block Scalars ❌

**Problem**: Event parser's scalar rule can't differentiate between:
- Colon in plain scalar format: `=VAL ::hello` 
- Colon in quoted scalar format: `=VAL ":hello` or `=VAL ':hello`
- Colon in block scalar format: `=VAL |:hello` or `=VAL >:hello`

**Root Cause**: When event lexer sees `=VAL |:hello`, it tokenizes as:
1. `=VAL` → E_SCALAR token
2. `|` → E_CHAR token
3. `:` → E_CHAR token (second char!)
4. `hello` → E_IDENTIFIER

But the grammar expects: E_SCALAR E_CHAR [content]

**Evidence**:
```
Input:  "- |\n hello"
Stage 1: ✅ Completes (3 lex calls)
Stage 2: ❌ "YAML Event Parse Error: syntax error, unexpected E_CHAR"
```

### Solutions (Priority Order)

#### Option A: Change Block Scalar IR Format (RECOMMENDED)
Use space-separated format:  `=VAL | hello` (not `:||`-separated)
- Prevents E_CHAR collision with colon in identifier pattern
- Requires changes:
  1. `ir_scalar_block()` in ir_builder.c: change to `"=VAL %c %s\n"`
  2. `yaml_event.l`: update identifier pattern to not consume the first char after space
  3. `yaml_event.y`: adjust scalar grammar to handle space-separated format

#### Option B: Quoted Block Content
Wrap block scalar content in quotes: `=VAL |"hello"`
- Minimal changes needed
- Uses existing quoted string handling

#### Option C: Extend Event Lexer
Add lookahead to event lexer tohandle `block-char : identifier` pattern specially

### Immediate Next Steps (After PR/Commit)

1. **Fix IR format** (Option A):
   - Change `ir_scalar_block()` to use space separator
   - Test with simple block scalar: `= |\nhello`
   - Submit test through full pipeline

2. **Verify with existing passing tests**:
   - 4RWC still passes (flow collections)
   - Run full suite to check for regressions

3. **Add more block scalar tests**:
   - Literal blocks (`|`)
   - Folded blocks (`>`)
   - With modifiers (`|+`, `>-`, etc.)

### Code References

**Files to  modify**:
- `src/ir_builder.c` (line 190, `ir_scalar_block()`)
- `src/yaml_event.l` (identifier pattern, block char handling)
- `src/yaml_event.y` (scalar rule)

**Test cases ready**:
- 4Q9F (folded block - 49 chars)
- 4QFQ (list items with block scalars)
- 2G84 (block modifier syntax)

### Metrics
- **Baseline pass rate**: 23.4% (82/351)
- **Block scalar tests identified**: 25+ tests
- **Expected gain when fixed**: +7-10 tests (~26-28%)

---

**Status**: READY FOR IMPLEMENTATION  
**Recommended Strategy**: Option A (space-separated IR format) -  cleanest solution with minimal grammar changes
**Estimated Effort**: 30-45 minutes (change 2 files, test, verify)

