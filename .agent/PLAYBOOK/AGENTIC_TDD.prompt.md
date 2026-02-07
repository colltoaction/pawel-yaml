# Life is Fair: TDD Protocol

Source of truth: `/home/widip/.agent/PLAYBOOK/tdd/life-is-fair.yaml`

## Mantra
Every day, writing code using TDD, life is fair.

## Core Idea
TDD makes development predictable and manageable by verifying each step before moving on.
Complexity is handled incrementally through disciplined, test-backed progress.

## Practices
1. **Baby Steps**
   Never take a step larger than you can verify.
2. **Tests as Design**
   Design APIs from the consumer point of view using tests first.
3. **Minimal Implementation**
   Write only the simplest code required to make the failing test pass.
4. **Continuous Refactoring**
   Improve structure and remove duplication while keeping tests green.
5. **Organic Emergence**
   Build complex systems by composing robust, small parts.

## Process
1. **RED**: Write a failing test.
2. **GREEN**: Make it pass in the simplest way.
3. **REFACTOR**: Improve structure with tests still green.
4. **REPEAT**: Take the next baby step.

## Significance
Even large architectures can be built from scratch with disciplined TDD when progress is incremental and verified.
