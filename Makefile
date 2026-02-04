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

# Generated parser files
YAML_TAB_C = $(GEN_SRC_DIR)/yaml.tab.c
YAML_TAB_H = $(GEN_INC_DIR)/yaml.tab.h
YAML_LEX_C = $(GEN_SRC_DIR)/yaml.lex.c

RML_TAB_C = $(GEN_SRC_DIR)/rml.tab.c
RML_TAB_H = $(GEN_INC_DIR)/rml.tab.h
RML_LEX_C = $(GEN_SRC_DIR)/rml.lex.c

# TDD & testing artifacts
TMP_DIR = $(BUILD_DIR)/tmp
LOG_DIR = $(BUILD_DIR)/log

OBJS = $(BUILD_DIR)/yaml.tab.o $(BUILD_DIR)/yaml.lex.o \
       $(BUILD_DIR)/rml.tab.o $(BUILD_DIR)/rml.lex.o \
       $(BUILD_DIR)/main.o

TARGET = $(BIN_DIR)/pawel-yaml

all: directories $(TARGET)

directories:
	mkdir -p $(BUILD_DIR) $(GEN_SRC_DIR) $(GEN_INC_DIR) $(BIN_DIR) $(LIB_DIR) $(TMP_DIR) $(LOG_DIR)

# Stage 1: YAML Parser
$(YAML_TAB_C) $(YAML_TAB_H): $(SRC_DIR)/yaml.y
	$(BISON) -d -o $(YAML_TAB_C) --defines=$(YAML_TAB_H) $(SRC_DIR)/yaml.y

$(YAML_LEX_C): $(SRC_DIR)/yaml.l $(YAML_TAB_H)
	$(FLEX) -o $(YAML_LEX_C) $(SRC_DIR)/yaml.l

# Stage 2: RML Parser
$(RML_TAB_C) $(RML_TAB_H): $(SRC_DIR)/rml.y
	$(BISON) -d -o $(RML_TAB_C) --defines=$(RML_TAB_H) $(SRC_DIR)/rml.y

$(RML_LEX_C): $(SRC_DIR)/rml.l $(RML_TAB_H)
	$(FLEX) -o $(RML_LEX_C) $(SRC_DIR)/rml.l

$(TARGET): $(OBJS)
	$(CC) $(OBJS) -o $(TARGET)

$(BUILD_DIR)/yaml.tab.o: $(YAML_TAB_C)
	$(CC) $(CFLAGS) -c $(YAML_TAB_C) -o $@

$(BUILD_DIR)/yaml.lex.o: $(YAML_LEX_C)
	$(CC) $(CFLAGS) -c $(YAML_LEX_C) -o $@

$(BUILD_DIR)/rml.tab.o: $(RML_TAB_C)
	$(CC) $(CFLAGS) -c $(RML_TAB_C) -o $@

$(BUILD_DIR)/rml.lex.o: $(RML_LEX_C)
	$(CC) $(CFLAGS) -c $(RML_LEX_C) -o $@

$(BUILD_DIR)/main.o: $(SRC_DIR)/main.c $(YAML_TAB_H) $(RML_TAB_H)
	$(CC) $(CFLAGS) -c $(SRC_DIR)/main.c -o $@

clean: clean-build

clean-build:
	rm -rf $(GEN_SRC_DIR) $(GEN_INC_DIR) $(BIN_DIR)
	rm -f $(BUILD_DIR)/*.o

deepclean:
	rm -rf $(BUILD_DIR)

# TDD Targets
test-event: directories
	@echo "Compiling yaml_event unit tests..."
	$(BISON) -d -o $(BUILD_DIR)/src/yaml_event.tab.c --defines=$(GEN_INC_DIR)/yaml_event.tab.h src/yaml_event.y
	$(CC) $(CFLAGS) -c $(BUILD_DIR)/src/yaml_event.tab.c -o $(BUILD_DIR)/yaml_event.tab.o
	$(CC) $(CFLAGS) -g test_yaml_event.c $(BUILD_DIR)/yaml_event.tab.o -o test_yaml_event

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
