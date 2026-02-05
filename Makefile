# Regular Monoidal Languages (RML) Driver

CC = gcc
CFLAGS = -I./src -I$(GEN_INC_DIR) -Wall -g -Wno-unused-function
BISON = bison
FLEX = flex

SRC_DIR = src
BUILD_DIR = build
GEN_SRC_DIR = $(BUILD_DIR)/src
GEN_INC_DIR = $(BUILD_DIR)/inc
BIN_DIR = $(BUILD_DIR)/bin
LIB_DIR = $(BUILD_DIR)/lib
AGENT_DIR = .agent

# External Dependencies (YAML Test Suite)
RUNTIMES_DIR = $(LIB_DIR)/yaml-runtimes
PLAY_DIR = $(LIB_DIR)/yaml-play
SUITE_DIR = $(LIB_DIR)/yaml-test-suite

# Parser definitions: PARSERS = name1 name2
# Note: RML parser logic is embedded in yaml_event.y and rml.y grammar files
# but compiled as separate units with proper namespacing to avoid symbol conflicts
PARSERS = yaml yaml_event

# Generated parser files (derived from PARSERS)
YAML_TAB_C = $(GEN_SRC_DIR)/yaml.tab.c
YAML_TAB_H = $(GEN_INC_DIR)/yaml.tab.h
YAML_LEX_C = $(GEN_SRC_DIR)/yaml.lex.c

# Object files (derived from PARSERS)
PARSER_OBJS = $(BUILD_DIR)/yaml.tab.o $(BUILD_DIR)/yaml.lex.o \
              $(BUILD_DIR)/yaml_event.tab.o $(BUILD_DIR)/yaml_event.lex.o

# TDD & testing artifacts
TMP_DIR = $(BUILD_DIR)/tmp
LOG_DIR = $(BUILD_DIR)/log

# Custom C source files for refactored architecture
# - lexer_context.c: unified lexer state management
# - ir_builder.c: IR generation API
# - pipeline.c: 3-stage pipeline driver
CUSTOM_OBJS = $(BUILD_DIR)/lexer_context.o $(BUILD_DIR)/ir_builder.o $(BUILD_DIR)/pipeline.o

OBJS = $(PARSER_OBJS) $(BUILD_DIR)/main.o $(CUSTOM_OBJS)

TARGET = $(BIN_DIR)/pawel-yaml

all: directories $(TARGET)

directories:
	mkdir -p $(BUILD_DIR) $(GEN_SRC_DIR) $(GEN_INC_DIR) $(BIN_DIR) $(LIB_DIR) $(TMP_DIR) $(LOG_DIR)

# ============================================================================
# Parser Generation: Bison & Flex
# Pattern: Each parser NAME produces:
#   - $(GEN_SRC_DIR)/NAME.tab.c + $(GEN_INC_DIR)/NAME.tab.h (from NAME.y)
#   - $(GEN_SRC_DIR)/NAME.lex.c (from NAME.l, depends on .tab.h)
# ============================================================================

$(GEN_SRC_DIR)/%.tab.c $(GEN_INC_DIR)/%.tab.h: $(SRC_DIR)/%.y
	$(BISON) -d -o $(GEN_SRC_DIR)/$*.tab.c --defines=$(GEN_INC_DIR)/$*.tab.h $<

$(GEN_SRC_DIR)/%.lex.c: $(SRC_DIR)/%.l $(GEN_INC_DIR)/%.tab.h
	$(FLEX) -o $@ $<

# ============================================================================
# Object Compilation: Generic pattern rule
# ============================================================================

$(BUILD_DIR)/%.o: $(GEN_SRC_DIR)/%.c
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/yaml.tab.o: $(GEN_SRC_DIR)/yaml.tab.c $(GEN_INC_DIR)/yaml_event.tab.h
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/main.o: $(SRC_DIR)/main.c $(YAML_TAB_H)
	$(CC) $(CFLAGS) -c $< -o $@


$(BUILD_DIR)/lexer_context.o: $(SRC_DIR)/lexer_context.c $(SRC_DIR)/lexer_context.h
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/ir_builder.o: $(SRC_DIR)/ir_builder.c $(SRC_DIR)/ir_builder.h
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/pipeline.o: $(SRC_DIR)/pipeline.c $(SRC_DIR)/pipeline.h
	$(CC) $(CFLAGS) -c $< -o $@

# ============================================================================
# Linking
# ============================================================================

$(TARGET): $(OBJS)
	$(CC) $(OBJS) -o $(TARGET)

# ============================================================================
# Cleanup
# ============================================================================

clean: clean-build

