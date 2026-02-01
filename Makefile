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
PARSER_TAB_C = $(GEN_SRC_DIR)/parser.tab.c
PARSER_TAB_H = $(GEN_INC_DIR)/parser.tab.h
LEX_YY_C = $(GEN_SRC_DIR)/lex.yy.c

# TDD & testing artifacts (preserved across clean)
TMP_DIR = $(BUILD_DIR)/tmp
LOG_DIR = $(BUILD_DIR)/log

OBJS = $(BUILD_DIR)/mrl.o $(BUILD_DIR)/main.o $(BUILD_DIR)/yaml_parser.o \
       $(BUILD_DIR)/parser.tab.o $(BUILD_DIR)/lex.yy.o

TARGET = $(BIN_DIR)/pawel-yaml

all: directories $(TARGET)

directories:
	mkdir -p $(BUILD_DIR) $(GEN_SRC_DIR) $(GEN_INC_DIR) $(BIN_DIR) $(LIB_DIR) $(TMP_DIR) $(LOG_DIR)

# Initialize submodules via cloning
setup: directories $(RUNTIMES_DIR) $(PLAY_DIR) $(SUITE_DIR)

$(RUNTIMES_DIR):
	git clone --depth 1 https://github.com/yaml/yaml-runtimes $@

$(PLAY_DIR):
	git clone --depth 1 https://github.com/yaml/yaml-play $@

$(SUITE_DIR):
	git clone --depth 1 https://github.com/yaml/yaml-test-suite $@

# Bison parser generation
$(PARSER_TAB_C) $(PARSER_TAB_H): $(SRC_DIR)/yaml.y $(SRC_DIR)/yaml_parser.h $(SRC_DIR)/mrl.h
	$(BISON) -d -o $(PARSER_TAB_C) --defines=$(PARSER_TAB_H) $(SRC_DIR)/yaml.y

# Flex lexer generation
$(LEX_YY_C): $(SRC_DIR)/lexer.l $(PARSER_TAB_H)
	$(FLEX) -o $(LEX_YY_C) $(SRC_DIR)/lexer.l

$(TARGET): $(OBJS)
	$(CC) $(OBJS) -o $(TARGET)

$(BUILD_DIR)/mrl.o: $(SRC_DIR)/mrl.c $(SRC_DIR)/mrl.h
	$(CC) $(CFLAGS) -c $(SRC_DIR)/mrl.c -o $(BUILD_DIR)/mrl.o

$(BUILD_DIR)/main.o: $(SRC_DIR)/main.c $(SRC_DIR)/mrl.h
	$(CC) $(CFLAGS) -c $(SRC_DIR)/main.c -o $(BUILD_DIR)/main.o

$(BUILD_DIR)/yaml_parser.o: $(SRC_DIR)/yaml_parser.c $(SRC_DIR)/yaml_parser.h $(SRC_DIR)/mrl.h $(PARSER_TAB_H)
	$(CC) $(CFLAGS) -c $(SRC_DIR)/yaml_parser.c -o $(BUILD_DIR)/yaml_parser.o

$(BUILD_DIR)/parser.tab.o: $(PARSER_TAB_C) $(PARSER_TAB_H) $(SRC_DIR)/yaml_parser.h $(SRC_DIR)/mrl.h
	$(CC) $(CFLAGS) -c $(PARSER_TAB_C) -o $(BUILD_DIR)/parser.tab.o

$(BUILD_DIR)/lex.yy.o: $(LEX_YY_C) $(PARSER_TAB_H)
	$(CC) $(CFLAGS) -c $(LEX_YY_C) -o $(BUILD_DIR)/lex.yy.o

clean: clean-build

clean-build:
	# Remove generated code and binaries, but preserve TDD artifacts
	rm -rf $(GEN_SRC_DIR) $(GEN_INC_DIR) $(BIN_DIR) $(LIB_DIR)
	rm -f $(BUILD_DIR)/*.o

# Deep clean: remove all build artifacts including test tracking
deepclean:
	rm -rf $(BUILD_DIR)

# Targeted clean for specific components
clean-parser:
	rm -f $(PARSER_TAB_C) $(PARSER_TAB_H) $(BUILD_DIR)/parser.tab.o

clean-lexer:
	rm -f $(LEX_YY_C) $(BUILD_DIR)/lex.yy.o

.PHONY: all setup clean clean-build deepclean clean-parser clean-lexer directories yaml-test-suite test-mrl

test-mrl: directories $(BUILD_DIR)/mrl.o tests/test_mrl.c
	$(CC) $(CFLAGS) $(BUILD_DIR)/mrl.o tests/test_mrl.c -o $(BUILD_DIR)/bin/test-mrl
	$(BUILD_DIR)/bin/test-mrl

yaml-test-suite: $(SUITE_DIR) $(TARGET)
	@PATH=$(BIN_DIR):$$PATH $(AGENT_DIR)/test_yaml_suite.sh

# Build pawel-yaml Docker image
docker-build-pawel: $(TARGET)
	docker build -t pawel-yaml:latest \
	  --build-arg BINARY=$(TARGET) \
	  -f Dockerfile.alpine .
