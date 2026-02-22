# Task Draft (Fresh Restart): Minimal Chyp Arity Core

https://github.com/akissinger/chyp

## Intent

Implement a **minimal Chyp-style language core** for wire-arity and permutation manipulation.

This task is intentionally narrow.

## Scope (Only)

Implement the following language elements:

- tensor/parallel composition: `*`
- sequential composition: `;`
- identity on 1 wire: `id`
- identity on 0 wires: `id0`
- swap shorthand: `sw` (equivalent to `sw[1,0]`)
- generalized swap/permutation: `sw[x0, x1, ..., xk]`

### Required Semantics

Interpret expressions as typed maps on wire counts.

- Objects: natural numbers `n` (wire count).
- Every primitive above denotes an arity-preserving permutation map `n -> n`.
- For `sw[x0, ..., xk]` on `k+1` wires:
  - output wire `i` receives input wire `xi`.
  - list must be a valid permutation of `0..k`.

## Explicit Focus

Use this behavior as the primary semantic target:

> Combining `id` and `sw` can build any permutation, but generalized `sw[...]` is the practical form. `sw` is shorthand for `sw[1,0]`.

## Minimal Algebraic Rules

1. `id` has arity `1 -> 1` and permutation `[0]`.
2. `id0` has arity `0 -> 0` and permutation `[]`.
3. `sw` has arity `2 -> 2` and permutation `[1,0]`.
4. `sw[p0,...,pk]` has arity `(k+1) -> (k+1)` and permutation `[p0,...,pk]`.
5. Tensor `f * g`:
   - arity adds (`n_f + n_g`),
   - permutation is block concatenation with right block index shift.
6. Sequential `f ; g`:
   - requires matching arity,
   - permutation composes.


## Deliverables

1. Minimal parser/evaluator implementation for this subset.
2. `.chyp` test inputs under `tests/` (recommended: `tests/chyp/`).
3. Expected outputs for each positive test.
4. Negative tests for invalid permutations and arity mismatch.
5. Short semantics note documenting operator precedence and permutation orientation.

## `.chyp` Test Requirements

Provide tests that cover at least:

1. `id`
2. `id0`
3. `sw`
4. `sw[0,2,1,3]`
5. tensor permutation assembly, e.g. `sw[1,2,0] * sw[1,0]`
6. sequential composition identity example, e.g. `sw ; sw`
7. invalid permutation (duplicate or out-of-range index)
8. arity mismatch in `;`

## Acceptance Criteria

1. `sw` is exactly treated as `sw[1,0]`.
2. `sw[...]` validates permutation structure strictly.
3. `*` and `;` semantics are implemented and tested.
4. All positive `.chyp` tests pass with deterministic outputs.
5. All negative `.chyp` tests fail with deterministic diagnostics.

## Notes for Fresh Agent

- Keep implementation minimal and explicit.
- Do not expand to full Chyp.
- Do not mix with YAML parser behavior in this task.
- Preserve small, test-driven increments.
