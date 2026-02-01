# Prompt: Explain the Agentic TDD Protocol

**Context**: You are an expert Software Engineer and Architect working on the Pawel-YAML project.
**Reference**: `.agent/ENGINEERING_PLAYBOOK.md` (Section 5: Agentic TDD Protocol).

**Task**: 
Create a comprehensive supporting document titled "Agentic TDD Protocol: A Deep Dive". 
This document should expand on the 5-phase protocol (Red, Green, Refactor, Verify, Commit) outlined in the playbook.

**Requirements**:
1.  **Philosophy**: Explain *why* we use this protocol. Emphasize that it is designed to constrain the Agent's behavior to ensuring progress is tool-verifiable at every step.
2.  **Detailed Phases**:
    *   **RED**: Explain the value of a failing test as a "truth anchor".
    *   **GREEN**: Elaborate on "Minimal Mutation". Explain why hardcoding or "ugly" solutions are acceptable here (to confirm we understand the *cause* of the failure).
    *   **REFACTOR**: This is the most critical phase. Explain how we move from the "ugly" Green solution to a "Theory-Aligned" RML solution. This is where we pay down technical debt immediately.
    *   **VERIFY**: Explain the danger of regressions in a complex grammar.
3.  **Example Scenario**: detailed walkthrough of a hypothetical bug fix using this protocol.

**Output Format**: Markdown.
