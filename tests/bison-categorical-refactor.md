---
references:
  - https://doi.org/10.1016/0001-8708(91)90003-P
  - https://doi.org/10.1137/0205037
  - https://www.cs.utexas.edu/~novak/yaccpaper.htm
  - https://doi.org/10.1016/j.aim.2009.02.016
  - file://etc/mytilus/research/rml.yaml
---
# 🛠️ Refactoring Pattern: C Statements -> Bison Grammar

### Goal:
Replace manual state management and branching (`if`, `else`, loop-driven logic) with declarative productions, ensuring the grammar serves as the authoritative specification of the language.

### Categorical Mapping:
- **Alphabet (`Γ`)**: Map the scanner interface (`%token`) to the base morphisms of the category.
- **Sequential (`A; B`)**: Map statement sequencing to **Categorical Composition** (`B ∘ A`), represented as production sequencing in Bison.
- **Branching (`if/else`)**: Map alternatives to the **Coproduct/Sum (`A + B`)**, implemented using the `|` operator in Bison rules.
- **Guards (`p && q`)**: Map combined admission conditions to the **Product/Meet (`p × q`)**.
- **Loops/Repetition**: Map imperative loops to **Least Fixpoints** via grammar recursion (`X: ε | X token`).
- **Protocols**: Map open/close requirements (e.g., brackets, transaction boundaries) to **Monoidal Bracketing**, utilizing the coherence of string diagrams to ensure balanced structures.
- **Failure**: Map `return error` to a distinguished **Failure Alternative** (e.g., `error` production or specific abort path).

### Technical Directives:
- Relate the **LALR(1)** shift-reduce strategy to the reduction of monoidal alphabets.
- Discuss how the **YYEOF** or termination symbols act as the categorical unit (I).
- Emphasize the **Mechanism vs. Policy** invariant: Bison provides the shift-reduce mechanism, while the refactored grammar defines the syntactic policy.
