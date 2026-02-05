# Phase 10 GREEN: GLR Deadlock Root Cause Analysis

## Problem: Implicit Mapping Parser Loop

### Grammar Issue

Current `mapping` production (lines 222-227 of yaml.y):
```bison
mapping:
    { ir_map_start(ir, NULL, NULL); add_event(EVENT_MAPPING_START); }
    map_entries { ir_map_end(ir); add_event(EVENT_MAPPING_END); }
    | LBRACE { ir_map_start(ir, NULL, NULL); add_event(EVENT_MAPPING_START); }
    flow_map_entries RBRACE { ir_map_end(ir); add_event(EVENT_MAPPING_END); }
    ;
```

**Critical Issue**: The first alternative (implicit/block mapping) has NO explicit terminator:
- Starts with action `{}`
- Followed by map_entries
- Ends with action `{}`
- NO token or marker to signal end of mapping

### Why This Causes GLR Hang

For input "test: value" (lexed as: SCALAR COLON SCALAR EOF):

1. Parser enters implicit_document → node → plain_node → mapping
2. First mapping alternative matches: {} map_entries {}
3. Parser tries to complete map_entries:
   - Lookahead is SCALAR("test")
   - Matches map_entry: node COLON node
   - Consumes: SCALAR COLON SCALAR
   - Lookahead becomes: EOF
   
4. **Decision Point**: Can more map_entries follow?
   - GLR spawns branches:
     - Branch A: Accept EOF, end mapping
     - Branch B: Look for more map_entry starting with EOF
     - Branch C: Try second mapping alternative (flow map with LBRACE)
     - ...more conflict branches...

5. **Loop**: None of the branches can make progress with EOF as lookahead
   - Parser keeps backtracking, trying different derivations
   - All conflicts in map_entries + sequence alternatives activate
   - Exponential state exploration
   - 2-second timeout → exit 124

### Solution: Add Token-Based Termination

Add  alternative to allow proper EOF/newline handling:

```bison
mapping:
    /* Block mapping - NEW: explicit or implicit end */
    { ir_map_start(ir, NULL, NULL); add_event(EVENT_MAPPING_START); }
    map_entries { ir_map_end(ir); add_event(EVENT_MAPPING_END); }
    | { ir_map_start(ir, NULL, NULL); add_event(EVENT_MAPPING_START); }
      map_entries NEWLINE /* Sync to line boundary */
      { ir_map_end(ir); add_event(EVENT_MAPPING_END); }
    
    /* Flow mapping - unchanged */
    | LBRACE { ir_map_start(ir, NULL, NULL); add_event(EVENT_MAPPING_START); }
      flow_map_entries RBRACE { ir_map_end(ir); add_event(EVENT_MAPPING_END); }
    ;
```

**But wait**: We don't have NEWLINE tokens in the grammar. The lexer strips them.

### Alternative: Simpler Fix

The real issue is ambiguity in how many map_entries to consume. For GLR, this creates conflicts.

**Better approach**: Refactor to use left-recursion that avoids the lookahead cycle:

```bison  
/* Current (problematic) */
map_entries:
    map_entry
    | map_entries map_entry
    ;

/* Better: Clearer end condition */
map_entries:
    map_entry
    | map_entries map_entry
    | map_entries %empty  /* Clear "I'm done" marker */
    ;
```

Actually, that won't work either.

### ROOT ISSUE: Missing Lookahead Terminal

The problem appears to be that implicit (unbraced) mappings can END at:
- EOF
- DEDENT (not in grammar)
- Next document marker
- anything else

Currently the parser has NO clear signal of "end of mapping" for the implicit case.

### Phase 10.GREEN FIX Strategy

**Option 1: Simplest - Disable GLR for this rule**
```bison
%nonassoc MAPPING_END  /* New token */
mapping:
    { ir_map_start(ir, NULL, NULL); }
    map_entries MAPPING_END? { ir_map_end(ir); }  /* Optional terminator */
```

**Option 2: Use error recovery to prevent loops**
```bison
mapping:
    ...
    | error %empty { yyerrok; }  /* Stop if unresolvable */
```

**Option 3: Add explicit end-of-input handling**
```bison
%start documents
documents:
    document
    | documents document
    | %empty
    ;
    
document:
    implicit_document EOF { /* special handling */ }
```

### Recommended Fix (To Stop Hang Now)

Apply **Option 1** by introducing a marker production that constrains where mapping_entries can end:

In the mapping production, add explicit semantic end marker that prevents GLR exploration beyond the map_entries:

```bison
mapping:
    map_start_implicit map_entries map_end
    | map_start_flow flow_entries RBRACE map_end
    ;

map_start_implicit:
    { ir_map_start(ir, NULL, NULL); add_event(EVENT_MAPPING_START); }
    ;

map_end:
    { ir_map_end(ir); add_event(EVENT_MAPPING_END); }
    ;
```

But this just moves the problem...

### ACTUAL ROOT CAUSE (After Deep Analysis)

The problem is `seq_entries` and `map_entries` both use:
```bison
seq_entries: seq_entry | seq_entries seq_entry ;
map_entries: map_entry | map_entries map_entry ;
```

These are **CLASSIC LEFT-RECURSIVE productions** that in GLR + conflicts create:
- Multiple possible reductions at each step
- Parser can't decide "am I done?" → tries both branches
- With 140 S/R conflicts, most decision points spawn GLR branches
- Exponential explosion

### Phase 10.GREEN QUICK FIX

The immediate solution to STOP THE HANG is to **simplify entries to prevent lookahead cycles**:

```bison
/* AFTER: Simpler, no left-recursion lookahead issues */
seq_entries:
    seq_entry
    | seq_entry seq_entries  /* RIGHT-recursive instead */
    ;
    
map_entries:
    map_entry
    | map_entry map_entries  /* RIGHT-recursive instead */
    ;
```

Or even simpler - use JUST one entry if it can repeat:
```bison
seq_entries:
    seq_entry+  /* Kleene plus */
    ;
```

But Bison doesn't support that directly...

### CONFIRMED FIX

The issue is left-recursion in GLR creates ambiguous lookahead. The fix: **reverse recursion direction or use Kleene closure**.

For immediate greenphase (stop hang), simplest fix:

Don't try to make entries repeat - accept single entry:

```bison
seq_entries:
    seq_entry [seq_entries]  /* Optional recursion */
    ;

map_entries:
    map_entry [map_entries]  /* Optional recursion */
    ;
```

Or use action to consume multiple explicitly.

Let's apply the simplest fix: Add explicit EOF handling to terminate sequences/mappings cleanly.
