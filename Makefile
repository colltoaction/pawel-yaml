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
PARSERS = yaml yaml_event rml

# Generated parser files (derived from PARSERS)
YAML_TAB_C = $(GEN_SRC_DIR)/yaml.tab.c
YAML_TAB_H = $(GEN_INC_DIR)/yaml.tab.h
YAML_LEX_C = $(GEN_SRC_DIR)/yaml.lex.c

RML_TAB_C = $(GEN_SRC_DIR)/rml.tab.c
RML_TAB_H = $(GEN_INC_DIR)/rml.tab.h
RML_LEX_C = $(GEN_SRC_DIR)/rml.lex.c

# Object files (derived from PARSERS)
PARSER_OBJS = $(BUILD_DIR)/yaml.tab.o $(BUILD_DIR)/yaml.lex.o \
              $(BUILD_DIR)/yaml_event.tab.o $(BUILD_DIR)/yaml_event.lex.o \
              $(BUILD_DIR)/rml.tab.o $(BUILD_DIR)/rml.lex.o

# TDD & testing artifacts
TMP_DIR = $(BUILD_DIR)/tmp
LOG_DIR = $(BUILD_DIR)/log

# Custom C source files (Stage 2: Event parser)
CUSTOM_OBJS = $(BUILD_DIR)/yaml_event_parser.o

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

$(BUILD_DIR)/main.o: $(SRC_DIR)/main.c $(YAML_TAB_H) $(RML_TAB_H)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/yaml_event_parser.o: $(SRC_DIR)/yaml_event_parser.c $(SRC_DIR)/yaml_event_parser.h
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

tdd: test-unit test-integration
	@echo ""
	@echo "✓ All TDD cycles complete!"

yaml-test-suite: $(SUITE_DIR) $(TARGET)
	@echo "Running YAML test suite..."
	@$(AGENT_DIR)/test_yaml_suite.sh

.PHONY: all clean clean-build deepclean directories yaml-test-suite tdd test-event test-unit test-integration test-discover