clean-build:
	rm -rf $(GEN_SRC_DIR) $(GEN_INC_DIR) $(BIN_DIR)
	rm -f $(BUILD_DIR)/*.o

deepclean:
	rm -rf $(BUILD_DIR)

# ============================================================================
# TDD Targets: Red-Green-Refactor-Verify Test-Driven Development
# ============================================================================

test-event: directories
	@echo "Compiling yaml_event unit tests..."
	$(BISON) -d -o $(BUILD_DIR)/src/yaml_event.tab.c --defines=$(GEN_INC_DIR)/yaml_event.tab.h src/yaml_event.y
	$(CC) $(CFLAGS) -c $(BUILD_DIR)/src/yaml_event.tab.c -o $(BUILD_DIR)/yaml_event.tab.o
	$(CC) $(CFLAGS) -g test_yaml_event.c test_yaml_event_stubs.c $(BUILD_DIR)/yaml_event.tab.o -o test_yaml_event

test-unit: test-event
	@echo "Running unit tests..."
	@./test_yaml_event

test-integration: $(TARGET) $(SUITE_DIR)
	@echo "Running integration tests against YAML test suite..."
	@python3 test_yaml_suite.py

test-discover:
	@$(AGENT_DIR)/tdd_harness.sh discover

# Comprehensive full test suite verification (all 351 tests)
test-full: $(TARGET)
	@echo "═══════════════════════════════════════════════════════"
	@echo "Running comprehensive YAML test suite (all 351 tests)..."
	@echo "═══════════════════════════════════════════════════════"
	@$(AGENT_DIR)/stage4_full_verification.sh

# Alias for backward compatibility and convenience
test: test-full

tdd: test-unit test-integration
	@echo ""
	@echo "✓ All TDD cycles complete!"

yaml-test-suite: $(SUITE_DIR) $(TARGET)
	@echo "Running YAML test suite..."
	@$(AGENT_DIR)/test_yaml_suite.sh

# ============================================================================
# Valgrind Memory Validation Targets
# ============================================================================

# Quick valgrind check with simple YAML input
valgrind: $(TARGET)
	@echo "Running valgrind memory check (simple test)..."
	@echo "key: value" | valgrind --leak-check=full --show-leak-kinds=all \
		--track-origins=yes --error-exitcode=1 $(TARGET) 2>&1 | tee $(LOG_DIR)/valgrind_simple.log
	@echo ""
	@echo "✓ Valgrind check complete. See $(LOG_DIR)/valgrind_simple.log for details."

# Comprehensive valgrind check with multiple test cases
# Note: Only checks for memory leaks, not application validation errors
valgrind-full: $(TARGET)
	@echo "═══════════════════════════════════════════════════════"
	@echo "Running comprehensive valgrind memory checks..."
	@echo "═══════════════════════════════════════════════════════"
	@mkdir -p $(LOG_DIR)
	@passed=0; failed=0; \
	for test_case in "key: value" "- item1\n- item2" "{a: 1, b: 2}" "[1, 2, 3]" "---\nkey: value\n..."; do \
		echo "Testing: $$test_case"; \
		valgrind_log=$$(mktemp); \
		if echo -e "$$test_case" | valgrind --leak-check=full --show-leak-kinds=all \
			--track-origins=yes --error-exitcode=42 $(TARGET) > /dev/null 2>"$$valgrind_log"; then \
			echo "  ✓ PASS (no memory leaks)"; \
			passed=$$((passed + 1)); \
		else \
			exit_code=$$?; \
			if [ $$exit_code -eq 42 ]; then \
				echo "  ✗ FAIL (memory leak detected)"; \
				failed=$$((failed + 1)); \
			else \
				echo "  ✓ PASS (no memory leaks, validation error ok)"; \
				passed=$$((passed + 1)); \
			fi; \
		fi; \
		rm -f "$$valgrind_log"; \
	done; \
	echo ""; \
	echo "Results: $$passed passed, $$failed failed"; \
	if [ $$failed -eq 0 ]; then \
		echo "✓ All valgrind checks passed!"; \
	else \
		echo "✗ Memory leaks detected. Run 'make valgrind' for details."; \
		exit 1; \
	fi

# Valgrind check on yaml-test-suite samples
valgrind-suite: $(TARGET) $(SUITE_DIR)
	@echo "Running valgrind on yaml-test-suite samples..."
	@mkdir -p $(LOG_DIR)
	@find $(SUITE_DIR) -name "*.yaml" -type f | head -20 | while read yaml_file; do \
		echo "Checking: $$yaml_file"; \
		valgrind --leak-check=full --error-exitcode=1 $(TARGET) < "$$yaml_file" > /dev/null 2>&1 || \
			echo "  ✗ Memory issue in $$yaml_file"; \
	done
	@echo "✓ Suite valgrind check complete."

# Summary check: just report if there are any leaks (no detailed output)
valgrind-summary: $(TARGET)
	@echo "Quick valgrind leak summary..."
	@if echo "key: value" | valgrind --leak-check=full --error-exitcode=1 $(TARGET) > /dev/null 2>&1; then \
		echo "✓ No memory leaks detected"; \
	else \
		echo "✗ Memory leaks detected. Run 'make valgrind' for details."; \
		exit 1; \
	fi

.PHONY: all clean clean-build deepclean directories yaml-test-suite tdd test-event test-unit test-integration test-discover valgrind valgrind-full valgrind-suite valgrind-summary
