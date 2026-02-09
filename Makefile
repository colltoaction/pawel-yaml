# YAML Compilation Pipeline
SHELL = /bin/sh

# Installation
BUILD = ./build
BINDIR = $(BUILD)/bin
BUILDSRCDIR = $(BUILD)/src
BUILDINCDIR = $(BUILD)/inc
BUILD_OBJDIR = $(BUILD)/obj
VPATH = src:$(BUILDSRCDIR):$(BUILDINCDIR)

# Build
CC = gcc
LEX = flex
YACC = bison
CFLAGS = -Wall -pedantic -g -I$(BUILDINCDIR) -Isrc
YFLAGS = -d
LFLAGS = -w

# Generated files
# TODO $(wildcard BUILD_OBJDIR/*.o)
OBJECTS = $(BUILD_OBJDIR)/main.o $(BUILD_OBJDIR)/scanning.lex.o $(BUILD_OBJDIR)/parsing.tab.o $(BUILD_OBJDIR)/composition.lex.o $(BUILD_OBJDIR)/composition.tab.o
BINTARGET = $(BUILD)/bin/pawel-yaml

# Rules
all: $(BINTARGET)

directories:
	@mkdir -p $(BUILD) $(BUILD)/bin $(BUILDSRCDIR) $(BUILDINCDIR) $(BUILD_OBJDIR)

# Grammar gen tabs
$(BUILDSRCDIR)/%.tab.c $(BUILDINCDIR)/%.tab.h: src/%.y directories
	$(YACC) $(YFLAGS) -o $(BUILDSRCDIR)/$*.tab.c $<

# Grammar gen lex
LEXTARGETS = $(patsubst src/%.l, $(BUILDSRCDIR)/%.lex.c, $(wildcard src/*.l))
lex: $(LEXTARGETS)

$(BUILDSRCDIR)/%.lex.c: src/%.l directories
	$(LEX) $(LFLAGS) -o $@ $<

$(BUILDSRCDIR)/scanning.lex.c: $(BUILDINCDIR)/parsing.tab.h
$(BUILDSRCDIR)/composition.lex.c: $(BUILDINCDIR)/composition.tab.h

# Rule for compiling .c to .o in build
$(BUILD_OBJDIR)/main.o: src/main.c directories
	$(CC) $(CFLAGS) -Werror -c $< -o $@

# Rule for compiling .c to .o in build
$(BUILD_OBJDIR)/%.o: $(BUILDSRCDIR)/%.c directories
	$(CC) $(CFLAGS) -Wno-unused-function -Wno-unused-variable -Wno-error=cpp -c $< -o $@

$(BINTARGET): $(OBJECTS) directories
	$(CC) $(OBJECTS) -o $@

# Testing
check: $(BINTARGET)
	./$< < test.yaml > /dev/null
	@echo "✓ Basic sanity check passed"

setup: ensure-test-failures yaml-test-suite
	@echo "✓ Setup complete (harness prerequisites ready)"

ensure-test-failures:
	@test -f TEST_FAILURES.yaml || { \
		echo "ERROR: TEST_FAILURES.yaml is missing"; \
		exit 1; \
	}

yaml-test-suite:
	@mkdir -p build/lib
	@if [ ! -d build/lib/yaml-test-suite/src ]; then \
		echo "Installing yaml-test-suite into build/lib/yaml-test-suite"; \
		if [ -d build/lib/yaml-test-suite/.git ]; then \
			git -C build/lib/yaml-test-suite pull --ff-only; \
		else \
			git clone --depth 1 https://github.com/yaml/yaml-test-suite.git build/lib/yaml-test-suite; \
		fi; \
	fi
	@test -d build/lib/yaml-test-suite/src || { \
		echo "ERROR: yaml-test-suite not available at build/lib/yaml-test-suite/src"; \
		echo "Run: git clone https://github.com/yaml/yaml-test-suite.git build/lib/yaml-test-suite"; \
		exit 1; \
	}

fuzz-lexer: $(BINTARGET)
	ITERATIONS=$${ITERATIONS:-300} TIMEOUT_SEC=$${TIMEOUT_SEC:-2} ./lexer_fuzz_chaos.sh $${SEED:-1337}

fuzz-lexer-strict: $(BINTARGET)
	ITERATIONS=$${ITERATIONS:-300} TIMEOUT_SEC=$${TIMEOUT_SEC:-2} FAIL_ON_TIMEOUT=1 ./lexer_fuzz_chaos.sh $${SEED:-1337}

fuzz-lexer-replay: $(BINTARGET)
	TIMEOUT_SEC=$${TIMEOUT_SEC:-2} MODE=replay REPLAY_PATH=$${REPLAY_PATH:-build/log/lexer_fuzz_cases} ./lexer_fuzz_chaos.sh replay

fuzz-lexer-replay-strict: $(BINTARGET)
	TIMEOUT_SEC=$${TIMEOUT_SEC:-2} FAIL_ON_TIMEOUT=1 FAIL_ON_AMBIGUOUS=1 MODE=replay REPLAY_PATH=$${REPLAY_PATH:-build/log/lexer_fuzz_cases} ./lexer_fuzz_chaos.sh replay

# Cleanup
clean:
	rm -rf $(BUILD)

.PHONY: all directories check clean lex fuzz-lexer fuzz-lexer-strict fuzz-lexer-replay fuzz-lexer-replay-strict
.PHONY: setup ensure-test-failures yaml-test-suite
