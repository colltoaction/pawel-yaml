# Agentic TDD Protocol: A Deep Dive

**Reference**: `.agent/ENGINEERING_PLAYBOOK.md`

---

## 1. Philosophy: Constraints as Freedom

The **Agentic TDD Protocol** is not just a testing strategy; it is a behavioral constraint system designed for autonomous coding agents.

In complex domains like YAML parsing (which requires strict adherence to the RML theoretical model), it is easy to get lost in "rabbit holes" of refactoring or speculative design. The TDD Protocol forces a linear, verifiable path:

1.  **Constraint**: You cannot write code without a failing test (RED).
2.  **Constraint**: You cannot focus on elegance until functionality is proven (GREEN).
3.  **Constraint**: You cannot move to the next task until the implementation matches the theory (REFACTOR).

By adhering to these constraints, we ensure that every code change is **tool-verifiable** and **theory-aligned**.

---

## 2. The 5 Phases in Detail

### Phase 1: RED (Failure Establishment)
> *"If it doesn't fail, you don't know what you're fixing."*

-   **Goal**: Establish a baseline of truth.
-   **Action**: Create a designated test case that fails.
-   **Why**: Often, a "bug" is a misunderstanding. By proving the failure with a tool (parser output, return code), we convert a subjective problem into an objective fact.
-   **Agent Behavior**: Do not guess. Run the harness. See the red text.

### Phase 2: GREEN (Minimal Mutation)
> *"Make it work, then make it right."*

-   **Goal**: Confirm understanding of the failure's root cause.
-   **Action**: Write the *simplest possible code* to make the test pass.
-   **The "License to Hack"**: In this phase, hardcoding, if-statements, and "ugly" code are **permitted and encouraged**.
    -   *Example*: If the test expects "foo" and gets "bar", it is acceptable to write `if (input == "foo_input") return "foo";`.
-   **Why**: If the "hack" passes the test, we have proven that *this specific location* in the code controls the output. We have localized the issue.

### Phase 3: REFACTOR (Theoretical Alignment)
> *"The hard part. paying the debt immediately."*

-   **Goal**: Align the "Green" solution with RML (Regular Monoidal Language) theory.
-   **Action**: Replace the hack with a proper Monoidal Morphism or Grammar Rule.
-   **Process**:
    1.  Look at the hack (e.g., `if (tag) ...`).
    2.  Ask: "What is the RML equivalent?" (e.g., `Attribute attached to Scalar`).
    3.  Rewrite the code using `mrl.y` constructs.
-   **Critical Check**: The test MUST stay Green. If alignment breaks the test, your theoretical understanding is wrong, or the theory needs extension.

### Phase 4: VERIFY (Regression Guard)
> *"Don't break the past."*

-   **Goal**: Ensure local fixes don't cause global chaos.
-   **Action**: Run the full relevant test suite (`make test` or `tdd_harness.sh`).
-   **Reality Check**: YAML is highly context-sensitive. Changing a lexer rule for Flow Sets might break Block Indentation. Detecting this *now* is cheap. Detecting it 10 commits later is expensive.

### Phase 5: ATOMIC COMMIT
> *"Save the game."*

-   **Goal**: Create a checkpoint.
-   **Action**: Commit with a message referencing the Test ID.
-   **Format**: `fix(735Y): resolve tag nesting [Agentic TDD]`

---

## 3. Example Scenario: Fixing "Flow Entry Trailing Comma"

**Scenario**: parser fails on `[a, b, ]`.

1.  **RED**:
    -   Create `tests/run/flow_comma.yaml`.
    -   Run harness. Output: `Syntax Error` (Expected `SUCCESS`).
    -   Status: **confirmed**.

2.  **GREEN**:
    -   Edit `mrl.y`.
    -   Existing rule: `flow_seq: '[' list ']'`.
    -   Change to: `flow_seq: '[' list opt_comma ']'`.
    -   Define `opt_comma: /* empty */ | ','`.
    -   Run harness. Status: **PASS**.

3.  **REFACTOR**:
    -   Review `mrl.y`. The grammar is messy. `opt_comma` is not an RML term.
    -   Consult `StringDiagram`. A trailing comma is just a `monoid identity` in the list construction morphism.
    -   Rewrite grammar to use proper left-recursive list structure that allows optional termination.
    -   Run harness. Status: **PASS**.

4.  **VERIFY**:
    -   Run `make test`.
    -   Oops! `[a, b]` (no trailing) now fails because of ambiguity.
    -   Fix grammar precedence.
    -   Run `make test`. All Green.

5.  **COMMIT**:
    -   `git commit -m "fix(flow): allow trailing commas in flow sequences"`

---

**Summary**: The Agentic TDD Protocol is our safety net. It allows us to move fast (Green) without accumulating debt (Refactor).
