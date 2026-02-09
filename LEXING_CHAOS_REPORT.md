# Lexing Chaos Report
## Date: 2026-02-07

## Scope
- Chaos target A: quoted map-key lexer rules in `src/scanning.l`
  - `QMAP_KEY`
  - `SMAP_KEY`
- Chaos target B: alias-as-key lexer shortcut in `src/scanning.l`
  - `*alias:` path currently coerced to `MAP_KEY`

## Repro Commands
```bash
./lexing_chaos.sh
./alias_key_chaos.sh
./flow_colon_chaos.sh
./tag_flow_chaos.sh
```

## A) Quoted Key Chaos Results
| Variant | `"key": "value"` | `'key': 'value'` | `key: value` | Suite Pass | Suite Fail | Suite Rate |
|:--|:--:|:--:|:--:|--:|--:|--:|
| baseline | PASS | PASS | PASS | 109 | 242 | 31.05% |
| drop_qmap | FAIL | PASS | PASS | 108 | 243 | 30.77% |
| drop_smap | PASS | FAIL | PASS | 106 | 245 | 30.20% |
| drop_both | FAIL | FAIL | PASS | 106 | 245 | 30.20% |

### Finding
- `QMAP_KEY` and `SMAP_KEY` are both active and beneficial in the current grammar.
- Removing either one reduces full-suite pass count and breaks its corresponding probe.

## B) Alias-Key Shortcut Chaos Results
| Variant | `*a : b` | `k: *a` | `k: v` | Suite Pass | Suite Fail | Suite Rate |
|:--|:--:|:--:|:--:|--:|--:|--:|
| baseline | PASS | FAIL | PASS | 109 | 242 | 31.05% |
| drop_alias_key_shortcut | FAIL | FAIL | PASS | 109 | 242 | 31.05% |

### Finding
- The alias-key shortcut currently affects probe behavior (`*a : b`), but has no net suite impact.
- Keeping it preserves compatibility for alias-key probes, but it still collapses alias-key semantics into scalar key semantics.

## Conclusion
- Keep quoted key rules (`QMAP_KEY`, `SMAP_KEY`): they are not redundant in current code.
- Alias-key shortcut is a semantic tradeoff:
  - **Coverage-neutral** on current suite totals.
  - **Fidelity-risky** because alias key identity is not preserved as alias event.

## C) Flow Colon Chaos Results
| Variant | `4ABK` | `5MUD` | `4FJ6` | `k: v` | Suite Pass | Suite Fail | Suite Rate |
|:--|:--:|:--:|:--:|:--:|--:|--:|--:|
| baseline | PASS | PASS | PASS | PASS | 109 | 242 | 31.05% |
| drop_colon_empty | PASS | PASS | PASS | PASS | 109 | 242 | 31.05% |
| drop_flow_key_fallback | PASS | PASS | FAIL | PASS | 104 | 247 | 29.63% |
| drop_both | PASS | PASS | FAIL | PASS | 104 | 247 | 29.63% |

### Finding
- `COLON_EMPTY` rule is currently coverage-neutral in this branch.
- Flow-key fallback branch in `MAP_KEY` lexing is critical:
  - Removing it breaks `4FJ6`.
  - Full suite drops by 5 passes.

## D) Tagged Flow-Key Chaos Results
| Variant | `!foo` key | `!!str` key | `!foo` value | plain flow | Suite Pass | Suite Fail | Suite Rate |
|:--|:--:|:--:|:--:|:--:|--:|--:|--:|
| baseline | PASS | FAIL | PASS | PASS | 109 | 242 | 31.05% |
| drop_compound_tag_rules | FAIL | FAIL | FAIL | PASS | 108 | 243 | 30.77% |
| drop_compound_plus_bare | FAIL | FAIL | FAIL | PASS | 108 | 243 | 30.77% |

### Finding
- Compound tag token rules (`!!...`, `!foo`, `!h!suffix`) are active and beneficial.
- Removing them drops full-suite pass by 1 and breaks both tagged-key and tagged-value probes.
- Removing bare `!` on top does not change measured suite totals in current branch.

## Next Recommended Chaos Targets
1. Anchor + alias key interactions (`26DV`, `6BFJ`, `6KGN`) with token-level probes.
2. Consider removing `COLON_EMPTY` for lexer simplification (no current coverage gain), then re-run full suite.
3. Investigate why `!!str` flow-key form still fails in baseline despite compound tag rules.
