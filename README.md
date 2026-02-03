# Pawel-YAML: Regular Monoidal Languages (RML) Parser ⚛️

Adopt the theoretical framework of **Regular Monoidal Languages** to build a high-fidelity YAML parser. Implement using a reentrant Bison/Flex toolchain and a GLR (Generalized LR) algorithm.

---

## 📊 Status: Growing Parser Completeness
- **Baseline**: ~60% pass rate.
- **Engine**: Unified RML architecture in `src/mrl.y` and `src/mrl.l`.
- **Methodology**: 100% Agentic TDD with 0% dead-code architecture.

## 🚀 Accomplishments
- **Align Theory**: Map YAML structural elements to Monoidal Alphabet ($\Gamma$) and Grammar ($\Psi$).
- **Leverage GLR**: Handle structural ambiguities with Bison's GLR algorithm.
- **Enforce TDD**: Use a strict Red-Green-Refactor protocol for tool-verifiable progress.
- **Consolidate Design**: Rework the parser, RML logic, and CLI driver into a unified Internal Service.

## 🛠 Handbooks & Knowledge Base
The project knowledge base is organized within the [`.agent/`](.agent/) directory:

- 🏗 **[Engineering Handbook](.agent/ENGINEERING_HANDBOOK.md)**: TDD protocol and build system.
- 💡 **[Computing Inspiration](.agent/COMPUTING_INSPIRATION.md)**: Index of foundational computer science principles.
- 📕 **[Glossary](.agent/PLAYBOOK/GLOSSARY.md)**: Core vocabulary and engineering verbs.

## 📁 Internal Architecture
- **`src/mrl.y`**: Implementation of the Monoidal Grammar ($\Psi$) and RML logic.
- **`src/mrl.l`**: Implementation of the Monoidal Alphabet ($\Gamma$) and Lexer logic.
- **`.agent/tooling.sh`**: Centralized tool for TDD, Chaos Engineering, and health checks.

## ⚡ Quick Start
```bash
# Setup environments and test suites
make setup

# Build and run a specific test
./.agent/tooling.sh tdd:test <ID>

# Run full project health check
./.agent/tooling.sh check
```
