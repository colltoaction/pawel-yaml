# Build System Strategy & Guide

## Overview
The `pawel-yaml` build system is a TDD-aware architecture designed to preserve test state and artifacts while allowing for rapid, granular rebuilds of the parser and lexer.

## Directory Structure
```
build/
├── src/          ← Generated parser/lexer (CLEANED by make clean)
├── inc/          ← Generated headers (CLEANED by make clean)
├── bin/          ← Compiled binary (CLEANED by make clean)
├── lib/          ← External deps (yaml-test-suite, etc.) (PRESERVED)
├── tmp/          ← Test artifacts, scratchpad (PRESERVED)
└── log/          ← Build logs, chaos results (PRESERVED)
```

## Effective Make Targets

### Build & Clean
- `make`: Build parser and lexer.
- `make setup`: Initialize official YAML test suites (yaml-test-suite, yaml-runtimes, yaml-play).
- `make clean`: **TDD-Safe.** Removes generated sources, headers, and binaries but **preserves** test artifacts in `build/tmp/` and external libraries in `build/lib/`.
- `make deepclean`: Full reset. Deletes the entire `build/` directory.
- `make clean-parser`: Targeted clean of parser-related artifacts.
- `make clean-lexer`: Targeted clean of lexer-related artifacts.

### Validation
- `make chaos`: Executes parser grammar validation (necessity analysis of alternatives).
- `make lexing`: Executes lexer token validation (necessity analysis of rules).
- `make tdd`: Triggers test discovery and lists available tests.

## TDD Integration
The build system is integrated with the `Agentic TDD Protocol`:
1. **RED**: Identify failing test and use `make clean && make` to verify the failure without losing discovery data.
2. **GREEN**: Modify code and rebuild. Artifacts in `build/tmp/` help debug specific inputs.
3. **VERIFY**: Run `make chaos` and `make lexing` to ensure no dead code or regressions were introduced.

## Troubleshooting
- **Stale Parser/Lexer**: If changes aren't reflecting, use `make clean-parser` or `make clean-lexer`.
- **Infrastructure Issues**: Use `make deepclean && make setup` to restore a pristine environment.
