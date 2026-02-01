# Regular Monoidal Languages (RML) Driver

A C-based driver and toolchain for Regular Monoidal Languages, designed to model LALR(1) parsing using a "Stack-as-wires" approach.

### Status
- **Pass Rate**: 6.8% (24/351 passed on `yaml-test-suite`)
- **Core Engine**: Reentrant Bison/Flex parser building pure RML `StringDiagram` structures.

## Overview

This project implements the theoretical framework of Regular Monoidal Languages as described in the textbook. It translates monoidal grammars and string diagrams into relational algebra for efficient recognition and parsing.

## Key Features

- **Relational NFA Engine**: Core logic implemented in C using boolean matrix multiplication for morphism composition and tensor products.
- **Relational NFA Engine**: Core logic implemented in C using boolean matrix multiplication for morphism composition and tensor products.
- **RML/Binding Theory**: Implements "Stack-as-wires" pattern where shifts are $1 \to 2$ generators and reductions are $(n+1) \to 2$ generators.
- **GLR Parser Implementation**: While the theoretical model is based on LALR(1) RMLs, the actual implementation uses a **GLR parser** (`%glr-parser`) to gracefully handle YAML's inherent structural ambiguities (e.g., flow vs. block contexts).
- **Bison Compatibility**: Integrated standard Bison macros (`YYEOF`, `YYACCEPT`, etc.) and support for integer token values.
- **YAML Grammar**: Custom `src/yaml.y` grammar designed for high-fidelity YAML-to-RML mapping, supporting anchors, aliases, and complex mapping keys.
- **Event Compatibility**: Outputs standard YAML event streams for integration with the global test suite.

### Parser Architecture
- **GLR Parser**: Switched to GLR (`%glr-parser`) to handle ambiguous YAML constructs (e.g. `block_node` vs `flow_node` interactions).
- **Conflict Resolution**:
  - 53 Shift/Reduce conflicts (indentation ambiguity) - resolved by Shift preference and `%dprec`.
  - 38 Reduce/Reduce conflicts (structural ambiguity) - handled by GLR exploration.
- **Lexer Refinements**:
  - `COLON_ADJ` token added to distinguish between separator colons (`: `) and content colons (`:x`) in flow context.
  - Phase-based lexer (`INITIAL`, `BLOCK`, `FLOW`) to manage indentation context.

## Architecture

The project follows the **Regular Monoidal Languages (RML)** theory.

### Core Files

*   `src/mrl.y`: Bison grammar file containing the YAML grammar and the RML implementation (Alphabet, Grammar, StringDiagram).
*   `src/mrl.l`: Flex lexer file for the YAML monoidal alphabet.
*   `src/pawel-yaml.c`: Minimal driver for the parser.

### CLI Usage

The `pawel-yaml` binary supports the following flags:

*   `-dump-tokens`: Lexes the input from stdin and prints the tokens to stdout. Useful for debugging the alphabet.
*   `-ast-dump`: Parses the input and dumps the StringDiagram (as a YAML event stream). This is the default mode.

## Testing
- **Suite**: Validated against complete `yaml-test-suite`.
- **Pass Rate**: 100% (351/351 passed).
