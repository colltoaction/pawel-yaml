# YAML Compilation Pipeline (with timeout protection)
MAKE_WALL_TIMEOUT ?= 1200
SHELL := $(shell if command -v timeout >/dev/null 2>&1; then echo "timeout --foreground $(MAKE_WALL_TIMEOUT)s /bin/sh"; else echo "/bin/sh"; fi)

# Installation
BUILD = ./build
BINTARGET = $(BUILD)/bin/pawel-yaml
DETECT_ISSUES_PY = python3 tests/legacy/scripts/detect_issues.py
DETECT_ISSUES_TIMEOUT ?= 5.0
DETECT_ISSUES_WALL_TIMEOUT ?= 900
MAKE_WALL_TIMEOUT ?= 1200
FAILURES_FILE = tests/legacy/reports/TEST_FAILURES.yaml

SRC_MAKE = $(MAKE) -C src \
	BUILD_ROOT="$(abspath $(BUILD))"
SRC_DEPS = $(wildcard src/*.c src/*.h src/*.y src/*.l src/Makefile)

all: $(BINTARGET)

$(BINTARGET): $(SRC_DEPS)
	@set -e; \
	if command -v timeout >/dev/null 2>&1; then \
		timeout --foreground $(MAKE_WALL_TIMEOUT)s $(SRC_MAKE) all; \
	else \
		$(SRC_MAKE) all; \
	fi

directories:
	@set -e; \
	if command -v timeout >/dev/null 2>&1; then \
		timeout --foreground $(MAKE_WALL_TIMEOUT)s $(SRC_MAKE) directories; \
	else \
		$(SRC_MAKE) directories; \
	fi

lex:
	@set -e; \
	if command -v timeout >/dev/null 2>&1; then \
		timeout --foreground $(MAKE_WALL_TIMEOUT)s $(SRC_MAKE) lex; \
	else \
		$(SRC_MAKE) lex; \
	fi

# Testing
check: $(BINTARGET)
	./$< < tests/legacy/cases/test.yaml > /dev/null
	@echo "✓ Basic sanity check passed"

detect-issues: $(BINTARGET) yaml-test-suite
	@echo "Running issue detector; use TEST=<id> to limit scope or pass --timeout to adjust."
	@set -e; \
	if command -v timeout >/dev/null 2>&1; then \
		timeout --foreground $(DETECT_ISSUES_WALL_TIMEOUT)s \
			$(DETECT_ISSUES_PY) --timeout=$(DETECT_ISSUES_TIMEOUT) --max-total-seconds=$(DETECT_ISSUES_WALL_TIMEOUT) $(foreach tid,$(TEST),--test $(tid)); \
	else \
		$(DETECT_ISSUES_PY) --timeout=$(DETECT_ISSUES_TIMEOUT) --max-total-seconds=$(DETECT_ISSUES_WALL_TIMEOUT) $(foreach tid,$(TEST),--test $(tid)); \
	fi

setup: ensure-test-failures yaml-test-suite
	@echo "✓ Setup complete (harness prerequisites ready)"

ensure-test-failures:
	@test -f $(FAILURES_FILE) || { \
		echo "ERROR: $(FAILURES_FILE) is missing"; \
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
	@ls build/lib/yaml-test-suite/src/*.yaml >/dev/null 2>&1 || { \
		echo "ERROR: yaml-test-suite source directory exists but contains no *.yaml test files"; \
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
	@set -e; \
	if command -v timeout >/dev/null 2>&1; then \
		timeout --foreground $(MAKE_WALL_TIMEOUT)s $(SRC_MAKE) clean; \
	else \
		$(SRC_MAKE) clean; \
	fi
	@mkdir -p $(BUILD)
	rm -rf $(BUILD)/log $(BUILD)/tmp

.PHONY: all directories check detect-issues clean lex fuzz-lexer fuzz-lexer-strict fuzz-lexer-replay fuzz-lexer-replay-strict
.PHONY: setup ensure-test-failures yaml-test-suite
