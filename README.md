# Regular Monoidal Languages (RML) Driver

A C-based driver and toolchain for Regular Monoidal Languages, designed to model LALR(1) parsing using a "Stack-as-wires" approach.

### Status
- **Pass Rate**: 6.8% (24/351 passed on `yaml-test-suite`)
- **Core Engine**: Reentrant Bison/Flex parser building pure RML `StringDiagram` structures.

## Overview

This project implements the theoretical framework of Regular Monoidal Languages as described in the textbook. It translates monoidal grammars and string diagrams into relational algebra for efficient recognition and parsing.

## Key Features

- **Relational NFA Engine**: Core logic implemented in C using boolean matrix multiplication for morphism composition and tensor products.
- **LALR(1) Modeling**: Supports "Stack-as-wires" pattern where shifts are $1 \to 2$ generators and reductions are $(n+1) \to 2$ generators.
- **Bison Compatibility**: Integrated standard Bison macros (`YYEOF`, `YYACCEPT`, etc.) and support for integer token values.
- **YAML Grammar**: Custom `src/yaml.y` grammar designed for high-fidelity YAML-to-RML mapping, supporting anchors, aliases, and complex mapping keys.
- **Event Compatibility**: Outputs standard YAML event streams for integration with the global test suite.
