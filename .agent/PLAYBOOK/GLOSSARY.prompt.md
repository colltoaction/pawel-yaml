# Project Glossary: Core Vocabulary & Abstractions

This glossary defines the technical terms and structural patterns utilized in the `pawel-yaml` project, ensuring consistent communication and architectural clarity.

---

## 🏗 Architectural Patterns

### **Abstraction**
A layer that hides implementation details to reduce complexity and allow for multiple implementations (e.g., `StringDiagram` implementations).

### **Decoupling**
The process of reducing interdependence between modules. We achieve this by refactoring "global contexts" into explicit dependency injection.

### **Internal Service**
A component that implements a standardized lifecycle (`init`, `start`, `shutdown`). All core parser components should be managed as Internal Services.

### **Repository Segregation**
The act of splitting monolithic data access interfaces into specialized, read-only or write-only views (Interface Segregation Principle).

### **SPI (Service Provider Interface)**
A mechanism for extensibility. In `pawel-yaml`, we use SPI-like patterns to load different RML evaluation strategies or presentation formats.

### **Snapshot**
A point-in-time, immutable view of the parser state or the RML morphism tree.

---

## 🛠 Engineering Verbs

### **Add**
Introduce new functionality, tests, or documentation.

### **Fix**
Address a bug or a failing test case in the TDD cycle.

### **Get Rid Of**
Ruthlessly remove obsolete code, unused variables, or "test-only" pollution.

### **Hook Up**
Connect a component to the system's event stream or lifecycle runner.

### **Introduce**
Establish a new abstraction, component, or design pattern.

### **Refactor**
Improve internal code structure without changing external behavior (Phase 3 of TDD).

### **Rework**
Perform a significant redesign of a core component or flow to align with architectural goals.

### **Segregate**
Split a fat interface or module into smaller, focused ones.

### **Support**
Extend current functionality to handle new YAML constructs or RML structures.

---

## 🎓 Project-Specific Terms

### **0% Dead-Code Architecture**
A guarantee that every line of grammar and lexer code is necessary, verified through Chaos Engineering.

### **Agentic TDD**
A specialized TDD protocol where every mutation is tool-verifiable and theory-aligned.

### **Chaos Engineering**
The practice of intentionally removing code to verify its impact on the test suite.

### **Macro Cycle**
A high-level refactoring sequence (e.g., "Future-Aware Refactoring") that operates on the project's history.

### **Morphism**
An RML structure representing a YAML fragment as a mapping in a monoidal category.

### **RML (Regular Monoidal Language)**
The theoretical foundation of the parser, mapping grammar to monoidal categories.
